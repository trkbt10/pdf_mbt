///|
/// Adobe Standard Strings for CFF SID 0-390, defined by Adobe TN 5176
/// Appendix A. The CFF charset parser uses these predefined glyph name
/// strings before consulting the CFF String INDEX for custom SIDs.
let adobe_standard_strings : Array[String] = [
  ".notdef", "space", "exclam", "quotedbl", "numbersign", "dollar", "percent", "ampersand",
  "quoteright", "parenleft", "parenright", "asterisk", "plus", "comma", "hyphen",
  "period", "slash", "zero", "one", "two", "three", "four", "five", "six", "seven",
  "eight", "nine", "colon", "semicolon", "less", "equal", "greater", "question",
  "at", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O",
  "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "bracketleft", "backslash",
  "bracketright", "asciicircum", "underscore", "quoteleft", "a", "b", "c", "d", "e",
  "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u",
  "v", "w", "x", "y", "z", "braceleft", "bar", "braceright", "asciitilde", "exclamdown",
  "cent", "sterling", "fraction", "yen", "florin", "section", "currency", "quotesingle",
  "quotedblleft", "guillemotleft", "guilsinglleft", "guilsinglright", "fi", "fl",
  "endash", "dagger", "daggerdbl", "periodcentered", "paragraph", "bullet", "quotesinglbase",
  "quotedblbase", "quotedblright", "guillemotright", "ellipsis", "perthousand", "questiondown",
  "grave", "acute", "circumflex", "tilde", "macron", "breve", "dotaccent", "dieresis",
  "ring", "cedilla", "hungarumlaut", "ogonek", "caron", "emdash", "AE", "ordfeminine",
  "Lslash", "Oslash", "OE", "ordmasculine", "ae", "dotlessi", "lslash", "oslash",
  "oe", "germandbls", "onesuperior", "logicalnot", "mu", "trademark", "Eth", "onehalf",
  "plusminus", "Thorn", "onequarter", "divide", "brokenbar", "degree", "thorn", "threequarters",
  "twosuperior", "registered", "minus", "eth", "multiply", "threesuperior", "copyright",
  "Aacute", "Acircumflex", "Adieresis", "Agrave", "Aring", "Atilde", "Ccedilla",
  "Eacute", "Ecircumflex", "Edieresis", "Egrave", "Iacute", "Icircumflex", "Idieresis",
  "Igrave", "Ntilde", "Oacute", "Ocircumflex", "Odieresis", "Ograve", "Otilde", "Scaron",
  "Uacute", "Ucircumflex", "Udieresis", "Ugrave", "Yacute", "Ydieresis", "Zcaron",
  "aacute", "acircumflex", "adieresis", "agrave", "aring", "atilde", "ccedilla",
  "eacute", "ecircumflex", "edieresis", "egrave", "iacute", "icircumflex", "idieresis",
  "igrave", "ntilde", "oacute", "ocircumflex", "odieresis", "ograve", "otilde", "scaron",
  "uacute", "ucircumflex", "udieresis", "ugrave", "yacute", "ydieresis", "zcaron",
  "exclamsmall", "Hungarumlautsmall", "dollaroldstyle", "dollarsuperior", "ampersandsmall",
  "Acutesmall", "parenleftsuperior", "parenrightsuperior", "twodotenleader", "onedotenleader",
  "zerooldstyle", "oneoldstyle", "twooldstyle", "threeoldstyle", "fouroldstyle",
  "fiveoldstyle", "sixoldstyle", "sevenoldstyle", "eightoldstyle", "nineoldstyle",
  "commasuperior", "threequartersemdash", "periodsuperior", "questionsmall", "asuperior",
  "bsuperior", "centsuperior", "dsuperior", "esuperior", "isuperior", "lsuperior",
  "msuperior", "nsuperior", "osuperior", "rsuperior", "ssuperior", "tsuperior", "ff",
  "ffi", "ffl", "parenleftinferior", "parenrightinferior", "Circumflexsmall", "hyphensuperior",
  "Gravesmall", "Asmall", "Bsmall", "Csmall", "Dsmall", "Esmall", "Fsmall", "Gsmall",
  "Hsmall", "Ismall", "Jsmall", "Ksmall", "Lsmall", "Msmall", "Nsmall", "Osmall",
  "Psmall", "Qsmall", "Rsmall", "Ssmall", "Tsmall", "Usmall", "Vsmall", "Wsmall",
  "Xsmall", "Ysmall", "Zsmall", "colonmonetary", "onefitted", "rupiah", "Tildesmall",
  "exclamdownsmall", "centoldstyle", "Lslashsmall", "Scaronsmall", "Zcaronsmall",
  "Dieresissmall", "Brevesmall", "Caronsmall", "Dotaccentsmall", "Macronsmall", "figuredash",
  "hypheninferior", "Ogoneksmall", "Ringsmall", "Cedillasmall", "questiondownsmall",
  "oneeighth", "threeeighths", "fiveeighths", "seveneighths", "onethird", "twothirds",
  "zerosuperior", "foursuperior", "fivesuperior", "sixsuperior", "sevensuperior",
  "eightsuperior", "ninesuperior", "zeroinferior", "oneinferior", "twoinferior",
  "threeinferior", "fourinferior", "fiveinferior", "sixinferior", "seveninferior",
  "eightinferior", "nineinferior", "centinferior", "dollarinferior", "periodinferior",
  "commainferior", "Agravesmall", "Aacutesmall", "Acircumflexsmall", "Atildesmall",
  "Adieresissmall", "Aringsmall", "AEsmall", "Ccedillasmall", "Egravesmall", "Eacutesmall",
  "Ecircumflexsmall", "Edieresissmall", "Igravesmall", "Iacutesmall", "Icircumflexsmall",
  "Idieresissmall", "Ethsmall", "Ntildesmall", "Ogravesmall", "Oacutesmall", "Ocircumflexsmall",
  "Otildesmall", "Odieresissmall", "OEsmall", "Oslashsmall", "Ugravesmall", "Uacutesmall",
  "Ucircumflexsmall", "Udieresissmall", "Yacutesmall", "Thornsmall", "Ydieresissmall",
  "001.000", "001.001", "001.002", "001.003", "Black", "Bold", "Book", "Light", "Medium",
  "Regular", "Roman", "Semibold",
]

