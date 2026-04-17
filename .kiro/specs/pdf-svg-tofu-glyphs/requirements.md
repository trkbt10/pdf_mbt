# SDD Draft: Tofu (missing glyph) for symbol characters

## Problem

User-reported visual defect: certain symbol characters in local-fixture
render as "tofu" (□) — the visible placeholder indicating a
missing glyph. Examples include the middle dot "・" (U+30FB), and
likely other non-Latin punctuation or bullet symbols.

Expected vs observed:

| Character | Expected | Observed |
|-----------|----------|----------|
| ・ (U+30FB middle dot) | small round dot | white box □ |
| (other Unicode bullets / dots / arrows) | glyph shape | □ |

### Why a blank square renders

`render_glyph_as_path` in `src/svg/render.mbt` rejects paths when
the resolved glyph outline is empty, falling through to
`svg_glyph_is_spacing(glyph)`. If no glyph is drawn, what the
viewer sees depends on the preceding / fallback layer.

Three plausible causes:

- **T1: glyph_id resolves to `.notdef`** (glyph 0). The CFF font's
  `.notdef` is typically drawn as a filled rectangle or empty
  box. The renderer currently draws glyph 0 faithfully, producing
  a rectangle that looks like "tofu".
- **T2: glyph_id resolution returns -1** because the Unicode
  codepoint has no entry in the synthetic cmap or the post
  reverse-lookup table. The fallback in `svg_resolve_glyph_id`
  returns -1, `render_glyph_as_path` returns false, and the text
  fallback path draws a `<text>` element. If the font-family is
  unrecognised by the viewer, the browser draws a tofu box.
- **T3: glyph_id resolves to a valid CID but the CFF charstring
  at that index is a placeholder rectangle** (some Adobe PDFs
  embed tofu glyphs for optional/rare characters).

T1 is most likely for CJK symbol characters mapped via a
ToUnicode CMap but absent from the Latin subset embedded in
T1_0/T1_1/etc. The PDF expects the CID font (C0_0, C0_1) to
supply these glyphs; if the CID-keyed CFF reverse lookup returns
glyph 0 for an unrecognised CID, the `.notdef` tofu shows up.

## Requirements

### Requirement 1: Diagnostic enumeration of tofu-rendered glyphs

#### 1.1: List codepoints rendered from glyph 0
A whitebox test SHALL walk every glyph drawn on local-fixture page 6 and 7
and report each one where `svg_resolve_glyph_id` returned glyph 0
(`.notdef`) or -1 (missing). The output SHALL include:
- source character code or CID
- font name (T1_0/T1_1/C0_0/C0_1/etc.)
- resolved glyph ID
- path count in the resulting outline

This shows which characters are affected without guessing at
"middle dot" specifically.

#### 1.2: Compare against expected pdftoppm glyphs
Where possible, cross-check against pdftoppm's output: run
`pdftotext -layout` on the same pages and list the characters in
the text stream. Any character present in pdftotext but rendered
as notdef in our SVG is a confirmed tofu defect.

### Requirement 2: Avoid drawing `.notdef` as tofu

#### 2.1: Suppress notdef rendering in SVG
When `svg_resolve_glyph_id` returns 0 for a Unicode codepoint that
is NOT the `.notdef` character itself (i.e. a real character with
no glyph in the font), `render_glyph_as_path` SHALL NOT draw the
notdef outline. Instead, it SHALL:
- try the text fallback (render as `<text>` with the correct
  Unicode character so the browser substitutes a system font), OR
- skip the glyph entirely if text fallback is also unavailable
  (less desirable but better than misleading tofu)

#### 2.2: Preserve notdef for intentional uses
If the PDF content stream explicitly references glyph 0 (via
direct glyph ID or CID 0 in a composite font), the current
rendering SHALL be preserved — this is rare but semantically
meaningful.

### Requirement 3: Root-cause fix for missing glyph mappings

#### 3.1: Surface missing CID-to-glyph mappings
If the diagnostic from Requirement 1 shows CIDs present in the
PDF content stream that are not mapped in the CFF charset, the
fix SHALL improve the charset lookup or add the missing range.

This may require:
- revisiting `cff_cid_to_glyph_id_map` for format-2 ranges
- handling CIDs above the charstring count by returning the
  default CID from the FD array (for CID-keyed CFF fonts with
  multiple FontDictionaries)

### Requirement 4: Acceptance

#### 4.1: No tofu in local-fixture pages 6, 7
After the fix, a visual inspection (SVG output opened in rsvg-
convert-rendered PNG or browser) of local-fixture pages 6, 7 SHALL not
show any tofu boxes. Every character in the PDF's text stream
SHALL render either:
- as a correct glyph path (preferred)
- as a `<text>` fallback with a character the browser can draw
  (acceptable for characters outside the embedded font's
  coverage)

#### 4.2: Diagnostic test as regression guard
The diagnostic from Requirement 1 SHALL remain in the test suite
and assert at the end that no glyph 0 (notdef) is drawn as a
visible path for a non-notdef codepoint.

#### 4.3: No regression on other tests
`moon test --target native` 720+ tests SHALL continue to pass.
Pixelmatch diff on pages 6, 7 SHALL improve or stay the same
(not regress).
