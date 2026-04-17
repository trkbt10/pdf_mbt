# Design: SVG Rendering Precision — Text Metrics

## Overview

Refactor SVG text rendering to emit real font-size values and position
glyphs in absolute SVG user-space coordinates, replacing the current
`font-size="1"` + matrix-scaling approach.

## Current Architecture

```
TextInterpreter → TextGlyphEvent (rendering_matrix includes font-size)
    ↓
page_render_text_svg()
    ↓
font-size="1" + transform="matrix(fs*Th 0 0 fs e page_h-f)"
    ↓
tspan x/y in 1/fs-relative units (e.g., x="0.722" for H→e in Helvetica)
```

## Target Architecture

```
TextInterpreter → TextGlyphEvent (rendering_matrix includes font-size)
    ↓
page_render_text_svg()
    ↓
font-size="{actual_fs}" + transform="matrix(Th 0 0 1 e page_h-f)" (or identity when Th=1)
    ↓
tspan x/y in absolute user-space points (e.g., x="0 17.33 ..." relative to text origin)
```

## Key Changes

### 1. Decompose rendering_matrix into font-size + positioning

The rendering matrix T_rm = T_state × T_m × CTM where:
- T_state = [[fs*Th, 0], [0, fs], [0, Tr]]

Factor out font-size:
- Extract `fs` from matrix.d (the Y-scale component)
- Remaining matrix: [[Th, 0], [0, 1], [e/fs, f/fs]] × CTM-contribution

For the common case (no rotation, identity CTM), this simplifies to:
- font-size = abs(first_glyph.rendering_matrix.matrix.d)
- transform includes only translation and optional Th scaling

### 2. Compute absolute glyph positions

Currently: positions are in 1/fs-relative space (e.g., x=0.722 means
0.722 × font-size = 17.33pt for fs=24).

Target: positions are in points relative to the text element's coordinate
system AFTER the transform is applied.

For each glyph, compute:
- glyph position = (rendering_matrix.e - first_glyph_e, rendering_matrix.f - first_glyph_f)
- Transform to SVG coords: apply Y-flip, divide by remaining scale factors

Since the parent transform already places the text at the correct origin,
the per-glyph x values should be cumulative advance in points:
- x_n = sum(w_i/1000 × fs + Tc + Tw_i) × Th for i=0..n-1

### 3. Handle non-standard font-size extraction

For CTM-based font sizing (e.g., Firefox PDFs where Tf=1 and CTM has
the actual scale), the effective font size must be extracted from the
rendering matrix, not from TextSpan.font_size alone.

`effective_fs = sqrt(rm.a² + rm.b²)` for the general case, or
`abs(rm.d)` for the common non-rotated case.

### 4. SVG output format

```xml
<text transform="matrix(1 0 0 1 100 296)"
      font-size="24"
      font-family="Helvetica, Arial, sans-serif"
      fill="#000000">
  <tspan x="0 17.33 30.67 36 41.33 46.67 69.33 82.67 90.67 98 104" y="0">HelloWorld</tspan>
</text>
```

Or for short spans with per-character tspans:
```xml
<text transform="..." font-size="24" ...>
  <tspan x="0" y="0">H</tspan>
  <tspan x="17.33" y="0">e</tspan>
  ...
</text>
```

### 5. Files to modify

- `src/svg/render.mbt` — `page_render_text_svg`, `svg_positioned_text`,
  `span_rendering_matrix`, `write_svg_text_matrix`, new helper functions
- `src/svg/render_wbtest.mbt` — update tests for new font-size values
- `npm/test/visual/compare.mjs` — regenerate references if needed

### 6. Backward compatibility

This is a rendering improvement, not an API change. No public API
signatures change. Test fixtures will need updated expected values.
