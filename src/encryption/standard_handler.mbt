///|
let standard_password_padding : Bytes = Bytes::from_array([
  b'\x28', b'\xbf', b'\x4e', b'\x5e', b'\x4e', b'\x75', b'\x8a', b'\x41', b'\x64',
  b'\x00', b'\x4e', b'\x56', b'\xff', b'\xfa', b'\x01', b'\x08', b'\x2e', b'\x2e',
  b'\x00', b'\xb6', b'\xd0', b'\x68', b'\x3e', b'\x80', b'\x2f', b'\x0c', b'\xa9',
  b'\xfe', b'\x64', b'\x53', b'\x69', b'\x7a',
])

///|
/// Authenticates an Encrypt dictionary with /Filter /Standard for revisions
/// 2, 3, 4, 5, and 6 using a user or owner password. On success it returns
/// the derived EncryptionKey, permission flags, and crypt filters needed for
/// encrypted strings, encrypted streams, and per-object encryption keys.
pub fn authenticate(
  encrypt_dict : @objects.PdfDictionary,
  password : Bytes,
  file_id : FileIdentifier,
) -> EncryptionKey? raise PdfEncryptionError {
  let parsed = parse_standard_encryption_dictionary(encrypt_dict)
  authenticate_standard(parsed, password, file_id)
}

///|
priv struct StandardEncryptionDictionary {
  revision : Int
  cipher_version : CipherVersion
  key_length_bytes : Int
  owner_entry : Bytes
  user_entry : Bytes
  owner_encrypted_file_key : Bytes?
  user_encrypted_file_key : Bytes?
  permissions : DocumentPermissions
  encrypt_metadata : Bool
  string_filter : CryptFilter
  stream_filter : CryptFilter
  embedded_file_filter : CryptFilter?
}

///|
fn authenticate_standard(
  parsed : StandardEncryptionDictionary,
  password : Bytes,
  file_id : FileIdentifier,
) -> EncryptionKey? raise PdfEncryptionError {
  if parsed.revision <= 4 {
    authenticate_legacy(parsed, password, file_id)
  } else {
    authenticate_aes256(parsed, truncate_password_127(password))
  }
}

///|
fn authenticate_legacy(
  parsed : StandardEncryptionDictionary,
  password : Bytes,
  file_id : FileIdentifier,
) -> EncryptionKey? raise PdfEncryptionError {
  let user_key = derive_legacy_file_key(parsed, password, file_id)
  if verify_legacy_user_entry(parsed, user_key, file_id) {
    return Some(
      encryption_context(parsed, user_key, EncryptionAccessMode::UserAccess),
    )
  }

  let owner_user_password = recover_legacy_owner_user_password(parsed, password)
  let owner_key = derive_legacy_file_key(parsed, owner_user_password, file_id)
  if verify_legacy_user_entry(parsed, owner_key, file_id) {
    Some(
      encryption_context(parsed, owner_key, EncryptionAccessMode::OwnerAccess),
    )
  } else {
    None
  }
}

///|
fn authenticate_aes256(
  parsed : StandardEncryptionDictionary,
  password : Bytes,
) -> EncryptionKey? raise PdfEncryptionError {
  let user_key = verify_aes256_user_password(parsed, password)
  match user_key {
    Some(file_key) =>
      Some(
        encryption_context(parsed, file_key, EncryptionAccessMode::UserAccess),
      )
    None => {
      let owner_key = verify_aes256_owner_password(parsed, password)
      match owner_key {
        Some(file_key) =>
          Some(
            encryption_context(
              parsed,
              file_key,
              EncryptionAccessMode::OwnerAccess,
            ),
          )
        None => None
      }
    }
  }
}

///|
fn encryption_context(
  parsed : StandardEncryptionDictionary,
  file_key : Bytes,
  access_mode : EncryptionAccessMode,
) -> EncryptionContext {
  EncryptionContext::{
    status: EncryptionStatus::EncryptedAuthorized,
    file_key,
    access_mode,
    permissions: parsed.permissions,
    cipher_version: parsed.cipher_version,
    encrypt_metadata: parsed.encrypt_metadata,
    string_filter: parsed.string_filter,
    stream_filter: parsed.stream_filter,
    embedded_file_filter: parsed.embedded_file_filter,
  }
}

