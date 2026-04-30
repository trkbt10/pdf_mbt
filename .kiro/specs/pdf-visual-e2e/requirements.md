# SDD Draft: Visual E2E Testing (Screenshot Diff)

## Requirements

### Requirement 1: Reference rendering pipeline
The test pipeline SHALL generate reference renderings of PDF pages
using an established tool (poppler pdftoppm) as ground truth.

#### 1.1: Reference PNG generation
For each test PDF page, `pdftoppm -png -r 150` SHALL produce a
reference PNG at 150 DPI.

### Requirement 2: SVG deferred output pipeline
The library SHALL expose normal SVG page output and deferred SVG output through
the SVG renderer package.

#### 2.1: Deferred image entries
`SvgDeferredResult` SHALL carry the `svg` string and `SvgImageEntry` array.
Each `SvgImageEntry` SHALL expose `mime_type`, `data`, `width`, and `height`.

### Requirement 3: SVG image alignment checks
The SVG package SHALL keep image placement aligned with page geometry through
`svg_image_high_precision_alignment`,
`svg_axis_aligned_image_bounds_alignment`,
`svg_non_axis_aligned_image_transform_alignment`, and
`svg_image_precision_acceptance_alignment`.

#### 3.1: Image data contract
`raw_rgba_image_mime` SHALL identify raw RGBA image payloads used by deferred
SVG image data.

#### 3.2: Clip path contract
`clip_path_geometry_transformation_alignment` and
`apply_clip_path_to_rendered_elements_alignment` SHALL guard SVG clipping
alignment.

### Requirement 4: SVG renderer alignment test suite
The SVG package SHALL keep renderer behavior covered by public alignment
functions for glyphs, fonts, clipping, colour, and page images.

#### 4.1: Glyph and font alignment
`svg_renderer_glyph_id_resolution_alignment`,
`synthetic_cmap_reflecting_charset_alignment`,
`glyph_outline_extraction_alignment`, `glyph_positioning_and_scaling_alignment`,
`glyph_fill_and_stroke_alignment`, and `glyph_svg_output_format_alignment`
SHALL cover glyph and font rendering behavior.

#### 4.2: Colour and FontFile alignment
`text_colour_from_graphics_state_alignment`,
`text_glyph_event_colour_propagation_alignment`,
`glyph_path_fill_colour_alignment`, `text_element_fill_colour_alignment`,
`font_file3_open_type_subtype_alignment`, `font_file3_type1c_subtype_alignment`,
`font_file3_cid_font_type0c_subtype_alignment`, and
`font_file_type1_non_compact_alignment` SHALL cover colour and embedded font
behavior.

### Requirement 5: SVG regression alignment guards
The SVG package SHALL keep regression guards through
`diagnostic_instrumentation_real_local_fixture_cff_alignment`,
`cid_realpath_root_cause_fixes_alignment`, `keep_diagnostic_tests_alignment`,
`demo_application_integration_alignment`,
`viewer_cache_application_lifetime_alignment`,
`viewer_cache_load_page_svg_stable_identity_alignment`,
`viewer_cache_blob_url_lifecycle_alignment`, and
`viewer_cache_wasm_stateless_per_call_alignment`.
