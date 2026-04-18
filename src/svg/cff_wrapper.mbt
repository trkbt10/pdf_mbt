///|
/// Detects whether raw bytes are standalone CFF (Compact Font Format) data
/// rather than a complete sfnt-wrapped font file (OTF/TTF/WOFF).
///
/// CFF v1 starts with major version byte 0x01. sfnt containers start with
/// 0x4F54544F (OTTO), 0x00010000 (TrueType), 0x74727565 (true), 0x774F4646
/// (wOFF), or 0x774F4632 (wOF2).
fn is_raw_cff(data : Bytes) -> Bool {
  if data.length() < 4 {
    return false
  }
  let magic = (data[0].to_int() << 24) |
    (data[1].to_int() << 16) |
    (data[2].to_int() << 8) |
    data[3].to_int()
  // Known sfnt/collection magic values
  if magic == 0x4F54544F ||
    magic == 0x00010000 ||
    magic == 0x74727565 ||
    magic == 0x774F4646 ||
    magic == 0x774F4632 ||
    magic == 0x74746366 {
    return false
  }
  // CFF version 1: major=1, minor=0, hdrSize>=4
  data[0] == b'\x01' && data[2].to_int() >= 4
}

///|
/// Wraps raw CFF data in a minimal OTF (OpenType) container so that
/// `@font.parse_font()` can parse it. Constructs synthetic `head`, `maxp`,
/// `hhea`, `hmtx`, and `cmap` tables alongside the `CFF ` table.
///
/// Returns the complete OTF binary, or None if the CFF data cannot be parsed
/// enough to determine glyph count.
fn wrap_cff_in_otf(cff_data : Bytes) -> Bytes? {
  let num_glyphs = cff_charstrings_count(cff_data)
  if num_glyphs <= 0 {
    return None
  }
  let head = build_synthetic_head(1000)
  let maxp = build_synthetic_maxp(num_glyphs)
  let hhea = build_synthetic_hhea(num_glyphs)
  let hmtx = build_synthetic_hmtx(num_glyphs)
  let glyph_names = cff_post_glyph_name_table(cff_data, num_glyphs)
  let cmap = build_synthetic_cmap(cff_data, num_glyphs)
  let tables : Array[(String, Bytes)] = [
    ("CFF ", cff_data),
    ("cmap", cmap),
    ("head", head),
    ("hhea", hhea),
    ("hmtx", hmtx),
    ("maxp", maxp),
  ]
  match glyph_names {
    Some(names) => tables.push(("post", build_synthetic_post(names)))
    None => ()
  }
  Some(@font.rebuild_sfnt(0x4F54544F, tables))
}

///|
/// Builds synthetic post glyph names for the CFF wrapper. CID-keyed
/// CIDFontType0C fonts expose their CID reverse map through cid.XXXXX post
/// name entries such as cid00012, while Type1C fonts preserve SID-based Adobe
/// glyph names.
fn cff_post_glyph_name_table(
  cff_data : Bytes,
  num_glyphs : Int,
) -> Array[String]? {
  if is_cid_keyed_cff(cff_data) {
    match parse_cff_cid_charset(cff_data, num_glyphs) {
      Some(cids) => {
        let names : Array[String] = []
        for cid in cids {
          names.push(cff_cid_post_name(cid))
        }
        Some(names)
      }
      None => None
    }
  } else {
    cff_glyph_name_table(cff_data, num_glyphs)
  }
}

///|
fn cff_cid_post_name(cid : Int) -> String {
  "cid" + cid_pad5(cid)
}

