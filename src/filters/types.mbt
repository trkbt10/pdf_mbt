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
pub(all) struct JpxImageData {
  width : Int
  height : Int
  num_components : Int
  bits_per_component : Int
  is_signed : Bool
  data : Bytes
} derive(Eq, Debug)

///|
priv struct DecodeParams {
  raw : @objects.PdfDictionary?
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
