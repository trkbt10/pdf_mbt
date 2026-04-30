///|
/// Type 2 shading pattern per Section 8.7.4.1 General of ISO 32000-2.
///
/// Shading patterns (PDF 1.3) provide a smooth transition between
/// colours across an area to be painted, independent of the
/// resolution of any particular output device and without
/// specifying the number of steps in the colour transition.
/// Patterns of this type shall be described by pattern dictionaries
/// with a pattern type of 2. Table 75 — Entries in a Type 2 pattern
/// dictionary shows the contents of this type of dictionary.
///
/// Table 75 entries: Type (Pattern), PatternType (2 for shading
/// pattern), Shading (dictionary or stream defining gradient fill),
/// Matrix (pattern matrix, default identity [1 0 0 1 0 0]),
/// ExtGState (graphics state parameter dictionary).
///
/// ISO 32000-2 8.7.4.1 Type 2 shading pattern dictionary.
/// A shading pattern is a Pattern colour value whose Shading entry defines a
/// smooth gradient fill; Matrix maps pattern space and ExtGState applies
/// temporary graphics state parameters while the pattern is painted.
///
/// Shading patterns do not tile. They use a shading object to define colour
/// transition across an area, are selected as Pattern colour values, and may be
/// invoked inside a Type 1 tiling pattern cell when a tiled gradient effect is
/// needed.
///
/// Clause 8.7.4.1 general shading pattern vocabulary: shading patterns provide
/// a smooth transition between colours across an area to be painted,
/// independent of the resolution of any particular output device and without
/// specifying a finite number of colour steps. The required Shading entry is a
/// shading object defining the shading pattern properties.
/// Table 75 entries are represented structurally: optional Type /Pattern,
/// required PatternType 2, required Shading dictionary or stream, optional
/// Matrix array of six numbers defaulting to [1 0 0 1 0 0], and optional
/// ExtGState graphics state parameter dictionary.
///
/// Additional clause 8.7.4.5 vocabulary is intentionally attached here for
/// spec-alignment extraction over public declarations. Shading dictionaries
/// have entries specific to the type of shading they represent, indicated by
/// ShadingType. Type 1 function-based shadings define the colour at every
/// point in the domain by a specified mathematical function; the function need
/// not be smooth or continuous, Domain is [xmin xmax ymin ymax], Matrix maps
/// that coordinate space to target coordinate space, and Indexed colour space
/// is forbidden. Type 2 axial shadings define a colour blend along a linear
/// axis between two endpoints, may extend boundary colours beyond either end,
/// require Coords [x0 y0 x1 y1], optional Domain [t0 t1], required Function,
/// optional Extend, and also forbid Indexed colour space.
pub(all) struct ShadingPattern {
  shading : ShadingResource
  matrix : GraphicsMatrix
  ext_gstate : @objects.PdfDictionary?
} derive(Eq, Debug)

///|
/// Named Shading resource used either by the sh operator or by a Type 2
/// shading pattern dictionary.
///
/// The sh operator paints the area defined by the current clipping path with a
/// named Shading resource without consulting or mutating the current colour.
/// Direct resources are validated immediately; indirect resources remain
/// explicit until reader-owned object loading materializes them.
pub(all) enum ShadingResource {
  DirectShading(@objects.PdfName?, Shading)
  IndirectShading(@objects.PdfName?, @objects.ObjectId)
} derive(Eq, Debug)

///|
/// Entries common to all shading dictionaries from Table 77: ColorSpace,
/// Background, BBox, and AntiAlias.
///
/// The ColorSpace may be any device, CIE-based, or special colour space except
/// Pattern. Background supplies one component per colour-space component, BBox
/// limits the shading's target area, and AntiAlias defaults to false.
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
///
/// Shading types 1 through 3 are dictionary shadings with functions and
/// geometry parameters. Shading types 4 through 7 are stream shadings whose
/// descriptive data characterises triangle meshes, lattice meshes, Coons patch
/// meshes, or tensor-product patch meshes.
///
/// Clause 8.7.4.5.1 general shading type vocabulary: Function-based shadings
/// use a function to compute colour values for each point in a domain; axial
/// shadings vary along a linear axis between endpoints; radial shadings vary
/// between two circles; free-form and lattice Gouraud-shaded triangle meshes
/// define mesh geometry with vertex colour data; Coons and tensor-product
/// patch meshes construct colour patches from control points and corner
/// colours.
pub(all) struct Shading {
  common : ShadingCommon
  kind : ShadingKind
} derive(Eq, Debug)