///|
fn parse_standard_encryption_dictionary(
  dict : @objects.PdfDictionary,
) -> StandardEncryptionDictionary raise PdfEncryptionError {
  require_standard_filter(dict)
  let revision = read_required_int(dict, b"R", "R").to_int()
  if revision < 2 || revision > 6 {
    raise PdfEncryptionError::UnsupportedAlgorithm(
      "unsupported Standard security handler revision " + revision.to_string(),
    )
  }

  let cipher_version = parse_cipher_version(
    read_optional_int(dict, b"V", "V").unwrap_or(0L),
  )
  let default_key_bits = if revision == 2 {
    40
  } else if revision >= 5 {
    256
  } else {
    128
  }
  let length_bits = read_optional_int(dict, b"Length", "Length")
    .unwrap_or(default_key_bits.to_int64())
    .to_int()
  let key_length_bytes = if revision == 2 { 5 } else { length_bits / 8 }
  if key_length_bytes <= 0 || key_length_bytes > 32 {
    raise PdfEncryptionError::MalformedEncryptionDictionary(
      "Length", "encryption key length must be in 1..32 bytes",
    )
  }

  let owner_entry = read_required_string(dict, b"O", "O")
  let user_entry = read_required_string(dict, b"U", "U")
  let permissions = DocumentPermissions::from_raw(
    read_required_int(dict, b"P", "P"),
  )
  let encrypt_metadata = read_optional_bool(
    dict, b"EncryptMetadata", "EncryptMetadata",
  ).unwrap_or(true)

  let owner_encrypted_file_key = read_optional_string(dict, b"OE", "OE")
  let user_encrypted_file_key = read_optional_string(dict, b"UE", "UE")
  read_optional_string(dict, b"Perms", "Perms") |> ignore

  validate_entry_lengths(
    revision, owner_entry, user_entry, owner_encrypted_file_key, user_encrypted_file_key,
  )

  let filters = parse_filters(dict, cipher_version, length_bits)
  StandardEncryptionDictionary::{
    revision,
    cipher_version,
    key_length_bytes,
    owner_entry,
    user_entry,
    owner_encrypted_file_key,
    user_encrypted_file_key,
    permissions,
    encrypt_metadata,
    string_filter: filters.0,
    stream_filter: filters.1,
    embedded_file_filter: filters.2,
  }
}

///|
fn validate_entry_lengths(
  revision : Int,
  owner_entry : Bytes,
  user_entry : Bytes,
  owner_encrypted_file_key : Bytes?,
  user_encrypted_file_key : Bytes?,
) -> Unit raise PdfEncryptionError {
  if revision <= 4 {
    if owner_entry.length() != 32 || user_entry.length() < 32 {
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        "O/U", "revision 2-4 O and U entries must contain 32 bytes",
      )
    }
  } else {
    if owner_entry.length() != 48 || user_entry.length() != 48 {
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        "O/U", "revision 5-6 O and U entries must contain 48 bytes",
      )
    }
    match owner_encrypted_file_key {
      Some(value) if value.length() == 32 => ()
      _ =>
        raise PdfEncryptionError::MalformedEncryptionDictionary(
          "OE", "revision 5-6 OE entry must contain 32 bytes",
        )
    }
    match user_encrypted_file_key {
      Some(value) if value.length() == 32 => ()
      _ =>
        raise PdfEncryptionError::MalformedEncryptionDictionary(
          "UE", "revision 5-6 UE entry must contain 32 bytes",
        )
    }
  }
}

///|
fn derive_legacy_file_key(
  parsed : StandardEncryptionDictionary,
  password : Bytes,
  file_id : FileIdentifier,
) -> Bytes raise PdfEncryptionError {
  let input = bytes_concat([
    pad_password_legacy(password),
    parsed.owner_entry,
    little_endian_permissions(parsed.permissions.raw_permissions),
    file_id.first,
    if parsed.revision >= 4 && !parsed.encrypt_metadata {
      Bytes::from_array([b'\xff', b'\xff', b'\xff', b'\xff'])
    } else {
      b""
    },
  ])
  let mut digest = crypto_md5(input)
  if parsed.revision >= 3 {
    for _ in 0..<50 {
      digest = crypto_md5(bytes_slice(digest, 0, parsed.key_length_bytes))
    }
  }
  bytes_slice(digest, 0, parsed.key_length_bytes)
}

