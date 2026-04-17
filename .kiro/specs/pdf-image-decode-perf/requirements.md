# SDD Draft: Image decode hot-loop preallocation

## Problem

After the pdf-svg-image-cache SDD confirmed that `pageSvgImageData`
no longer re-walks graphics events per accessor, the cumulative
first-pass time for <local-fixture> page 7 is still
**11,699 ms** on the reference machine. Per-image profiling shows
the full cost materializes on `image[0]`, with `image[1..11]` all
cache hits in the 0-8 ms range:

```
pageToSvgDeferred(6): 211 ms
image[0]: 11,699 ms     ← page-wide materialization runs here
image[1..11]: 0-8 ms    ← cached after materialization
second pass (all 12): 34 ms
```

This proves the cache correctness: one graphics walk per page, one
extract per image, all subsequent accesses are free. The remaining
11.7 s is the **actual extract_image_xobject cost for all 12
images on page 7**.

Page 7 contains five 480×761 RGBA images (1.46M pixels each) plus
seven smaller images — roughly 9M total output pixels. The hot
loop in `decode_sample_bytes_to_rgb` uses an unbounded
`Array[Byte]` with `push` for every channel of every pixel, and
`pixel_to_device_rgb` allocates a fresh `Array[Double]` of the
colour-space components on every pixel.

Neither allocation pre-sizes the target buffer. Growing an `Array`
via `push` is amortized O(1) but each reallocation copies the
existing bytes. With ~36M byte pushes on page 7, the
copy-while-growing cost dominates.

The behaviour matches Codex's self-report:

> "支配的なのは重複 walk ではなく extract_image_xobject 側の画像
> 抽出・色変換コストです。"

and the earlier profiling where even a single 148×249 RGBA image
took 5.9 s in isolation — a working-set size proportional to
hundreds of kilobytes but with O(N log N) cost from repeated
buffer re-growth inside `extract_image_xobject`.

## Requirements

### Requirement 1: Pre-allocated RGBA buffer

#### 1.1: Byte buffer sized up-front
`decode_sample_bytes_to_rgb` SHALL allocate the output RGBA byte
buffer with `width * height * 4` capacity at the start of the
pixel loop, instead of an empty `Array[Byte]` grown via `push`.
Writing SHALL use index assignment into a `FixedArray[Byte]` or
`Bytes::makei` pattern rather than push operations.

#### 1.2: No per-pixel Array[Double] allocation
`pixel_to_device_rgb` SHALL NOT allocate a new `Array[Double]` for
the colour-space component buffer on every pixel. The components
array SHALL be reused across pixels in the hot loop (e.g. reset
length and overwrite indices, or pass a pre-allocated scratch
buffer from the caller).

#### 1.3: No per-pixel Array[Byte] allocation in stencil path
`decode_stencil_alpha_mask` SHALL follow the same preallocation
pattern for the alpha byte buffer so StencilMask images benefit
equally.

### Requirement 2: Semantics preservation

#### 2.1: Output bytes unchanged
The resulting `ImageDeviceRgbRaster::rgba` and
`ImageAlphaMaskRaster::alpha` SHALL be byte-identical to the
current implementation's output for every input fixture exercised
by `moon test --target native`. The optimisation SHALL not change
colour semantics, alpha composition, or clamping.

#### 2.2: Error propagation preserved
The new hot loop SHALL retain the existing
`PdfGraphicsError::InvalidImage` raise points for Indexed lookup
range checks and other validation failures. Error messages SHALL
remain stable so downstream consumers relying on the text can
continue to match on it.

### Requirement 3: Test compensation

#### 3.1: Pixel-identity regression test
A whitebox test SHALL extract a representative DeviceRGB raster
(smallest fixture available) through both the current and the
optimised code paths and assert byte-equality on the resulting
`rgba` buffer. If the optimised path replaces the current one
entirely, the test still asserts against a golden hex fixture for
`rgba` bytes so regressions are detected.

#### 3.2: Performance bound test
A whitebox test SHALL extract every image on <local-fixture>
page 7 and assert the cumulative time stays under 3,000 ms on the
reference machine (was 11,699 ms). Guarded by fixture presence.

#### 3.3: No allocation counter regression
Where the runtime supports it (e.g. via
`@test.allocation_count()` or similar), a test SHALL assert the
number of `Array[Double]` allocations per pixel stays at a small
constant (≤ 1 per ImageDescriptor, not per pixel).

If no allocation counter is available, fall back to asserting the
time-per-pixel of a reference extraction stays within
`2 × time-per-pixel-of-smallest-fixture` — a pragmatic proxy for
"the hot loop scales with pixel count, not pixel-count-squared".

### Requirement 4: Acceptance criteria

#### 4.1: Page 7 cumulative image data under 3 seconds
After the optimisation, the cumulative time of the 12
`pageSvgImageData(6, i)` calls on page 7 SHALL be under 3,000 ms
on the reference machine. Current baseline: 11,699 ms.

#### 4.2: Per-image for 480×761 image under 400 ms
Extracting a single 480×761 RGBA image (via wasm
`extract_image_xobject` through the normal accessor path) SHALL
complete in under 400 ms. Current baseline: ~2,000 ms per image in
the dominant bucket.

#### 4.3: No regression on other pages
Cumulative extraction time on pages 4–6 SHALL not increase beyond
10 % of current baseline.

#### 4.4: No regression on tests or visual diff
`moon test --target native` 718+ tests SHALL continue to pass.
local-fixture pixelmatch diff SHALL NOT regress from page 6 = 12.50 %, page
7 = 17.47 %.