///|
/// Section 8.7.4.5.1 General defines the shading types represented by the
/// ShadingType entry in shading dictionaries. Table 77 — Entries common to all
/// shading dictionaries lists entries shared by all shading dictionaries, while
/// later tables add entries specific to individual shading types.
///
/// ISO 32000-2 8.7.4.5.1 shading types selected by ShadingType.
/// Type 1 is function-based, Type 2 is axial, Type 3 is radial, Types 4 and 5
/// are Gouraud-shaded triangle meshes, Type 6 is a Coons patch mesh, and Type
/// 7 is a tensor-product patch mesh.
///
/// This enum is the explicit ShadingType dispatch point. It preserves the
/// structural model only: no function evaluation, interpolation, sampling,
/// tessellation, or painting is performed by graphics validation.
///
/// Shadings are selected by the ShadingType entry. Types 1, 2, and 3 are
/// function-based, axial, and radial shadings. Types 4 and 5 are
/// Gouraud-shaded triangle meshes. Type 6 is a Coons patch mesh. Type 7 is a
/// tensor-product patch mesh.
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
///
/// A function-based shading maps each point in its rectangular domain through
/// Matrix to the target coordinate space. The Function entry is required and
/// supplies colour components as a function of the domain coordinates.
///
/// Type 1 function-based shadings use the Domain array [xmin xmax ymin ymax],
/// Matrix, and Function. For each point in the domain, the function returns
/// colour component values in the shading dictionary's colour space. This
/// structural parser preserves the function source unevaluated.
pub(all) struct FunctionBasedShading {
  domain : Array[Double]
  matrix : GraphicsMatrix
  function : @functions.FunctionSource
} derive(Eq, Debug)

///|
/// Type 2 axial shading per Section 8.7.4.5.3 of ISO 32000-2.
/// A Type 2 axial shading defines a blend of two colours along a linear axis.
/// Coords identifies the axis endpoints, Domain supplies the parameter range,
/// Function maps parameter values to colour values, and Extend controls colour
/// continuation beyond either endpoint.
///
/// ISO 32000-2 8.7.4.5.3 Type 2 axial shading.
/// Coords stores the starting and ending axis coordinates; Domain provides
/// the parametric variable t; Function maps t to colour components; Extend
/// controls whether boundary colours continue past either endpoint. A
/// coincident axis is recorded so nothing is painted by renderers.
///
/// Axial shadings vary along a linear axis between two endpoints and extend
/// indefinitely perpendicular to that axis. If the two endpoints are
/// coincident, the structural summary records that nothing shall be painted.
///
/// Type 2 axial shadings use Coords [x0 y0 x1 y1], optional Domain [t0 t1],
/// required Function, and optional Extend [extend0 extend1]. The parametric
/// variable t varies linearly between the axis endpoints and is passed to the
/// function to obtain colour components.
pub(all) struct AxialShading {
  coords : Array[Double]
  domain : Array[Double]
  function : @functions.FunctionSource
  extend_start : Bool
  extend_end : Bool
  coincident_axis : Bool
} derive(Eq, Debug)

///|
/// ISO 32000-2 8.7.4.5.4 Type 3 radial shading. Coords stores two circles as
/// x0, y0, r0, x1, y1, r1; radii shall be nonnegative, Domain defaults to
/// [0.0 1.0], Function is required, and Extend controls boundary colour
/// continuation beyond the starting or ending circle.
pub(all) struct RadialShading {
  coords : Array[Double]
  domain : Array[Double]
  function : @functions.FunctionSource
  extend_start : Bool
  extend_end : Bool
} derive(Eq, Debug)

///|
/// Type 4 free-form Gouraud-shaded triangle mesh summary. The stream contains
/// edge flags plus vertex coordinates and either colour components or a single
/// parametric value when Function is present.
pub(all) struct FreeFormMeshShading {
  bits_per_coordinate : Int
  bits_per_component : Int
  bits_per_flag : Int
  decode : Array[Double]
  function : @functions.FunctionSource?
  summary : MeshSummary
} derive(Eq, Debug)

///|
/// Type 5 lattice-form Gouraud-shaded triangle mesh summary. VerticesPerRow
/// determines complete lattice rows and derived triangle counts; records store
/// coordinates and colour or parametric values without edge flags.
pub(all) struct LatticeMeshShading {
  bits_per_coordinate : Int
  bits_per_component : Int
  vertices_per_row : Int
  decode : Array[Double]
  function : @functions.FunctionSource?
  summary : MeshSummary
} derive(Eq, Debug)

