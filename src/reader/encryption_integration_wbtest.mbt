///|
fn synthetic_encrypted_file_id_hex() -> Bytes {
  b"73796e7468657469632d656e637279707465642d66697874757265"
}

///|
fn synthetic_standard_v4_encrypt_dict() -> Bytes {
  b"<< /Filter /Standard /V 4 /R 4 /Length 40 " +
  b"/O <50f9e8134ae59c50015f92c4c6765e93e655d728c5ea024a614b8ea765a58c78> " +
  b"/U <d608d153d4b5b3861c7a74a98ce437a828bf4e5e4e758a4164004e56fffa0108> " +
  b"/P -4 " +
  b"/CF << /StdCF << /CFM /V2 /Length 40 >> >> " +
  b"/StmF /StdCF /StrF /StdCF >>"
}

///|
fn synthetic_encrypted_stream_bytes() -> Bytes {
  Bytes::from_array([
    b'\x9f', b'\xb8', b'\xfd', b'\x02', b'\x7b', b'\x08', b'\x5d', b'\xe6', b'\xde',
    b'\xc7', b'\x07', b'\x68', b'\x4e', b'\x8c', b'\x96', b'\xc8', b'\xfa', b'\xf4',
    b'\xe6', b'\xf0', b'\x0e', b'\x42',
  ])
}

///|
fn synthetic_encrypted_object_stream_bytes() -> Bytes {
  Bytes::from_array([
    b'\x16', b'\x59', b'\x64', b'\x42', b'\x97', b'\xbe', b'\x83', b'\x02', b'\x91',
    b'\x06', b'\xbb', b'\xb5', b'\x5f', b'\x79', b'\x0e', b'\x5d', b'\xf6', b'\xb3',
    b'\x38',
  ])
}

///|
fn synthetic_trailer_id() -> Bytes {
  b" /ID [<" +
  synthetic_encrypted_file_id_hex() +
  b"> <" +
  synthetic_encrypted_file_id_hex() +
  b">]"
}

///|
fn build_synthetic_encrypted_table_fixture() -> Bytes {
  let prefix = b""
  let header = b"%PDF-1.7\r\n%\x80\x80\x80\x80\r\n"
  let header_base = prefix.length().to_int64()
  let bytes = prefix + header

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog /Pages 2 0 R >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /Contents 4 0 R >>",
  )
  let encrypted_stream = synthetic_encrypted_stream_bytes()
  let (bytes, content_offset) = append_indirect_object(
    bytes,
    header_base,
    4,
    0,
    build_stream_object_body(
      b"<< /Length " +
      decimal_bytes(encrypted_stream.length().to_int64()) +
      b" >>",
      encrypted_stream,
    ),
  )
  let (bytes, encrypt_offset) = append_indirect_object(
    bytes,
    header_base,
    5,
    0,
    synthetic_standard_v4_encrypt_dict(),
  )

  let xref_offset = object_offset(bytes, header_base)
  let bytes = bytes +
    b"xref\r\n" +
    b"0 6\r\n" +
    xref_entry_line(0L, 65535, b'f') +
    xref_entry_line(catalog_offset, 0, b'n') +
    xref_entry_line(pages_offset, 0, b'n') +
    xref_entry_line(page_offset, 0, b'n') +
    xref_entry_line(content_offset, 0, b'n') +
    xref_entry_line(encrypt_offset, 0, b'n') +
    b"trailer\r\n" +
    b"<< /Size 6 /Root 1 0 R /Encrypt 5 0 R" +
    synthetic_trailer_id() +
    b" >>\r\n" +
    b"startxref\r\n" +
    decimal_bytes(xref_offset) +
    b"\r\n%%EOF\r\n"
  bytes
}

///|
fn build_synthetic_encrypted_xref_stream_fixture() -> Bytes {
  let prefix = b""
  let header = b"%PDF-1.7\r\n%\x80\x80\x80\x80\r\n"
  let header_base = prefix.length().to_int64()
  let bytes = prefix + header

  let (bytes, catalog_offset) = append_indirect_object(
    bytes, header_base, 1, 0, b"<< /Type /Catalog >>",
  )
  let (bytes, encrypt_offset) = append_indirect_object(
    bytes,
    header_base,
    5,
    0,
    synthetic_standard_v4_encrypt_dict(),
  )
  let encrypted_object_stream = synthetic_encrypted_object_stream_bytes()
  let (bytes, object_stream_offset) = append_indirect_object(
    bytes,
    header_base,
    6,
    0,
    build_stream_object_body(
      b"<< /Type /ObjStm /N 1 /First 4 /Length " +
      decimal_bytes(encrypted_object_stream.length().to_int64()) +
      b" >>",
      encrypted_object_stream,
    ),
  )

  let xref_stream_offset = object_offset(bytes, header_base)
  let xref_stream_data = xref_stream_entry_bytes(1, catalog_offset.to_int(), 0) +
    xref_stream_entry_bytes(1, encrypt_offset.to_int(), 0) +
    xref_stream_entry_bytes(1, object_stream_offset.to_int(), 0) +
    xref_stream_entry_bytes(2, 6, 0) +
    xref_stream_entry_bytes(1, xref_stream_offset.to_int(), 0)
  let xref_stream_body = build_stream_object_body(
    b"<< /Type /XRef /Size 9 /Index [1 1 5 4] /W [1 2 2] " +
    b"/Root 1 0 R /Encrypt 5 0 R" +
    synthetic_trailer_id() +
    b" /Length " +
    decimal_bytes(xref_stream_data.length().to_int64()) +
    b" >>",
    xref_stream_data,
  )
  let (bytes, _) = append_indirect_object(
    bytes, header_base, 8, 0, xref_stream_body,
  )

  bytes +
  b"startxref\r\n" +
  decimal_bytes(xref_stream_offset) +
  b"\r\n%%EOF\r\n"
}

///|
test "PdfFile::open authenticates empty password and decrypts encrypted stream objects" {
  let file = PdfFile::open(build_synthetic_encrypted_table_fixture())
  let stream_id = @objects.ObjectId::{ object_number: 4, generation_number: 0 }

  assert_eq(file.is_encrypted(), true)
  match file.load_object(stream_id) {
    @objects.PdfObject::Stream(stream) =>
      assert_eq(stream.data, b"Hello encrypted stream")
    _ => fail("expected decrypted stream")
  }
}

///|
test "PdfFile::open handles Encrypt trailer entries in xref streams and encrypted object streams" {
  let file = PdfFile::open(build_synthetic_encrypted_xref_stream_fixture())
  let member_id = @objects.ObjectId::{ object_number: 7, generation_number: 0 }

  assert_eq(file.is_encrypted(), true)
  match file.load_object(member_id) {
    @objects.PdfObject::String(value) => assert_eq(value, b"Secret member")
    _ => fail("expected decrypted object stream member")
  }
}
