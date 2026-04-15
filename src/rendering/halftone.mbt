///|
pub(all) enum SpotFunction {
  SimpleDot
  InvertedSimpleDot
  CosineDot
  Line
  LineX
  LineY
  Round
} derive(Eq, Debug)

///|
pub(all) struct HalftoneScreen {
  frequency : Double
  angle : Double
  spot_function : SpotFunction
} derive(Eq, Debug)

///|
pub(all) struct ThresholdArray {
  width : Int
  height : Int
  bits_per_sample : Int
  values : Array[Int]
} derive(Eq, Debug)

///|
pub fn HalftoneScreen::new(
  frequency : Double,
  angle : Double,
  spot_function : SpotFunction,
) -> HalftoneScreen raise PdfRenderingError {
  if !valid_halftone_number(frequency) {
    raise PdfRenderingError::InvalidResource(
      "halftone screen frequency must be positive",
    )
  }
  if angle.is_nan() || angle.is_inf() {
    raise PdfRenderingError::InvalidResource(
      "halftone screen angle must be finite",
    )
  }
  HalftoneScreen::{ frequency, angle, spot_function }
}

///|
pub fn SpotFunction::sample(
  self : SpotFunction,
  x : Double,
  y : Double,
) -> Double {
  let cx = clamp_spot_coordinate(x)
  let cy = clamp_spot_coordinate(y)
  match self {
    SimpleDot => 1.0 - (cx * cx + cy * cy)
    InvertedSimpleDot => cx * cx + cy * cy - 1.0
    CosineDot =>
      (
        @math.cos(degrees_to_radians(180.0 * cx)) +
        @math.cos(degrees_to_radians(180.0 * cy))
      ) /
      2.0
    Line => -abs_double(cy)
    LineX => cx
    LineY => cy
    Round =>
      if abs_double(cx) + abs_double(cy) <= 1.0 {
        1.0 - (cx * cx + cy * cy)
      } else {
        let ax = abs_double(cx) - 1.0
        let ay = abs_double(cy) - 1.0
        ax * ax + ay * ay - 1.0
      }
  }
}

///|
pub fn HalftoneScreen::generate_threshold_array(
  self : HalftoneScreen,
  width : Int,
  height : Int,
  bits_per_sample? : Int = 8,
  limits? : RenderLimits = RenderLimits::default(),
) -> ThresholdArray raise PdfRenderingError {
  validate_threshold_geometry(width, height, bits_per_sample, limits)
  let samples : Array[Double] = []
  for y in 0..<height {
    for x in 0..<width {
      samples.push(
        self.spot_function.sample(
          cell_coordinate(x, width),
          cell_coordinate(y, height),
        ),
      )
    }
  }
  let values : Array[Int] = []
  let max_value = threshold_max(bits_per_sample)
  for index in 0..<samples.length() {
    let rank = whitening_rank(samples, index)
    values.push(rank * max_value / (samples.length() + 1))
  }
  ThresholdArray::{ width, height, bits_per_sample, values }
}

///|
pub fn ThresholdArray::threshold_at(
  self : ThresholdArray,
  x : Int,
  y : Int,
) -> Int raise PdfRenderingError {
  self.validate()
  let tx = positive_mod(x, self.width)
  let ty = positive_mod(y, self.height)
  self.values[ty * self.width + tx]
}

///|
pub fn ThresholdArray::screen_component(
  self : ThresholdArray,
  component : Double,
  x : Int,
  y : Int,
) -> Bool raise PdfRenderingError {
  let threshold = self.threshold_at(x, y)
  let effective = if threshold == 0 { 1 } else { threshold }
  let requested = colour_component(component) *
    threshold_max(self.bits_per_sample).to_double()
  requested >= effective.to_double()
}

///|
pub fn ThresholdArray::validate(
  self : ThresholdArray,
) -> Unit raise PdfRenderingError {
  validate_threshold_geometry(
    self.width,
    self.height,
    self.bits_per_sample,
    RenderLimits::default(),
  )
  if self.values.length() != self.width * self.height {
    raise PdfRenderingError::InvalidResource(
      "threshold array value count must match width and height",
    )
  }
  let max_value = threshold_max(self.bits_per_sample)
  for value in self.values {
    if value < 0 || value > max_value {
      raise PdfRenderingError::InvalidResource(
        "threshold array values must fit bits per sample",
      )
    }
  }
}

///|
fn validate_threshold_geometry(
  width : Int,
  height : Int,
  bits_per_sample : Int,
  limits : RenderLimits,
) -> Unit raise PdfRenderingError {
  if width <= 0 || height <= 0 {
    raise PdfRenderingError::InvalidResource(
      "threshold array dimensions must be positive",
    )
  }
  if bits_per_sample != 8 && bits_per_sample != 16 {
    raise PdfRenderingError::InvalidResource(
      "threshold arrays support 8 or 16 bits per sample",
    )
  }
  let cell_pixels = width * height
  if cell_pixels > limits.max_halftone_cell_pixels {
    raise PdfRenderingError::LimitExceeded(
      "halftone cell pixels",
      cell_pixels,
      limits.max_halftone_cell_pixels,
    )
  }
  let bytes = cell_pixels * bytes_for_bits(bits_per_sample)
  if bytes > limits.max_threshold_bytes {
    raise PdfRenderingError::LimitExceeded(
      "threshold bytes",
      bytes,
      limits.max_threshold_bytes,
    )
  }
}

///|
fn whitening_rank(samples : Array[Double], index : Int) -> Int {
  let mut rank = 1
  for other in 0..<samples.length() {
    if other != index &&
      (
        samples[other] < samples[index] ||
        (samples[other] == samples[index] && other < index)
      ) {
      rank += 1
    }
  }
  rank
}

///|
fn cell_coordinate(index : Int, size : Int) -> Double {
  (index.to_double() + 0.5) / size.to_double() * 2.0 - 1.0
}

///|
fn threshold_max(bits_per_sample : Int) -> Int {
  if bits_per_sample == 16 {
    65535
  } else {
    255
  }
}

///|
fn positive_mod(value : Int, modulus : Int) -> Int {
  let raw = value % modulus
  if raw < 0 {
    raw + modulus
  } else {
    raw
  }
}

///|
fn valid_halftone_number(value : Double) -> Bool {
  value > 0.0 && !value.is_nan() && !value.is_inf()
}

///|
fn clamp_spot_coordinate(value : Double) -> Double {
  if value < -1.0 {
    -1.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
fn degrees_to_radians(degrees : Double) -> Double {
  degrees * 3.141592653589793 / 180.0
}

///|
fn abs_double(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}