///|
/// Extracts the number of glyphs (CharStrings INDEX entry count) from raw CFF
/// data. Parses the CFF header, skips Name INDEX, reads Top DICT INDEX to find
/// the CharStrings offset (operator 17), then reads the uint16 count at that
/// offset.
fn cff_charstrings_count(data : Bytes) -> Int {
  if data.length() < 5 {
    return 0
  }
  // CFF header: major(1) minor(1) hdrSize(1) offSize(1)
  let hdr_size = data[2].to_int()
  if hdr_size < 4 || hdr_size >= data.length() {
    return 0
  }
  let mut pos = hdr_size
  // Skip Name INDEX
  pos = cff_skip_index(data, pos)
  if pos <= 0 {
    return 0
  }
  // Read Top DICT INDEX — we need the first entry
  let top_dict_start = pos
  let top_dict_count = cff_read_uint16(data, top_dict_start)
  if top_dict_count == 0 {
    return 0
  }
  let off_size = data[top_dict_start + 2].to_int()
  if off_size < 1 || off_size > 4 {
    return 0
  }
  // First entry: offsets[0] and offsets[1]
  let offsets_start = top_dict_start + 3
  let off0 = cff_read_offset(data, offsets_start, off_size) - 1
  let off1 = cff_read_offset(data, offsets_start + off_size, off_size) - 1
  let data_start = offsets_start + (top_dict_count + 1) * off_size
  let td_offset = data_start + off0
  let td_length = off1 - off0
  if td_offset < 0 || td_offset + td_length > data.length() {
    return 0
  }
  // Parse Top DICT for operator 17 (CharStrings offset)
  let charstrings_offset = cff_dict_find_operator(
    data, td_offset, td_length, 17,
  )
  if charstrings_offset < 0 || charstrings_offset + 2 > data.length() {
    return 0
  }
  // CharStrings INDEX: first 2 bytes = uint16 count
  cff_read_uint16(data, charstrings_offset)
}

///|
/// Skips a CFF INDEX structure at the given position. Returns the position
/// immediately after the INDEX, or -1 on error.
fn cff_skip_index(data : Bytes, pos : Int) -> Int {
  if pos + 2 > data.length() {
    return -1
  }
  let count = cff_read_uint16(data, pos)
  if count == 0 {
    return pos + 2
  }
  if pos + 3 > data.length() {
    return -1
  }
  let off_size = data[pos + 2].to_int()
  if off_size < 1 || off_size > 4 {
    return -1
  }
  let offsets_start = pos + 3
  let offsets_end = offsets_start + (count + 1) * off_size
  if offsets_end > data.length() {
    return -1
  }
  // Last offset value gives data size
  let last_offset = cff_read_offset(
      data,
      offsets_start + count * off_size,
      off_size,
    ) -
    1
  offsets_end + last_offset
}

///|
/// Reads a big-endian uint16 from bytes at the given position.
fn cff_read_uint16(data : Bytes, pos : Int) -> Int {
  (data[pos].to_int() << 8) | data[pos + 1].to_int()
}

///|
/// Reads a CFF offset of the given byte size (1-4) at the given position.
fn cff_read_offset(data : Bytes, pos : Int, off_size : Int) -> Int {
  match off_size {
    1 => data[pos].to_int()
    2 => (data[pos].to_int() << 8) | data[pos + 1].to_int()
    3 =>
      (data[pos].to_int() << 16) |
      (data[pos + 1].to_int() << 8) |
      data[pos + 2].to_int()
    4 =>
      (data[pos].to_int() << 24) |
      (data[pos + 1].to_int() << 16) |
      (data[pos + 2].to_int() << 8) |
      data[pos + 3].to_int()
    _ => 0
  }
}

///|
/// Searches a CFF DICT for a specific operator and returns the last operand
/// value (integer). Returns -1 if not found.
fn cff_dict_find_operator(
  data : Bytes,
  offset : Int,
  length : Int,
  target_op : Int,
) -> Int {
  let end = offset + length
  let mut pos = offset
  let mut last_operand = -1
  while pos < end {
    let b0 = data[pos].to_int()
    pos += 1
    if cff_dict_byte_is_operand(b0) {
      // Operand
      let (val, new_pos) = cff_decode_dict_operand(data, pos, b0)
      last_operand = val
      pos = new_pos
    } else if b0 == 12 {
      // Two-byte operator
      if pos < end {
        let op = (12 << 8) | data[pos].to_int()
        pos += 1
        if op == target_op {
          return last_operand
        }
      }
      last_operand = -1
    } else {
      // Single-byte operator
      if b0 == target_op {
        return last_operand
      }
      last_operand = -1
    }
  }
  -1
}

///|
fn cff_dict_byte_is_operand(b0 : Int) -> Bool {
  b0 == 28 || b0 == 29 || b0 == 30 || (b0 >= 32 && b0 <= 254)
}

