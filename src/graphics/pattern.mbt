///|
pub(all) enum PatternPaintType {
  Coloured
  Uncoloured
} derive(Eq, Debug)

///|
pub(all) enum TilingType {
  ConstantSpacing
  NoDistortion
  ConstantSpacingFast
} derive(Eq, Debug)

///|
pub(all) struct TilingPattern {
  paint_type : PatternPaintType
  tiling_type : TilingType
  bbox : GraphicsRect
  x_step : Double
  y_step : Double
  resources : @objects.PdfDictionary
  matrix : GraphicsMatrix
  stream : @objects.PdfStream
} derive(Eq, Debug)

///|
pub(all) enum PatternDefinition {
  Tiling(TilingPattern)
  Shading(ShadingPattern)
} derive(Eq, Debug)

///|
pub(all) enum PatternResource {
  DirectPattern(@objects.PdfName, PatternDefinition)
  IndirectPattern(@objects.PdfName, @objects.ObjectId)
} derive(Eq, Debug)

///|
pub fn resolve_pattern_resource(
  resources : @content.ContentResources,
  name : @objects.PdfName,
  offset : Int64,
) -> PatternResource raise PdfGraphicsError {
  let object = try
    resources.lookup_resource(@content.ResourceCategory::Pattern, name)
  catch {
    error => raise PdfGraphicsError::ContentFailure(error)
  } noraise {
    value => value
  }
  match object {
    None =>
      raise PdfGraphicsError::ResourceFailure(
        offset,
        "missing Pattern resource " + name.to_text(),
      )
    Some(value) =>
      parse_pattern_object(
        name,
        value,
        ColourDefaults::from_resources(resources, offset),
        offset,
      )
  }
}

///|
pub fn parse_pattern_object(
  name : @objects.PdfName,
  object : @objects.PdfObject,
  defaults : ColourDefaults,
  offset : Int64,
) -> PatternResource raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Ref(object_id) =>
      PatternResource::IndirectPattern(name, object_id)
    @objects.PdfObject::Stream(stream) => {
      let pattern_type = pattern_type_from_dict(stream.dict, offset)
      if pattern_type != 1L {
        raise graphics_resource_error(
          offset, "stream Pattern resource must have PatternType 1",
        )
      }
      PatternResource::DirectPattern(
        name,
        PatternDefinition::Tiling(parse_tiling_pattern_stream(stream, offset)),
      )
    }
    @objects.PdfObject::Dictionary(dict) => {
      let pattern_type = pattern_type_from_dict(dict, offset)
      if pattern_type != 2L {
        raise graphics_resource_error(
          offset, "dictionary Pattern resource must have PatternType 2",
        )
      }
      PatternResource::DirectPattern(
        name,
        PatternDefinition::Shading(
          parse_shading_pattern_dictionary(dict, defaults, offset),
        ),
      )
    }
    _ =>
      raise graphics_resource_error(
        offset, "Pattern resource must be a stream, dictionary, or reference",
      )
  }
}

