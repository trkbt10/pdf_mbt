# text

## API

- **`TextErrorContext`** (Struct) — Text diagnostics carry decoded-content operator offsets and optional
- **`TextMatrix`** (Struct) — ISO PDF six-number affine matrix `[a b c d e f]` used for text matrices and
- **`TextInterpretationCache`** (Struct) — Owned by one text interpretation pass. Later caches can hang off this value
- **`concat`** (Function) — Returns `transform x current`, matching the PDF matrix composition order
- **`TextInterpretationLimits`** (Struct) — Per-interpretation limits for untrusted CMap, ToUnicode, and mapping data.
- **`TextPaintIntent`** (Struct) — Renderer-independent paint intent for a glyph at one text-showing point.
- **`TextRenderingMatrix`** (Struct) — Snapshot of the text rendering matrix computed before emitting a glyph.
- **`TextPoint`** (Struct) — Coordinate pair in text space or a transformed text coordinate space.
- **`TextState`** (Struct) — Text state parameters stored in the graphics state for clause 9.
- **`WritingMode`** (Enum) — PDF writing mode used by composite-font metrics.
- **`TextRenderingMode`** (Enum) — Text rendering mode from ISO 32000-2 Table 105.
- **`TextObjectState`** (Struct) — Matrices that exist only inside a text object.
- **`decode_runtime_font_string`** (Function) — 


- **`TextInterpreter`** (Struct) — 


- **`from_six`** (Function) — 


- **`translation`** (Function) — 


- **`scale`** (Function) — 


- **`translated`** (Function) — 


- **`replace_with`** (Function) — 


- **`transform_point`** (Function) — 


- **`glyph_advance_translation`** (Function) — 


- **`text_state_matrix`** (Function) — 


- **`from_text_state`** (Function) — 


- **`SimpleEncoding`** (Struct) — 


- **`standard`** (Function) — 


- **`from_name`** (Function) — 


- **`glyph_name_for_code`** (Function) — 


- **`require_text_object`** (Function) — 


- **`base_encoding_names`** (Function) — 


- **`identity`** (Function) — 


- **`GlyphMetrics`** (Struct) — 


- **`GlyphIdentifier`** (Enum) — 


- **`GlyphFallback`** (Enum) — 


- **`DecodedGlyph`** (Struct) — 


- **`UnicodeMapping`** (Enum) — 


- **`TextSourceString`** (Struct) — 


- **`TextGlyphEvent`** (Struct) — 


- **`TextEvent`** (Enum) — 


- **`TextSpan`** (Struct) — 


- **`ExtractedText`** (Struct) — 


- **`FontResourceSummary`** (Struct) — 


- **`TextResources`** (Struct) — 


- **`TextInitialState`** (Struct) — 


- **`TextProgram`** (Struct) — 


- **`unknown`** (Function) — 


- **`empty`** (Function) — 


- **`from_spans`** (Function) — 


- **`parse_decoded_cmap`** (Function) — 


- **`parse_decoded_to_unicode_cmap`** (Function) — 


- **`CMapParser`** (Struct) — 


- **`parse`** (Function) — 


- **`handle_operator`** (Function) — 


- **`read_codespace_ranges`** (Function) — 


- **`read_cid_chars`** (Function) — 


- **`read_cid_ranges`** (Function) — 


- **`read_bf_chars`** (Function) — 


- **`read_bf_ranges`** (Function) — 


- **`apply_definition`** (Function) — 


- **`apply_use_cmap`** (Function) — 


- **`add_codespace_range`** (Function) — 


- **`add_cid_mapping`** (Function) — 


- **`take_count`** (Function) — 


- **`expect_string_operand`** (Function) — 


- **`expect_int_operand`** (Function) — 


- **`expect_object_operand`** (Function) — 


- **`expect_end_operator`** (Function) — 


- **`next_token`** (Function) — 


- **`invalid`** (Function) — 


- **`CMapToken`** (Enum) — 


- **`validate_code_range`** (Function) — 


- **`expand_bfrange_string`** (Function) — 