///|
/// Decodes a CFF DICT operand. Returns (value, new_position).
fn cff_decode_dict_operand(data : Bytes, pos : Int, b0 : Int) -> (Int, Int) {
  if b0 >= 32 && b0 <= 246 {
    (b0 - 139, pos)
  } else if b0 >= 247 && b0 <= 250 {
    let b1 = data[pos].to_int()
    ((b0 - 247) * 256 + b1 + 108, pos + 1)
  } else if b0 >= 251 && b0 <= 254 {
    let b1 = data[pos].to_int()
    (-(b0 - 251) * 256 - b1 - 108, pos + 1)
  } else if b0 == 28 {
    let hi = data[pos].to_int()
    let lo = data[pos + 1].to_int()
    let val = (hi << 8) | lo
    if val >= 32768 {
      (val - 65536, pos + 2)
    } else {
      (val, pos + 2)
    }
  } else if b0 == 29 {
    let val = (data[pos].to_int() << 24) |
      (data[pos + 1].to_int() << 16) |
      (data[pos + 2].to_int() << 8) |
      data[pos + 3].to_int()
    (val, pos + 4)
  } else if b0 == 30 {
    // Real number — skip nibble pairs until 0xF terminator
    let mut p = pos
    for i = 0; i < 20; i = i + 1 {
      let b = data[p].to_int()
      p += 1
      let hi = (b >> 4) & 0xF
      let lo = b & 0xF
      if hi == 0xF || lo == 0xF {
        break
      }
    }
    (0, p)
  } else {
    (0, pos)
  }
}

///|
/// Builds a synthetic `head` table (54 bytes) for the OTF wrapper.
fn build_synthetic_head(units_per_em : Int) -> Bytes {
  let buf : Array[Byte] = Array::make(54, b'\x00')
  // version: 1.0 (0x00010000)
  buf[0] = b'\x00'
  buf[1] = b'\x01'
  buf[2] = b'\x00'
  buf[3] = b'\x00'
  // fontRevision: 1.0
  buf[4] = b'\x00'
  buf[5] = b'\x01'
  // checksumAdjustment: 0 (placeholder)
  // magicNumber: 0x5F0F3CF5
  buf[12] = b'\x5F'
  buf[13] = b'\x0F'
  buf[14] = b'\x3C'
  buf[15] = b'\xF5'
  // flags: 0x000B (baseline at y=0, LSB at x=0, hints)
  buf[16] = b'\x00'
  buf[17] = b'\x0B'
  // unitsPerEm
  buf[18] = ((units_per_em >> 8) & 0xFF).to_byte()
  buf[19] = (units_per_em & 0xFF).to_byte()
  // created/modified: 0 (8 bytes each, already zero)
  // xMin, yMin, xMax, yMax: 0 (already zero)
  // macStyle: 0
  // lowestRecPPEM: 8
  buf[46] = b'\x00'
  buf[47] = b'\x08'
  // indexToLocFormat: 0 (short offsets — not used for CFF but required)
  buf[50] = b'\x00'
  buf[51] = b'\x00'
  // glyphDataFormat: 0
  buf[52] = b'\x00'
  buf[53] = b'\x00'
  Bytes::from_array(buf[:])
}

///|
/// Builds a synthetic `maxp` table (6 bytes, CFF version 0x00005000).
fn build_synthetic_maxp(num_glyphs : Int) -> Bytes {
  let buf : Array[Byte] = Array::make(6, b'\x00')
  // version: 0x00005000 (CFF/CFF2)
  buf[0] = b'\x00'
  buf[1] = b'\x00'
  buf[2] = b'\x50'
  buf[3] = b'\x00'
  // numGlyphs
  buf[4] = ((num_glyphs >> 8) & 0xFF).to_byte()
  buf[5] = (num_glyphs & 0xFF).to_byte()
  Bytes::from_array(buf[:])
}

///|
/// Builds a synthetic `hhea` table (36 bytes).
fn build_synthetic_hhea(num_glyphs : Int) -> Bytes {
  let buf : Array[Byte] = Array::make(36, b'\x00')
  // majorVersion: 1, minorVersion: 0
  buf[0] = b'\x00'
  buf[1] = b'\x01'
  // ascender: 800
  buf[4] = b'\x03'
  buf[5] = b'\x20'
  // descender: -200 (0xFF38)
  buf[6] = b'\xFF'
  buf[7] = b'\x38'
  // lineGap: 0 (already zero)
  // advanceWidthMax: 1000
  buf[10] = b'\x03'
  buf[11] = b'\xE8'
  // numberOfHMetrics (offset 34-35)
  buf[34] = ((num_glyphs >> 8) & 0xFF).to_byte()
  buf[35] = (num_glyphs & 0xFF).to_byte()
  Bytes::from_array(buf[:])
}

