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

#### 1.1: raster_image_entry RGBA buffer validation

The SVG image path SHALL pass DeviceRgbRaster and StencilMaskRaster
results through `raster_image_entry`. The helper validates the raw
RGBA buffer shape with `width * height * 4` before target-specific
encoding, preserving the pre-allocated RGBA buffer contract supplied
by graphics image decoding.

### Requirement 2: page_image_entry_data semantics preservation

`page_image_entry_data` SHALL preserve image semantics while routing
DeviceRgbRaster, StencilMaskRaster, and EncodedImageData through the
same SVG image entry pipeline. Device RGB raster bytes and painted
stencil mask bytes remain unchanged; encoded JPEG and JP2 bytes pass
through unchanged.

#### 2.1: image_data_from_rgba regression compensation

`image_data_from_rgba` SHALL continue to validate positive width,
positive height, and exact `width * height * 4` byte counts before
constructing ImageData for native PNG encoding and regression checks.

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
