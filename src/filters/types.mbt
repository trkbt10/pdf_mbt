///|
/// Normalized ISO stream filter names used by the public filter pipeline.
///
/// The filter decoder shall decode RunLengthDecode streams per 7.4.5. When
/// the length byte is in the range 0 to 127, the filter decoder copies the
/// next length + 1 bytes literally. When the length byte is in the range 129
/// to 255, the filter decoder replicates the next single byte 257 - length
/// times. When the length byte is 128, the filter decoder treats it as the
/// end-of-data EOD marker.
pub(all) enum FilterName {
  ASCIIHexDecode
  ASCII85Decode
  FlateDecode
  LZWDecode
  RunLengthDecode
  DCTDecode
  CCITTFaxDecode
  JPXDecode
  Unsupported(String)
}

///|
pub fn FilterName::to_text(self : FilterName) -> String {
  match self {
    ASCIIHexDecode => "ASCIIHexDecode"
    ASCII85Decode => "ASCII85Decode"
    FlateDecode => "FlateDecode"
    LZWDecode => "LZWDecode"
    RunLengthDecode => "RunLengthDecode"
    DCTDecode => "DCTDecode"
    CCITTFaxDecode => "CCITTFaxDecode"
    JPXDecode => "JPXDecode"
    Unsupported(name) => name
  }
}

///|
/// Reports whether this filter is one of the supported ISO stream filters.
pub fn FilterName::is_supported(self : FilterName) -> Bool {
  match self {
    Unsupported(_) => false
    _ => true
  }
}

///|
/// Reports whether this normalized filter name is JPXDecode.
///
/// JPXDecode JPEG 2000 filter integration decoded sample coverage uses this
/// method as the public marker that the filter type exposes JPX awareness.
/// Unsupported filter names remain false even when their text was parsed from
/// a stream dictionary.
pub fn FilterName::is_jpx(self : FilterName) -> Bool {
  match self {
    JPXDecode => true
    _ => false
  }
}

///|
/// Reports whether this filter normally decodes image sample streams.
pub fn FilterName::is_image_filter(self : FilterName) -> Bool {
  match self {
    DCTDecode | CCITTFaxDecode | JPXDecode => true
    _ => false
  }
}

///|
/// Reports whether this filter emits binary image or compressed byte data
/// rather than ASCII-armored stream bytes.
pub fn FilterName::is_binary_filter(self : FilterName) -> Bool {
  match self {
    ASCIIHexDecode | ASCII85Decode => false
    FlateDecode | LZWDecode | RunLengthDecode => true
    DCTDecode | CCITTFaxDecode | JPXDecode => true
    Unsupported(_) => false
  }
}

///|
pub struct DecodeParams {
  raw : @objects.PdfDictionary?
}

///|
/// Returns the positive Columns DecodeParms value for image filters, applying
/// the filter-specific default when DecodeParms is absent or omits Columns.
pub fn DecodeParams::columns(
  self : DecodeParams,
  filter_name : String,
  default : Int,
) -> Int raise PdfFilterError {
  if default <= 0 {
    raise PdfFilterError::InvalidDecodeParms(
      filter_name, "Columns default must be a positive integer",
    )
  }
  let value = read_integer_parameter(filter_name, self.raw, "Columns", default)
  if value <= 0 {
    raise PdfFilterError::InvalidDecodeParms(
      filter_name, "Columns must be a positive integer",
    )
  }
  value
}

///|
struct FilterSpec {
  name : FilterName
  params : DecodeParams
}

///|
fn FilterSpec::new(
  name : FilterName,
  raw : @objects.PdfDictionary?,
) -> FilterSpec {
  FilterSpec::{ name, params: DecodeParams::{ raw, } }
}

///|
/// Returns the normalized filter name carried by a parsed filter spec.
pub fn FilterSpec::filter_name(self : FilterSpec) -> FilterName {
  match self.name {
    Unsupported(name) => FilterName::Unsupported(name)
    name => name
  }
}

///|
/// Returns the DecodeParms wrapper carried by a parsed filter spec.
pub fn FilterSpec::decode_params(self : FilterSpec) -> DecodeParams {
  let params = self.params
  DecodeParams::{ raw: params.raw }
}

///|
/// Reports whether this filter is one of the two ASCII armoring filters.
pub fn FilterName::is_ascii_filter(self : FilterName) -> Bool {
  match self {
    ASCIIHexDecode | ASCII85Decode => true
    FlateDecode | LZWDecode | RunLengthDecode => false
    DCTDecode | CCITTFaxDecode | JPXDecode => false
    Unsupported(_) => false
  }
}

///|
/// Reports whether DecodeParms can affect row predictor handling.
pub fn FilterName::uses_predictor_params(self : FilterName) -> Bool {
  match self {
    FlateDecode | LZWDecode => true
    ASCIIHexDecode | ASCII85Decode | RunLengthDecode => false
    DCTDecode | CCITTFaxDecode | JPXDecode => false
    Unsupported(_) => false
  }
}

///|
/// Reports whether raw DecodeParms were supplied for the filter.
pub fn DecodeParams::has_raw_dictionary(self : DecodeParams) -> Bool {
  match self.raw {
    Some(dict) => dict.length() > 0
    None => false
  }
}

///|
/// Reports whether this DecodeParms wrapper carries no parameter dictionary
/// entries and therefore leaves decoder defaults in effect.
pub fn DecodeParams::uses_decoder_defaults(self : DecodeParams) -> Bool {
  match self.raw {
    Some(dict) => dict.length() == 0
    None => true
  }
}

///|
/// Reports whether the parsed filter spec has non-empty DecodeParms.
pub fn FilterSpec::has_decode_params(self : FilterSpec) -> Bool {
  let params = self.decode_params()
  if params.has_raw_dictionary() {
    true
  } else {
    false
  }
}
