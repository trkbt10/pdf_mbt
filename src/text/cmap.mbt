///|
pub(all) struct CIDSystemInfo {
  registry : String
  ordering : String
  supplement : Int
} derive(Eq, Debug)

///|
pub(all) struct CMapCodespaceRange {
  low : Bytes
  high : Bytes
} derive(Eq, Debug)

///|
pub(all) struct CMapCIDMapping {
  low : Bytes
  high : Bytes
  cid_start : Int
} derive(Eq, Debug)

///|
pub(all) struct CMap {
  mut name : @objects.PdfName?
  mut writing_mode : WritingMode
  mut cid_system_info : CIDSystemInfo?
  mut use_cmap : @objects.PdfName?
  codespaces : Array[CMapCodespaceRange]
  cid_mappings : Array[CMapCIDMapping]
  notdef_mappings : Array[CMapCIDMapping]
} derive(Eq, Debug)

///|
pub(all) struct CMapDecodeResult {
  source_bytes : Bytes
  source_code : Int
  cid : Int
  consumed : Int
  writing_mode : WritingMode
  fallback : GlyphFallback
} derive(Eq, Debug)

///|
pub(all) struct ToUnicodeCodeMapping {
  low : Bytes
  high : Bytes
  values : Array[String]
} derive(Eq, Debug)

///|
pub(all) struct ToUnicodeCMap {
  name : @objects.PdfName?
  use_cmap : @objects.PdfName?
  codespaces : Array[CMapCodespaceRange]
  mappings : Array[ToUnicodeCodeMapping]
} derive(Eq, Debug)

///|
pub fn CIDSystemInfo::compatible_with(
  self : CIDSystemInfo,
  other : CIDSystemInfo,
) -> Bool {
  self.registry == other.registry &&
  self.ordering == other.ordering &&
  self.supplement >= other.supplement
}

///|
pub fn CMapCodespaceRange::length(self : CMapCodespaceRange) -> Int {
  self.low.length()
}

///|
pub fn CMap::empty() -> CMap {
  CMap::{
    name: None,
    writing_mode: WritingMode::Horizontal,
    cid_system_info: None,
    use_cmap: None,
    codespaces: [],
    cid_mappings: [],
    notdef_mappings: [],
  }
}

///|
pub fn ToUnicodeCMap::empty() -> ToUnicodeCMap {
  ToUnicodeCMap::{ name: None, use_cmap: None, codespaces: [], mappings: [] }
}

///|
pub fn resolve_predefined_cmap(
  name : @objects.PdfName,
  offset : Int64,
) -> CMap raise PdfTextError {
  if name == @objects.PdfName::new(b"Identity-H") {
    identity_cmap(name, WritingMode::Horizontal)
  } else if name == @objects.PdfName::new(b"Identity-V") {
    identity_cmap(name, WritingMode::Vertical)
  } else {
    raise PdfTextError::InvalidCMap(
      TextErrorContext::at(offset),
      "unsupported predefined CMap " + name.to_text(),
    )
  }
}

///|
pub fn CMap::decode_next(
  self : CMap,
  bytes : Bytes,
  start : Int,
) -> CMapDecodeResult raise PdfTextError {
  let context = TextErrorContext::at(start.to_int64())
  if start < 0 || start >= bytes.length() {
    raise PdfTextError::InvalidCMap(
      context, "CMap decode start is outside source bytes",
    )
  }
  match self.match_codespace(bytes, start) {
    Some(code) => self.decode_matched_code(code)
    None => {
      let consumed = self.partial_codespace_length(bytes, start)
      let source = copy_bytes_range(bytes, start, consumed)
      CMapDecodeResult::{
        source_bytes: source,
        source_code: bytes_to_uint(source),
        cid: 0,
        consumed,
        writing_mode: self.writing_mode,
        fallback: GlyphFallback::CIDZero,
      }
    }
  }
}

///|
pub fn ToUnicodeCMap::map_source_code(
  self : ToUnicodeCMap,
  source : Bytes,
) -> String? {
  let value = bytes_to_uint(source)
  for mapping in self.mappings {
    if source.length() == mapping.low.length() &&
      value >= bytes_to_uint(mapping.low) &&
      value <= bytes_to_uint(mapping.high) {
      let index = value - bytes_to_uint(mapping.low)
      if index >= 0 && index < mapping.values.length() {
        return Some(mapping.values[index])
      }
    }
  }
  None
}