///|
/// WinAnsiEncoding glyph name table for PDF simple fonts. The synthetic cmap
/// builder uses this table to map character codes to CFF charset glyph names.
let winansi_encoding : Array[String] = [
  "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "",
  "", "", "", "", "", "", "", "", "", "", "", "", "space", "exclam", "quotedbl",
  "numbersign", "dollar", "percent", "ampersand", "quotesingle", "parenleft", "parenright",
  "asterisk", "plus", "comma", "hyphen", "period", "slash", "zero", "one", "two",
  "three", "four", "five", "six", "seven", "eight", "nine", "colon", "semicolon",
  "less", "equal", "greater", "question", "at", "A", "B", "C", "D", "E", "F", "G",
  "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W",
  "X", "Y", "Z", "bracketleft", "backslash", "bracketright", "asciicircum", "underscore",
  "grave", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n",
  "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "braceleft", "bar",
  "braceright", "asciitilde", "", "Euro", "", "quotesinglbase", "florin", "quotedblbase",
  "ellipsis", "dagger", "daggerdbl", "circumflex", "perthousand", "Scaron", "guilsinglleft",
  "OE", "", "Zcaron", "", "", "quoteleft", "quoteright", "quotedblleft", "quotedblright",
  "bullet", "endash", "emdash", "tilde", "trademark", "scaron", "guilsinglright",
  "oe", "", "zcaron", "Ydieresis", "space", "exclamdown", "cent", "sterling", "currency",
  "yen", "brokenbar", "section", "dieresis", "copyright", "ordfeminine", "guillemotleft",
  "logicalnot", "hyphen", "registered", "macron", "degree", "plusminus", "twosuperior",
  "threesuperior", "acute", "mu", "paragraph", "periodcentered", "cedilla", "onesuperior",
  "ordmasculine", "guillemotright", "onequarter", "onehalf", "threequarters", "questiondown",
  "Agrave", "Aacute", "Acircumflex", "Atilde", "Adieresis", "Aring", "AE", "Ccedilla",
  "Egrave", "Eacute", "Ecircumflex", "Edieresis", "Igrave", "Iacute", "Icircumflex",
  "Idieresis", "Eth", "Ntilde", "Ograve", "Oacute", "Ocircumflex", "Otilde", "Odieresis",
  "multiply", "Oslash", "Ugrave", "Uacute", "Ucircumflex", "Udieresis", "Yacute",
  "Thorn", "germandbls", "agrave", "aacute", "acircumflex", "atilde", "adieresis",
  "aring", "ae", "ccedilla", "egrave", "eacute", "ecircumflex", "edieresis", "igrave",
  "iacute", "icircumflex", "idieresis", "eth", "ntilde", "ograve", "oacute", "ocircumflex",
  "otilde", "odieresis", "divide", "oslash", "ugrave", "uacute", "ucircumflex", "udieresis",
  "yacute", "thorn", "ydieresis",
]

