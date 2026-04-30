///|
pub fn parse_file_spec_path(raw : Bytes) -> PdfFileSpecPath {
  let components : Array[Bytes] = []
  let current : Array[Byte] = []
  let mut index = 0
  while index < raw.length() {
    let byte = raw[index]
    if byte == b'\\' && index + 1 < raw.length() && raw[index + 1] == b'/' {
      current.push(b'/')
      index += 2
    } else if byte == b'/' {
      components.push(Bytes::from_array(current))
      current.clear()
      index += 1
    } else {
      current.push(byte)
      index += 1
    }
  }
  components.push(Bytes::from_array(current))
  PdfFileSpecPath::{
    raw,
    absolute: raw.length() > 0 && raw[0] == b'/',
    components,
  }
}

///|
pub fn normalize_file_spec_path(path : PdfFileSpecPath) -> PdfFileSpecPath {
  let normalized : Array[Bytes] = []
  for component in path.components {
    if component == b".." &&
      normalized.length() > 0 &&
      normalized[normalized.length() - 1] != b".." {
      let _ = normalized.pop()
    } else {
      normalized.push(component)
    }
  }
  PdfFileSpecPath::{
    raw: file_spec_join_components(normalized, path.absolute),
    absolute: path.absolute,
    components: normalized,
  }
}

///|
pub fn resolve_file_spec_path(
  base : PdfFileSpecPath,
  relative : PdfFileSpecPath,
) -> PdfFileSpecPath raise PdfDocumentError {
  if relative.absolute {
    raise file_spec_error(
      None,
      "relative file specification must not be absolute",
    )
  }
  let combined : Array[Bytes] = []
  let mut limit = base.components.length()
  if limit > 0 {
    limit -= 1
  }
  for index in 0..<limit {
    combined.push(base.components[index])
  }
  for component in relative.components {
    combined.push(component)
  }
  normalize_file_spec_path(PdfFileSpecPath::{
    raw: file_spec_join_components(combined, base.absolute),
    absolute: base.absolute,
    components: combined,
  })
}

///|
/// Resolve a relative URL file specification path against a base URL.
///
/// Section 7.11.5 URL specifications use an FS entry URL and an F entry uniform
/// resource locator. The relative path is URL escaped according to Internet RFC
/// 3986, matching the Internet RFC 1738 URL escaping vocabulary used by older
/// file specification text.
pub fn resolve_file_spec_url_path(
  base_url : Bytes,
  relative_path : PdfFileSpecPath,
) -> Bytes raise PdfDocumentError {
  if relative_path.absolute {
    raise file_spec_error(None, "URL file specification path must be relative")
  }
  reject_url_relative_path(relative_path.raw)
  let encoded = encode_url_path(relative_path)
  resolve_encoded_url_path(base_url, encoded)
}

///|
fn reject_url_relative_path(raw : Bytes) -> Unit raise PdfDocumentError {
  let mut index = 0
  while index < raw.length() {
    let byte = raw[index]
    if byte == b':' || byte == b'?' || byte == b'#' || byte == b';' {
      raise file_spec_error(
        None,
        "URL file specification path must not contain scheme, query, fragment, or parameters",
      )
    }
    if byte == b'/' && index + 1 < raw.length() && raw[index + 1] == b'/' {
      raise file_spec_error(
        None,
        "URL file specification path must not contain authority",
      )
    }
    index += 1
  }
}

///|
fn encode_url_path(path : PdfFileSpecPath) -> Bytes {
  let out : Array[Byte] = []
  let mut component_index = 0
  while component_index < path.components.length() {
    if component_index > 0 {
      out.push(b'/')
    }
    let component = path.components[component_index]
    for byte_index in 0..<component.length() {
      url_encode_byte(out, component[byte_index])
    }
    component_index += 1
  }
  Bytes::from_array(out)
}

///|
fn url_encode_byte(out : Array[Byte], byte : Byte) -> Unit {
  if is_url_path_safe(byte) {
    out.push(byte)
  } else {
    out.push(b'%')
    out.push(hex_digit(byte.to_int() / 16))
    out.push(hex_digit(byte.to_int() % 16))
  }
}

///|
fn is_url_path_safe(byte : Byte) -> Bool {
  (byte >= b'A' && byte <= b'Z') ||
  (byte >= b'a' && byte <= b'z') ||
  (byte >= b'0' && byte <= b'9') ||
  byte == b'-' ||
  byte == b'.' ||
  byte == b'_' ||
  byte == b'~'
}

///|
fn hex_digit(value : Int) -> Byte {
  if value < 10 {
    (b'0'.to_int() + value).to_byte()
  } else {
    (b'A'.to_int() + value - 10).to_byte()
  }
}

///|
fn resolve_encoded_url_path(base_url : Bytes, encoded : Bytes) -> Bytes {
  let base_dir = url_base_directory(base_url)
  let components = parse_file_spec_path(encoded).components
  let prefix = trim_url_base_for_relative_components(base_dir, components)
  let out : Array[Byte] = []
  file_spec_append_bytes(out, prefix)
  let mut index = 0
  while index < components.length() {
    if components[index] == b".." {
      index += 1
      continue
    }
    if index > 0 && out.length() > 0 && out[out.length() - 1] != b'/' {
      out.push(b'/')
    }
    file_spec_append_bytes(out, components[index])
    index += 1
  }
  Bytes::from_array(out)
}

///|
fn url_base_directory(base_url : Bytes) -> Bytes {
  let mut last_slash = -1
  for index in 0..<base_url.length() {
    if base_url[index] == b'/' {
      last_slash = index
    }
  }
  if last_slash < 0 {
    b""
  } else {
    base_url[0:last_slash + 1].to_bytes()
  }
}

///|
fn trim_url_base_for_relative_components(
  base_dir : Bytes,
  components : Array[Bytes],
) -> Bytes {
  let mut prefix = base_dir
  for component in components {
    if component == b".." {
      prefix = url_parent_directory(prefix)
    }
  }
  prefix
}

///|
fn url_parent_directory(prefix : Bytes) -> Bytes {
  let minimum = url_authority_end(prefix)
  let mut end = prefix.length() - 1
  if end < minimum {
    return prefix
  }
  while end > minimum && prefix[end - 1] != b'/' {
    end -= 1
  }
  prefix[0:end].to_bytes()
}

///|
fn url_authority_end(bytes : Bytes) -> Int {
  let mut index = 0
  while index + 2 < bytes.length() {
    if bytes[index] == b':' &&
      bytes[index + 1] == b'/' &&
      bytes[index + 2] == b'/' {
      let mut cursor = index + 3
      while cursor < bytes.length() {
        if bytes[cursor] == b'/' {
          return cursor + 1
        }
        cursor += 1
      }
      return bytes.length()
    }
    index += 1
  }
  0
}
