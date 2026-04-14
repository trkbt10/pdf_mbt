///|
pub(all) suberror PdfReaderError {
  InvalidHeader(Int64, String)
  MissingTailMarker(String)
  InvalidXref(Int64, String)
  InvalidTrailer(Int64, String)
  InvalidObjectStream(Int64, String)
  InvalidObjectLocation(@objects.ObjectId, String)
  UnsupportedFilter(Int64, String)
  DecodeStreamError(Int64, @filters.PdfFilterError)
  EncryptionError(@encryption.PdfEncryptionError)
  PrevChainCycle(Int64)
  ParseObjectError(Int64, @objects.PdfParseError)
} derive(Eq, Debug)
