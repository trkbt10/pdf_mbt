///|
fn file_spec_path_bytes(values : Array[Byte]) -> Bytes {
  Bytes::from_array(values)
}

///|
test "file specification paths preserve components and escaped solidus" {
  let path = parse_file_spec_path(
    file_spec_path_bytes([
      b'i', b'n', b'\\', b'/', b'o', b'u', b't', b'/', b'n', b'e', b'x', b't',
    ]),
  )
  assert_eq(path.absolute, false)
  assert_eq(path.components.length(), 2)
  assert_eq(path.components[0], b"in/out")
  assert_eq(path.components[1], b"next")

  let absolute = parse_file_spec_path(b"/root//file/")
  assert_eq(absolute.absolute, true)
  assert_eq(absolute.components.length(), 5)
  assert_eq(absolute.components[0], b"")
  assert_eq(absolute.components[2], b"")
  assert_eq(absolute.components[4], b"")
}

///|
test "file specification relative resolution normalizes parent components" {
  let base = parse_file_spec_path(
    b"/HardDisk/PDFDocuments/AnnualReport/Summary.pdf",
  )
  let relative = parse_file_spec_path(b"../../ArtFiles/Figure1.pdf")
  let resolved = resolve_file_spec_path(base, relative)
  assert_eq(resolved.absolute, true)
  assert_eq(resolved.raw, b"/HardDisk/ArtFiles/Figure1.pdf")

  let bad : Result[PdfFileSpecPath, PdfDocumentError] = try? resolve_file_spec_path(
    base,
    parse_file_spec_path(b"/absolute.pdf"),
  )
  match bad {
    Err(InvalidFileSpecification(_, reason)) =>
      assert_eq(reason.contains("relative"), true)
    _ => fail("expected absolute relative path rejection")
  }
}

///|
test "file specification URL helper escapes bytes and rejects non-path input" {
  let raw = file_spec_path_bytes([
    b'd', b'i', b'r', b' ', b'n', b'a', b'm', b'e', b'/', b'\xe3', b'\x81', b'\x82',
    b'.', b'p', b'd', b'f',
  ])
  let resolved = resolve_file_spec_url_path(
    b"https://example.test/a/b/base.pdf",
    parse_file_spec_path(raw),
  )
  assert_eq(resolved, b"https://example.test/a/b/dir%20name/%E3%81%82.pdf")

  let parent = resolve_file_spec_url_path(
    b"https://example.test/a/b/base.pdf",
    parse_file_spec_path(b"../c.pdf"),
  )
  assert_eq(parent, b"https://example.test/a/c.pdf")

  let bad_query : Result[Bytes, PdfDocumentError] = try? resolve_file_spec_url_path(
    b"https://example.test/base.pdf",
    parse_file_spec_path(b"file.pdf?download=1"),
  )
  match bad_query {
    Err(InvalidFileSpecification(_, reason)) =>
      assert_eq(reason.contains("query"), true)
    _ => fail("expected URL query rejection")
  }
}
