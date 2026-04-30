///|
fn dict_name(key : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(key)
}

///|
fn required_name(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field : String,
) -> @objects.PdfName raise PdfEncryptionError {
  match dict.get(dict_name(key)) {
    Some(@objects.PdfObject::Name(value)) => value
    Some(_) =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field, "entry must be a direct name object",
      )
    None =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field, "missing required entry",
      )
  }
}

///|
fn optional_name(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field : String,
) -> @objects.PdfName? raise PdfEncryptionError {
  match dict.get(dict_name(key)) {
    Some(@objects.PdfObject::Name(value)) => Some(value)
    Some(_) =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field, "entry must be a direct name object",
      )
    None => None
  }
}

///|
fn optional_integer(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field : String,
) -> Int64? raise PdfEncryptionError {
  match dict.get(dict_name(key)) {
    Some(@objects.PdfObject::Integer(value)) => Some(value)
    Some(_) =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field, "entry must be a direct integer object",
      )
    None => None
  }
}

///|
fn optional_dictionary(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field : String,
) -> @objects.PdfDictionary? raise PdfEncryptionError {
  match dict.get(dict_name(key)) {
    Some(@objects.PdfObject::Dictionary(value)) => Some(value)
    Some(_) =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field, "entry must be a direct dictionary object",
      )
    None => None
  }
}

///|
fn optional_string(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field : String,
) -> Bytes? raise PdfEncryptionError {
  match dict.get(dict_name(key)) {
    Some(@objects.PdfObject::String(value)) => Some(value)
    Some(_) =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field, "entry must be a direct byte string",
      )
    None => None
  }
}

///|
fn validate_key_length(
  cipher_version : CipherVersion,
  length_bits : Int,
) -> Unit raise PdfEncryptionError {
  match cipher_version {
    V1 =>
      if length_bits != 40 {
        raise PdfEncryptionError::MalformedEncryptionDictionary(
          "Length", "V 1 encryption key length must be 40 bits",
        )
      }
    V2 | V3 =>
      if length_bits < 40 || length_bits > 128 || length_bits % 8 != 0 {
        raise PdfEncryptionError::MalformedEncryptionDictionary(
          "Length", "V 2 and V 3 key length must be a multiple of 8 from 40 to 128 bits",
        )
      }
    V4 =>
      if length_bits != 128 {
        raise PdfEncryptionError::MalformedEncryptionDictionary(
          "Length", "V 4 crypt filters use a 128-bit file encryption key",
        )
      }
    V5 =>
      if length_bits != 256 {
        raise PdfEncryptionError::MalformedEncryptionDictionary(
          "Length", "V 5 crypt filters use a 256-bit file encryption key",
        )
      }
  }
}

///|
fn validate_filter_reference(
  cf_dict : @objects.PdfDictionary?,
  name : @objects.PdfName,
  field : String,
) -> Unit raise PdfEncryptionError {
  if name == dict_name(b"Identity") {
    return
  }
  match cf_dict {
    Some(filters) =>
      match filters.get(name) {
        Some(@objects.PdfObject::Dictionary(_)) => ()
        Some(_) =>
          raise PdfEncryptionError::MalformedEncryptionDictionary(
            field, "crypt filter reference must resolve to a dictionary",
          )
        None =>
          raise PdfEncryptionError::MalformedEncryptionDictionary(
            field, "crypt filter reference must name CF entry or Identity",
          )
      }
    None =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field, "crypt filter reference requires a CF dictionary",
      )
  }
}

///|
/// Parses common encryption dictionary entries and crypt-filter references:
/// Filter, SubFilter, V, Length, CF, StmF, StrF, and EFF. This validates V
/// values, Length constraints, standard Identity names, and CF references
/// before Standard password authentication or public-key diagnostics begin.
pub fn parse_common_encryption_dictionary(
  dict : @objects.PdfDictionary,
) -> EncryptionDictionaryInfo raise PdfEncryptionError {
  let filter = required_name(dict, b"Filter", "Filter")
  let subfilter = optional_name(dict, b"SubFilter", "SubFilter")
  let cipher_version = parse_cipher_version(
    optional_integer(dict, b"V", "V").unwrap_or(0L),
  )
  let default_bits = cipher_version.default_key_bits()
  let length_bits = optional_integer(dict, b"Length", "Length")
    .unwrap_or(default_bits.to_int64())
    .to_int()
  validate_key_length(cipher_version, length_bits)

  let cf_dict = optional_dictionary(dict, b"CF", "CF")
  let stream_filter_name = optional_name(dict, b"StmF", "StmF").unwrap_or(
    dict_name(b"Identity"),
  )
  let string_filter_name = optional_name(dict, b"StrF", "StrF").unwrap_or(
    dict_name(b"Identity"),
  )
  let embedded_file_filter_name = optional_name(dict, b"EFF", "EFF")
  if cipher_version.supports_crypt_filters() {
    validate_filter_reference(cf_dict, stream_filter_name, "StmF")
    validate_filter_reference(cf_dict, string_filter_name, "StrF")
    match embedded_file_filter_name {
      Some(name) => validate_filter_reference(cf_dict, name, "EFF")
      None => ()
    }
  }
  EncryptionDictionaryInfo::{
    filter,
    subfilter,
    cipher_version,
    length_bits,
    crypt_filters: cf_dict,
    stream_filter_name,
    string_filter_name,
    embedded_file_filter_name,
  }
}

