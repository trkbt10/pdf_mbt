///|
priv enum FilterName {
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
fn FilterName::to_text(self : FilterName) -> String {
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
priv struct FilterSpec {
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
