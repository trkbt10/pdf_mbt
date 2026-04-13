///|
fn GraphicsInterpreter::apply_colour_operator(
  self : GraphicsInterpreter,
  operation : @content.ContentOperation,
) -> Unit raise PdfGraphicsError {
  if self.state.colour_restriction.is_restricted() {
    return
  }
  let offset = operation.offset
  match operation.operator {
    SetStrokingColorSpace =>
      self.select_named_colour_space(operation, ColourUse::Stroking)
    SetNonstrokingColorSpace =>
      self.select_named_colour_space(operation, ColourUse::Nonstroking)
    SetStrokingGray =>
      self.apply_convenience_colour(
        operation,
        ColourUse::Stroking,
        DeviceColourSpace::DeviceGray,
        1,
      )
    SetNonstrokingGray =>
      self.apply_convenience_colour(
        operation,
        ColourUse::Nonstroking,
        DeviceColourSpace::DeviceGray,
        1,
      )
    SetStrokingRgb =>
      self.apply_convenience_colour(
        operation,
        ColourUse::Stroking,
        DeviceColourSpace::DeviceRGB,
        3,
      )
    SetNonstrokingRgb =>
      self.apply_convenience_colour(
        operation,
        ColourUse::Nonstroking,
        DeviceColourSpace::DeviceRGB,
        3,
      )
    SetStrokingCmyk =>
      self.apply_convenience_colour(
        operation,
        ColourUse::Stroking,
        DeviceColourSpace::DeviceCMYK,
        4,
      )
    SetNonstrokingCmyk =>
      self.apply_convenience_colour(
        operation,
        ColourUse::Nonstroking,
        DeviceColourSpace::DeviceCMYK,
        4,
      )
    SetStrokingColor =>
      self.apply_explicit_colour(operation, ColourUse::Stroking, false)
    SetNonstrokingColor =>
      self.apply_explicit_colour(operation, ColourUse::Nonstroking, false)
    SetStrokingColorSpecial =>
      self.apply_explicit_colour(operation, ColourUse::Stroking, true)
    SetNonstrokingColorSpecial =>
      self.apply_explicit_colour(operation, ColourUse::Nonstroking, true)
    _ =>
      raise PdfGraphicsError::BadOperand(
        offset, "operation is not a colour operator",
      )
  }
}

///|
fn GraphicsInterpreter::select_named_colour_space(
  self : GraphicsInterpreter,
  operation : @content.ContentOperation,
  colour_use : ColourUse,
) -> Unit raise PdfGraphicsError {
  let name = single_name_operand(operation, "colour space name")
  let space = resolve_content_colour_space(
    self.resources,
    name,
    operation.offset,
  )
  self.state.set_colour_space(colour_use, space)
  self.emit_colour_change(operation.offset, colour_use)
}

///|
fn GraphicsInterpreter::apply_convenience_colour(
  self : GraphicsInterpreter,
  operation : @content.ContentOperation,
  colour_use : ColourUse,
  device : DeviceColourSpace,
  expected : Int,
) -> Unit raise PdfGraphicsError {
  require_operand_count(operation, expected)
  let components = operands_as_numbers(operation)
  let space = resolve_default_device_space(
    self.resources,
    device,
    operation.offset,
  )
  if space.component_count() != expected {
    raise PdfGraphicsError::InvalidGraphicsState(
      operation.offset,
      "default device colour space component count mismatch",
    )
  }
  let value = numeric_colour_value(space, components, operation.offset)
  self.state.replace_colour_state(colour_use, space, value)
  self.emit_colour_change(operation.offset, colour_use)
}

///|
fn GraphicsInterpreter::apply_explicit_colour(
  self : GraphicsInterpreter,
  operation : @content.ContentOperation,
  colour_use : ColourUse,
  special : Bool,
) -> Unit raise PdfGraphicsError {
  let state = self.state.colour_state(colour_use)
  if !special {
    validate_sc_supported(state.colour_space, operation.offset)
    let components = operands_as_numbers(operation)
    let value = numeric_colour_value(
      state.colour_space,
      components,
      operation.offset,
    )
    self.state.set_colour_value(colour_use, value, operation.offset)
  } else {
    let value = scn_colour_value(state.colour_space, operation)
    match state.colour_space {
      Pattern(_) =>
        match value.pattern {
          Some(pattern_name) => {
            let resource = resolve_pattern_resource(
              self.resources,
              pattern_name,
              operation.offset,
            )
            validate_pattern_selection(
              resource,
              state.colour_space,
              value,
              operation.offset,
            )
            self.state.set_colour_value(colour_use, value, operation.offset)
            let selected = self.state.colour_state(colour_use).colour_value
            self.events.push(
              GraphicsEvent::PatternColourSelected(
                operation.offset,
                colour_use,
                resource,
                selected,
                self.state.copy(),
              ),
            )
            return
          }
          None =>
            raise PdfGraphicsError::BadOperand(
              operation.offset,
              "SCN/scn Pattern colour requires a pattern name",
            )
        }
      _ => ()
    }
    self.state.set_colour_value(colour_use, value, operation.offset)
  }
  self.emit_colour_change(operation.offset, colour_use)
}

