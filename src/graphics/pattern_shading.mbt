///|
/// ISO 32000-2 8.7.4.1 Type 2 shading pattern dictionary.
/// A shading pattern is a Pattern colour value whose Shading entry defines a
/// smooth gradient fill; Matrix maps pattern space and ExtGState applies
/// temporary graphics state parameters while the pattern is painted.
pub(all) struct ShadingPattern {
  shading : ShadingResource
  matrix : GraphicsMatrix
  ext_gstate : @objects.PdfDictionary?
} derive(Eq, Debug)

///|
/// Named Shading resource used either by the sh operator or by a Type 2
/// shading pattern dictionary.
pub(all) enum ShadingResource {
  DirectShading(@objects.PdfName?, Shading)
  IndirectShading(@objects.PdfName?, @objects.ObjectId)
} derive(Eq, Debug)

///|
/// Entries common to all shading dictionaries from Table 77: ColorSpace,
/// Background, BBox, and AntiAlias.
pub(all) struct ShadingCommon {
  colour_space : ColourSpace
  background : Array[Double]?
  bbox : GraphicsRect?
  anti_alias : Bool
} derive(Eq, Debug)

///|
/// Parsed shading dictionary or stream dictionary. ShadingType selects the
/// geometry of the gradient fill, and the common entries describe the target
/// colour space and clipping/background behaviour.
pub(all) struct Shading {
  common : ShadingCommon
  kind : ShadingKind
} derive(Eq, Debug)

///|
/// ISO 32000-2 8.7.4.5.1 shading types selected by ShadingType.
/// Type 1 is function-based, Type 2 is axial, Type 3 is radial, Types 4 and 5
/// are Gouraud-shaded triangle meshes, Type 6 is a Coons patch mesh, and Type
/// 7 is a tensor-product patch mesh.
pub(all) enum ShadingKind {
  FunctionBased(FunctionBasedShading)
  Axial(AxialShading)
  Radial(RadialShading)
  FreeFormMesh(FreeFormMeshShading)
  LatticeMesh(LatticeMeshShading)
  CoonsPatchMesh(CoonsPatchMeshShading)
  TensorPatchMesh(TensorPatchMeshShading)
} derive(Eq, Debug)

///|
/// ISO 32000-2 8.7.4.5.2 Type 1 function-based shading.
/// The Domain rectangle is mapped by Matrix into the target coordinate space,
/// and the required Function defines the colour at every point in the domain.
/// This shading type is rejected with an Indexed colour space.
pub(all) struct FunctionBasedShading {
  domain : Array[Double]
  matrix : GraphicsMatrix
  function : @objects.PdfObject
} derive(Eq, Debug)

///|
/// ISO 32000-2 8.7.4.5.3 Type 2 axial shading.
/// Coords stores the starting and ending axis coordinates; Domain provides
/// the parametric variable t; Function maps t to colour components; Extend
/// controls whether boundary colours continue past either endpoint. A
/// coincident axis is recorded so nothing is painted by renderers.
pub(all) struct AxialShading {
  coords : Array[Double]
  domain : Array[Double]
  function : @objects.PdfObject
  extend_start : Bool
  extend_end : Bool
  coincident_axis : Bool
} derive(Eq, Debug)

///|
pub(all) struct RadialShading {
  coords : Array[Double]
  domain : Array[Double]
  function : @objects.PdfObject
  extend_start : Bool
  extend_end : Bool
} derive(Eq, Debug)

///|
pub(all) struct FreeFormMeshShading {
  bits_per_coordinate : Int
  bits_per_component : Int
  bits_per_flag : Int
  decode : Array[Double]
  function : @objects.PdfObject?
  summary : MeshSummary
} derive(Eq, Debug)

///|
pub(all) struct LatticeMeshShading {
  bits_per_coordinate : Int
  bits_per_component : Int
  vertices_per_row : Int
  decode : Array[Double]
  function : @objects.PdfObject?
  summary : MeshSummary
} derive(Eq, Debug)

///|
pub(all) struct CoonsPatchMeshShading {
  bits_per_coordinate : Int
  bits_per_component : Int
  bits_per_flag : Int
  decode : Array[Double]
  function : @objects.PdfObject?
  summary : PatchMeshSummary
} derive(Eq, Debug)

///|
/// ISO 32000-2 8.7.4.5.8 Type 7 tensor-product patch mesh shading.
/// Table 85 data values encode a 4-by-4 tensor of 16 control points, four
/// corner colours, and edge flags whose nonzero values reuse the shared edge
/// from the previous patch.
pub(all) struct TensorPatchMeshShading {
  bits_per_coordinate : Int
  bits_per_component : Int
  bits_per_flag : Int
  decode : Array[Double]
  function : @objects.PdfObject?
  summary : PatchMeshSummary
} derive(Eq, Debug)

