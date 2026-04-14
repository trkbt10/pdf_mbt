///|
test "BlendMode parses standard names and classifies categories" {
  let separable = [
    BlendMode::Multiply,
    BlendMode::Screen,
    BlendMode::Overlay,
    BlendMode::Darken,
    BlendMode::Lighten,
    BlendMode::ColorDodge,
    BlendMode::ColorBurn,
    BlendMode::HardLight,
    BlendMode::SoftLight,
    BlendMode::Difference,
    BlendMode::Exclusion,
  ]
  for mode in separable {
    assert_eq(mode.classify() == BlendModeClass::SeparableBlend, true)
    assert_eq(mode.is_separable(), true)
  }
  let nonseparable = [
    BlendMode::Hue,
    BlendMode::SaturationBlend,
    BlendMode::Color,
    BlendMode::Luminosity,
  ]
  for mode in nonseparable {
    assert_eq(mode.classify() == BlendModeClass::NonSeparableBlend, true)
    assert_eq(mode.is_non_separable(), true)
  }
  assert_eq(BlendMode::Normal.classify() == BlendModeClass::NormalBlend, true)
  assert_eq(BlendMode::Multiply.is_white_preserving(), true)
  assert_eq(BlendMode::Darken.is_white_preserving(), true)
  assert_eq(BlendMode::ColorBurn.is_white_preserving(), true)
  assert_eq(BlendMode::Screen.is_white_preserving(), false)
}

///|
test "BlendMode normalizes Compatible and uses array fallback names" {
  let compatible = BlendMode::from_pdf_object(
    @objects.PdfObject::Name(pdf_name(b"Compatible")),
    1L,
  )
  assert_eq(compatible == BlendMode::Normal, true)
  let fallback = BlendMode::from_pdf_object(
    @objects.PdfObject::Array([
      @objects.PdfObject::Name(pdf_name(b"FutureMode")),
      @objects.PdfObject::Name(pdf_name(b"Multiply")),
    ]),
    1L,
  )
  assert_eq(fallback == BlendMode::Multiply, true)
  let all_unknown = BlendMode::from_pdf_object(
    @objects.PdfObject::Array([
      @objects.PdfObject::Name(pdf_name(b"FutureMode")),
    ]),
    1L,
  )
  assert_eq(all_unknown == BlendMode::Normal, true)
}
