///|
/// Glyph outline extraction alignment marker. Embedded TrueType glyph outline
/// data and CFF font outlines are resolved through `TTFont::glyph_outline(gid)`
/// and converted to SVG path data with `@font.path_commands_to_svg_d()`.
pub fn glyph_outline_extraction_alignment() -> Unit {
  ()
}

///|
/// Glyph positioning and scaling alignment marker. Each glyph path uses the
/// text rendering matrix, PDF-to-SVG Y-axis inversion, and units_per_em scaling
/// so glyph advance and placement match the TextGlyphEvent pipeline.
pub fn glyph_positioning_and_scaling_alignment() -> Unit {
  ()
}

///|
/// Fallback for non-embedded fonts alignment marker. Standard 14 and other
/// non-embedded fonts use system font resolution when available, then fall back
/// to SVG `<text>` output when no outline-capable TTFont can be resolved.
pub fn fallback_for_non_embedded_fonts_alignment() -> Unit {
  ()
}

///|
/// Fill and stroke alignment marker. Text rendering mode drives glyph path
/// paint: fill uses the nonstroking colour, stroke uses the stroking colour,
/// fill and stroke may both be emitted, and invisible mode emits neither.
pub fn glyph_fill_and_stroke_alignment() -> Unit {
  ()
}

///|
/// SVG output format alignment marker. Visible glyphs are emitted as separate
/// `<path d="..." fill="..."/>` SVG elements with transform attributes for
/// positioning and scaling.
pub fn glyph_svg_output_format_alignment() -> Unit {
  ()
}