///|
/// Reports whether the shading pattern temporarily changes graphics state.
pub fn ShadingPattern::uses_temporary_graphics_state(
  self : ShadingPattern,
) -> Bool {
  if self.ext_gstate is Some(dict) && dict.length() > 0 {
    true
  } else {
    self.matrix != GraphicsMatrix::identity()
  }
}

///|
/// Reports whether the shading kind is encoded as mesh or patch data.
pub fn ShadingKind::is_mesh_based(self : ShadingKind) -> Bool {
  match self {
    FreeFormMesh(_) | LatticeMesh(_) => true
    CoonsPatchMesh(_) | TensorPatchMesh(_) => true
    FunctionBased(_) | Axial(_) | Radial(_) => false
  }
}

///|
/// Resolves a Shading resource by name from the Shading subdictionary.
/// Direct dictionaries and streams are parsed as shading dictionaries; indirect
/// references are preserved for the caller to resolve.
pub fn resolve_shading_resource(
  resources : @content.ContentResources,
  name : @objects.PdfName,
  offset : Int64,
) -> ShadingResource raise PdfGraphicsError {
  let object = try
    resources.lookup_resource(@content.ResourceCategory::Shading, name)
  catch {
    error => raise PdfGraphicsError::ContentFailure(error)
  } noraise {
    value => value
  }
  match object {
    None =>
      raise PdfGraphicsError::ResourceFailure(
        offset,
        "missing Shading resource " + name.to_text(),
      )
    Some(value) =>
      parse_shading_object(
        Some(name),
        value,
        ColourDefaults::from_resources(resources, offset),
        offset,
      )
  }
}

///|
/// Parses a Type 2 shading pattern dictionary from ISO 32000-2 Table 75.
/// The required Shading entry supplies the gradient fill, Matrix defaults to
/// identity, and ExtGState is retained as temporary graphics state parameters.
pub fn parse_shading_pattern_dictionary(
  dict : @objects.PdfDictionary,
  defaults : ColourDefaults,
  offset : Int64,
) -> ShadingPattern raise PdfGraphicsError {
  require_type_marker(dict, b"Pattern", offset, "Pattern")
  let pattern_type = require_integer_value(
    required_entry(dict, b"PatternType", offset),
    offset,
    "PatternType",
  )
  if pattern_type != 2L {
    raise graphics_resource_error(
      offset, "shading pattern PatternType must be 2",
    )
  }
  let shading = parse_shading_object(
    None,
    required_entry(dict, b"Shading", offset),
    defaults,
    offset,
  )
  let ext_gstate = match optional_entry(dict, b"ExtGState") {
    Some(value) => Some(require_dictionary_value(value, offset, "ExtGState"))
    None => None
  }
  ShadingPattern::{
    shading,
    matrix: optional_graphics_matrix(dict, offset, "Shading pattern Matrix"),
    ext_gstate,
  }
}

///|
/// Parses a shading object from a dictionary, stream, or indirect reference.
/// Shading dictionaries may be simple dictionaries for Types 1 through 3 or
/// stream dictionaries with descriptive data for mesh Types 4 through 7.
pub fn parse_shading_object(
  name : @objects.PdfName?,
  object : @objects.PdfObject,
  defaults : ColourDefaults,
  offset : Int64,
) -> ShadingResource raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Ref(object_id) =>
      ShadingResource::IndirectShading(name, object_id)
    @objects.PdfObject::Dictionary(dict) =>
      ShadingResource::DirectShading(
        name,
        parse_shading_dictionary(dict, None, defaults, offset),
      )
    @objects.PdfObject::Stream(stream) =>
      ShadingResource::DirectShading(
        name,
        parse_shading_dictionary(stream.dict, Some(stream), defaults, offset),
      )
    _ =>
      raise graphics_resource_error(
        offset, "Shading resource must be a dictionary, stream, or reference",
      )
  }
}

///|
fn parse_shading_dictionary(
  dict : @objects.PdfDictionary,
  stream : @objects.PdfStream?,
  defaults : ColourDefaults,
  offset : Int64,
) -> Shading raise PdfGraphicsError {
  let shading_type = require_integer_value(
    required_entry(dict, b"ShadingType", offset),
    offset,
    "ShadingType",
  )
  if shading_type < 1L || shading_type > 7L {
    raise graphics_resource_error(offset, "ShadingType must be in range 1..7")
  }
  let colour_space = parse_shading_colour_space(
    required_entry(dict, b"ColorSpace", offset),
    defaults,
    offset,
  )
  let function = optional_entry(dict, b"Function")
  validate_shading_indexed_rules(shading_type, colour_space, function, offset)
  let common = ShadingCommon::{
    colour_space,
    background: parse_shading_background(dict, colour_space, offset),
    bbox: optional_graphics_rect(dict, b"BBox", offset, "Shading BBox"),
    anti_alias: optional_bool_entry(
      dict, b"AntiAlias", false, offset, "AntiAlias",
    ),
  }
  Shading::{
    common,
    kind: parse_shading_kind(
      shading_type, dict, stream, colour_space, function, offset,
    ),
  }
}

