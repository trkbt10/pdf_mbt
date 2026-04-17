# Tasks: CID-keyed CFF reverse-lookup real-data path

## Task 1: Add diagnostic test for local-fixture page 6 CID chain

**File:** `src/svg/render_wbtest.mbt`

Add a whitebox test that:

1. Loads `<local-fixture>` (skip
   with `println` if not present — match the existing diagnostic
   local-fixture test)
2. Iterates fonts on page 6
3. For each font, if a FontFile3 stream exists, decode the stream
   and print for each CFF:
   - Stream length
   - `is_raw_cff` result
   - `is_cid_keyed_cff` result
   - CIDCount operator value (0 if not CID-keyed)
   - charset format, num_glyphs, first 5 CIDs from the map
   - wrapped OTF length
   - `parse_font` success + num_glyphs
   - first 5 entries of `ttf.post.glyph_names`

The test SHALL NOT assert any specific expectation — the stdout
output is the investigation artifact.

## Task 2: Run test and analyse output

Run `moon test --target native -p trkbt10/pdf/src/svg` and capture
the diagnostic output. Identify which stage (A–H in design.md)
breaks for real local-fixture CFF data.

Based on the observed failure, proceed to the matching fix task
(3a, 3b, or 3c).

## Task 3a: Fix TopDICT real-number operand handling

**Condition:** diagnosis shows `is_cid_keyed_cff` returns false on
a font that should be detected.

**File:** `src/svg/cff_wrapper.mbt`

Audit `cff_decode_dict_operand` to verify that operand b0=30 (real
number) advances the position past all nibble bytes up to the 0xF
terminator, matching mizchi/font's `skip_real_number`. Fix any
off-by-one or premature-return issue.

Add a small unit test that exercises real-number operand skipping
with a known input.

## Task 3b: Fix synthetic post table format

**Condition:** diagnosis shows `ttf.post.glyph_names` is empty but
the CID reverse map was built successfully.

**File:** `src/svg/cff_wrapper.mbt`

Inspect the current synthetic post table bytes with a hex dump or
print. Compare against the Apple/Microsoft post 2.0 spec. Fix any
structural issue:

- Version must be `0x00020000`
- After the header, numGlyphs (uint16)
- Then numGlyphs uint16 glyphNameIndex values (values ≥258 index
  into the custom names pool, subtracting 258)
- Then the custom names pool as Pascal strings (length byte then
  bytes, no terminator)

Add a unit test that constructs a synthetic post, feeds it via
`rebuild_sfnt`, and verifies `parse_font` returns the expected
names.

## Task 3c: Align renderer and wrapper glyph name format

**Condition:** diagnosis shows post names are present but
`svg_cid_glyph_id` does not find them.

**File:** `src/svg/render.mbt` and/or `src/svg/cff_wrapper.mbt`

Ensure both sides use the same format. Recommended:
`"cid" + pad5(cid)` (e.g. `cid00012`).

Extract into a shared helper (e.g. `cff_cid_glyph_name(cid: Int) -> String`)
in `cff_charset.mbt`, used by both the wrapper (when emitting post
names) and the renderer (when reverse-looking up).

## Task 4: Verify the fix

1. Rerun the diagnostic test; stages A→H should all succeed for
   C0_0 and C0_1 on page 6
2. `moon test --target native` — all tests pass
3. `moon build --target wasm-gc --release && cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm`
4. Pixelmatch local-fixture pages 6, 7 (same script used in previous SDD
   runs); acceptance: page 6 < 10.0%, page 7 ≤ 17.6%
5. Report actual diff in the commit message

## Task 5: Spec alignment gate

```bash
indexion spec align status .kiro/specs/pdf-svg-cid-realpath/requirements.md src/svg/ --threshold 0.3 --fail-on drifted
```

Must exit 0 (no DRIFTED).

## Task 6: Keep diagnostic test in suite

The diagnostic test added in Task 1 remains as a regression guard.
Update its assertion at the end to verify every extracted CFF
stream parses successfully (either raw CFF wrapped or full sfnt),
but keep the printed diagnostic output for future investigations.
