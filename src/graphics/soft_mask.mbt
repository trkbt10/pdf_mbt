///|
pub(all) enum SoftMaskSubtype {
  AlphaSoftMask
  LuminositySoftMask
} derive(Eq, Debug)

///|
pub(all) enum SoftMaskTransferFunction {
  IdentityTransferFunction
  DirectTransferFunction(@objects.PdfObject)
  UnresolvedTransferFunction(@objects.ObjectId)
} derive(Eq, Debug)

///|
pub(all) enum SoftMaskGroupSource {
  DirectSoftMaskGroup(FormXObject)
  UnresolvedSoftMaskGroup(@objects.ObjectId)
} derive(Eq, Debug)

///|
pub(all) struct SoftMaskDictionary {
  subtype : SoftMaskSubtype
  group : SoftMaskGroupSource
  backdrop_colour : Array[Double]
  transfer_function : SoftMaskTransferFunction
  raw : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum SoftMaskSource {
  NoSoftMask
  AlphaMask(SoftMaskDictionary)
  LuminosityMask(SoftMaskDictionary)
  UnresolvedSoftMask(@objects.ObjectId)
} derive(Eq, Debug)

///|
pub(all) struct EstablishedSoftMask {
  source : SoftMaskSource
  established_ctm : GraphicsMatrix?
} derive(Eq, Debug)

///|
pub fn SoftMaskSource::none() -> SoftMaskSource {
  SoftMaskSource::NoSoftMask
}

///|
pub fn EstablishedSoftMask::none() -> EstablishedSoftMask {
  EstablishedSoftMask::{
    source: SoftMaskSource::NoSoftMask,
    established_ctm: None,
  }
}

///|
pub fn SoftMaskSource::establish(
  self : SoftMaskSource,
  ctm : GraphicsMatrix,
) -> EstablishedSoftMask {
  match self {
    NoSoftMask => EstablishedSoftMask::none()
    _ => EstablishedSoftMask::{ source: self, established_ctm: Some(ctm) }
  }
}

///|
pub fn EstablishedSoftMask::copy(
  self : EstablishedSoftMask,
) -> EstablishedSoftMask {
  EstablishedSoftMask::{
    source: self.source,
    established_ctm: self.established_ctm,
  }
}

///|
pub fn SoftMaskSource::from_pdf_object(
  object : @objects.PdfObject,
  offset : Int64,
) -> SoftMaskSource raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Name(name) =>
      if name == pdf_name(b"None") {
        SoftMaskSource::NoSoftMask
      } else {
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "SMask name must be None",
        )
      }
    @objects.PdfObject::Dictionary(dict) =>
      soft_mask_from_dictionary(dict, offset)
    @objects.PdfObject::Ref(id) => SoftMaskSource::UnresolvedSoftMask(id)
    @objects.PdfObject::Null => SoftMaskSource::NoSoftMask
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "SMask must be None, a dictionary, or an indirect reference",
      )
  }
}

///|
fn soft_mask_from_dictionary(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> SoftMaskSource raise PdfGraphicsError {
  let subtype = parse_soft_mask_subtype(dict, offset)
  let group = parse_soft_mask_group(required_entry(dict, b"G", offset), offset)
  let backdrop_colour = parse_soft_mask_backdrop(
    dict,
    soft_mask_group_component_count(group),
    offset,
  )
  let transfer_function = parse_soft_mask_transfer(dict)
  let mask = SoftMaskDictionary::{
    subtype,
    group,
    backdrop_colour,
    transfer_function,
    raw: dict,
  }
  match subtype {
    AlphaSoftMask => SoftMaskSource::AlphaMask(mask)
    LuminositySoftMask => SoftMaskSource::LuminosityMask(mask)
  }
}

///|
fn parse_soft_mask_subtype(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> SoftMaskSubtype raise PdfGraphicsError {
  let name = require_name_value(
    required_entry(dict, b"S", offset),
    offset,
    "SMask S",
  )
  if name == pdf_name(b"Alpha") {
    SoftMaskSubtype::AlphaSoftMask
  } else if name == pdf_name(b"Luminosity") {
    SoftMaskSubtype::LuminositySoftMask
  } else {
    raise PdfGraphicsError::InvalidGraphicsState(
      offset, "SMask S must be Alpha or Luminosity",
    )
  }
}

///|
fn parse_soft_mask_group(
  object : @objects.PdfObject,
  offset : Int64,
) -> SoftMaskGroupSource raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Ref(id) =>
      SoftMaskGroupSource::UnresolvedSoftMaskGroup(id)
    @objects.PdfObject::Stream(stream) => {
      let form = validate_form_xobject(None, stream, offset)
      match form.group {
        Some(group) =>
          match group.transparency {
            Some(_) => SoftMaskGroupSource::DirectSoftMaskGroup(form)
            None =>
              raise PdfGraphicsError::InvalidGraphicsState(
                offset, "SMask G Form XObject must declare a Transparency group",
              )
          }
        None =>
          raise PdfGraphicsError::InvalidGraphicsState(
            offset, "SMask G must be a transparency group Form XObject",
          )
      }
    }
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "SMask G must be a Form XObject stream or indirect reference",
      )
  }
}

///|
fn soft_mask_group_component_count(group : SoftMaskGroupSource) -> Int? {
  match group {
    DirectSoftMaskGroup(form) =>
      match form.group {
        Some(info) =>
          match info.transparency {
            Some(transparency) => transparency.component_count()
            None => None
          }
        None => None
      }
    UnresolvedSoftMaskGroup(_) => None
  }
}

///|
fn parse_soft_mask_backdrop(
  dict : @objects.PdfDictionary,
  component_count : Int?,
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  match optional_entry(dict, b"BC") {
    None => []
    Some(object) => {
      let values = require_array_value(object, offset, "SMask BC")
      if component_count is Some(count) {
        if values.length() != count {
          raise PdfGraphicsError::InvalidGraphicsState(
            offset, "SMask BC length must match the mask group colour space",
          )
        }
      }
      let numbers : Array[Double] = []
      for value in values {
        numbers.push(require_number_value(value, offset, "SMask BC"))
      }
      numbers
    }
  }
}

///|
fn parse_soft_mask_transfer(
  dict : @objects.PdfDictionary,
) -> SoftMaskTransferFunction {
  match optional_entry(dict, b"TR") {
    None => SoftMaskTransferFunction::IdentityTransferFunction
    Some(@objects.PdfObject::Name(name)) if name == pdf_name(b"Identity") =>
      SoftMaskTransferFunction::IdentityTransferFunction
    Some(@objects.PdfObject::Ref(id)) =>
      SoftMaskTransferFunction::UnresolvedTransferFunction(id)
    Some(value) => SoftMaskTransferFunction::DirectTransferFunction(value)
  }
}
