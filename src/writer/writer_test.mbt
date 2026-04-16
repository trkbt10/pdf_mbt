///|
test "writer serializes every object shape to parseable PDF syntax" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Name With Space")] = Name(
    @objects.PdfName::new(b"Value"),
  )
  dict[@objects.PdfName::new(b"Flag")] = Boolean(true)
  let object = @objects.PdfObject::Array([
    Boolean(false),
    Integer(42L),
    Real(3.5),
    String(b"a(b)\\c\n"),
    Name(@objects.PdfName::new(b"A#B")),
    Dictionary(dict),
    Null,
    Ref(@objects.ObjectId::{ object_number: 9, generation_number: 2 }),
  ])
  let reparsed = @parser.parse_object(@writer.serialize_object(object))
  assert_eq(reparsed == object, true)
  let stream_dict : @objects.PdfDictionary = Map::new()
  let stream = @objects.PdfObject::Stream(@objects.PdfStream::{
    dict: stream_dict,
    data: b"abc",
  })
  let indirect = @parser.parse_indirect_object(
    @writer.serialize_indirect_object(@objects.IndirectObject::{
      id: @objects.ObjectId::{ object_number: 10, generation_number: 0 },
      value: stream,
      start_offset: 0L,
      end_offset: 0L,
    }),
  )
  match indirect.value {
    Stream(parsed) => {
      assert_eq(parsed.data, b"abc")
      assert_eq(
        parsed.dict.get(@objects.PdfName::new(b"Length")) == Some(Integer(3L)),
        true,
      )
    }
    _ => fail("expected parsed stream")
  }
  assert_eq(@writer.serialize_object(String(b"\x00\xff")), b"(\x00\xff)")
}

///|
test "writer creates a PDF that PdfDocument can open" {
  let bytes = @writer.create_pdf(@writer.text_content(b"Hello"))
  let document = @reader.PdfDocument::open(bytes)
  assert_eq(document.page_count(), 1)
  let page = document.page(0)
  assert_eq(page.content_instructions().length(), 5)
}

///|
test "writer creates a FlateDecode content stream PdfDocument can read" {
  let bytes = @writer.create_compressed_pdf(@writer.text_content(b"Compressed"))
  let document = @reader.PdfDocument::open(bytes)
  assert_eq(document.page_count(), 1)
  assert_eq(document.page(0).content_instructions().length(), 5)
}

///|
test "writer appends modified objects as an incremental update" {
  let original = @writer.create_pdf(@writer.text_content(b"Original"))
  let updated_page : @objects.PdfDictionary = Map::new()
  updated_page[@objects.PdfName::new(b"Type")] = Name(
    @objects.PdfName::new(b"Page"),
  )
  updated_page[@objects.PdfName::new(b"Parent")] = Ref(@objects.ObjectId::{
    object_number: 2,
    generation_number: 0,
  })
  updated_page[@objects.PdfName::new(b"MediaBox")] = Array([
    Integer(0L),
    Integer(0L),
    Integer(300L),
    Integer(400L),
  ])
  updated_page[@objects.PdfName::new(b"Resources")] = Dictionary(Map::new())
  let updated = @writer.append_incremental_update(original, [
    @objects.IndirectObject::{
      id: @objects.ObjectId::{ object_number: 3, generation_number: 0 },
      value: Dictionary(updated_page),
      start_offset: 0L,
      end_offset: 0L,
    },
  ])
  assert_eq(updated.has_prefix(original), true)
  assert_eq(updated.rev_find(b"/Prev") is Some(_), true)
  let document = @reader.PdfDocument::open(updated)
  assert_eq(document.page_count(), 1)
  match document.page(0).media_box() {
    Some(box) => {
      assert_eq(box.right, 300.0)
      assert_eq(box.top, 400.0)
    }
    None => fail("expected updated MediaBox")
  }
}
