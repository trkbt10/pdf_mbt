///|
/// Typed diagnostics for the narrow crypto primitives used by PDF encryption.
pub(all) suberror PdfCryptoError {
  InvalidKey(String)
  InvalidBlockSize(String)
  InvalidIv(String)
  InvalidPadding(String)
  InvalidLength(String)
} derive(Eq, Debug)
