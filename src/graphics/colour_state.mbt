///|
/// Selects whether a colour operator applies to stroking or nonstroking
/// graphics operations: CS/SC/SCN/G/RG/K affect stroking, while
/// cs/sc/scn/g/rg/k affect nonstroking.
pub(all) enum ColourUse {
  Stroking
  Nonstroking
} derive(Eq, Debug)

///|
/// Current colour value. In a Pattern colour space, the pattern object name is
/// the colour value and components are present only for uncoloured tiling
/// patterns with an underlying colour space.
pub(all) struct ColourValue {
  components : Array[Double]
  pattern : @objects.PdfName?
} derive(Eq, Debug)

///|
/// Current colour-space and current colour parameter of the graphics state.
/// Colour values are interpreted according to this colour space; images and
/// later processing stages can consume the same device-independent colour
/// specification without performing raster colour rendering here.
pub(all) struct ColourState {
  colour_space : ColourSpace
  colour_value : ColourValue
} derive(Eq, Debug)

///|
pub fn ColourValue::copy(self : ColourValue) -> ColourValue {
  ColourValue::{ components: self.components.copy(), pattern: self.pattern }
}

///|
pub fn ColourState::copy(self : ColourState) -> ColourState {
  ColourState::{
    colour_space: self.colour_space.copy(),
    colour_value: self.colour_value.copy(),
  }
}

///|
/// Initial graphics-state colour is DeviceGray with a single black component
/// value 0.0 for both stroking and nonstroking operations.
pub fn ColourState::initial() -> ColourState {
  let space = ColourSpace::Device(DeviceColourSpace::DeviceGray)
  ColourState::{ colour_space: space, colour_value: space.initial_value() }
}

///|
pub fn GraphicsState::colour_state(
  self : GraphicsState,
  colour_use : ColourUse,
) -> ColourState {
  match colour_use {
    Stroking => self.stroking_colour.copy()
    Nonstroking => self.nonstroking_colour.copy()
  }
}

///|
pub fn GraphicsState::set_colour_space(
  self : GraphicsState,
  colour_use : ColourUse,
  space : ColourSpace,
) -> Unit {
  let value = space.initial_value()
  self.replace_colour_state(colour_use, space, value)
}

///|
/// Sets the current stroking or nonstroking colour value. SCN/scn Pattern
/// colour selection stores the pattern name as the active colour for later
/// painting operators such as S, f, Tj, and image-mask Do.
pub fn GraphicsState::set_colour_value(
  self : GraphicsState,
  colour_use : ColourUse,
  value : ColourValue,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  let space = match colour_use {
    Stroking => self.stroking_colour.colour_space
    Nonstroking => self.nonstroking_colour.colour_space
  }
  validate_colour_value_for_space(space, value, offset)
  let normalized = match value.pattern {
    Some(pattern) =>
      pattern_colour_value(space, value.components, pattern, offset)
    None => numeric_colour_value(space, value.components, offset)
  }
  self.replace_colour_state(colour_use, space.copy(), normalized)
}

///|
fn GraphicsState::replace_colour_state(
  self : GraphicsState,
  colour_use : ColourUse,
  space : ColourSpace,
  value : ColourValue,
) -> Unit {
  let state = ColourState::{
    colour_space: space.copy(),
    colour_value: value.copy(),
  }
  match colour_use {
    Stroking => self.stroking_colour = state
    Nonstroking => self.nonstroking_colour = state
  }
}

///|
fn validate_colour_value_for_space(
  space : ColourSpace,
  value : ColourValue,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  match space {
    Pattern(params) => {
      if value.pattern is None {
        raise PdfGraphicsError::BadOperand(
          offset, "Pattern colour value requires a pattern name",
        )
      }
      let expected = match params.underlying {
        Some(underlying) => underlying.component_count()
        None => 0
      }
      if value.components.length() != expected {
        raise PdfGraphicsError::BadOperand(
          offset, "Pattern colour value component count mismatch",
        )
      }
    }
    _ => {
      if value.pattern is Some(_) {
        raise PdfGraphicsError::BadOperand(
          offset, "pattern name is only valid for Pattern colour spaces",
        )
      }
      if value.components.length() != space.component_count() {
        raise PdfGraphicsError::BadOperand(
          offset, "colour value component count mismatch",
        )
      }
    }
  }
}

///|
fn numeric_colour_value(
  space : ColourSpace,
  components : Array[Double],
  offset : Int64,
) -> ColourValue raise PdfGraphicsError {
  if components.length() != space.component_count() {
    raise PdfGraphicsError::BadOperand(
      offset, "colour value component count mismatch",
    )
  }
  ColourValue::{
    components: normalize_colour_components(space, components, offset),
    pattern: None,
  }
}

///|
fn pattern_colour_value(
  space : ColourSpace,
  components : Array[Double],
  pattern : @objects.PdfName,
  offset : Int64,
) -> ColourValue raise PdfGraphicsError {
  match space {
    Pattern(params) => {
      let expected = match params.underlying {
        Some(underlying) => underlying.component_count()
        None => 0
      }
      if components.length() != expected {
        raise PdfGraphicsError::BadOperand(
          offset, "Pattern colour value component count mismatch",
        )
      }
      let normalized = match params.underlying {
        Some(underlying) =>
          normalize_colour_components(underlying, components, offset)
        None => []
      }
      ColourValue::{ components: normalized, pattern: Some(pattern) }
    }
    _ =>
      raise PdfGraphicsError::BadOperand(
        offset, "pattern name is only valid for Pattern colour spaces",
      )
  }
}

///|
fn normalize_colour_components(
  space : ColourSpace,
  components : Array[Double],
  offset : Int64,
) -> Array[Double] raise PdfGraphicsError {
  match space {
    Indexed(params) => {
      if components.length() != 1 {
        raise PdfGraphicsError::BadOperand(
          offset, "Indexed colour value requires one component",
        )
      }
      [clamp_indexed_component(components[0], params.hival)]
    }
    _ => {
      let ranges = space.component_ranges()
      if components.length() != ranges.length() {
        raise PdfGraphicsError::BadOperand(
          offset, "colour value component count mismatch",
        )
      }
      let output : Array[Double] = []
      for index in 0..<components.length() {
        output.push(
          clamp_double(components[index], ranges[index].min, ranges[index].max),
        )
      }
      output
    }
  }
}

///|
fn clamp_indexed_component(value : Double, hival : Int) -> Double {
  clamp_double(@math.floor(value + 0.5), 0.0, hival.to_double())
}

///|
fn clamp_double(value : Double, min : Double, max : Double) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}
