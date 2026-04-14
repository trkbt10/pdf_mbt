///|
/// Padding policy for AES modes used by PDF encryption.
pub(all) enum PaddingMode {
  PKCS7
  NoPadding
} derive(Eq, Debug)