///|
/// Escaped TopDICT operator for CID-keyed CFF ROS (Registry/Ordering/
/// Supplement), encoded in Adobe TN 5176 as byte sequence 12 30.
let cff_ros_operator : Int = (12 << 8) | 30

///|
/// Escaped TopDICT operator for CID-keyed CFF CIDCount, encoded in Adobe TN
/// 5176 as byte sequence 12 34.
let cff_cid_count_operator : Int = (12 << 8) | 34

///|
/// Resolves a predefined CFF SID through Adobe Standard Strings. Returns None
/// for custom SIDs, which are resolved through the CFF String INDEX.
pub fn adobe_standard_string(sid : Int) -> String? {
  if sid >= 0 && sid < adobe_standard_strings.length() {
    Some(adobe_standard_strings[sid])
  } else {
    None
  }
}

///|
/// Resolves a PDF WinAnsiEncoding character code to an Adobe glyph name for
/// synthetic cmap population. Unassigned character codes return "".
pub fn winansi_glyph_name(code : Int) -> String {
  if code >= 0 && code < winansi_encoding.length() {
    winansi_encoding[code]
  } else {
    ""
  }
}

///|
/// Reads an entry from the CFF String INDEX. The String INDEX is the third
/// CFF INDEX after the header, following Name INDEX and Top DICT INDEX, and
/// supplies custom glyph name strings for SIDs starting at 391.
pub fn cff_string_index_entry(data : Bytes, index : Int) -> String? {
  if index < 0 || data.length() < 5 {
    return None
  }
  let hdr_size = data[2].to_int()
  if hdr_size < 4 || hdr_size > data.length() {
    return None
  }
  let name_end = cff_skip_index(data, hdr_size)
  if name_end < 0 {
    return None
  }
  let top_dict_end = cff_skip_index(data, name_end)
  if top_dict_end < 0 {
    return None
  }
  match cff_index_entry_bounds(data, top_dict_end, index) {
    Some((start, end)) => Some(cff_ascii_string(data, start, end))
    None => None
  }
}

