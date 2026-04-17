# Design: Image decode hot-loop preallocation

## Overview

Replace the push-based `Array[Byte]` and per-pixel `Array[Double]`
allocations inside `decode_sample_bytes_to_rgb`,
`decode_stencil_alpha_mask`, and `pixel_to_device_rgb` with
pre-allocated buffers and index-based writes. The current code
path's functional semantics are preserved; only the allocation
pattern changes.

The target files are entirely within `src/graphics/`, which is
not touched by any in-flight SDD work, so this change is
independent of the other SVG specs.

## Current hot loop

`src/graphics/image_decode.mbt:265..312`
(`decode_sample_bytes_to_rgb`):

```moonbit
let samples = decode_image_sample_values(decoded, descriptor.layout, offset~)
let alpha = alpha_for_image_descriptor(descriptor, samples, offset)
let bits_per_component = require_bits_per_component(descriptor, offset)
let rgba : Array[Byte] = []
for pixel in 0..<(descriptor.width * descriptor.height) {
  let (r, g, b) = pixel_to_device_rgb(
    space,
    descriptor.decode,
    bits_per_component,
    samples,
    pixel,
    offset,
  )
  rgba.push(unit_to_byte(r))
  rgba.push(unit_to_byte(g))
  rgba.push(unit_to_byte(b))
  rgba.push(alpha_byte_at(alpha, pixel))
}
ExtractedImageData::DeviceRgbRaster(ImageDeviceRgbRaster::{
  width: descriptor.width,
  height: descriptor.height,
  rgba: Bytes::from_array(rgba),
})
```

`src/graphics/image_decode.mbt:598..630`
(`pixel_to_device_rgb`):

```moonbit
_ => {
  let count = space.component_count()
  let components : Array[Double] = []
  for component in 0..<count {
    components.push(
      decode_sample_value(
        samples[pixel * count + component],
        bits_per_component,
        decode[component],
      ),
    )
  }
  components_to_device_rgb(space, components, offset)
}
```

For a 480×761 DeviceRGB image that's 1,095,840 `pixel_to_device_rgb`
calls, each allocating a fresh 3-element `Array[Double]`. The
outer `rgba` push sequence is 4 × 1,095,840 = ~4.4M push operations
doubling the underlying storage ~22 times with full copies at each
resize.

## Pre-allocated RGBA buffer

The pre-allocated RGBA buffer SHALL replace the growable
`Array[Byte]` push loop. `decode_sample_bytes_to_rgb` reserves
`width * height * 4` bytes up front in a `FixedArray[Byte]` and
writes pixel channels via index assignment. No per-pixel
`Array[Double]` allocation for components occurs in the hot loop:
the component scratch buffer is hoisted to the caller and reused
for every pixel. The same pre-allocation pattern applies to
`decode_stencil_alpha_mask` so the stencil path benefits equally.

## Semantics preservation

Semantics preservation SHALL hold: the produced
`ImageDeviceRgbRaster::rgba` and `ImageAlphaMaskRaster::alpha`
bytes are byte-identical to the current implementation for every
fixture exercised by `moon test --target native`. Error
propagation SHALL remain the same — `PdfGraphicsError::InvalidImage`
raises at the existing Indexed range-check points and validation
failures continue to surface with the same error messages.

## Test compensation

Test compensation SHALL exercise pixel-identity against a golden
fixture plus a performance-bound assertion. The pixel-identity
regression test extracts a small representative DeviceRGB raster
and asserts byte-equality. The performance-bound test extracts
every page-7 image and asserts cumulative time < 3,000 ms on the
reference machine. An allocation counter, if available, asserts
a small constant number of per-ImageDescriptor allocations rather
than per-pixel.

## Solution

### Phase 1: Pre-size the RGBA output

Use `FixedArray[Byte]` sized to `width * height * 4` and write via
index. Convert to `Bytes` at the end with a single copy.