///|
fn verify_legacy_user_entry(
  parsed : StandardEncryptionDictionary,
  file_key : Bytes,
  file_id : FileIdentifier,
) -> Bool raise PdfEncryptionError {
  let computed = compute_legacy_user_entry(parsed, file_key, file_id)
  if parsed.revision == 2 {
    bytes_equal_prefix(parsed.user_entry, computed, 32)
  } else {
    bytes_equal_prefix(parsed.user_entry, computed, 16)
  }
}

///|
fn compute_legacy_user_entry(
  parsed : StandardEncryptionDictionary,
  file_key : Bytes,
  file_id : FileIdentifier,
) -> Bytes raise PdfEncryptionError {
  if parsed.revision == 2 {
    crypto_rc4(file_key, standard_password_padding)
  } else {
    let digest = crypto_md5(standard_password_padding + file_id.first)
    let mut value = crypto_rc4(file_key, digest)
    for round in 1..<20 {
      value = crypto_rc4(xor_key_with_round(file_key, round), value)
    }
    value + bytes_slice(standard_password_padding, 0, 16)
  }
}

///|
fn recover_legacy_owner_user_password(
  parsed : StandardEncryptionDictionary,
  owner_password : Bytes,
) -> Bytes raise PdfEncryptionError {
  let mut key = crypto_md5(pad_password_legacy(owner_password))
  if parsed.revision >= 3 {
    for _ in 0..<50 {
      key = crypto_md5(key)
    }
  }
  key = bytes_slice(key, 0, parsed.key_length_bytes)
  if parsed.revision == 2 {
    crypto_rc4(key, parsed.owner_entry)
  } else {
    let mut value = parsed.owner_entry
    let mut round = 19
    while round >= 0 {
      value = crypto_rc4(xor_key_with_round(key, round), value)
      round -= 1
    }
    value
  }
}

///|
#warnings("-unused_value")
fn compute_legacy_owner_entry(
  revision : Int,
  key_length_bytes : Int,
  user_password : Bytes,
  owner_password : Bytes,
) -> Bytes raise PdfEncryptionError {
  let owner_source = if owner_password.length() == 0 {
    user_password
  } else {
    owner_password
  }
  let mut key = crypto_md5(pad_password_legacy(owner_source))
  if revision >= 3 {
    for _ in 0..<50 {
      key = crypto_md5(key)
    }
  }
  key = bytes_slice(key, 0, key_length_bytes)
  let mut value = pad_password_legacy(user_password)
  if revision == 2 {
    crypto_rc4(key, value)
  } else {
    for round in 0..<20 {
      value = crypto_rc4(xor_key_with_round(key, round), value)
    }
    value
  }
}

///|
fn verify_aes256_user_password(
  parsed : StandardEncryptionDictionary,
  password : Bytes,
) -> Bytes? raise PdfEncryptionError {
  let validation_salt = bytes_slice(parsed.user_entry, 32, 40)
  let expected = bytes_slice(parsed.user_entry, 0, 32)
  let actual = aes256_hash(parsed.revision, password, validation_salt, None)
  if actual != expected {
    return None
  }
  let key_salt = bytes_slice(parsed.user_entry, 40, 48)
  let wrapping_key = aes256_hash(parsed.revision, password, key_salt, None)
  match parsed.user_encrypted_file_key {
    Some(encrypted_key) =>
      Some(decrypt_aes256_file_key(wrapping_key, encrypted_key))
    None => None
  }
}

///|
fn verify_aes256_owner_password(
  parsed : StandardEncryptionDictionary,
  password : Bytes,
) -> Bytes? raise PdfEncryptionError {
  let validation_salt = bytes_slice(parsed.owner_entry, 32, 40)
  let expected = bytes_slice(parsed.owner_entry, 0, 32)
  let user_entry = parsed.user_entry
  let actual = aes256_hash(
    parsed.revision,
    password,
    validation_salt,
    Some(user_entry),
  )
  if actual != expected {
    return None
  }
  let key_salt = bytes_slice(parsed.owner_entry, 40, 48)
  let wrapping_key = aes256_hash(
    parsed.revision,
    password,
    key_salt,
    Some(user_entry),
  )
  match parsed.owner_encrypted_file_key {
    Some(encrypted_key) =>
      Some(decrypt_aes256_file_key(wrapping_key, encrypted_key))
    None => None
  }
}

///|
fn aes256_hash(
  revision : Int,
  password : Bytes,
  salt : Bytes,
  user_key : Bytes?,
) -> Bytes raise PdfEncryptionError {
  let input = match user_key {
    Some(key) => password + salt + key
    None => password + salt
  }
  if revision == 5 {
    crypto_sha256(input)
  } else {
    aes256_revision6_hash(password, salt, user_key)
  }
}

