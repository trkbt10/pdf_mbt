# SDD Draft: SVG Text Colour from Graphics State

## Problem

The SVG renderer hardcodes `fill="#000000"` for all text elements
(both `<text>` and glyph `<path>`). PDF text colour comes from the
graphics state's nonstroking colour, which can be any colour in any
colour space.

ISO 32000-2 §9.3.6 specifies that text rendering mode 0 (Fill) uses
the nonstroking colour. The current SVG renderer ignores this.

## Requirements

### Requirement 1: Text colour from graphics state

#### 1.1: Nonstroking colour for text fill
The SVG text fill colour SHALL be derived from the current graphics
state's nonstroking colour at the time the text operator is executed,
not hardcoded to black.

#### 1.2: Colour space conversion
DeviceRGB, DeviceGray, DeviceCMYK, and CalRGB nonstroking colours
SHALL be converted to SVG hex colour values using the same
`svg_colour` function already used for path rendering.

### Requirement 2: TextGlyphEvent colour propagation

#### 2.1: Graphics state at text render time
The SVG renderer SHALL access the graphics state that was active when
the text was rendered. The text interpreter's TextGlyphEvent currently
lacks colour information, so the renderer must obtain it from the
graphics events stream.

#### 2.2: Text event to graphics state mapping
The graphics state colour at the time of each text span SHALL be
tracked by correlating text events with the enclosing graphics state
from the page's graphics event stream.

### Requirement 3: Glyph path fill colour

#### 3.1: Per-glyph fill colour
When rendering glyphs as SVG `<path>` elements, the fill attribute
SHALL use the nonstroking colour from the graphics state, not "#000000".

### Requirement 4: Text element fill colour

#### 4.1: Per-span fill colour
When rendering text as SVG `<text>` elements (Standard 14 fallback),
the fill attribute SHALL use the nonstroking colour from the graphics
state, not "#000000".
