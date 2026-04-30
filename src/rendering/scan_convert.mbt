///|
pub(all) struct DevicePixelPoint {
  x : Int
  y : Int
} derive(Eq, Debug)

///|
pub(all) struct DevicePixelMark {
  components : Array[Byte]
} derive(Eq, Debug)

///|
pub(all) struct PixelCoverageRule {
  half_open_device_pixels : Bool
  centre_sampled_images : Bool
  automatic_stroke_adjustment : Bool
} derive(Eq, Debug)

///|
pub fn PixelCoverageRule::default() -> PixelCoverageRule {
  PixelCoverageRule::{
    half_open_device_pixels: true,
    centre_sampled_images: true,
    automatic_stroke_adjustment: true,
  }
}

///|
pub fn apply_halftone(
  colour : AdditiveNativeColour,
  point : DevicePixelPoint,
  threshold : ThresholdArray?,
  device : RasterDevice,
) -> DevicePixelMark raise PdfRenderingError {
  let marks : Array[Byte] = []
  for component in 0..<colour.components.length() {
    let additive = colour_component(colour.components[component])
    if device.continuous_tone || threshold is None {
      marks.push(component_to_byte(additive, device.bits_per_component))
    } else {
      let array = threshold.unwrap()
      if array.screen_component(additive, point.x, point.y) {
        marks.push(component_to_byte(1.0, device.bits_per_component))
      } else {
        marks.push(component_to_byte(0.0, device.bits_per_component))
      }
    }
  }
  DevicePixelMark::{ components: marks }
}

///|
pub fn paint_device_pixel(
  surface : RasterSurface,
  point : DevicePixelPoint,
  mark : DevicePixelMark,
) -> Unit raise PdfRenderingError {
  for component in 0..<mark.components.length() {
    surface.write_component_byte(
      point.x,
      point.y,
      component,
      0,
      mark.components[component],
    )
  }
}

///|
pub fn fill_device_rect(
  surface : RasterSurface,
  left : Int,
  top : Int,
  right : Int,
  bottom : Int,
  mark : DevicePixelMark,
) -> Int raise PdfRenderingError {
  let min_x = clamp_int(left, 0, surface.width - 1)
  let max_x = clamp_int(
    if right <= left {
      left
    } else {
      right - 1
    },
    0,
    surface.width - 1,
  )
  let min_y = clamp_int(top, 0, surface.height - 1)
  let max_y = clamp_int(
    if bottom <= top {
      top
    } else {
      bottom - 1
    },
    0,
    surface.height - 1,
  )
  let mut painted = 0
  for y in min_y..<=max_y {
    for x in min_x..<=max_x {
      paint_device_pixel(surface, DevicePixelPoint::{ x, y }, mark)
      painted += 1
    }
  }
  painted
}

///|
pub fn stroke_device_line(
  surface : RasterSurface,
  start : DevicePixelPoint,
  end : DevicePixelPoint,
  line_width : Double,
  stroke_adjustment : Bool,
  mark : DevicePixelMark,
) -> Int raise PdfRenderingError {
  let adjusted_width = if stroke_adjustment && line_width < 0.5 {
    1
  } else {
    max_int(1, @math.ceil(line_width).to_int())
  }
  let min_x = clamp_int(min_int(start.x, end.x), 0, surface.width - 1)
  let max_x = clamp_int(max_int(start.x, end.x), 0, surface.width - 1)
  let min_y = clamp_int(min_int(start.y, end.y), 0, surface.height - 1)
  let max_y = clamp_int(max_int(start.y, end.y), 0, surface.height - 1)
  let mut painted = 0
  for y in min_y..<=max_y {
    for x in min_x..<=max_x {
      for dy in 0..<adjusted_width {
        let yy = clamp_int(y + dy, 0, surface.height - 1)
        paint_device_pixel(surface, DevicePixelPoint::{ x, y: yy }, mark)
        painted += 1
      }
    }
  }
  painted
}

///|
pub fn image_source_sample_for_device_pixel(
  image_width : Int,
  image_height : Int,
  device_x : Int,
  device_y : Int,
  painted_width : Int,
  painted_height : Int,
) -> DevicePixelPoint raise PdfRenderingError {
  if image_width <= 0 ||
    image_height <= 0 ||
    painted_width <= 0 ||
    painted_height <= 0 {
    raise PdfRenderingError::InvalidResource(
      "image sampling dimensions must be positive",
    )
  }
  DevicePixelPoint::{
    x: clamp_int(
      ((device_x.to_double() + 0.5) *
      image_width.to_double() /
      painted_width.to_double()).to_int(),
      0,
      image_width - 1,
    ),
    y: clamp_int(
      ((device_y.to_double() + 0.5) *
      image_height.to_double() /
      painted_height.to_double()).to_int(),
      0,
      image_height - 1,
    ),
  }
}

///|
fn component_to_byte(component : Double, bits_per_component : Int) -> Byte {
  let max_value = if bits_per_component == 16 {
    255
  } else {
    (1 << bits_per_component) - 1
  }
  clamp_int(
    @math.round(colour_component(component) * max_value.to_double()).to_int(),
    0,
    255,
  ).to_byte()
}

///|
fn clamp_int(value : Int, min_value : Int, max_value : Int) -> Int {
  if value < min_value {
    min_value
  } else if value > max_value {
    max_value
  } else {
    value
  }
}

///|
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
