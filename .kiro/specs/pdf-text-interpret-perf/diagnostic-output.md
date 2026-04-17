# Diagnostic Output: pdf-text-interpret-perf

## Command

```bash
moon test src/reader --target native --filter 'diagnostic local-fixture page 6 text interpreter breakdown'
```

## Fixture

- PDF: `<local-fixture>`
- Page: 6 (zero-index 5)

## Output

```text
local-fixture page 6 parse_decoded_content: 13 ms
local-fixture page 6 interpret_text: 528071 ms spans=3181 events=7871
text_interpret phases: interpret_loop=528071ms
text_interpret glyph_decodes=4348 allocation_count=7529 font_loads=3181 font_load_ms=527920
text_interpret operators: q[count=125,ms=0] Q[count=125,ms=0] cm[count=1,ms=0] Tc[count=15,ms=0] Tf[count=126,ms=0] Tr[count=2,ms=0] BT[count=171,ms=0] ET[count=171,ms=1] Tm[count=171,ms=0] TJ[count=171,ms=528069] other[count=827,ms=0]
Total tests: 1, passed: 1, failed: 0.
```

## Analysis

The parse phase is not the bottleneck: `parse_decoded_content` completed in 13 ms.

The interpreter loop accounts for the full delay: `interpret_text` took 528,071 ms. The time is concentrated in `TJ` operators, but the more precise counter identifies the internal cost: `font_loads=3181` and `font_load_ms=527920`.

This means the actual hot spot is H1: runtime font resolution is repeated for each text source string inside `TJ`. The current implementation calls `TextInterpreter::current_font` from `show_string`, and `current_font` calls `load_runtime_font(...)` each time. On this page, the 171 `TJ` operators expand into 3,181 source strings/spans, so the interpreter reparses the font dictionaries, ToUnicode CMaps, and embedded font programs 3,181 times.

## Targeted Fix

Cache the resolved `RuntimeFont` in `TextInterpreter`, keyed by the current font resource name, and invalidate/update it when `Tf` selects a different font. The fix should avoid reparsing runtime font state across repeated `Tj`/`TJ` strings while preserving existing behavior when `Tf` changes the font.
