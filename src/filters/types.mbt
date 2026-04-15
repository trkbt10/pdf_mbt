///|
priv enum FilterName {
  ASCIIHexDecode
  ASCII85Decode
  FlateDecode
  LZWDecode
  RunLengthDecode
  DCTDecode
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
    Unsupported(name) => name
  }
}

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