///|
/// Parses Standard security handler fields and permissions: R, O, U, OE, UE,
/// P, Perms, EncryptMetadata, V/Length, and supported crypt filters. Revision
/// 6 O and U entries must be 48 bytes before password authentication starts.
pub fn parse_standard_security_handler_fields(
  dict : @objects.PdfDictionary,
) -> StandardEncryptionDictionary raise PdfEncryptionError {
  let parsed = parse_standard_encryption_dictionary(dict)
  if parsed.revision >= 5 &&
    (parsed.owner_entry.length() != 48 || parsed.user_entry.length() != 48) {
    raise PdfEncryptionError::MalformedEncryptionDictionary(
      "O/U", "revision 5-6 O and U entries must contain 48 bytes",
    )
  }
  parsed
}

///|
fn recipient_bytes(
  values : Array[@objects.PdfObject],
  field : String,
) -> Array[Bytes] raise PdfEncryptionError {
  let out : Array[Bytes] = []
  for value in values {
    match value {
      @objects.PdfObject::String(bytes) => out.push(bytes)
      _ =>
        raise PdfEncryptionError::MalformedEncryptionDictionary(
          field, "recipient entries must be byte strings",
        )
    }
  }
  out
}

///|
fn collect_cf_recipients(
  cf_dict : @objects.PdfDictionary?,
) -> Array[Bytes] raise PdfEncryptionError {
  let out : Array[Bytes] = []
  match cf_dict {
    Some(filters) =>
      for _, value in filters {
        match value {
          @objects.PdfObject::Dictionary(filter_dict) =>
            match filter_dict.get(dict_name(b"Recipients")) {
              Some(@objects.PdfObject::Array(values)) =>
                out.append(recipient_bytes(values, "CF.Recipients").view())
              Some(_) =>
                raise PdfEncryptionError::MalformedEncryptionDictionary(
                  "CF.Recipients", "crypt-filter recipients must be an array",
                )
              None => ()
            }
          _ =>
            raise PdfEncryptionError::MalformedEncryptionDictionary(
              "CF", "crypt filter entry must be a dictionary",
            )
        }
      }
    None => ()
  }
  out
}

///|
fn permitted_public_key_subfilter(name : @objects.PdfName?) -> Bool {
  match name {
    Some(value) =>
      value == dict_name(b"adbe.pkcs7.s3") ||
      value == dict_name(b"adbe.pkcs7.s4") ||
      value == dict_name(b"adbe.pkcs7.s5")
    None => true
  }
}

///|
/// Parses public-key handler metadata, permitted SubFilter names, top-level
/// recipient arrays, crypt-filter recipient placement, and public-key
/// permission bits while leaving CMS, X.509, private-key matching, and custom
/// handler decryption unsupported.
pub fn parse_public_key_encryption_dictionary(
  dict : @objects.PdfDictionary,
) -> PublicKeyEncryptionMetadata raise PdfEncryptionError {
  let filter = required_name(dict, b"Filter", "Filter")
  let subfilter = optional_name(dict, b"SubFilter", "SubFilter")
  if !permitted_public_key_subfilter(subfilter) {
    raise PdfEncryptionError::UnsupportedSecurityHandler(
      "unsupported public-key SubFilter",
    )
  }
  let recipients = match dict.get(dict_name(b"Recipients")) {
    Some(@objects.PdfObject::Array(values)) =>
      recipient_bytes(values, "Recipients")
    Some(_) =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        "Recipients", "public-key recipients must be an array",
      )
    None => []
  }
  let cf_dict = optional_dictionary(dict, b"CF", "CF")
  let crypt_filter_recipients = collect_cf_recipients(cf_dict)
  if recipients.length() == 0 && crypt_filter_recipients.length() == 0 {
    raise PdfEncryptionError::UnsupportedSecurityHandler(
      "public-key handler requires Recipients metadata and CMS decryption is unsupported",
    )
  }
  let permissions = optional_integer(dict, b"P", "P").map(value => {
    DocumentPermissions::from_raw(value)
  })
  PublicKeyEncryptionMetadata::{
    filter,
    subfilter,
    recipients,
    crypt_filter_recipients,
    permissions,
  }
}

///|
/// 7.6.5.1 General public-key security handler parser for certificate-based
/// security. It records Recipients, CMS, X.509 certificate, and private-key
/// requirements so unsupported public-key decryption is reported before
/// protected content is exposed.
pub fn parse_public_key_security_handler_general(
  dict : @objects.PdfDictionary,
) -> PublicKeySecurityHandlerGeneral raise PdfEncryptionError {
  parse_public_key_encryption_dictionary(dict) |> ignore
  PublicKeySecurityHandlerGeneral::{
    requires_cms: true,
    requires_x509_certificate: true,
    requires_private_key: true,
    unsupported_in_this_phase: true,
  }
}

///|
/// Parses encrypted payload dictionaries for wrapper documents, requiring a
/// Subtype name and preserving optional version bytes without opening the
/// embedded encrypted PDF payload.
pub fn parse_encrypted_payload_dictionary(
  dict : @objects.PdfDictionary,
) -> EncryptedPayloadInfo raise PdfEncryptionError {
  match optional_name(dict, b"Type", "Type") {
    Some(value) if value != dict_name(b"EncryptedPayload") =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        "Type", "encrypted payload Type must be EncryptedPayload",
      )
    _ => ()
  }
  let subtype = required_name(dict, b"Subtype", "Subtype")
  let version = optional_string(dict, b"Version", "Version")
  EncryptedPayloadInfo::{ subtype, version }
}
