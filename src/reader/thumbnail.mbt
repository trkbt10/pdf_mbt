///|
pub fn PdfPage::thumbnail(
  self : PdfPage,
) -> PdfThumbnail? raise PdfDocumentError {
  let owner = navigation_key(b"Thumb")
  match self.entry(owner) {
    Some(value) => {
      let stream = require_navigation_stream(
        self.file,
        value,
        owner,
        "page thumbnail",
      )
      Some(parse_thumbnail_stream(self.index(), stream, owner))
    }
    None => None
  }
}

///|
fn parse_thumbnail_stream(
  page_index : Int,
  stream : @objects.PdfStream,
  owner : @objects.PdfName,
) -> PdfThumbnail raise PdfDocumentError {
  PdfThumbnail::{
    page_index,
    width: thumbnail_required_positive_int(
      stream.dict,
      navigation_key(b"Width"),
      owner,
    ),
    height: thumbnail_required_positive_int(
      stream.dict,
      navigation_key(b"Height"),
      owner,
    ),
    color_space: thumbnail_color_space(
      stream.dict.get(navigation_key(b"ColorSpace")),
    ),
    bits_per_component: thumbnail_optional_positive_int(
      stream.dict.get(navigation_key(b"BitsPerComponent")),
      owner,
      "BitsPerComponent",
    ),
    decode: stream.dict.get(navigation_key(b"Decode")),
    raw_stream: stream,
  }
}

///|
fn thumbnail_required_positive_int(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  owner : @objects.PdfName,
) -> Int raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => {
      let number = navigation_int(value, owner, key.to_text())
      if number <= 0 {
        raise navigation_error(owner, key.to_text() + " must be positive")
      }
      number
    }
    None => raise navigation_error(owner, key.to_text() + " is required")
  }
}

///|
fn thumbnail_optional_positive_int(
  value : @objects.PdfObject?,
  owner : @objects.PdfName,
  label : String,
) -> Int? raise PdfDocumentError {
  match value {
    Some(object) => {
      let number = navigation_int(object, owner, label)
      if number <= 0 {
        raise navigation_error(owner, label + " must be positive")
      }
      Some(number)
    }
    None => None
  }
}

///|
fn thumbnail_color_space(value : @objects.PdfObject?) -> PdfThumbnailColorSpace {
  match value {
    Some(@objects.PdfObject::Name(name)) if name ==
      navigation_key(b"DeviceGray") => PdfThumbnailColorSpace::DeviceGray
    Some(@objects.PdfObject::Name(name)) if name == navigation_key(b"DeviceRGB") =>
      PdfThumbnailColorSpace::DeviceRGB
    Some(@objects.PdfObject::Name(name)) if name ==
      navigation_key(b"DeviceCMYK") => PdfThumbnailColorSpace::DeviceCMYK
    Some(@objects.PdfObject::Array(values)) =>
      if values.length() > 0 &&
        values[0] == @objects.PdfObject::Name(navigation_key(b"Indexed")) {
        PdfThumbnailColorSpace::Indexed
      } else {
        PdfThumbnailColorSpace::Other(@objects.PdfObject::Array(values))
      }
    Some(object) => PdfThumbnailColorSpace::Other(object)
    None => PdfThumbnailColorSpace::Absent
  }
}
