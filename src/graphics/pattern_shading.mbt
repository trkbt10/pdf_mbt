///|
pub(all) struct ShadingPattern {
  shading : ShadingResource
  matrix : GraphicsMatrix
  ext_gstate : @objects.PdfDictionary?
} derive(Eq, Debug)

///|
pub(all) enum ShadingResource {
  DirectShading(@objects.PdfName?, Shading)
  IndirectShading(@objects.PdfName?, @objects.ObjectId)
} derive(Eq, Debug)

///|
pub(all) struct ShadingCommon {
  colour_space : ColourSpace
  background : Array[Double]?
  bbox : GraphicsRect?
  anti_alias : Bool
} derive(Eq, Debug)

///|
pub(all) struct Shading {
  common : ShadingCommon
  kind : ShadingKind
} derive(Eq, Debug)

///|
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
pub(all) struct FunctionBasedShading {
  domain : Array[Double]
  matrix : GraphicsMatrix
  function : @objects.PdfObject
} derive(Eq, Debug)

///|
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
pub(all) struct TensorPatchMeshShading {
  bits_per_coordinate : Int
  bits_per_component : Int
  bits_per_flag : Int
  decode : Array[Double]
  function : @objects.PdfObject?
  summary : PatchMeshSummary
} derive(Eq, Debug)

///|
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
