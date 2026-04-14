///|
pub(all) enum TransparencyGroupContext {
  FormTransparencyGroup
  PageTransparencyGroup
  PatternTransparencyGroup
} derive(Eq, Debug)

///|
pub(all) struct TransparencyGroup {
  blending_colour_space : ColourSpace?
  isolated : Bool
  knockout : Bool
  raw : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub fn parse_transparency_group_dictionary(
  dict : @objects.PdfDictionary,
  context : TransparencyGroupContext,
  offset : Int64,
) -> TransparencyGroup raise PdfGraphicsError {
  match optional_entry(dict, b"Type") {
    Some(type_value) => {
      let type_name = require_name_value(type_value, offset, "Group Type")
      if type_name != pdf_name(b"Group") {
        raise PdfGraphicsError::InvalidXObject(
          offset, "Group Type must be Group",
        )
      }
    }
    None => ()
  }
  let subtype = require_name_value(
    required_entry(dict, b"S", offset),
    offset,
    "Transparency group subtype",
  )
  if subtype != pdf_name(b"Transparency") {
    raise PdfGraphicsError::InvalidXObject(
      offset, "transparency group subtype must be Transparency",
    )
  }
  let space = optional_group_colour_space(dict, offset)
  let isolated = match context {
    PageTransparencyGroup => true
    _ => optional_group_bool(dict, b"I", false, offset, "I")
  }
  let knockout = match context {
    PageTransparencyGroup => false
    _ => optional_group_bool(dict, b"K", false, offset, "K")
  }
  TransparencyGroup::{
    blending_colour_space: space,
    isolated,
    knockout,
    raw: dict,
  }
}

///|
pub fn try_parse_transparency_group_dictionary(
  dict : @objects.PdfDictionary,
  context : TransparencyGroupContext,
  offset : Int64,
) -> TransparencyGroup? raise PdfGraphicsError {
  match optional_entry(dict, b"S") {
    Some(@objects.PdfObject::Name(name)) if name == pdf_name(b"Transparency") =>
      Some(parse_transparency_group_dictionary(dict, context, offset))
    Some(_) => None
    None => None
  }
}

///|
pub fn TransparencyGroup::component_count(self : TransparencyGroup) -> Int? {
  match self.blending_colour_space {
    Some(space) => Some(space.component_count())
    None => None
  }
}

///|
fn optional_group_colour_space(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> ColourSpace? raise PdfGraphicsError {
  match optional_entry(dict, b"CS") {
    None => None
    Some(object) => {
      let space = parse_colour_space_object(
        object,
        ColourDefaults::empty(),
        offset,
      )
      validate_transparency_group_colour_space(space, offset)
      Some(space)
    }
  }
}

///|
fn validate_transparency_group_colour_space(
  space : ColourSpace,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  match space {
    Device(_) | CalGray(_) | CalRGB(_) | Lab(_) | ICCBased(_) => ()
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "transparency group CS must be a device, CIE-based, or ICCBased colour space",
      )
  }
}

///|
fn optional_group_bool(
  dict : @objects.PdfDictionary,
  key : Bytes,
  default : Bool,
  offset : Int64,
  label : String,
) -> Bool raise PdfGraphicsError {
  match optional_entry(dict, key) {
    Some(value) => require_bool_value(value, offset, label)
    None => default
  }
}
