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
fn cff_index_entry_bounds(
  data : Bytes,
  pos : Int,
  index : Int,
) -> (Int, Int)? {
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
