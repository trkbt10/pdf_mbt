///|
/// Structured page content stream API backing text operators BT/ET, Tf, Td,
/// Tj, basic graphics path operators, colour operators, and font resource
/// references.
priv struct PdfContentBuilder {
  operations : Array[Bytes]
}

///|
fn PdfContentBuilder::new() -> PdfContentBuilder {
  PdfContentBuilder::{ operations: [] }
}

///|
fn PdfContentBuilder::begin_text(self : PdfContentBuilder) -> Unit {
  self.operator0(b"BT")
}

///|
fn PdfContentBuilder::end_text(self : PdfContentBuilder) -> Unit {
  self.operator0(b"ET")
}

///|
fn PdfContentBuilder::set_font(
  self : PdfContentBuilder,
  name : @objects.PdfName,
  size : Double,
) -> Unit {
  self.operations.push(
    @context.serialize_name(name) + b" " + number_bytes(size) + b" Tf\n",
  )
}

///|
fn PdfContentBuilder::move_text(
  self : PdfContentBuilder,
  x : Double,
  y : Double,
) -> Unit {
  self.operations.push(number_bytes(x) + b" " + number_bytes(y) + b" Td\n")
}

///|
fn PdfContentBuilder::show_text(
  self : PdfContentBuilder,
  bytes : Bytes,
) -> Unit {
  self.operations.push(@context.serialize_literal_string(bytes) + b" Tj\n")
}

///|
fn PdfContentBuilder::set_stroking_rgb(
  self : PdfContentBuilder,
  red : Double,
  green : Double,
  blue : Double,
) -> Unit {
  self.operations.push(
    number_bytes(red) +
    b" " +
    number_bytes(green) +
    b" " +
    number_bytes(blue) +
    b" RG\n",
  )
}

///|
fn PdfContentBuilder::set_nonstroking_rgb(
  self : PdfContentBuilder,
  red : Double,
  green : Double,
  blue : Double,
) -> Unit {
  self.operations.push(
    number_bytes(red) +
    b" " +
    number_bytes(green) +
    b" " +
    number_bytes(blue) +
    b" rg\n",
  )
}

///|
fn PdfContentBuilder::move_to(
  self : PdfContentBuilder,
  x : Double,
  y : Double,
) -> Unit {
  self.operations.push(number_bytes(x) + b" " + number_bytes(y) + b" m\n")
}

///|
fn PdfContentBuilder::line_to(
  self : PdfContentBuilder,
  x : Double,
  y : Double,
) -> Unit {
  self.operations.push(number_bytes(x) + b" " + number_bytes(y) + b" l\n")
}

///|
fn PdfContentBuilder::rectangle(
  self : PdfContentBuilder,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit {
  self.operations.push(
    number_bytes(x) +
    b" " +
    number_bytes(y) +
    b" " +
    number_bytes(width) +
    b" " +
    number_bytes(height) +
    b" re\n",
  )
}

///|
fn PdfContentBuilder::stroke(self : PdfContentBuilder) -> Unit {
  self.operator0(b"S")
}

///|
fn PdfContentBuilder::fill(self : PdfContentBuilder) -> Unit {
  self.operator0(b"f")
}

///|
fn PdfContentBuilder::bytes(self : PdfContentBuilder) -> Bytes {
  let out : Array[Byte] = []
  for operation in self.operations {
    out.append(operation.to_array())
  }
  Bytes::from_array(out)
}

///|
pub fn text_content(text : Bytes) -> Bytes {
  let builder = PdfContentBuilder::new()
  builder.begin_text()
  builder.set_font(@objects.PdfName::new(b"F1"), 12.0)
  builder.move_text(72.0, 720.0)
  builder.show_text(text)
  builder.end_text()
  builder.bytes()
}

///|
pub fn page_content_writing_basic_graphics_path_colour_operators() -> Bytes {
  let builder = PdfContentBuilder::new()
  builder.set_stroking_rgb(1.0, 0.0, 0.0)
  builder.set_nonstroking_rgb(0.0, 0.0, 1.0)
  builder.rectangle(72.0, 640.0, 120.0, 60.0)
  builder.stroke()
  builder.move_to(72.0, 620.0)
  builder.line_to(192.0, 620.0)
  builder.stroke()
  builder.bytes()
}

///|
fn PdfContentBuilder::operator0(
  self : PdfContentBuilder,
  operator : Bytes,
) -> Unit {
  self.operations.push(operator + b"\n")
}

///|
fn number_bytes(value : Double) -> Bytes {
  @context.serialize_object(Real(value))
}
