# Content Streams

The `src/content/` package parses page content streams into typed operator/operand sequences.

## Instruction Model

`ContentStreamParser` tokenizes decoded content bytes into `ContentInstruction`:
- `Operation(ContentOperation)` — `StandardContentOperator` enum value + `Array[PdfObject]` operands + byte offset
- `InlineImage(PdfInlineImage)` — BI/ID/EI inline image data with dictionary and pixel bytes

## Operator Coverage

`StandardContentOperator` covers the full ISO 32000-2 Annex A operator set:

| Category | Operators |
|----------|-----------|
| Graphics state | q, Q, cm, w, J, j, M, d, ri, i, gs |
| Path construction | m, l, c, v, y, h, re |
| Path painting | S, s, f, F, f*, B, B*, b, b*, n |
| Clipping | W, W* |
| Text | BT, ET, Tc, Tw, Tz, TL, Tf, Tr, Ts, Td, TD, Tm, T*, Tj, TJ, ', " |
| Colour | CS, cs, SC, SCN, sc, scn, G, g, RG, rg, K, k |
| XObjects | Do |
| Inline images | BI, ID, EI |
| Marked content | MP, DP, BMC, BDC, EMC |
| Shading | sh |
| Compatibility | BX, EX |

## Compatibility Tracking

`CompatibilityTracker` maintains BX/EX nesting depth counter. Inside a compatibility section (`depth > 0`), unknown operators are silently ignored instead of raising `PdfContentError`. Unbalanced EX raises an error.

## See Also

- wiki://file-reading
- wiki://graphics
- wiki://text-extraction