///|
fn GraphicsInterpreter::emit_colour_change(
  self : GraphicsInterpreter,
  offset : Int64,
  colour_use : ColourUse,
) -> Unit {
  let state = self.state.colour_state(colour_use)
  self.events.push(
    GraphicsEvent::StateChanged(
      offset,
      GraphicsStateChange::ColourChanged(
        colour_use,
        state.colour_space.copy(),
        state.colour_value.copy(),
      ),
      self.state.copy(),
    ),
  )
}

///|
fn validate_sc_supported(
  space : ColourSpace,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  match space {
    Device(_) | CalGray(_) | CalRGB(_) | Lab(_) | Indexed(_) => ()
    _ =>
      raise PdfGraphicsError::BadOperand(
        offset, "SC/sc cannot set this current colour space",
      )
  }
}

///|
fn scn_colour_value(
  space : ColourSpace,
  operation : @content.ContentOperation,
) -> ColourValue raise PdfGraphicsError {
  match space {
    Pattern(_) => {
      if operation.operands.length() == 0 {
        raise PdfGraphicsError::BadOperand(
          operation.offset,
          "SCN/scn Pattern colour requires a pattern name",
        )
      }
      let last = operation.operands[operation.operands.length() - 1]
      let pattern = match last {
        @objects.PdfObject::Name(name) => name
        _ =>
          raise PdfGraphicsError::BadOperand(
            operation.offset,
            "SCN/scn Pattern colour requires a pattern name",
          )
      }
      let components : Array[Double] = []
      for index in 0..<(operation.operands.length() - 1) {
        components.push(
          operand_number(
            operation.operands[index],
            operation.offset,
            "Pattern colour component",
          ),
        )
      }
      pattern_colour_value(space, components, pattern, operation.offset)
    }
    _ => {
      let components = operands_as_numbers(operation)
      numeric_colour_value(space, components, operation.offset)
    }
  }
}

///|
fn operands_as_numbers(
  operation : @content.ContentOperation,
) -> Array[Double] raise PdfGraphicsError {
  let components : Array[Double] = []
  for operand in operation.operands {
    components.push(
      operand_number(operand, operation.offset, "colour component"),
    )
  }
  components
}

///|
pub fn resolve_content_colour_space(
  resources : @content.ContentResources,
  name : @objects.PdfName,
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  if name == @objects.PdfName::new(b"DeviceGray") ||
    name == @objects.PdfName::new(b"DeviceRGB") ||
    name == @objects.PdfName::new(b"DeviceCMYK") ||
    name == @objects.PdfName::new(b"Pattern") {
    parse_colour_space_object(
      @objects.PdfObject::Name(name),
      ColourDefaults::from_resources(resources, offset),
      offset,
    )
  } else {
    let object = try
      resources.lookup_resource(@content.ResourceCategory::ColorSpace, name)
    catch {
      error => raise PdfGraphicsError::ContentFailure(error)
    } noraise {
      value => value
    }
    match object {
      None =>
        raise PdfGraphicsError::ResourceFailure(
          offset,
          "missing ColorSpace resource " + name.to_text(),
        )
      Some(value) =>
        parse_colour_space_object(
          value,
          ColourDefaults::from_resources(resources, offset),
          offset,
        )
    }
  }
}

///|
pub fn resolve_default_device_space(
  resources : @content.ContentResources,
  device : DeviceColourSpace,
  offset : Int64,
) -> ColourSpace raise PdfGraphicsError {
  parse_colour_space_object(
    @objects.PdfObject::Name(device_colour_space_name(device)),
    ColourDefaults::from_resources(resources, offset),
    offset,
  )
}

///|
pub fn ColourDefaults::from_resources(
  resources : @content.ContentResources,
  offset : Int64,
) -> ColourDefaults raise PdfGraphicsError {
  let category = try
    resources.category_object(@content.ResourceCategory::ColorSpace)
  catch {
    error => raise PdfGraphicsError::ContentFailure(error)
  } noraise {
    value => value
  }
  match category {
    None => ColourDefaults::empty()
    Some(@objects.PdfObject::Dictionary(dict)) =>
      ColourDefaults::{
        default_gray: dict.get(@objects.PdfName::new(b"DefaultGray")),
        default_rgb: dict.get(@objects.PdfName::new(b"DefaultRGB")),
        default_cmyk: dict.get(@objects.PdfName::new(b"DefaultCMYK")),
      }
    Some(_) =>
      raise PdfGraphicsError::ResourceFailure(
        offset, "ColorSpace resource category must be a dictionary",
      )
  }
}

///|
fn device_colour_space_name(device : DeviceColourSpace) -> @objects.PdfName {
  match device {
    DeviceGray => @objects.PdfName::new(b"DeviceGray")
    DeviceRGB => @objects.PdfName::new(b"DeviceRGB")
    DeviceCMYK => @objects.PdfName::new(b"DeviceCMYK")
  }
}