///|
fn parse_shading_colour_space(
  object : @objects.PdfObject,
  defaults : ColourDefaults,
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  let space = parse_colour_space_object(object, defaults, offset)
  match space {
    Pattern(_) =>
      raise graphics_resource_error(
        offset, "Shading ColorSpace cannot be Pattern",
      )
    _ => space
  }
}

///|
fn validate_shading_indexed_rules(
  shading_type : Int64,
  space : ColourSpace,
  function : @objects.PdfObject?,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  match space {
    Indexed(_) =>
      if shading_type <= 3L || function is Some(_) {
        raise graphics_resource_error(
          offset, "Indexed ColorSpace is not permitted for this shading",
        )
      }
    _ => ()
  }
}

///|
fn parse_shading_background(
  dict : @objects.PdfDictionary,
  space : ColourSpace,
  offset : Int64,
) -> Array[Double]? raise PdfGraphicsError {
  match optional_entry(dict, b"Background") {
    None => None
    Some(value) => {
      let components = require_number_array_value(
        value,
        space.component_count(),
        offset,
        "Background",
      )
      Some(components)
    }
  }
}

///|
fn parse_shading_kind(
  shading_type : Int64,
  dict : @objects.PdfDictionary,
  stream : @objects.PdfStream?,
  space : ColourSpace,
  function : @objects.PdfObject?,
  offset : Int64,
) -> ShadingKind raise PdfGraphicsError {
  if shading_type == 1L {
    ShadingKind::FunctionBased(
      parse_function_based_shading(dict, function, offset),
    )
  } else if shading_type == 2L {
    ShadingKind::Axial(parse_axial_shading(dict, function, offset))
  } else if shading_type == 3L {
    ShadingKind::Radial(parse_radial_shading(dict, function, offset))
  } else {
    let mesh_stream = match stream {
      Some(value) => value
      None =>
        raise graphics_resource_error(
          offset, "mesh shading types 4 through 7 must be stream objects",
        )
    }
    parse_mesh_shading_kind(
      shading_type, dict, mesh_stream, space, function, offset,
    )
  }
}

///|
fn parse_function_based_shading(
  dict : @objects.PdfDictionary,
  function : @objects.PdfObject?,
  offset : Int64,
) -> FunctionBasedShading raise PdfGraphicsError {
  FunctionBasedShading::{
    domain: optional_number_array_value(
      dict,
      b"Domain",
      4,
      [0.0, 1.0, 0.0, 1.0],
      offset,
      "Domain",
    ),
    matrix: optional_graphics_matrix(dict, offset, "Function shading Matrix"),
    function: require_shading_function(function, offset),
  }
}

///|
fn parse_axial_shading(
  dict : @objects.PdfDictionary,
  function : @objects.PdfObject?,
  offset : Int64,
) -> AxialShading raise PdfGraphicsError {
  let coords = require_number_array_value(
    required_entry(dict, b"Coords", offset),
    4,
    offset,
    "Coords",
  )
  AxialShading::{
    coords,
    domain: optional_number_array_value(
      dict,
      b"Domain",
      2,
      [0.0, 1.0],
      offset,
      "Domain",
    ),
    function: require_shading_function(function, offset),
    extend_start: optional_extend(dict, offset)[0],
    extend_end: optional_extend(dict, offset)[1],
    coincident_axis: coords[0] == coords[2] && coords[1] == coords[3],
  }
}

///|
fn parse_radial_shading(
  dict : @objects.PdfDictionary,
  function : @objects.PdfObject?,
  offset : Int64,
) -> RadialShading raise PdfGraphicsError {
  let coords = require_number_array_value(
    required_entry(dict, b"Coords", offset),
    6,
    offset,
    "Coords",
  )
  if coords[2] < 0.0 || coords[5] < 0.0 {
    raise graphics_resource_error(
      offset, "radial shading radii must be nonnegative",
    )
  }
  RadialShading::{
    coords,
    domain: optional_number_array_value(
      dict,
      b"Domain",
      2,
      [0.0, 1.0],
      offset,
      "Domain",
    ),
    function: require_shading_function(function, offset),
    extend_start: optional_extend(dict, offset)[0],
    extend_end: optional_extend(dict, offset)[1],
  }
}

///|
fn require_shading_function(
  function : @objects.PdfObject?,
  offset : Int64,
) -> @objects.PdfObject raise PdfGraphicsError {
  match function {
    Some(value) => value
    None =>
      raise graphics_resource_error(
        offset, "shading Function entry is required",
      )
  }
}

///|
fn optional_extend(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Array[Bool] raise PdfGraphicsError {
  match optional_entry(dict, b"Extend") {
    None => [false, false]
    Some(value) => {
      let values = require_array_value(value, offset, "Extend")
      if values.length() != 2 {
        raise graphics_resource_error(
          offset, "Extend must contain two booleans",
        )
      }
      [
        require_bool_value(values[0], offset, "Extend"),
        require_bool_value(values[1], offset, "Extend"),
      ]
    }
  }
}
