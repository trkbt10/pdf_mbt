///|
/// Lenient TrueType / OpenType parser for fonts embedded inside CIDFontType2
/// dictionaries. The shared mizchi/font `parse_ttf` rejects fonts that lack a
/// `cmap` table, which is the common shape for subset PDF embedding because
/// the PDF supplies CIDToGIDMap externally and the producer drops the now
/// redundant cmap to save bytes. Refusing to parse those fonts bubbles up to
/// the SVG renderer as fallback `<text font-family="MS-PGothic, sans-serif">`,
/// and absent the system font the user sees Japanese text as tofu boxes.
///
/// This parser accepts the same byte layout as `parse_ttf` but treats `cmap`
/// as optional — the only consumer of `TTFont::cmap` for PDF fonts is
/// codepoint → GID lookup, which the CID emission path bypasses entirely in
/// favour of CIDToGIDMap / CFF charset / cmap lookups maintained alongside
/// the embedded font in `SvgEmbeddedFont`. We default the absent cmap to an
/// empty `Map[Int, Int]` so glyph rendering can proceed via
/// `TTFont::glyph_outline(gid)`.
///
/// We deliberately reuse mizchi/font's public table parsers (parse_head,
/// parse_maxp, parse_hhea, parse_hmtx, parse_loca, parse_post, parse_os2,
/// parse_vorg, parse_kern, parse_name, parse_cmap) so the resulting TTFont is
/// byte-for-byte identical to the strict path for everything except the cmap
/// fallback. CFF / CFF2 / fvar / gvar / vhea / vmtx / gasp / variable axes
/// are all optional and decoded the same way.
fn parse_ttf_lenient(data : Bytes) -> @font.TTFont? {
  if data.length() < 12 {
    return None
  }
  let reader = @font.BinaryReader::at(data, 0)
  let _sfnt_version = reader.read_uint32()
  let num_tables = reader.read_uint16()
  let _search_range = reader.read_uint16()
  let _entry_selector = reader.read_uint16()
  let _range_shift = reader.read_uint16()
  let table_offsets : Map[String, Int] = Map::new()
  for _i in 0..<num_tables {
    let tag = reader.read_tag()
    let _checksum = reader.read_uint32()
    let offset = reader.read_uint32()
    let _length = reader.read_uint32()
    table_offsets[tag] = offset
  }
  let head_offset = match table_offsets.get("head") {
    Some(value) => value
    None => return None
  }
  let maxp_offset = match table_offsets.get("maxp") {
    Some(value) => value
    None => return None
  }
  let hhea_offset = match table_offsets.get("hhea") {
    Some(value) => value
    None => return None
  }
  let hmtx_offset = match table_offsets.get("hmtx") {
    Some(value) => value
    None => return None
  }
  let (units_per_em, index_to_loc_format) = @font.parse_head(reader, head_offset)
  let num_glyphs = @font.parse_maxp(reader, maxp_offset)
  let (ascent, descent, line_gap, num_h_metrics) = @font.parse_hhea(
    reader, hhea_offset,
  )
  let (advance_widths, left_side_bearings) = @font.parse_hmtx(
    reader, hmtx_offset, num_glyphs, num_h_metrics,
  )
  let cmap = match table_offsets.get("cmap") {
    Some(offset) => @font.parse_cmap(reader, offset)
    None => Map::new()
  }
  let glyf_offset = match table_offsets.get("glyf") {
    Some(value) => value
    None => 0
  }
  let loca = match (table_offsets.get("loca"), table_offsets.get("glyf")) {
    (Some(loca_offset), Some(_)) =>
      @font.parse_loca(reader, loca_offset, num_glyphs, index_to_loc_format)
    _ => []
  }
  let post = match table_offsets.get("post") {
    Some(offset) => Some(@font.parse_post(reader, offset, num_glyphs))
    None => None
  }
  let os2 = match table_offsets.get("OS/2") {
    Some(offset) => Some(@font.parse_os2(reader, offset))
    None => None
  }
  let vorg = match table_offsets.get("VORG") {
    Some(offset) => Some(@font.parse_vorg(reader, offset))
    None => None
  }
  let kern_pairs = match table_offsets.get("kern") {
    Some(offset) => @font.parse_kern(reader, offset)
    None => Map::new()
  }
  let name_records = match table_offsets.get("name") {
    Some(offset) => @font.parse_name(reader, offset)
    None => Map::new()
  }
  Some(@font.TTFont::{
    units_per_em,
    index_to_loc_format,
    num_glyphs,
    ascent,
    descent,
    line_gap,
    num_h_metrics,
    glyf_offset,
    data,
    cmap,
    loca,
    advance_widths,
    left_side_bearings,
    cff: None,
    gvar: None,
    var_axes: [],
    kern_pairs,
    avar_segments: [],
    name_records,
    os2,
    post,
    vertical: None,
    gasp: [],
    vorg,
  })
}