- **`replace_last_u16be`** (Function) — 


- **`with_resource`** (Function) — 


- **`RuntimeFont`** (Struct) — 


- **`RuntimeGlyph`** (Struct) — 


- **`from_horizontal_width`** (Function) — 


- **`resolve_width`** (Function) — 


- **`load_runtime_font`** (Function) — 


- **`restore`** (Function) — 


- **`decode_simple_font_string`** (Function) — 


- **`decode_composite_font_string`** (Function) — 


- **`glyph_metrics_for_code`** (Function) — 


- **`unicode_for_glyph`** (Function) — 


- **`track_entry`** (Function) — 


- **`move_to_next_line`** (Function) — 


- **`show_string`** (Function) — 


- **`is_zero_width_spacing_glyph`** (Function) — 


- **`advance_after_glyph`** (Function) — 


- **`apply_tj_adjustment`** (Function) — 


- **`current_font`** (Function) — 


- **`current_font_size`** (Function) — 


- **`validate_codespace_length`** (Function) — 


- **`CMapCodespaceRange`** (Struct) — 


- **`CMapCIDMapping`** (Struct) — 


- **`TextPathConstruction`** (Struct) — 


- **`CMap`** (Struct) — 


- **`CMapDecodeResult`** (Struct) — 


- **`ToUnicodeCodeMapping`** (Struct) — 


- **`ToUnicodeCMap`** (Struct) — 


- **`compatible_with`** (Function) — 


- **`length`** (Function) — 


- **`decode_next`** (Function) — 


- **`map_source_code`** (Function) — 


- **`match_codespace`** (Function) — 


- **`decode_matched_code`** (Function) — 


- **`partial_codespace_length`** (Function) — 


- **`find_cid_mapping`** (Function) — 


- **`code_in_range`** (Function) — 


- **`prefix_can_match_range`** (Function) — 


- **`ranges_overlap`** (Function) — 


- **`bytes_to_uint`** (Function) — 


- **`copy_bytes_range`** (Function) — 


- **`default`** (Function) — 


- **`at`** (Function) — 


- **`with_text_knockout`** (Function) — 


- **`map_glyph_name_to_unicode`** (Function) — 


- **`decode_utf16be_text`** (Function) — 


- **`write_codepoint`** (Function) — 


- **`read_u16be`** (Function) — 


- **`glyph_name_unicode_pattern`** (Function) — 


- **`parse_hex_codepoint`** (Function) — 


- **`hex_digit_value`** (Function) — 


- **`validate_cmap_use_depth`** (Function) — 


- **`validate_range_expansion`** (Function) — 


- **`clips`** (Function) — 


- **`save`** (Function) — 


- **`apply_tstar`** (Function) — 


- **`TextStateSnapshot`** (Struct) — 


- **`with_word_spacing`** (Function) — 


- **`from_int`** (Function) — 


- **`with_default_limits`** (Function) — 


- **`strokes`** (Function) — 


- **`is_invisible`** (Function) — 


- **`new`** (Function) — 


- **`from_rendering_mode`** (Function) — 


- **`path_construction`** (Function) — 


- **`initial`** (Function) — 


- **`with_character_spacing`** (Function) — 


- **`fills`** (Function) — 


- **`with_horizontal_scaling_percent`** (Function) — 


- **`with_leading`** (Function) — 


- **`with_rendering_mode`** (Function) — 


- **`with_text_rise`** (Function) — 


- **`TextStateStack`** (Struct) — 


- **`effective_font_size`** (Function) — 


- **`horizontal_scale_factor`** (Function) — 


- **`vertical_scale_factor`** (Function) — 


- **`rendering_matrix`** (Function) — 


- **`move_line`** (Function) — 


- **`set_text_matrix`** (Function) — 


- **`apply_td`** (Function) — 


- **`apply_tm`** (Function) — 


- **`GlyphWidthSource`** (Enum) — 
- **`SimpleEncodingName`** (Enum) — 
- **`CIDSystemInfo`** (Struct) — 
- **`RuntimeFontKind`** (Enum) —
