///|
test "raster device constructors validate native component invariants" {
  let gray = RasterDevice::gray(3, 2)
  gray.validate()
  assert_eq(gray.native_colour_space.component_count(), 1)
  assert_eq(gray.component_count(), 1)

  let rgb = RasterDevice::rgb(3, 2)
  rgb.validate()
  assert_eq(rgb.native_colour_space.component_count(), 3)
  assert_eq(rgb.component_count(), 3)

  let cmyk = RasterDevice::cmyk(3, 2)
  cmyk.validate()
  assert_eq(cmyk.native_colour_space.component_count(), 4)
  assert_eq(cmyk.component_count(), 4)
}

///|
test "raster device validation rejects dimensions resolution and process drift" {
  let bad_width : Result[Unit, PdfRenderingError] = try? RasterDevice::rgb(0, 2).validate()
  match bad_width {
    Err(InvalidDevice(reason)) => assert_eq(reason.contains("width"), true)
    _ => fail("expected invalid width")
  }

  let bad_resolution : Result[Unit, PdfRenderingError] = try? RasterDevice::rgb(
      2, 2,
    )
    .with_resolution(0.0, 72.0)
    .validate()
  match bad_resolution {
    Err(InvalidDevice(reason)) => assert_eq(reason.contains("resolution"), true)
    _ => fail("expected invalid resolution")
  }

  let bad_process : Result[Unit, PdfRenderingError] = try? RasterDevice::rgb(
      2, 2,
    )
    .with_process_colourants([@objects.PdfName::new(b"Red")])
    .validate()
  match bad_process {
    Err(InvalidDevice(reason)) => assert_eq(reason.contains("process"), true)
    _ => fail("expected invalid process colourants")
  }
}

///|
test "raster device validation enforces bits and allocation limits" {
  let bad_bits : Result[Unit, PdfRenderingError] = try? RasterDevice::gray(2, 2)
    .with_bits_per_component(3)
    .validate()
  match bad_bits {
    Err(InvalidDevice(reason)) => assert_eq(reason.contains("bits"), true)
    _ => fail("expected invalid bits per component")
  }

  let limits = RenderLimits::{
    max_width: 10,
    max_height: 10,
    max_surface_bytes: 11,
    max_process_colourants: 4,
    max_spot_colourants: 2,
    max_bits_per_component: 16,
    max_threshold_bytes: 64,
    max_path_segments: 64,
    max_halftone_cell_pixels: 64,
    max_provider_cache_entries: 8,
  }
  let oversized : Result[Unit, PdfRenderingError] = try? RasterDevice::rgb(2, 2)
    .with_limits(limits)
    .validate()
  match oversized {
    Err(LimitExceeded(name, observed, limit)) => {
      assert_eq(name, "surface bytes")
      assert_eq(observed, 12)
      assert_eq(limit, 11)
    }
    _ => fail("expected surface allocation limit failure")
  }
}

///|
test "spot colourants extend component count and must be unique" {
  let device = RasterDevice::cmyk(2, 2).with_spot_colourants([
    @objects.PdfName::new(b"SpotA"),
    @objects.PdfName::new(b"SpotB"),
  ])
  device.validate()
  assert_eq(device.component_count(), 6)

  let duplicate : Result[Unit, PdfRenderingError] = try? RasterDevice::cmyk(
      2, 2,
    )
    .with_spot_colourants([@objects.PdfName::new(b"Cyan")])
    .validate()
  match duplicate {
    Err(InvalidDevice(reason)) => assert_eq(reason.contains("duplicates"), true)
    _ => fail("expected duplicate colourant rejection")
  }
}

///|
test "render reports capture strictness skips fallbacks and limit observations" {
  let options = RenderOptions::best_effort()
  assert_eq(options.is_strict(), false)

  let report = RenderReport::empty()
  report.record_paint()
  report.record_skip(
    12L,
    "paint-image",
    SkippedRenderReason::UnsupportedResource("unsupported filter"),
  )
  report.record_provider_fallback(
    "colour-transform", "classic-device", "DeviceRGB",
  )
  report.observe_limit("surface bytes", 10, 100)

  assert_eq(report.paint_count, 1)
  assert_eq(report.skipped_operations.length(), 1)
  assert_eq(report.provider_fallbacks.length(), 1)
  assert_eq(report.limit_observations.length(), 1)
}
