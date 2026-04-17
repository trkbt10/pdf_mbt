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
