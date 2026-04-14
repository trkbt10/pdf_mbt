///|
/// Typed diagnostics for PDF encryption dictionary parsing, authentication,
/// authorization, and byte transformation.
pub(all) suberror PdfEncryptionError {
  CryptoFailure(@crypto.PdfCryptoError)
  MalformedEncryptionDictionary(String, String)
  MissingCredentials
  InvalidCredentials
  UnsupportedSecurityHandler(String)
  UnsupportedAlgorithm(String)
  AuthorizationFailure(String)
  PermissionValidationFailure(String)
  PasswordPreprocessingFailure(@common_data.PdfCommonDataError)
} derive(Eq, Debug)

///|
pub fn wrap_crypto_error(error : @crypto.PdfCryptoError) -> PdfEncryptionError {
  PdfEncryptionError::CryptoFailure(error)
}