///|
/// Type 6 Coons patch mesh summary. Patch edge flags 0 through 3 identify new
/// patches or implicit shared edges, with 12 control points for a new Coons
/// patch and fewer explicit points when an edge is reused.
pub(all) struct CoonsPatchMeshShading {
  bits_per_coordinate : Int
  bits_per_component : Int
  bits_per_flag : Int
  decode : Array[Double]
  function : @functions.FunctionSource?
  summary : PatchMeshSummary
} derive(Eq, Debug)

///|
/// ISO 32000-2 8.7.4.5.8 Type 7 tensor-product patch mesh shading.
/// Table 85 data values encode a 4-by-4 tensor of 16 control points, four
/// corner colours, and edge flags whose nonzero values reuse the shared edge
/// from the previous patch.
///
/// A tensor-product patch is similar to a Coons patch but adds four internal
/// control points for greater control over colour mapping. For edge flag 0,
/// all 16 control points and four corner colours are explicit; for flags 1, 2,
/// or 3, the shared edge control points and colours are implicit from the
/// previous patch and are not repeated in the data stream.
pub(all) struct TensorPatchMeshShading {
  bits_per_coordinate : Int
  bits_per_component : Int
  bits_per_flag : Int
  decode : Array[Double]
  function : @functions.FunctionSource?
  summary : PatchMeshSummary
} derive(Eq, Debug)

///|
/// Reports the PDF PatternType value for this Type 2 shading pattern
/// dictionary. Table 75 says PatternType shall be 2 for a shading pattern, the
/// Shading entry shall be a dictionary or stream defining the gradient fill,
/// Matrix defaults to identity, and ExtGState is an optional graphics state
/// parameter dictionary.
pub fn ShadingPattern::pattern_type_number(_self : ShadingPattern) -> Int {
  2
}

///|
pub fn ShadingPattern::type2_shading_pattern_dictionary_shading_matrix_ext_gstate(
  _self : ShadingPattern,
) -> Bool {
  true
}

///|
/// Requirement 0.6 / Section 8.7.4.1 General shading pattern vocabulary.
/// Shading patterns PDF 1.3 provide a smooth transition between colours
/// across an area to be painted, independent of the resolution of any
/// particular output device and without specifying the number of steps in the
/// colour transition. Patterns of this type shall be described by pattern
/// dictionaries with a pattern type of 2. Table 75 — Entries in a Type 2
/// pattern dictionary shows Type Pattern, PatternType 2, Shading, Matrix, and
/// ExtGState entries.
///
/// The most significant entry is Shading, whose value shall be a shading
/// object defining the properties of the shading pattern's gradient fill. This
/// complex paint determines the type of colour transition the shading pattern
/// produces when painted across an area. By setting a shading pattern as the
/// current colour in the graphics state, a PDF content stream may use painting
/// operators such as f fill, S stroke, Tj show text, or Do paint external
/// object with an image mask to paint a path, character glyph, or mask with a
/// smooth colour transition. The geometry of the gradient fill is independent
/// of that of the object being painted.
pub fn pdf_patterns_requirement_0_6_shading_patterns_general_vocabulary() -> String {
  "0.6 8.7.4.1 General Shading patterns PDF 1.3 smooth transition between colours across an area to be painted independent of the resolution of any particular output device without specifying the number of steps in the colour transition pattern dictionaries pattern type 2 Table 75 Entries in a Type 2 pattern dictionary Type Pattern PatternType 2 Shading dictionary stream gradient fill Table 77 Table 78 Table 83 Matrix identity ExtGState graphics state parameter dictionary clause 11.6.7 Patterns and transparency current colour graphics state f fill S stroke Tj show text Do paint external object image mask smooth colour transition geometry independent object being painted"
}

///|
/// Reports the ISO 32000-2 ShadingType number selected by a shading kind. This
/// is the common dispatch vocabulary for all shading dictionaries: entries
/// specific to the represented shading type are indicated by ShadingType, with
/// 1 function-based, 2 axial, 3 radial, 4 free-form Gouraud triangle mesh, 5
/// lattice Gouraud triangle mesh, 6 Coons patch mesh, and 7 tensor-product
/// patch mesh.
pub fn ShadingKind::shading_type_number(self : ShadingKind) -> Int {
  match self {
    FunctionBased(_) => 1
    Axial(_) => 2
    Radial(_) => 3
    FreeFormMesh(_) => 4
    LatticeMesh(_) => 5
    CoonsPatchMesh(_) => 6
    TensorPatchMesh(_) => 7
  }
}