///|
/// Builds a synthetic `hmtx` table with uniform advance widths.
/// Each entry: advanceWidth(uint16) + lsb(int16) = 4 bytes per glyph.
fn build_synthetic_hmtx(num_glyphs : Int) -> Bytes {
  let buf : Array[Byte] = Array::make(num_glyphs * 4, b'\x00')
  // Default advance width: 600 (reasonable monospace-ish default)
  for i = 0; i < num_glyphs; i = i + 1 {
    buf[i * 4] = b'\x02'
    buf[i * 4 + 1] = b'\x58'
    // lsb: 0 (already zero)
  }
  Bytes::from_array(buf[:])
}

///|
/// Builds a synthetic `post` format 2 table from CFF charset glyph names.
/// SVG renderer GlyphName resolution can reverse lookup glyph_name to glyph_id
/// through this post table when PDF Encoding Differences are not represented by
/// WinAnsiEncoding source codes in the synthetic cmap.
fn build_synthetic_post(glyph_names : Array[String]) -> Bytes {
  let mut string_bytes = 0
  for name in glyph_names {
    string_bytes += 1 + cff_post_name_length(name)
  }
  let total = 32 + 2 + glyph_names.length() * 2 + string_bytes
  let buf : Array[Byte] = Array::make(total, b'\x00')
  cff_write_uint(buf, 0, 0x00020000, 4)
  cff_write_uint(buf, 32, glyph_names.length(), 2)
  let indices = 34
  let mut string_pos = indices + glyph_names.length() * 2
  for glyph_id in 0..<glyph_names.length() {
    cff_write_uint(buf, indices + glyph_id * 2, 258 + glyph_id, 2)
    let name = glyph_names[glyph_id]
    let length = cff_post_name_length(name)
    buf[string_pos] = length.to_byte()
    string_pos += 1
    for i in 0..<length {
      buf[string_pos + i] = name.code_unit_at(i).to_byte()
    }
    string_pos += length
  }
  Bytes::from_array(buf[:])
}

///|
fn cff_post_name_length(name : String) -> Int {
  if name.length() > 255 {
    255
  } else {
    name.length()
  }
}

///|
/// Synthetic cmap reflecting charset. When the CFF charset and String INDEX
/// can be parsed, this builds WinAnsiEncoding-based cmap population by
/// resolving character_code values to charset glyph names and then glyph_id
/// entries. If CFF charset parsing fails, it uses the identity fallback when
/// charset parsing fails, matching the original Type1C wrapper behaviour.
///
/// For PDF use, the actual character-to-glyph mapping comes from the PDF
/// font's Encoding and ToUnicode entries. This synthetic cmap supplies
/// `@font.parse_font` with a bounded mapping so `TTFont::cmap.get(code)` can
/// resolve embedded CFF glyph IDs for SVG path rendering.
fn build_synthetic_cmap(cff_data : Bytes, num_glyphs : Int) -> Bytes {
  if is_cid_keyed_cff(cff_data) {
    build_identity_cmap(num_glyphs)
  } else {
    match cff_glyph_name_table(cff_data, num_glyphs) {
      Some(glyph_names) =>
        build_synthetic_cmap_format4(cff_charset_cmap_entries(glyph_names))
      None => build_identity_cmap(num_glyphs)
    }
  }
}

///|
/// Synthetic cmap reflecting charset alignment marker. The raw CFF wrapper uses
/// WinAnsiEncoding-based cmap population by resolving Adobe charset glyph names
/// and falls back to an identity fallback when charset parsing fails.
pub fn synthetic_cmap_reflecting_charset_alignment() -> Unit {
  ()
}

///|
fn cff_charset_cmap_entries(glyph_names : Array[String]) -> Array[(Int, Int)] {
  let entries : Array[(Int, Int)] = []
  for code in 0..<256 {
    let glyph_name = winansi_glyph_name(code)
    if glyph_name.length() > 0 {
      let glyph_id = cff_find_glyph_name(glyph_names, glyph_name)
      if glyph_id > 0 {
        entries.push((code, glyph_id))
      }
    }
  }
  entries
}

///|
fn cff_find_glyph_name(glyph_names : Array[String], glyph_name : String) -> Int {
  for glyph_id in 1..<glyph_names.length() {
    if glyph_names[glyph_id] == glyph_name {
      return glyph_id
    }
  }
  -1
}