///|
fn cff_index_entry_bounds(data : Bytes, pos : Int, index : Int) -> (Int, Int)? {
  if pos + 2 > data.length() {
    return None
  }
  let count = cff_read_uint16(data, pos)
  if index < 0 || index >= count {
    return None
  }
  if count == 0 || pos + 3 > data.length() {
    return None
  }
  let off_size = data[pos + 2].to_int()
  if off_size < 1 || off_size > 4 {
    return None
  }
  let offsets_start = pos + 3
  let offsets_end = offsets_start + (count + 1) * off_size
  if offsets_end > data.length() {
    return None
  }
  let start_offset = cff_read_offset(
    data,
    offsets_start + index * off_size,
    off_size,
  )
  let end_offset = cff_read_offset(
    data,
    offsets_start + (index + 1) * off_size,
    off_size,
  )
  if start_offset < 1 || end_offset < start_offset {
    return None
  }
  let data_start = offsets_end
  let start = data_start + start_offset - 1
  let end = data_start + end_offset - 1
  if start < data_start || end > data.length() {
    None
  } else {
    Some((start, end))
  }
}

///|
fn cff_ascii_string(data : Bytes, start : Int, end : Int) -> String {
  let chars : Array[Char] = []
  for pos in start..<end {
    chars.push(data[pos].to_char())
  }
  String::from_array(chars)
}

///|
/// Reads the CFF charset offset from Top DICT operator 15. Values 0, 1, and 2
/// identify predefined charsets; other non-negative values are absolute CFF
/// offsets to a charset table. Returns -1 when the charset operator is absent
/// or the Top DICT cannot be parsed.
pub fn cff_charset_offset(data : Bytes) -> Int {
  match cff_top_dict_entry_bounds(data) {
    Some((offset, length)) => cff_dict_find_operator(data, offset, length, 15)
    None => -1
  }
}

///|
/// Detects CID-keyed CFF fonts by scanning the TopDICT for the ROS operator
/// or CIDCount operator. CIDFontType0C streams use ROS to identify the CID
/// system and their charset entries are CIDs rather than Type1C SIDs.
pub fn is_cid_keyed_cff(data : Bytes) -> Bool {
  match cff_top_dict_entry_bounds(data) {
    Some((offset, length)) =>
      cff_dict_has_operator(data, offset, length, cff_ros_operator) ||
      cff_dict_has_operator(data, offset, length, cff_cid_count_operator)
    None => false
  }
}

///|
/// Reads the CIDCount TopDICT operator for a CID-keyed CFF font. Returns 0
/// when CIDCount is absent or the TopDICT cannot be parsed.
pub fn cff_cid_count(data : Bytes) -> Int {
  match cff_top_dict_entry_bounds(data) {
    Some((offset, length)) => {
      let count = cff_dict_find_operator(
        data, offset, length, cff_cid_count_operator,
      )
      if count > 0 {
        count
      } else {
        0
      }
    }
    None => 0
  }
}

///|
/// Parses the CFF charset table into a glyph_id to SID array. Supports CFF
/// charset format 0, format 1, and format 2 as defined by Adobe TN 5176.
/// glyph_id 0 is always SID 0 (.notdef). Returns None for malformed charset
/// data or predefined charset offsets that do not contain an inline table.
pub fn parse_cff_charset(data : Bytes, num_glyphs : Int) -> Array[Int]? {
  if num_glyphs <= 0 {
    return None
  }
  let sids = Array::make(num_glyphs, 0)
  if num_glyphs == 1 {
    return Some(sids)
  }
  let offset = cff_charset_offset(data)
  if offset < 3 || offset >= data.length() {
    return None
  }
  let format = data[offset].to_int()
  match format {
    0 => parse_cff_charset_format0(data, offset + 1, sids, num_glyphs)
    1 => parse_cff_charset_format1(data, offset + 1, sids, num_glyphs)
    2 => parse_cff_charset_format2(data, offset + 1, sids, num_glyphs)
    _ => None
  }
}

///|
/// Parses a CID-keyed CFF charset as glyph_id to CID values. The binary
/// charset formats are identical to Type1C SID charsets, but CIDFontType0C
/// semantics define each entry as a CID; glyph_id 0 is CID 0 (.notdef).
pub fn parse_cff_cid_charset(data : Bytes, num_glyphs : Int) -> Array[Int]? {
  parse_cff_charset(data, num_glyphs)
}

