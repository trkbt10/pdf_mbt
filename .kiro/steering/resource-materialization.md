# Resource Materialization SoT

This document is the source of truth for PDF resource materialization. The
contract is simple: every Ref-shaped value must be unwrapped with
`resolve_indirect` before variant matching. Materializers may reject malformed
resolved shapes, but they must not silently branch on a still-indirect object.

## Shared Primitive

- WHAT: `resolve_indirect(file, object)` follows `PdfObject::Ref` chains until a
  concrete object is reached, reports missing objects, detects cycles, and caps
  pathological depth.
- WHERE: `src/reader/indirect_resolution.mbt:13`.
- WHEN: used by page resource, text resource, annotation, structure, optional
  content, metadata, and fixture helpers before matching indirect operands.
- WHICH: accepts every `PdfObject`; `Ref` is dereferenced, `Null` from a missing
  indirect object is rejected, non-Ref values are returned unchanged.

## Page Content Resources

- WHAT: materializes `/Resources` for content stream interpretation, including
  nested resource dictionaries inside Form XObjects and image masks.
- WHERE: `src/reader/xobjects.mbt:16`, `src/reader/xobjects.mbt:70`,
  `src/reader/xobjects.mbt:102`, `src/reader/xobjects.mbt:134`.
- WHEN: `PdfPage::materialized_content_resources` and
  `PdfPage::materialized_content_stream`, used by graphics and SVG pipelines.
- WHICH: top-level `/Resources` and named categories must resolve to
  dictionaries. `XObject` values must resolve to streams. `ColorSpace`,
  `Pattern`, `Shading`, and `ExtGState` values may resolve to arrays,
  dictionaries, streams, names, or scalars according to their downstream parser;
  nested Ref values are recursively resolved before the next match.

## XObject Resources

- WHAT: materializes Form XObject `/Resources`, image `ColorSpace`, `Mask`, and
  `SMask` entries, and rejects recursive object graphs by object id.
- WHERE: `src/reader/xobjects.mbt:164`, `src/reader/xobjects.mbt:233`,
  `src/reader/xobjects.mbt:261`, `src/reader/xobjects.mbt:307`,
  `src/reader/xobjects.mbt:359`.
- WHEN: during `PdfPage::materialized_content_resources` when `include_xobjects`
  is true; `PdfPage::materialized_content_stream_without_xobjects` intentionally
  skips page-level XObject expansion.
- WHICH: Form and Image XObjects accept resolved streams. Form `/Resources` must
  resolve to a dictionary. Image nested entries accept resolved arrays,
  dictionaries, streams, names, and scalar values, with recursive materialization
  for arrays, dictionaries, and streams.

## Text And Font Resources

- WHAT: materializes text extraction resources, especially `Font`,
  `ExtGState`, font descriptor entries, font program streams, and
  `DescendantFonts`.
- WHERE: `src/reader/text.mbt:124`, `src/reader/text.mbt:145`,
  `src/reader/text.mbt:157`, `src/reader/text.mbt:188`,
  `src/reader/text.mbt:226`, `src/reader/text.mbt:241`,
  `src/reader/text.mbt:286`, `src/reader/text.mbt:307`.
- WHEN: `PdfPage::text_resources`, `PdfPage::text_program`, and
  `PdfPage::extracted_text` before text decoding and SVG font discovery.
- WHICH: `/Resources` and `Font`/`ExtGState` categories must resolve to
  dictionaries. Font values accept resolved dictionaries or `Null` as an error;
  `Encoding`, `ToUnicode`, `Widths`, `FontDescriptor`, `FontFile*`, and each
  `DescendantFonts` element are unwrapped before matching.

## Pattern And Shading Resources

- WHAT: loads single pattern and shading resources for graphics parsing, with
  page colour defaults derived from direct page resources.
- WHERE: `src/reader/patterns.mbt:2`, `src/reader/patterns.mbt:23`,
  `src/reader/patterns.mbt:44`, `src/reader/patterns.mbt:122`,
  `src/reader/patterns.mbt:157`.
- WHEN: `PdfPage::pattern_resource`, `PdfPage::shading_resource`, and
  `PdfPage::pattern_resources`.
- WHICH: `/Resources` and the named category must resolve to dictionaries.
  Individual pattern and shading values are resolved before passing to the
  graphics parser. This path currently resolves one Ref hop through
  `page_load_resource_object`; new resource materializers should use
  `resolve_indirect` directly.

## Optional Content And Properties

- WHAT: resolves optional-content property dictionaries and order arrays used
  by graphics visibility evaluation.
- WHERE: `src/reader/optional_content.mbt:9`, `src/reader/optional_content.mbt:37`,
  `src/reader/optional_content.mbt:54`; graphics evaluation is in
  `src/graphics/optional_content.mbt`.
- WHEN: `PdfPage::optional_content_state`, then
  `PdfPage::graphics_program` / `PdfPage::graphics_events`.
- WHICH: OCG and OCMD property values are unwrapped before dictionary matching.
  Missing optional-content configuration falls back to visible-by-default
  behavior.

## Annotations And Structure

- WHAT: resolves annotation arrays, annotation dictionaries, structure elements,
  parent tree values, interchange metadata, and page piece dictionaries.
- WHERE: `src/reader/annotations.mbt:25`,
  `src/reader/structure_common.mbt:27`, `src/reader/structure_tree.mbt:246`,
  `src/reader/interchange_metadata.mbt:10`,
  `src/reader/interchange_piece_info.mbt:10`.
- WHEN: `PdfPage::annotations`, structure tree traversal, metadata accessors,
  and page piece-info accessors.
- WHICH: resolved arrays and dictionaries are parsed by their domain-specific
  validators; malformed concrete variants are rejected by those validators.

## SVG Glyph ID Resolver

- WHAT: converts each `TextGlyphEvent` to one glyph id using one ordered
  resolver for SVG path emission.
- WHERE: `src/svg/render.mbt:1604`; embedded font cache and CIDToGIDMap loading
  live at `src/svg/render.mbt:2278` and `src/svg/render.mbt:2386`.
- WHEN: `page_render_text_span_as_paths` calls `render_glyph_as_path`, which
  calls `svg_resolve_embedded_glyph_id`.
- WHICH: priority is CFF charset CID map, ToUnicode through subset cmap,
  CID-keyed subset cmap, explicit `CIDToGIDMap`, `/CIDToGIDMap /Identity`,
  legacy post-table names, simple-font character-code cmap, then in-range
  identity fallback.