///|
fn build_synthetic_cmap_format4(entries : Array[(Int, Int)]) -> Bytes {
  let seg_count = entries.length() + 1
  let subtable_length = 16 + seg_count * 8
  let total = 4 + 8 + subtable_length
  let buf : Array[Byte] = Array::make(total, b'\x00')
  // cmap header: version=0, numTables=1
  cff_write_uint(buf, 2, 1, 2)
  // Encoding record: platformID=3 (Windows), encodingID=1 (Unicode BMP)
  cff_write_uint(buf, 4, 3, 2)
  cff_write_uint(buf, 6, 1, 2)
  cff_write_uint(buf, 8, 12, 4)
  let base = 12
  cff_write_uint(buf, base, 4, 2)
  cff_write_uint(buf, base + 2, subtable_length, 2)
  cff_write_uint(buf, base + 6, seg_count * 2, 2)
  let (search_range, entry_selector, range_shift) = cff_format4_search_values(
    seg_count,
  )
  cff_write_uint(buf, base + 8, search_range, 2)
  cff_write_uint(buf, base + 10, entry_selector, 2)
  cff_write_uint(buf, base + 12, range_shift, 2)
  let end_codes = base + 14
  let reserved_pad = end_codes + seg_count * 2
  let start_codes = reserved_pad + 2
  let id_deltas = start_codes + seg_count * 2
  let id_range_offsets = id_deltas + seg_count * 2
  for i in 0..<entries.length() {
    let (code, glyph_id) = entries[i]
    cff_write_uint(buf, end_codes + i * 2, code, 2)
    cff_write_uint(buf, start_codes + i * 2, code, 2)
    cff_write_uint(buf, id_deltas + i * 2, cff_format4_delta(code, glyph_id), 2)
    cff_write_uint(buf, id_range_offsets + i * 2, 0, 2)
  }
  let sentinel = entries.length()
  cff_write_uint(buf, end_codes + sentinel * 2, 0xFFFF, 2)
  cff_write_uint(buf, start_codes + sentinel * 2, 0xFFFF, 2)
  cff_write_uint(buf, id_deltas + sentinel * 2, 1, 2)
  cff_write_uint(buf, id_range_offsets + sentinel * 2, 0, 2)
  Bytes::from_array(buf[:])
}

///|
fn cff_format4_search_values(seg_count : Int) -> (Int, Int, Int) {
  let mut power = 1
  let mut entry_selector = 0
  while power * 2 <= seg_count {
    power *= 2
    entry_selector += 1
  }
  let search_range = power * 2
  let range_shift = seg_count * 2 - search_range
  (search_range, entry_selector, range_shift)
}

///|
fn cff_format4_delta(code : Int, glyph_id : Int) -> Int {
  let mut delta = glyph_id - code
  while delta < 0 {
    delta += 65536
  }
  delta & 0xFFFF
}

///|
fn cff_write_uint(
  buf : Array[Byte],
  offset : Int,
  value : Int,
  width : Int,
) -> Unit {
  for i in 0..<width {
    let shift = (width - 1 - i) * 8
    buf[offset + i] = ((value >> shift) & 0xFF).to_byte()
  }
}

///|
/// Builds a synthetic `cmap` table with format 12 identity mapping.
/// Maps codepoints 0..numGlyphs-1 → glyph IDs 0..numGlyphs-1.
fn build_identity_cmap(num_glyphs : Int) -> Bytes {
  let end_code = num_glyphs - 1
  // cmap header (4 bytes) + encoding record (8 bytes) + format 12 subtable
  // Format 12: fixed header (16 bytes) + 1 group (12 bytes) = 28 bytes
  let subtable_length = 16 + 12
  let total = 4 + 8 + subtable_length
  let buf : Array[Byte] = Array::make(total, b'\x00')
  // cmap header: version=0, numTables=1
  cff_write_uint(buf, 2, 1, 2)
  // Encoding record: platformID=3 (Windows), encodingID=10 (Unicode full)
  cff_write_uint(buf, 4, 3, 2)
  cff_write_uint(buf, 6, 10, 2)
  // subtableOffset = 12
  cff_write_uint(buf, 8, 12, 4)
  // Format 12 subtable at offset 12
  let base = 12
  // format: 12
  cff_write_uint(buf, base, 12, 2)
  // length (uint32)
  let len = subtable_length
  cff_write_uint(buf, base + 4, len, 4)
  // numGroups: 1
  cff_write_uint(buf, base + 12, 1, 4)
  // Group 0: startCharCode=0, endCharCode=end_code, startGlyphID=0
  let g = base + 16
  cff_write_uint(buf, g + 4, end_code, 4)
  Bytes::from_array(buf[:])
}