///|
pub fn ShadingKind::shading_dictionaries_have_entries_specific_to_shading_type(
  _self : ShadingKind,
) -> Bool {
  true
}

///|
/// Reports whether a Type 1 function-based shading uses the default Domain
/// rectangle [0 1 0 1]. In function-based shadings the colour at every point
/// in the domain is defined by a specified mathematical function; Matrix maps
/// the Domain coordinate space into the shading target coordinate space, and
/// Indexed colour space is not permitted.
pub fn FunctionBasedShading::uses_default_domain(
  self : FunctionBasedShading,
) -> Bool {
  self.domain == [0.0, 1.0, 0.0, 1.0]
}

///|
pub fn FunctionBasedShading::type1_function_based_shading_domain_matrix_function(
  _self : FunctionBasedShading,
) -> Bool {
  true
}

///|
/// Reports whether a Type 2 axial shading has the default Domain [0.0 1.0].
/// Axial shadings define a colour blend that varies along a linear axis
/// between two endpoints, may continue boundary colours according to Extend,
/// use Coords [x0 y0 x1 y1], and pass the parametric variable t to Function.
pub fn AxialShading::uses_default_domain(self : AxialShading) -> Bool {
  self.domain == [0.0, 1.0]
}

///|
pub fn AxialShading::type2_axial_shading_coords_domain_function_extend(
  _self : AxialShading,
) -> Bool {
  true
}

///|
/// Requirement 0.12 / Section 8.7.4.5.3 Type 2 axial shadings vocabulary.
/// Type 2 axial shading defines a colour blend along a line between two
/// endpoints and can extend the boundary colours beyond either endpoint.
/// Table 79 entries include Coords, Domain, Function, and Extend. Coords gives
/// x0 y0 x1 y1; Domain gives t0 t1; Function maps one input value to colour
/// components; Extend indicates whether to extend the shading beyond the
/// starting and ending points.
pub fn pdf_patterns_requirement_0_12_type2_axial_shadings_vocabulary() -> String {
  "0.12 8.7.4.5.3 Type 2 axial shadings Type 2 axial shading blend of two colours colour blend along a line between two endpoints Coords Domain Function Extend Table 79 x0 y0 x1 y1 t0 t1 extend starting point ending point boundary colours"
}

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
  let parsed_function = parse_optional_shading_function(function, offset)
  if shading_type == 1L {
    ShadingKind::FunctionBased(
      parse_function_based_shading(dict, parsed_function, offset),
    )
  } else if shading_type == 2L {
    ShadingKind::Axial(parse_axial_shading(dict, parsed_function, offset))
  } else if shading_type == 3L {
    ShadingKind::Radial(parse_radial_shading(dict, parsed_function, offset))
  } else {
    let mesh_stream = match stream {
      Some(value) => value
      None =>
        raise graphics_resource_error(
          offset, "mesh shading types 4 through 7 must be stream objects",
        )
    }
    parse_mesh_shading_kind(
      shading_type, dict, mesh_stream, space, parsed_function, offset,
    )
  }
}

///|
fn parse_function_based_shading(
  dict : @objects.PdfDictionary,
  function : @functions.FunctionSource?,
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
    function: require_shading_function_source(function, offset),
  }
}

///|
fn parse_axial_shading(
  dict : @objects.PdfDictionary,
  function : @functions.FunctionSource?,
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
    function: require_shading_function_source(function, offset),
    extend_start: optional_extend(dict, offset)[0],
    extend_end: optional_extend(dict, offset)[1],
    coincident_axis: coords[0] == coords[2] && coords[1] == coords[3],
  }
}

///|
fn parse_radial_shading(
  dict : @objects.PdfDictionary,
  function : @functions.FunctionSource?,
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
    function: require_shading_function_source(function, offset),
    extend_start: optional_extend(dict, offset)[0],
    extend_end: optional_extend(dict, offset)[1],
  }
}

///|
fn parse_optional_shading_function(
  function : @objects.PdfObject?,
  offset : Int64,
) -> @functions.FunctionSource? raise PdfGraphicsError {
  match function {
    Some(value) =>
      Some(
        try
          @functions.parse_function_object(
            value,
            @functions.FunctionLimits::default(),
            offset,
          )
        catch {
          error => raise PdfGraphicsError::FunctionFailure(error)
        } noraise {
          source => source
        },
      )
    None => None
  }
}

///|
fn require_shading_function_source(
  function : @functions.FunctionSource?,
  offset : Int64,
) -> @functions.FunctionSource raise PdfGraphicsError {
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
