///|
fn initialize_encryption(file : PdfFile) -> Unit raise PdfReaderError {
  match file.trailer.encrypt {
    Some(encrypt_id) => {
      let encrypt_object = file.load_object(encrypt_id)
      let encrypt_dict = match encrypt_object {
        @objects.PdfObject::Dictionary(dict) => dict
        @objects.PdfObject::Null =>
          raise PdfReaderError::EncryptionError(
            @encryption.PdfEncryptionError::MalformedEncryptionDictionary(
              "Encrypt", "Encrypt dictionary object is missing",
            ),
          )
        _ =>
          raise PdfReaderError::EncryptionError(
            @encryption.PdfEncryptionError::MalformedEncryptionDictionary(
              "Encrypt", "Encrypt entry must resolve to a dictionary",
            ),
          )
      }
      let file_id = encryption_file_identifier(file.trailer.id)
      let authenticated = try
        @encryption.authenticate(encrypt_dict, b"", file_id)
      catch {
        error => raise PdfReaderError::EncryptionError(error)
      } noraise {
        result => result
      }
      match authenticated {
        Some(context) => file.encryption = Some(context)
        None =>
          raise PdfReaderError::EncryptionError(
            @encryption.PdfEncryptionError::InvalidCredentials,
          )
      }
    }
    None => ()
  }
}

///|
fn encryption_file_identifier(
  file_id : PdfFileId?,
) -> @encryption.FileIdentifier {
  match file_id {
    Some(value) =>
      @encryption.FileIdentifier::{
        first: value.first,
        second: Some(value.second),
      }
    None => @encryption.FileIdentifier::{ first: b"", second: None }
  }
}

///|
pub fn PdfDocument::is_encrypted(self : PdfDocument) -> Bool {
  self.file.is_encrypted()
}

///|
pub fn PdfDocument::permissions(self : PdfDocument) -> PdfPermissions {
  self.file.permissions()
}
