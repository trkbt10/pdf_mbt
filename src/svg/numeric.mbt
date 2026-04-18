///|
/// Pads CFF/PDF CID values to the five decimal digits used in synthetic
/// cid.XXXXX glyph names for both CFF post tables and SVG glyph lookup.
fn cid_pad5(value : Int) -> String {
  pad_unsigned_decimal(value, 5)
}

///|
fn pad_unsigned_decimal(value : Int, width : Int) -> String {
  let s = value.to_string()
  let builder = StringBuilder::new()
  for _ in s.length()..<width {
    builder.write_char('0')
  }
  builder.write_string(s)
  builder.to_string()
}