///|
fn aes256_revision6_hash(
  password : Bytes,
  salt : Bytes,
  user_key : Bytes?,
) -> Bytes raise PdfEncryptionError {
  let user_bytes = user_key.unwrap_or(b"")
  let mut key = crypto_sha256(password + salt + user_bytes)
  let mut encrypted = b""
  let mut round = 0
  while round < 64 || encrypted[encrypted.length() - 1].to_int() > round - 32 {
    let seed = password + key + user_bytes
    let repeated = repeat_bytes(seed, 64)
    encrypted = crypto_aes_cbc_encrypt(
      bytes_slice(key, 0, 16),
      bytes_slice(key, 16, 32),
      repeated,
      @crypto.PaddingMode::NoPadding,
    )
    key = match first_16_mod_3(encrypted) {
      0 => crypto_sha256(encrypted)
      1 => crypto_sha384(encrypted)
      _ => crypto_sha512(encrypted)
    }
    round += 1
  }
  bytes_slice(key, 0, 32)
}

///|
fn decrypt_aes256_file_key(
  wrapping_key : Bytes,
  encrypted_key : Bytes,
) -> Bytes raise PdfEncryptionError {
  crypto_aes_cbc_decrypt(
    wrapping_key,
    Bytes::make(16, b'\x00'),
    encrypted_key,
    @crypto.PaddingMode::NoPadding,
  )
}

///|
fn parse_filters(
  dict : @objects.PdfDictionary,
  cipher_version : CipherVersion,
  length_bits : Int,
) -> (CryptFilter, CryptFilter, CryptFilter?) raise PdfEncryptionError {
  let default_method = match cipher_version {
    V1 | V2 | V3 => CryptFilterMethod::V2
    V4 => CryptFilterMethod::V2
    V5 => CryptFilterMethod::AESV3
  }
  let default_string_name = if cipher_version == CipherVersion::V4 {
    read_optional_name(dict, b"StrF", "StrF").unwrap_or(
      @objects.PdfName::new(b"Identity"),
    )
  } else {
    @objects.PdfName::new(b"StdCF")
  }
  let default_stream_name = if cipher_version == CipherVersion::V4 {
    read_optional_name(dict, b"StmF", "StmF").unwrap_or(
      @objects.PdfName::new(b"Identity"),
    )
  } else {
    @objects.PdfName::new(b"StdCF")
  }
  let embedded_name = read_optional_name(dict, b"EFF", "EFF")
  let cf_dict = read_optional_dictionary(dict, b"CF", "CF")
  let string_filter = parse_crypt_filter(
    default_string_name, cf_dict, default_method, length_bits,
  )
  let stream_filter = parse_crypt_filter(
    default_stream_name, cf_dict, default_method, length_bits,
  )
  let embedded_file_filter = match embedded_name {
    Some(name) =>
      Some(parse_crypt_filter(name, cf_dict, default_method, length_bits))
    None => None
  }
  (string_filter, stream_filter, embedded_file_filter)
}

///|
fn parse_crypt_filter(
  name : @objects.PdfName,
  cf_dict : @objects.PdfDictionary?,
  default_method : CryptFilterMethod,
  default_length_bits : Int,
) -> CryptFilter raise PdfEncryptionError {
  if name == @objects.PdfName::new(b"Identity") {
    return CryptFilter::{
      name,
      filter_method: CryptFilterMethod::Identity,
      auth_event: CryptFilterAuthEvent::DocOpen,
      length_bits: None,
    }
  }

  let dict = match cf_dict {
    Some(filters) =>
      match filters.get(name) {
        Some(@objects.PdfObject::Dictionary(value)) => Some(value)
        Some(_) =>
          raise PdfEncryptionError::MalformedEncryptionDictionary(
            "CF", "crypt filter entry must be a dictionary",
          )
        None => None
      }
    None => None
  }

  match dict {
    Some(filter_dict) => {
      let crypt_method = match read_optional_name(filter_dict, b"CFM", "CFM") {
        Some(value) => parse_crypt_filter_method(value)
        None => CryptFilterMethod::None
      }
      let auth_event = match
        read_optional_name(filter_dict, b"AuthEvent", "AuthEvent") {
        Some(value) => parse_auth_event(value)
        None => CryptFilterAuthEvent::DocOpen
      }
      let length_bits = read_optional_int(filter_dict, b"Length", "Length").map(value => {
          value.to_int()
        },
      )
      CryptFilter::{
        name,
        filter_method: crypt_method,
        auth_event,
        length_bits,
      }
    }
    None =>
      CryptFilter::{
        name,
        filter_method: default_method,
        auth_event: CryptFilterAuthEvent::DocOpen,
        length_bits: Some(default_length_bits),
      }
  }
}

