# Diagnostic Output: Page 2 Clip Regression

## Inputs

- Current HEAD SVG: `diagnostic/page2-head.svg`
- Pre-fix SVG from commit `dacefdc`: `diagnostic/page2-dacefdc.svg`
- Source PDF: `<local-fixture>`
- Page: 2 (`pageIndex = 1`)

## SVG Structure Diff

| Metric | HEAD | `dacefdc` |
| --- | ---: | ---: |
| SVG bytes | 455,211 | 454,784 |
| `<text>` elements | 2,059 | 2,059 |
| `<path>` elements | 54 | 54 |
| `<g>` elements | 52 | 0 |
| `<clipPath>` definitions | 3 | 3 |
| `clip-path` attributes | 2,110 | 2,107 |
| `text#c2` clip assignments | 2,058 | 2,058 |
| `path#c1` clip assignments | 0 | 48 |
| `path#c3` clip assignments | 0 | 1 |
| `g#c1` clip assignments | 50 | 0 |
| `g#c3` clip assignments | 2 | 0 |

The `7d702a2` glyph-correctness change moved glyph path clipping from
`<path clip-path="...">` to `<g clip-path="..."><path .../></g>`.
It did not introduce the right-column `text#c2` assignments: both HEAD
and `dacefdc` emit 2,058 transformed `<text>` elements with
`clip-path="url(#c2)"`.

## ClipPath Geometry

Both HEAD and `dacefdc` emit identical clip definitions:

```text
c1 evenodd M 26.16 294.33 L 241.53 294.33 L 241.53 226.14 L 26.16 226.14 Z
c2 evenodd M 271.05 832.8 L 581.01 832.8 L 581.01 43.71 L 271.05 43.71 Z
c3 evenodd M 553.17 31.92 L 576.21 31.92 L 576.21 16.56 L 553.17 16.56 Z
```

For each rectangle the vertical edge goes from larger SVG Y to smaller
SVG Y, then returns through the close edge. The conventional signed
areas are negative in SVG's y-down coordinate values:

| Clip | Signed area |
| --- | ---: |
| `c1` | -14,686.0803 |
| `c2` | -244,586.3364 |
| `c3` | -353.8944 |

The fill rule is `evenodd`; for a single rectangular subpath the path
direction does not invert inside/outside. The isolated rsvg repro in
`npm/test/clip_repro.mjs` shows the actual failure mode: when
`clip-path="url(#c2)"` is applied directly to a transformed `<text>`
element, rsvg renders zero dark pixels even though the text position is
inside the page-space rectangle.

## Raster Check

Right-column crop used for the check:

```text
x=270, y=45, width=315, height=760
```

| Image | Dark pixels | Non-white pixels |
| --- | ---: | ---: |
| pdftoppm reference | 8,980 | 29,603 |
| HEAD rsvg output | 0 | 0 |
| `dacefdc` rsvg output | 0 | 0 |

## Conclusion

The missing right column is not caused by a changed clipPath definition
between `dacefdc` and HEAD. The actionable bug is direct page-space
`clip-path` emission on transformed fallback `<text>` elements. The fix
should apply the clip in an untransformed SVG context, analogous to the
glyph path wrapper, while preserving the existing glyph path wrapper.
