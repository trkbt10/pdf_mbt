///|
test "encryption diagnostics expose stable failure categories" {
  let malformed = PdfEncryptionError::MalformedEncryptionDictionary(
    "Filter", "expected name",
  )
  match malformed {
    MalformedEncryptionDictionary(field, reason) => {
      assert_eq(field, "Filter")
      assert_eq(reason, "expected name")
    }
    _ => fail("expected malformed dictionary category")
  }

  let missing = PdfEncryptionError::MissingCredentials
  match missing {
    MissingCredentials => ()
    _ => fail("expected missing credentials category")
  }

  let unsupported = PdfEncryptionError::UnsupportedSecurityHandler("PubSec")
  match unsupported {
    UnsupportedSecurityHandler(handler) => assert_eq(handler, "PubSec")
    _ => fail("expected unsupported handler category")
  }

  let crypto = wrap_crypto_error(@crypto.PdfCryptoError::InvalidKey("bad key"))
  match crypto {
    CryptoFailure(@crypto.PdfCryptoError::InvalidKey(reason)) =>
      assert_eq(reason, "bad key")
    _ => fail("expected wrapped crypto error")
  }
}
