///|
pub(all) enum BlendMode {
  Normal
  Multiply
  Screen
  Overlay
  Darken
  Lighten
  ColorDodge
  ColorBurn
  HardLight
  SoftLight
  Difference
  Exclusion
  Hue
  SaturationBlend
  Color
  Luminosity
} derive(Eq, Debug)

///|
pub(all) enum BlendModeClass {
  NormalBlend
  SeparableBlend
  NonSeparableBlend
} derive(Eq, Debug)

///|
pub fn BlendMode::from_pdf_object(
  object : @objects.PdfObject,
  offset : Int64,
) -> BlendMode raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Name(name) => BlendMode::from_name_or_normal(name)
    @objects.PdfObject::Array(values) => blend_mode_from_array(values, offset)
    _ =>
      raise PdfGraphicsError::InvalidGraphicsState(
        offset, "BM ExtGState entry must be a name or array of names",
      )
  }
}

///|
pub fn BlendMode::from_name_or_normal(name : @objects.PdfName) -> BlendMode {
  match standard_blend_mode_name(name) {
    Some(mode) => mode
    None => BlendMode::Normal
  }
}

///|
pub fn BlendMode::classify(self : BlendMode) -> BlendModeClass {
  match self {
    Normal => BlendModeClass::NormalBlend
    Hue | SaturationBlend | Color | Luminosity =>
      BlendModeClass::NonSeparableBlend
    _ => BlendModeClass::SeparableBlend
  }
}

///|
pub fn BlendMode::is_separable(self : BlendMode) -> Bool {
  match self.classify() {
    NonSeparableBlend => false
    _ => true
  }
}

///|
pub fn BlendMode::is_non_separable(self : BlendMode) -> Bool {
  self.classify() == BlendModeClass::NonSeparableBlend
}

///|
pub fn BlendMode::is_white_preserving(self : BlendMode) -> Bool {
  match self {
    Multiply | Darken | ColorBurn => true
    _ => false
  }
}

///|
fn blend_mode_from_array(
  values : Array[@objects.PdfObject],
  offset : Int64,
) -> BlendMode raise PdfGraphicsError {
  for value in values {
    match value {
      @objects.PdfObject::Name(name) =>
        match standard_blend_mode_name(name) {
          Some(mode) => return mode
          None => ()
        }
      _ =>
        raise PdfGraphicsError::InvalidGraphicsState(
          offset, "BM array entries must be names",
        )
    }
  }
  BlendMode::Normal
}

///|
fn standard_blend_mode_name(name : @objects.PdfName) -> BlendMode? {
  if name == pdf_name(b"Normal") || name == pdf_name(b"Compatible") {
    Some(BlendMode::Normal)
  } else if name == pdf_name(b"Multiply") {
    Some(BlendMode::Multiply)
  } else if name == pdf_name(b"Screen") {
    Some(BlendMode::Screen)
  } else if name == pdf_name(b"Overlay") {
    Some(BlendMode::Overlay)
  } else if name == pdf_name(b"Darken") {
    Some(BlendMode::Darken)
  } else if name == pdf_name(b"Lighten") {
    Some(BlendMode::Lighten)
  } else if name == pdf_name(b"ColorDodge") {
    Some(BlendMode::ColorDodge)
  } else if name == pdf_name(b"ColorBurn") {
    Some(BlendMode::ColorBurn)
  } else if name == pdf_name(b"HardLight") {
    Some(BlendMode::HardLight)
  } else if name == pdf_name(b"SoftLight") {
    Some(BlendMode::SoftLight)
  } else if name == pdf_name(b"Difference") {
    Some(BlendMode::Difference)
  } else if name == pdf_name(b"Exclusion") {
    Some(BlendMode::Exclusion)
  } else if name == pdf_name(b"Hue") {
    Some(BlendMode::Hue)
  } else if name == pdf_name(b"Saturation") {
    Some(BlendMode::SaturationBlend)
  } else if name == pdf_name(b"Color") {
    Some(BlendMode::Color)
  } else if name == pdf_name(b"Luminosity") {
    Some(BlendMode::Luminosity)
  } else {
    None
  }
}
