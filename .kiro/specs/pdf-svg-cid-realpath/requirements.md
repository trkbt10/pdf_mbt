# SDD Draft: CID-keyed CFF reverse-lookup real-data path

## Problem

The `pdf-svg-cid-charset` SDD added CID-keyed CFF detection
(`is_cid_keyed_cff`), CID charset parsing, a `cid→glyph_id` reverse
map, synthetic `cid00000` post glyph names, and a renderer
`svg_resolve_glyph_id` branch that consults the post table for
`GlyphIdentifier::CID(cid)`. Unit tests pass.

However, the visual pixelmatch diff for <local-fixture> page 6
did not improve (still 12.6%, baseline 12.6%). Numbered list icons
(①②③④) and ShinGoPro Japanese text are still absent or
incorrectly rendered.

Observed symptoms:
- Codex self-reports "page 6 の実際の rendered spans は今回追加した
  CFF CID reverse lookup path に入っていない"
- Page 6 has CID fonts `C0_0` (7 glyphs), `C0_1` (24 glyphs),
  `C2_0` Wingdings (FALLBACK)
- CFF wrapper attempted the CID-keyed path but the real-data code
  path is not activated

Candidate root causes:
1. `is_cid_keyed_cff` detection returns false on real local-fixture CFF
   streams (TopDICT scanner fails on operand encodings present in
   real fonts)
2. Detection returns true but `cff_cid_to_glyph_id_map` fails
   (charset format not handled)
3. Detection and mapping succeed but `build_synthetic_post` does not
   emit the `cid00000` names into the OTF wrapper
4. Names are emitted but mizchi/font `parse_font` does not parse the
   synthetic post table (unsupported post version or offset error)
5. post table parsed but `ttf.post.glyph_names` empty in the
   returned TTFont
6. Everything works but `svg_resolve_glyph_id` `GlyphName` path uses
   a different string representation (case, prefix, padding)

## Requirements

### Requirement 1: Diagnostic instrumentation for real local-fixture CFF data

#### 1.1: Diagnostic test for is_cid_keyed_cff on local-fixture fonts
A diagnostic test SHALL load <local-fixture>, extract every
FontFile3 stream for page 6, decode it, and report for each:
- `is_raw_cff(data)` result
- `is_cid_keyed_cff(data)` result (if raw CFF)
- CIDCount operator value
- charset format (0 / 1 / 2) and number of glyphs

The output SHALL be printed so failures can be localised to
detection, parsing, or mapping.

#### 1.2: Diagnostic test for synthetic post names
The same diagnostic SHALL construct the wrapped OTF via
`wrap_cff_in_otf`, feed it to `@font.parse_font`, and print the
first 5 entries of `ttf.post.glyph_names` to confirm the
`cid00000` format round-trips through parse_font.

### Requirement 2: Root cause fixes

#### 2.1: TopDICT scanner covers real operand encodings
If diagnosis shows the TopDICT scanner misreads operand encodings
on real fonts (e.g. real-number operator 30, long integer 29), the
scanner SHALL be fixed to handle all DICT operand types per Adobe
TN 5176 Table 3.

#### 2.2: Synthetic post table parses correctly
If diagnosis shows `parse_font` returns an empty glyph_names array,
the synthetic post table format SHALL be corrected so mizchi/font
can parse it. Post format 2.0 with a string pool and glyphNameIndex
is the canonical format.

#### 2.3: Renderer name format matches wrapper name format
If diagnosis shows a format mismatch between emitted names (e.g.
`cid00012`) and lookup (e.g. `cid.00012` or `cid12`), the renderer
and wrapper SHALL agree on a single format. The wrapper is the
source of truth.

### Requirement 3: Acceptance criteria

#### 3.1: local-fixture page 6 CID glyphs render
After the real-data path is fixed, local-fixture page 6 SHALL render:
- At least some glyphs sourced from the CID fonts (C0_0 / C0_1)
- No visible regression on existing Type1C paths

#### 3.2: Visual diff improvement
local-fixture page 6 pixelmatch diff SHALL decrease from 12.6%, targeting
less than 10.0%.

#### 3.3: No regression on page 7 or existing tests
local-fixture page 7 diff SHALL NOT regress beyond 17.6%. All existing
`moon test --target native` tests SHALL pass.

### Requirement 4: Keep diagnostic tests

#### 4.1: Tests remain in codebase
The diagnostic test added for Requirement 1 SHALL remain in the
test suite as a regression guard. It prints to stdout but only
asserts that every extracted CFF stream either parses as raw CFF or
parses as a full sfnt container (no silent skips).
