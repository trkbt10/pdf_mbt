///|
/// Coordinate pair in text space or a transformed text coordinate space.
pub(all) struct TextPoint {
  x : Double
  y : Double
} derive(Eq, Debug)

///|
/// ISO PDF six-number affine matrix `[a b c d e f]` used for text matrices and
/// CTM-like inputs. Points map by `x' = a*x + c*y + e`,
/// `y' = b*x + d*y + f`.
pub(all) struct TextMatrix {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
} derive(Eq, Debug)

///|
/// Snapshot of the text rendering matrix computed before emitting a glyph.
pub(all) struct TextRenderingMatrix {
  matrix : TextMatrix
} derive(Eq, Debug)

///|
pub fn TextPoint::new(x : Double, y : Double) -> TextPoint {
  TextPoint::{ x, y }
}

///|
pub fn TextMatrix::identity() -> TextMatrix {
  TextMatrix::{ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0 }
}

///|
pub fn TextMatrix::from_six(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  e : Double,
  f : Double,
) -> TextMatrix {
  TextMatrix::{ a, b, c, d, e, f }
}

///|
pub fn TextMatrix::translation(tx : Double, ty : Double) -> TextMatrix {
  TextMatrix::from_six(1.0, 0.0, 0.0, 1.0, tx, ty)
}

///|
pub fn TextMatrix::scale(sx : Double, sy : Double) -> TextMatrix {
  TextMatrix::from_six(sx, 0.0, 0.0, sy, 0.0, 0.0)
}

///|
/// Returns `transform x current`, matching the PDF matrix composition order
/// already used by the graphics package for `cm`.
pub fn TextMatrix::concat(
  transform : TextMatrix,
  current : TextMatrix,
) -> TextMatrix {
  TextMatrix::{
    a: transform.a * current.a + transform.b * current.c,
    b: transform.a * current.b + transform.b * current.d,
    c: transform.c * current.a + transform.d * current.c,
    d: transform.c * current.b + transform.d * current.d,
    e: transform.e * current.a + transform.f * current.c + current.e,
    f: transform.e * current.b + transform.f * current.d + current.f,
  }
}

///|
pub fn TextMatrix::translated(
  self : TextMatrix,
  tx : Double,
  ty : Double,
) -> TextMatrix {
  TextMatrix::concat(TextMatrix::translation(tx, ty), self)
}

///|
pub fn TextMatrix::replace_with(
  _self : TextMatrix,
  replacement : TextMatrix,
) -> TextMatrix {
  replacement
}

///|
pub fn TextMatrix::transform_point(
  self : TextMatrix,
  point : TextPoint,
) -> TextPoint {
  TextPoint::{
    x: self.a * point.x + self.c * point.y + self.e,
    y: self.b * point.x + self.d * point.y + self.f,
  }
}

///|
pub fn TextMatrix::glyph_advance_translation(
  tx : Double,
  ty : Double,
) -> TextMatrix {
  TextMatrix::translation(tx, ty)
}

///|
pub fn TextMatrix::text_state_matrix(
  font_size : Double,
  horizontal_scaling : Double,
  text_rise : Double,
) -> TextMatrix {
  TextMatrix::from_six(
    font_size * horizontal_scaling,
    0.0,
    0.0,
    font_size,
    0.0,
    text_rise,
  )
}

///|
pub fn TextRenderingMatrix::from_text_state(
  text_matrix : TextMatrix,
  font_size : Double,
  horizontal_scaling : Double,
  text_rise : Double,
  ctm : TextMatrix,
) -> TextRenderingMatrix {
  let text_state = TextMatrix::text_state_matrix(
    font_size, horizontal_scaling, text_rise,
  )
  TextRenderingMatrix::{
    matrix: TextMatrix::concat(TextMatrix::concat(text_state, text_matrix), ctm),
  }
}
