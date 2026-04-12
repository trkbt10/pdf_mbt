///|
fn build_minimal_open_fixture() -> Bytes {
  b"garbage\n" +
  b"%PDF-1.7\r\n" +
  b"1 0 obj\n" +
  b"<< /Type /Catalog /Pages 2 0 R >>\n" +
  b"endobj\n" +
  b"xref\r\n" +
  b"0 2\r\n" +
  b"0000000000 65535 f\r\n" +
  b"0000000010 00000 n \n" +
  b"trailer\r\n" +
  b"<< /Size 2 /Root 1 0 R >>\r\n" +
  b"startxref\r\n" +
  b"59\r\n" +
  b"%%EOF\r\n"
}

///|
test "PdfFile::open exposes version trailer root and lazy object loading" {
  let file = PdfFile::open(build_minimal_open_fixture())
  let trailer = file.trailer()
  let root_ref = file.root_ref()

  assert_eq(file.version() == PdfVersion::{ major: 1, minor: 7 }, true)
  assert_eq(trailer.size, 2)
  assert_eq(trailer.root == root_ref, true)
  assert_eq(
    root_ref == @objects.ObjectId::{ object_number: 1, generation_number: 0 },
    true,
  )

  let root_object = file.load_object(root_ref)
  let root_again = file.load_object(root_ref)
  match root_object {
    @objects.PdfObject::Dictionary(dict) => {
      assert_eq(
        dict.get(@objects.PdfName::new(b"Type")) ==
        Some(@objects.PdfObject::Name(@objects.PdfName::new(b"Catalog"))),
        true,
      )
      assert_eq(
        dict.get(@objects.PdfName::new(b"Pages")) ==
        Some(
          @objects.PdfObject::Ref(@objects.ObjectId::{
            object_number: 2,
            generation_number: 0,
          }),
        ),
        true,
      )
    }
    _ => fail("expected catalog dictionary")
  }
  assert_eq(root_again == root_object, true)

  let missing = file.load_object(@objects.ObjectId::{
    object_number: 99,
    generation_number: 0,
  })
  assert_eq(missing == @objects.PdfObject::Null, true)
}