///|
fn identity_cmap(name : @objects.PdfName, mode : WritingMode) -> CMap {
  CMap::{
    name: Some(name),
    writing_mode: mode,
    cid_system_info: None,
    use_cmap: None,
    codespaces: [CMapCodespaceRange::{ low: b"\x00\x00", high: b"\xff\xff" }],
    cid_mappings: [
      CMapCIDMapping::{ low: b"\x00\x00", high: b"\xff\xff", cid_start: 0 },
    ],
    notdef_mappings: [],
  }
}

///|
fn CMap::match_codespace(self : CMap, bytes : Bytes, start : Int) -> Bytes? {
  let mut matched : Bytes? = None
  for range in self.codespaces {
    let length = range.length()
    if start + length <= bytes.length() {
      let source = copy_bytes_range(bytes, start, length)
      if code_in_range(source, range.low, range.high) {
        match matched {
          None => matched = Some(source)
          Some(previous) =>
            if source.length() > previous.length() {
              matched = Some(source)
            }
        }
      }
    }
  }
  matched
}

///|
fn CMap::decode_matched_code(self : CMap, source : Bytes) -> CMapDecodeResult {
  match find_cid_mapping(self.cid_mappings, source) {
    Some(cid) =>
      CMapDecodeResult::{
        source_bytes: source,
        source_code: bytes_to_uint(source),
        cid,
        consumed: source.length(),
        writing_mode: self.writing_mode,
        fallback: GlyphFallback::NoFallback,
      }
    None =>
      match find_cid_mapping(self.notdef_mappings, source) {
        Some(cid) =>
          CMapDecodeResult::{
            source_bytes: source,
            source_code: bytes_to_uint(source),
            cid,
            consumed: source.length(),
            writing_mode: self.writing_mode,
            fallback: GlyphFallback::NotdefGlyph,
          }
        None =>
          CMapDecodeResult::{
            source_bytes: source,
            source_code: bytes_to_uint(source),
            cid: 0,
            consumed: source.length(),
            writing_mode: self.writing_mode,
            fallback: GlyphFallback::CIDZero,
          }
      }
  }
}

///|
fn CMap::partial_codespace_length(
  self : CMap,
  bytes : Bytes,
  start : Int,
) -> Int {
  let remaining = bytes.length() - start
  let mut best = 1
  for range in self.codespaces {
    let length = range.length()
    let available = if remaining < length { remaining } else { length }
    if available > best &&
      prefix_can_match_range(bytes, start, available, range.low, range.high) {
      best = available
    }
  }
  best
}

///|
fn find_cid_mapping(mappings : Array[CMapCIDMapping], source : Bytes) -> Int? {
  let value = bytes_to_uint(source)
  for mapping in mappings {
    if source.length() == mapping.low.length() &&
      value >= bytes_to_uint(mapping.low) &&
      value <= bytes_to_uint(mapping.high) {
      return Some(mapping.cid_start + value - bytes_to_uint(mapping.low))
    }
  }
  None
}

///|
fn code_in_range(source : Bytes, low : Bytes, high : Bytes) -> Bool {
  source.length() == low.length() &&
  low.length() == high.length() &&
  bytes_to_uint(source) >= bytes_to_uint(low) &&
  bytes_to_uint(source) <= bytes_to_uint(high)
}

///|
fn prefix_can_match_range(
  bytes : Bytes,
  start : Int,
  length : Int,
  low : Bytes,
  high : Bytes,
) -> Bool {
  let prefix = copy_bytes_range(bytes, start, length)
  let low_prefix = copy_bytes_range(low, 0, length)
  let high_prefix = copy_bytes_range(high, 0, length)
  bytes_to_uint(prefix) >= bytes_to_uint(low_prefix) &&
  bytes_to_uint(prefix) <= bytes_to_uint(high_prefix)
}

///|
fn ranges_overlap(
  left : CMapCodespaceRange,
  right : CMapCodespaceRange,
) -> Bool {
  left.length() == right.length() &&
  bytes_to_uint(left.low) <= bytes_to_uint(right.high) &&
  bytes_to_uint(right.low) <= bytes_to_uint(left.high)
}

///|
fn bytes_to_uint(bytes : Bytes) -> Int {
  let mut value = 0
  for byte in bytes {
    value = value * 256 + byte.to_int()
  }
  value
}

///|
fn copy_bytes_range(bytes : Bytes, start : Int, length : Int) -> Bytes {
  let output : Array[Byte] = []
  for index in start..<(start + length) {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}
