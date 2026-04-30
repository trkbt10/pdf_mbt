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
/// Section 8.6.6.1 General, "Special colour spaces" says special colour spaces
/// add features or properties to an underlying colour space. The special
/// families are Pattern, Indexed, Separation, and DeviceN, covering patterns,
/// colour mapping, separations, high-fidelity colour, and multitone colour.
/// Section 8.6.6.2 Pattern colour spaces allows the current colour space to be
/// Pattern, where an area is painted with a pattern rather than a single
/// colour; "Patterns" discusses patterns in detail. Section 8.6.6.3 Indexed
/// colour spaces specifies a colour map or colour table of arbitrary colours in
/// another base colour space. SCN/scn carry a Pattern name as the colour value,
/// with optional underlying colour components for uncoloured tiling patterns.
/// Colour values are otherwise interpreted according to the current colour
/// space without performing raster colour rendering here.
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
pub fn ColourState::with_fill_colour(
  self : ColourState,
  value : ColourValue,
  offset? : Int64 = 0L,
) -> ColourState raise PdfGraphicsError {
  let space = self.colour_space.copy()
  let normalized = value.normalized_for_space(space, offset~)
  ColourState::{ colour_space: space, colour_value: normalized }
}

///|
pub fn ColourState::with_stroke_colour(
  self : ColourState,
  value : ColourValue,
  offset? : Int64 = 0L,
) -> ColourState raise PdfGraphicsError {
  let space = self.colour_space.copy()
  let normalized = value.normalized_for_space(space, offset~)
  ColourState::{ colour_space: space, colour_value: normalized }
}

///|
pub fn ColourState::resolve_default_space(
  self : ColourState,
  defaults : ColourDefaults,
  offset? : Int64 = 0L,
) -> ColourSpace raise PdfGraphicsError {
  match self.colour_space.to_device_family() {
    Some(device) => {
      let resolved = defaults.resolve_device_space(device, offset~)
      resolved
    }
    None => {
      let retained = self.colour_space.copy()
      retained
    }
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

///|
/// Pair of stroking and nonstroking colour states saved independently from
/// the full graphics state stack for colour-only validation and replay.
pub(all) struct ColourStateSnapshot {
  stroking : ColourState
  nonstroking : ColourState
} derive(Eq, Debug)

///|
/// LIFO stack for the current colour-space and colour-value pair. This mirrors
/// the q/Q graphics-state semantics for colour fields without copying path,
/// transparency, or text-independent graphics parameters.
pub(all) struct ColourStateStack {
  stack : Array[ColourStateSnapshot]
} derive(Eq, Debug)

///|
pub fn ColourValue::normalized_for_space(
  self : ColourValue,
  space : ColourSpace,
  offset? : Int64 = 0L,
) -> ColourValue raise PdfGraphicsError {
  validate_colour_value_for_space(space, self, offset)
  match self.pattern {
    Some(pattern) =>
      pattern_colour_value(space, self.components, pattern, offset)
    None => numeric_colour_value(space, self.components, offset)
  }
}

///|
pub fn ColourValue::convert_to_rgb(
  self : ColourValue,
  space : ColourSpace,
  offset? : Int64 = 0L,
) -> DeviceRgbColour raise PdfGraphicsError {
  let normalized = self.normalized_for_space(space, offset~)
  space.convert_to_rgb(normalized, offset~)
}

///|
pub fn ColourState::normalized(
  self : ColourState,
  offset? : Int64 = 0L,
) -> ColourState raise PdfGraphicsError {
  ColourState::{
    colour_space: self.colour_space.copy(),
    colour_value: self.colour_value.normalized_for_space(
      self.colour_space,
      offset~,
    ),
  }
}

///|
pub fn ColourState::convert_to_rgb(
  self : ColourState,
  offset? : Int64 = 0L,
) -> DeviceRgbColour raise PdfGraphicsError {
  self.colour_value.convert_to_rgb(self.colour_space, offset~)
}

///|
pub fn ColourStateSnapshot::from_graphics_state(
  state : GraphicsState,
) -> ColourStateSnapshot {
  ColourStateSnapshot::{
    stroking: state.stroking_colour.copy(),
    nonstroking: state.nonstroking_colour.copy(),
  }
}

///|
pub fn ColourStateSnapshot::apply_to_graphics_state(
  self : ColourStateSnapshot,
  state : GraphicsState,
) -> Unit {
  state.stroking_colour = self.stroking.copy()
  state.nonstroking_colour = self.nonstroking.copy()
}

///|
pub fn ColourStateStack::new() -> ColourStateStack {
  ColourStateStack::{ stack: [] }
}

///|
pub fn ColourStateStack::depth(self : ColourStateStack) -> Int {
  self.stack.length()
}

///|
pub fn ColourStateStack::push_graphics_state(
  self : ColourStateStack,
  state : GraphicsState,
) -> Unit {
  self.stack.push(ColourStateSnapshot::from_graphics_state(state))
}

///|
pub fn ColourStateStack::pop_into_graphics_state(
  self : ColourStateStack,
  state : GraphicsState,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  match self.stack.pop() {
    Some(snapshot) => snapshot.apply_to_graphics_state(state)
    None => raise PdfGraphicsError::GraphicsStackUnderflow(offset)
  }
}

///|
pub fn GraphicsState::current_colour_space(
  self : GraphicsState,
  colour_use : ColourUse,
) -> ColourSpace {
  self.colour_state(colour_use).colour_space
}

///|
pub fn GraphicsState::current_colour_value(
  self : GraphicsState,
  colour_use : ColourUse,
) -> ColourValue {
  self.colour_state(colour_use).colour_value
}

///|
pub fn GraphicsState::current_colour_as_rgb(
  self : GraphicsState,
  colour_use : ColourUse,
  offset? : Int64 = 0L,
) -> DeviceRgbColour raise PdfGraphicsError {
  self.colour_state(colour_use).convert_to_rgb(offset~)
}