///|
fn parse_crypt_filter_method(name : @objects.PdfName) -> CryptFilterMethod {
  if name == @objects.PdfName::new(b"None") {
    CryptFilterMethod::None
  } else if name == @objects.PdfName::new(b"V2") {
    CryptFilterMethod::V2
  } else if name == @objects.PdfName::new(b"AESV2") {
    CryptFilterMethod::AESV2
  } else if name == @objects.PdfName::new(b"AESV3") {
    CryptFilterMethod::AESV3
  } else {
    CryptFilterMethod::Unsupported(name.bytes)
  }
}

///|
fn parse_auth_event(name : @objects.PdfName) -> CryptFilterAuthEvent {
  if name == @objects.PdfName::new(b"DocOpen") {
    CryptFilterAuthEvent::DocOpen
  } else if name == @objects.PdfName::new(b"EFOpen") {
    CryptFilterAuthEvent::EFOpen
  } else {
    CryptFilterAuthEvent::Unsupported(name.bytes)
  }
}

///|
fn parse_cipher_version(
  value : Int64,
) -> CipherVersion raise PdfEncryptionError {
  match value {
    1L => CipherVersion::V1
    2L => CipherVersion::V2
    3L => CipherVersion::V3
    4L => CipherVersion::V4
    5L => CipherVersion::V5
    0L => CipherVersion::V1
    _ =>
      raise PdfEncryptionError::UnsupportedAlgorithm(
        "unsupported encryption version " + value.to_string(),
      )
  }
}

///|
fn require_standard_filter(
  dict : @objects.PdfDictionary,
) -> Unit raise PdfEncryptionError {
  match dict.get(@objects.PdfName::new(b"Filter")) {
    Some(@objects.PdfObject::Name(name)) if name ==
      @objects.PdfName::new(b"Standard") => ()
    Some(@objects.PdfObject::Name(name)) =>
      raise PdfEncryptionError::UnsupportedSecurityHandler(name.to_text())
    Some(_) =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        "Filter", "Filter entry must be a name",
      )
    None =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        "Filter", "missing Standard security handler filter",
      )
  }
}

///|
fn read_required_int(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field_name : String,
) -> Int64 raise PdfEncryptionError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(@objects.PdfObject::Integer(value)) => value
    Some(_) =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field_name, "entry must be an integer",
      )
    None =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field_name, "missing required entry",
      )
  }
}

///|
fn read_optional_int(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field_name : String,
) -> Int64? raise PdfEncryptionError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(@objects.PdfObject::Integer(value)) => Some(value)
    Some(_) =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field_name, "entry must be an integer",
      )
    None => None
  }
}

///|
fn read_required_string(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field_name : String,
) -> Bytes raise PdfEncryptionError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(@objects.PdfObject::String(value)) => value
    Some(_) =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field_name, "entry must be a byte string",
      )
    None =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field_name, "missing required entry",
      )
  }
}

///|
fn read_optional_string(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field_name : String,
) -> Bytes? raise PdfEncryptionError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(@objects.PdfObject::String(value)) => Some(value)
    Some(_) =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field_name, "entry must be a byte string",
      )
    None => None
  }
}

///|
fn read_optional_name(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field_name : String,
) -> @objects.PdfName? raise PdfEncryptionError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(@objects.PdfObject::Name(value)) => Some(value)
    Some(_) =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field_name, "entry must be a name",
      )
    None => None
  }
}

///|
fn read_optional_bool(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field_name : String,
) -> Bool? raise PdfEncryptionError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(@objects.PdfObject::Boolean(value)) => Some(value)
    Some(_) =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field_name, "entry must be a boolean",
      )
    None => None
  }
}

///|
fn read_optional_dictionary(
  dict : @objects.PdfDictionary,
  key : Bytes,
  field_name : String,
) -> @objects.PdfDictionary? raise PdfEncryptionError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(@objects.PdfObject::Dictionary(value)) => Some(value)
    Some(_) =>
      raise PdfEncryptionError::MalformedEncryptionDictionary(
        field_name, "entry must be a dictionary",
      )
    None => None
  }
}