```moonbit
let total = descriptor.width * descriptor.height
let rgba = FixedArray::make(total * 4, b'\x00')
for pixel in 0..<total {
  let (r, g, b) = pixel_to_device_rgb(...)
  rgba[pixel * 4] = unit_to_byte(r)
  rgba[pixel * 4 + 1] = unit_to_byte(g)
  rgba[pixel * 4 + 2] = unit_to_byte(b)
  rgba[pixel * 4 + 3] = alpha_byte_at(alpha, pixel)
}
ExtractedImageData::DeviceRgbRaster(ImageDeviceRgbRaster::{
  width: descriptor.width,
  height: descriptor.height,
  rgba: Bytes::from_fixed_array(rgba),
})
```

If `Bytes::from_fixed_array` does not exist in this MoonBit
version, use `Bytes::makei(total * 4, fn(i) { rgba[i] })` — still
O(N) with one allocation. The choice is an implementation detail
of the build; both avoid O(N) reallocations during the write.

### Phase 2: Reuse components scratch buffer

Pass a mutable `Array[Double]` scratch buffer into
`pixel_to_device_rgb` from the caller:

```moonbit
fn pixel_to_device_rgb(
  space : ColourSpace,
  decode : Array[ImageDecodeRange],
  bits_per_component : Int,
  samples : Array[Int],
  pixel : Int,
  scratch : Array[Double],  // NEW — pre-sized to max component count
  offset : Int64,
) -> (Double, Double, Double) raise PdfGraphicsError { ... }
```

The caller in `decode_sample_bytes_to_rgb` allocates `scratch` once
with `space.component_count()` entries (max 4 for CMYK / DeviceN
aliases) and reuses it for every pixel:

```moonbit
let component_count = space.component_count()
let scratch : Array[Double] = Array::make(component_count, 0.0)
for pixel in 0..<total {
  for c in 0..<component_count {
    scratch[c] = decode_sample_value(
      samples[pixel * component_count + c],
      bits_per_component,
      decode[c],
    )
  }
  let (r, g, b) = components_to_device_rgb(space, scratch, offset)
  ...
}
```

The `Indexed` path takes a separate branch that sets scratch
directly from the lookup table bytes using the same mechanism.

### Phase 3: Stencil mask buffer

`decode_stencil_alpha_mask` follows the same pattern with alpha
bytes. Pre-size, index-write, then package as `Bytes`.

### Code organisation

The preallocation change is largely contained in
`decode_sample_bytes_to_rgb` and `decode_stencil_alpha_mask`. The
signature change to `pixel_to_device_rgb` ripples once into the
caller. Keep the existing functional style — no global mutable
state, no thread-unsafe shared buffers.

### Verification approach

Phase 1 and Phase 2 are complementary but independent. Phase 1
alone should cut the time roughly in half (the push-growth cost is
the dominant factor per the analysis in requirements). Phase 2
adds another 10–20 % by removing per-pixel allocations.

Measure after each phase; commit after each.

## Files to modify

- `src/graphics/image_decode.mbt`
  - `decode_sample_bytes_to_rgb` — pre-size RGBA buffer
  - `decode_stencil_alpha_mask` — pre-size alpha buffer
  - `pixel_to_device_rgb` — accept scratch buffer
  - `indexed_pixel_to_device_rgb` — accept scratch buffer
- `src/graphics/image_decode_wbtest.mbt`
  - New pixel-identity golden fixture test
  - New cumulative-time bound test (guarded by local-fixture fixture presence)

Do not modify colour-space conversion files. The optimisation is
purely in the pixel loop plumbing.

## Acceptance verification

1. `moon test --target native` — all tests pass (new tests added)
2. Wasm rebuild + Node profile:
   - Page 7 cumulative `pageSvgImageData(6, i)` over 12 indices
     < 3,000 ms (was 11,699 ms)
   - Pages 4, 5, 6 stay within 10 % of current baselines
3. `indexion spec align status .kiro/specs/pdf-image-decode-perf/requirements.md src/graphics/ --threshold 0.3 --fail-on drifted`
   returns 0
