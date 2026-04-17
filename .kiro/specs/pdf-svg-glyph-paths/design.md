# Design: SVG Glyph Path Rendering

## Overview

Replace `<text>` SVG elements with `<path>` elements when the PDF font
has an embedded TrueType font program. Each glyph is rendered as an
individual SVG path using outlines from the `glyf` table.

## Architecture

```
TextInterpreter → TextGlyphEvent (rendering_matrix, source_code, font_name)
    ↓
page_render_text_svg()
    ↓
Has TTFont for this font? ──yes──→ render_glyph_paths()
    │                                   ↓
    no                             For each glyph:
    ↓                                TTFont.cmap.get(source_code) → gid
render as <text> (existing)          TTFont.glyph_outline(gid) → PathCommand[]
                                     path_commands_to_svg_d() → "d" string
                                     Apply rendering_matrix as transform
                                     Emit <path d="..." transform="..." fill="..."/>
```

## Key Design Decisions

### 1. One `<path>` per glyph vs. merged path

One path per glyph allows individual positioning via transform.
Merging all glyphs into a single path would require translating
each outline's coordinates, which is more complex.

### 2. Transform matrix

For each glyph, the transform is:
```
transform="matrix(a b c d e f)"
```
where the matrix is the rendering_matrix with:
- Y-flip for SVG coordinates (negate b and c, f = page_height - f)
- Scale factor of 1/units_per_em built into a,b,c,d

Since the rendering_matrix already includes font_size, and glyph
outlines are in units_per_em space, the scale is:
```
glyph_scale = 1.0 / units_per_em
```
Applied to the rendering_matrix's scale components.

### 3. Font resource access

The SVG renderer needs TTFont access. Currently:
- `font_runtime.mbt` parses FontFile2 into TTFont
- RuntimeFont stores `ttf: @font.TTFont?`
- TextGlyphEvent has `font_name` and `glyph.source_code`

The SVG renderer needs a map from font_name → TTFont, built from
the page's font resources. This parallels the existing
`page_svg_font_families` function.

### 4. Files to modify

- `src/svg/render.mbt` — add glyph path rendering, modify
  `page_render_text_svg` to choose path vs text mode
- `src/svg/render_wbtest.mbt` — add tests for path-based rendering

### 5. New dependency

`src/svg/moon.pkg` already imports `trkbt10/pdf/src/text` which
exposes TTFont access. But the SVG package needs to import
`mizchi/font` directly for `path_commands_to_svg_d` and
`TTFont::glyph_outline`.