///|
fn pad_password_legacy(password : Bytes) -> Bytes {
  let out : Array[Byte] = []
  let copy_len = if password.length() > 32 { 32 } else { password.length() }
  for index in 0..<copy_len {
    out.push(password[index])
  }
  let mut pad_index = 0
  while out.length() < 32 {
    out.push(standard_password_padding[pad_index])
    pad_index += 1
  }
  Bytes::from_array(out)
}

///|
fn truncate_password_127(password : Bytes) -> Bytes {
  if password.length() <= 127 {
    password
  } else {
    bytes_slice(password, 0, 127)
  }
}

///|
fn little_endian_permissions(value : Int64) -> Bytes {
  Bytes::from_array([
    (value & 0xffL).to_byte(),
    ((value >> 8) & 0xffL).to_byte(),
    ((value >> 16) & 0xffL).to_byte(),
    ((value >> 24) & 0xffL).to_byte(),
  ])
}

///|
fn xor_key_with_round(key : Bytes, round : Int) -> Bytes {
  Bytes::makei(key.length(), index => key[index] ^ round.to_byte())
}

///|
fn bytes_equal_prefix(left : Bytes, right : Bytes, count : Int) -> Bool {
  if left.length() < count || right.length() < count {
    return false
  }
  for index in 0..<count {
    if left[index] != right[index] {
      return false
    }
  }
  true
}

///|
fn first_16_mod_3(bytes : Bytes) -> Int {
  let mut result = 0
  for index in 0..<16 {
    result = (result * 256 + bytes[index].to_int()) % 3
  }
  result
}

///|
fn repeat_bytes(bytes : Bytes, times : Int) -> Bytes {
  let out : Array[Byte] = []
  for _ in 0..<times {
    out.append(bytes.to_array().view())
  }
  Bytes::from_array(out)
}

///|
fn bytes_concat(chunks : Array[Bytes]) -> Bytes {
  let out : Array[Byte] = []
  for chunk in chunks {
    out.append(chunk.to_array().view())
  }
  Bytes::from_array(out)
}

///|
fn bytes_slice(data : Bytes, start : Int, end : Int) -> Bytes {
  Bytes::from_array(data.view(start~, end~).to_array().view())
}

///|
fn crypto_md5(input : Bytes) -> Bytes raise PdfEncryptionError {
  try @crypto.md5_digest(input) catch {
    error => raise PdfEncryptionError::CryptoFailure(error)
  } noraise {
    digest => digest
  }
}

///|
fn crypto_sha256(input : Bytes) -> Bytes raise PdfEncryptionError {
  try @crypto.sha256_digest(input) catch {
    error => raise PdfEncryptionError::CryptoFailure(error)
  } noraise {
    digest => digest
  }
}

///|
fn crypto_sha384(input : Bytes) -> Bytes raise PdfEncryptionError {
  try @crypto.sha384_digest(input) catch {
    error => raise PdfEncryptionError::CryptoFailure(error)
  } noraise {
    digest => digest
  }
}

///|
fn crypto_sha512(input : Bytes) -> Bytes raise PdfEncryptionError {
  try @crypto.sha512_digest(input) catch {
    error => raise PdfEncryptionError::CryptoFailure(error)
  } noraise {
    digest => digest
  }
}

///|
fn crypto_rc4(key : Bytes, data : Bytes) -> Bytes raise PdfEncryptionError {
  try @crypto.rc4_transform(key, data) catch {
    error => raise PdfEncryptionError::CryptoFailure(error)
  } noraise {
    output => output
  }
}

///|
fn crypto_aes_cbc_encrypt(
  key : Bytes,
  iv : Bytes,
  data : Bytes,
  padding : @crypto.PaddingMode,
) -> Bytes raise PdfEncryptionError {
  try @crypto.aes_cbc_encrypt(key, iv, data, padding) catch {
    error => raise PdfEncryptionError::CryptoFailure(error)
  } noraise {
    output => output
  }
}

///|
fn crypto_aes_cbc_decrypt(
  key : Bytes,
  iv : Bytes,
  data : Bytes,
  padding : @crypto.PaddingMode,
) -> Bytes raise PdfEncryptionError {
  try @crypto.aes_cbc_decrypt(key, iv, data, padding) catch {
    error => raise PdfEncryptionError::CryptoFailure(error)
  } noraise {
    output => output
  }
}