///|
fn cff_top_dict_entry_bounds(data : Bytes) -> (Int, Int)? {
  if data.length() < 5 {
    return None
  }
  let hdr_size = data[2].to_int()
  if hdr_size < 4 || hdr_size > data.length() {
    return None
  }
  let name_end = cff_skip_index(data, hdr_size)
  if name_end < 0 {
    return None
  }
  cff_index_entry_bounds(data, name_end, 0)
}

///|
fn cff_dict_has_operator(
  data : Bytes,
  offset : Int,
  length : Int,
  target_op : Int,
) -> Bool {
  let end = offset + length
  let mut pos = offset
  while pos < end {
    let b0 = data[pos].to_int()
    pos += 1
    if b0 >= 32 {
      let (_, new_pos) = cff_decode_dict_operand(data, pos, b0)
      pos = new_pos
    } else if b0 == 12 {
      if pos < end {
        let op = (12 << 8) | data[pos].to_int()
        pos += 1
        if op == target_op {
          return true
        }
      }
    } else if b0 == target_op {
      return true
    }
  }
  false
}

///|
fn parse_cff_charset_format0(
  data : Bytes,
  pos : Int,
  sids : Array[Int],
  num_glyphs : Int,
) -> Array[Int]? {
  let needed = pos + (num_glyphs - 1) * 2
  if needed > data.length() {
    return None
  }
  for glyph_id in 1..<num_glyphs {
    sids[glyph_id] = cff_read_uint16(data, pos + (glyph_id - 1) * 2)
  }
  Some(sids)
}

///|
fn parse_cff_charset_format1(
  data : Bytes,
  pos : Int,
  sids : Array[Int],
  num_glyphs : Int,
) -> Array[Int]? {
  let mut current_pos = pos
  let mut glyph_id = 1
  while glyph_id < num_glyphs {
    if current_pos + 3 > data.length() {
      return None
    }
    let first_sid = cff_read_uint16(data, current_pos)
    let num_left = data[current_pos + 2].to_int()
    current_pos += 3
    let count = num_left + 1
    if glyph_id + count > num_glyphs {
      return None
    }
    for i in 0..<count {
      sids[glyph_id + i] = first_sid + i
    }
    glyph_id += count
  }
  Some(sids)
}

///|
fn parse_cff_charset_format2(
  data : Bytes,
  pos : Int,
  sids : Array[Int],
  num_glyphs : Int,
) -> Array[Int]? {
  let mut current_pos = pos
  let mut glyph_id = 1
  while glyph_id < num_glyphs {
    if current_pos + 4 > data.length() {
      return None
    }
    let first_sid = cff_read_uint16(data, current_pos)
    let num_left = cff_read_uint16(data, current_pos + 2)
    current_pos += 4
    let count = num_left + 1
    if glyph_id + count > num_glyphs {
      return None
    }
    for i in 0..<count {
      sids[glyph_id + i] = first_sid + i
    }
    glyph_id += count
  }
  Some(sids)
}

///|
/// Builds a CFF glyph_id to glyph_name table by combining the parsed CFF
/// charset SIDs with Adobe Standard Strings and the custom CFF String INDEX.
/// The returned array is indexed directly by glyph_id for synthetic cmap
/// construction and SVG glyph name resolution.
pub fn cff_glyph_name_table(data : Bytes, num_glyphs : Int) -> Array[String]? {
  match parse_cff_charset(data, num_glyphs) {
    Some(sids) => {
      let names : Array[String] = []
      for sid in sids {
        match cff_sid_glyph_name(data, sid) {
          Some(name) => names.push(name)
          None => return None
        }
      }
      Some(names)
    }
    None => None
  }
}

///|
fn cff_sid_glyph_name(data : Bytes, sid : Int) -> String? {
  if sid < 0 {
    return None
  }
  match adobe_standard_string(sid) {
    Some(name) => Some(name)
    None => cff_string_index_entry(data, sid - adobe_standard_strings.length())
  }
}