///|
fn pattern_type_from_dict(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Int64 raise PdfGraphicsError {
  require_type_marker(dict, b"Pattern", offset, "Pattern")
  let pattern_type = require_integer_value(
    required_entry(dict, b"PatternType", offset),
    offset,
    "PatternType",
  )
  if pattern_type != 1L && pattern_type != 2L {
    raise graphics_resource_error(offset, "PatternType must be 1 or 2")
  }
  pattern_type
}

///|
pub fn parse_tiling_pattern_stream(
  stream : @objects.PdfStream,
  offset : Int64,
) -> TilingPattern raise PdfGraphicsError {
  let pattern_type = pattern_type_from_dict(stream.dict, offset)
  if pattern_type != 1L {
    raise graphics_resource_error(
      offset, "tiling pattern PatternType must be 1",
    )
  }
  let paint_type = parse_pattern_paint_type(
    require_integer_value(
      required_entry(stream.dict, b"PaintType", offset),
      offset,
      "PaintType",
    ),
    offset,
  )
  let tiling_type = parse_tiling_type(
    require_integer_value(
      required_entry(stream.dict, b"TilingType", offset),
      offset,
      "TilingType",
    ),
    offset,
  )
  let x_step = require_number_value(
    required_entry(stream.dict, b"XStep", offset),
    offset,
    "XStep",
  )
  let y_step = require_number_value(
    required_entry(stream.dict, b"YStep", offset),
    offset,
    "YStep",
  )
  if x_step == 0.0 || y_step == 0.0 {
    raise graphics_resource_error(
      offset, "tiling pattern XStep and YStep must be nonzero",
    )
  }
  TilingPattern::{
    paint_type,
    tiling_type,
    bbox: required_graphics_rect(stream.dict, b"BBox", offset, "BBox"),
    x_step,
    y_step,
    resources: require_dictionary_value(
      required_entry(stream.dict, b"Resources", offset),
      offset,
      "Resources",
    ),
    matrix: optional_graphics_matrix(stream.dict, offset, "Pattern Matrix"),
    stream,
  }
}

///|
fn parse_pattern_paint_type(
  value : Int64,
  offset : Int64,
) -> PatternPaintType raise PdfGraphicsError {
  if value == 1L {
    PatternPaintType::Coloured
  } else if value == 2L {
    PatternPaintType::Uncoloured
  } else {
    raise graphics_resource_error(offset, "PaintType must be 1 or 2")
  }
}

///|
fn parse_tiling_type(
  value : Int64,
  offset : Int64,
) -> TilingType raise PdfGraphicsError {
  if value == 1L {
    TilingType::ConstantSpacing
  } else if value == 2L {
    TilingType::NoDistortion
  } else if value == 3L {
    TilingType::ConstantSpacingFast
  } else {
    raise graphics_resource_error(offset, "TilingType must be 1, 2, or 3")
  }
}

///|
pub fn validate_tiling_pattern_cell(
  pattern : TilingPattern,
  initial : GraphicsInitialState,
  offset : Int64,
) -> GraphicsProgram raise PdfGraphicsError {
  let decoded = try @filters.decode_stream(pattern.stream) catch {
    error => raise map_filter_error(offset, "tiling pattern cell", error)
  } noraise {
    bytes => bytes
  }
  let resources = @content.ContentResources::from_dictionary(pattern.resources)
  let content = try @content.parse_decoded_content(decoded, resources) catch {
    error => raise PdfGraphicsError::ContentFailure(error)
  } noraise {
    parsed => parsed
  }
  let restricted_initial = match pattern.paint_type {
    Coloured => initial
    Uncoloured =>
      GraphicsInitialState::{
        ctm: initial.ctm,
        initial_clip: initial.initial_clip,
        user_unit: initial.user_unit,
        page_rotate: initial.page_rotate,
        colour_restriction: ColourRestriction::UncolouredTilingPattern,
      }
  }
  interpret_content(content, restricted_initial)
}

///|
fn validate_pattern_selection(
  resource : PatternResource,
  space : ColourSpace,
  value : ColourValue,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  match resource {
    IndirectPattern(_, _) => ()
    DirectPattern(_, definition) =>
      match definition {
        Tiling(pattern) =>
          validate_tiling_pattern_selection(
            pattern.paint_type,
            space,
            value,
            offset,
          )
        Shading(_) =>
          validate_coloured_pattern_selection(
            space, value, offset, "shading pattern",
          )
      }
  }
}

///|
fn validate_tiling_pattern_selection(
  paint_type : PatternPaintType,
  space : ColourSpace,
  value : ColourValue,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  match paint_type {
    Coloured =>
      validate_coloured_pattern_selection(
        space, value, offset, "coloured tiling pattern",
      )
    Uncoloured =>
      match space {
        Pattern(params) =>
          match params.underlying {
            Some(_) => ()
            None =>
              raise PdfGraphicsError::BadOperand(
                offset, "uncoloured tiling pattern requires an underlying colour space",
              )
          }
        _ =>
          raise PdfGraphicsError::BadOperand(
            offset, "Pattern resource selection requires a Pattern colour space",
          )
      }
  }
}

///|
fn validate_coloured_pattern_selection(
  space : ColourSpace,
  value : ColourValue,
  offset : Int64,
  label : String,
) -> Unit raise PdfGraphicsError {
  match space {
    Pattern(params) =>
      match params.underlying {
        None =>
          if value.components.length() != 0 {
            raise PdfGraphicsError::BadOperand(
              offset,
              label + " must be selected without colour components",
            )
          }
        Some(_) =>
          raise PdfGraphicsError::BadOperand(
            offset,
            label + " requires a bare Pattern colour space",
          )
      }
    _ =>
      raise PdfGraphicsError::BadOperand(
        offset, "Pattern resource selection requires a Pattern colour space",
      )
  }
}
