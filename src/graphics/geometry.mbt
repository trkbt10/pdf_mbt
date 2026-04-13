///|
/// Coordinate pair in PDF user space or a transformed coordinate space.
pub(all) struct GraphicsPoint {
  x : Double
  y : Double
} derive(Eq, Debug)

///|
/// Page or path rectangle represented by lower-left and upper-right values.
pub(all) struct GraphicsRect {
  left : Double
  bottom : Double
  right : Double
  top : Double
} derive(Eq, Debug)

///|
/// ISO PDF six-number affine transformation matrix `[a b c d e f]`.
/// When used as the current transformation matrix (CTM), it maps user space
/// coordinates in a PDF content stream toward output device coordinates for
/// device-independent graphics. It maps points by `x' = a*x + c*y + e`,
/// `y' = b*x + d*y + f`.
pub(all) struct GraphicsMatrix {
  a : Double
  b : Double
  c : Double
  d : Double
  e : Double
  f : Double
} derive(Eq, Debug)

///|
pub fn GraphicsPoint::new(x : Double, y : Double) -> GraphicsPoint {
  GraphicsPoint::{ x, y }
}

///|
pub fn GraphicsRect::new(
  left : Double,
  bottom : Double,
  right : Double,
  top : Double,
) -> GraphicsRect {
  GraphicsRect::{ left, bottom, right, top }
}

///|
pub fn GraphicsMatrix::identity() -> GraphicsMatrix {
  GraphicsMatrix::{ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 0.0, f: 0.0 }
}

///|
pub fn GraphicsMatrix::from_six(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  e : Double,
  f : Double,
) -> GraphicsMatrix {
  GraphicsMatrix::{ a, b, c, d, e, f }
}

///|
pub fn GraphicsMatrix::translation(tx : Double, ty : Double) -> GraphicsMatrix {
  GraphicsMatrix::from_six(1.0, 0.0, 0.0, 1.0, tx, ty)
}

///|
pub fn GraphicsMatrix::scale(sx : Double, sy : Double) -> GraphicsMatrix {
  GraphicsMatrix::from_six(sx, 0.0, 0.0, sy, 0.0, 0.0)
}

///|
pub fn GraphicsMatrix::rotation(radians : Double) -> GraphicsMatrix {
  let rc = @math.cos(radians)
  let rs = @math.sin(radians)
  GraphicsMatrix::from_six(rc, rs, 0.0 - rs, rc, 0.0, 0.0)
}

///|
pub fn GraphicsMatrix::skew(
  x_angle : Double,
  y_angle : Double,
) -> GraphicsMatrix {
  GraphicsMatrix::from_six(
    1.0,
    @math.tan(y_angle),
    @math.tan(x_angle),
    1.0,
    0.0,
    0.0,
  )
}

///|
/// Returns `transform x current`, the PDF `cm` premultiplication order.
pub fn GraphicsMatrix::concat(
  transform : GraphicsMatrix,
  current : GraphicsMatrix,
) -> GraphicsMatrix {
  GraphicsMatrix::{
    a: transform.a * current.a + transform.b * current.c,
    b: transform.a * current.b + transform.b * current.d,
    c: transform.c * current.a + transform.d * current.c,
    d: transform.c * current.b + transform.d * current.d,
    e: transform.e * current.a + transform.f * current.c + current.e,
    f: transform.e * current.b + transform.f * current.d + current.f,
  }
}

///|
pub fn GraphicsMatrix::transform_point(
  self : GraphicsMatrix,
  point : GraphicsPoint,
) -> GraphicsPoint {
  GraphicsPoint::{
    x: self.a * point.x + self.c * point.y + self.e,
    y: self.b * point.x + self.d * point.y + self.f,
  }
}

///|
pub fn GraphicsMatrix::determinant(self : GraphicsMatrix) -> Double {
  self.a * self.d - self.b * self.c
}

///|
pub fn GraphicsMatrix::inverse(self : GraphicsMatrix) -> GraphicsMatrix? {
  let det = self.determinant()
  if det == 0.0 {
    None
  } else {
    Some(GraphicsMatrix::{
      a: self.d / det,
      b: (0.0 - self.b) / det,
      c: (0.0 - self.c) / det,
      d: self.a / det,
      e: (self.c * self.f - self.d * self.e) / det,
      f: (self.b * self.e - self.a * self.f) / det,
    })
  }
}
