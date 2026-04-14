///|
test "extension parser accepts minimal single-prefix dictionary" {
  let object = @parser.parse_object(
    b"<< /Type /Extensions /GLGR << /BaseVersion /1.7 /ExtensionLevel 1002 >> >>",
  )
  let extensions = parse_extensions_dictionary(
    object,
    extension_test_context(PdfVersion::{ major: 2, minor: 0 }, None),
  )
  let entry = expect_extension_prefix(extensions, b"GLGR")
  assert_eq(entry.prefix == extension_key(b"GLGR"), true)
  assert_eq(entry.raw_value is @objects.PdfObject::Dictionary(_), true)
  assert_eq(extensions.raw_dict.get(extension_key(b"GLGR")) is Some(_), true)
  assert_eq(entry.developers.length(), 1)
  assert_eq(
    entry.developers[0].base_version == PdfVersion::{ major: 1, minor: 7 },
    true,
  )
  assert_eq(entry.developers[0].extension_level, 1002)
  assert_eq(
    entry.developers[0].raw_dict.get(extension_key(b"BaseVersion")) is Some(_),
    true,
  )
}

///|
test "extension parser accepts pdf20 arrays and preserves ordered developer data" {
  let object = @parser.parse_object(
    b"<< /Type /Extensions /ISO_ [" +
    b"<< /Type /DeveloperExtensions /BaseVersion /2.0 /ExtensionLevel 24064 /URL (https://www.iso.org/standard/77686.html) >>" +
    b"<< /Type /DeveloperExtensions /BaseVersion /2.0 /ExtensionLevel 24654 /URL (https://www.iso.org/standard/79150.html) /ExtensionRevision (2020) >>" +
    b"] >>",
  )
  let extensions = parse_extensions_dictionary(
    object,
    extension_test_context(PdfVersion::{ major: 2, minor: 0 }, None),
  )
  let entry = expect_extension_prefix(extensions, b"ISO_")
  assert_eq(entry.raw_value is @objects.PdfObject::Array(_), true)
  assert_eq(entry.developers.length(), 2)
  assert_eq(entry.developers[0].extension_level, 24064)
  assert_eq(entry.developers[1].extension_level, 24654)
  assert_eq(
    entry.developers[0].url == Some(b"https://www.iso.org/standard/77686.html"),
    true,
  )
  assert_eq(entry.developers[1].extension_revision == Some(b"2020"), true)
}

///|
test "extension parser rejects malformed structure and scalar types" {
  expect_invalid_extension(
    @parser.parse_object(
      b"<< /Type /Bad /GLGR << /BaseVersion /1.7 /ExtensionLevel 1002 >> >>",
    ),
    None,
    "Type",
  )
  expect_invalid_extension(
    @parser.parse_object(
      b"<< /GLGR << /Type /Bad /BaseVersion /1.7 /ExtensionLevel 1002 >> >>",
    ),
    Some(extension_key(b"GLGR")),
    "DeveloperExtensions",
  )
  expect_invalid_extension(
    @parser.parse_object(b"<< /GLGR << /ExtensionLevel 1002 >> >>"),
    Some(extension_key(b"GLGR")),
    "BaseVersion",
  )
  expect_invalid_extension(
    @parser.parse_object(b"<< /GLGR << /BaseVersion /1.7 >> >>"),
    Some(extension_key(b"GLGR")),
    "ExtensionLevel",
  )
  expect_invalid_extension(
    @parser.parse_object(
      b"<< /GLGR << /BaseVersion (1.7) /ExtensionLevel 1002 >> >>",
    ),
    Some(extension_key(b"GLGR")),
    "name",
  )
  expect_invalid_extension(
    @parser.parse_object(
      b"<< /GLGR << /BaseVersion /1.7 /ExtensionLevel /high >> >>",
    ),
    Some(extension_key(b"GLGR")),
    "integer",
  )
  expect_invalid_extension(
    @parser.parse_object(b"<< /GLGR /Bad >>"),
    Some(extension_key(b"GLGR")),
    "dictionary",
  )
  expect_invalid_extension(
    @parser.parse_object(b"<< /Type /Extensions >>"),
    None,
    "prefix",
  )
  expect_invalid_extension(
    @parser.parse_object(b"<< /GLGR [] >>"),
    Some(extension_key(b"GLGR")),
    "at least one",
  )
}

///|
test "extension parser rejects indirect extension tree values" {
  expect_invalid_extension(@objects.PdfObject::Ref(oid(8)), None, "direct")
  expect_invalid_extension(
    @parser.parse_object(b"<< /GLGR 8 0 R >>"),
    Some(extension_key(b"GLGR")),
    "direct",
  )
  expect_invalid_extension(
    @parser.parse_object(b"<< /GLGR [8 0 R] >>"),
    Some(extension_key(b"GLGR")),
    "direct",
  )
  expect_invalid_extension(
    @parser.parse_object(
      b"<< /GLGR << /BaseVersion 8 0 R /ExtensionLevel 1002 >> >>",
    ),
    Some(extension_key(b"GLGR")),
    "direct",
  )
  expect_invalid_extension(
    @parser.parse_object(
      b"<< /GLGR << /BaseVersion /1.7 /ExtensionLevel 8 0 R >> >>",
    ),
    Some(extension_key(b"GLGR")),
    "direct",
  )
  expect_invalid_extension(
    @parser.parse_object(
      b"<< /GLGR << /BaseVersion /1.7 /ExtensionLevel 1 /Private 8 0 R >> >>",
    ),
    Some(extension_key(b"GLGR")),
    "direct",
  )
}

///|
test "extension version policy compares integer tuples and gates pdf20 syntax" {
  let context = extension_test_context(PdfVersion::{ major: 2, minor: 0 }, None)
  let version = parse_extension_version_name(
    extension_key(b"1.10"),
    "test version",
    context,
    None,
  )
  assert_eq(version == PdfVersion::{ major: 1, minor: 10 }, true)
  assert_eq(
    compare_pdf_versions(PdfVersion::{ major: 1, minor: 10 }, PdfVersion::{
      major: 1,
      minor: 7,
    }) >
    0,
    true,
  )

  expect_invalid_extension(
    @parser.parse_object(
      b"<< /GLGR << /BaseVersion /2.0 /ExtensionLevel 1 >> >>",
    ),
    Some(extension_key(b"GLGR")),
    "header",
    context=extension_test_context(PdfVersion::{ major: 1, minor: 7 }, None),
  )
  expect_invalid_extension(
    @parser.parse_object(
      b"<< /GLGR << /BaseVersion /2.0 /ExtensionLevel 1 >> >>",
    ),
    Some(extension_key(b"GLGR")),
    "Catalog",
    context=extension_test_context(
      PdfVersion::{ major: 2, minor: 0 },
      Some(PdfVersion::{ major: 1, minor: 7 }),
    ),
  )
  expect_invalid_extension(
    @parser.parse_object(
      b"<< /GLGR [<< /BaseVersion /1.7 /ExtensionLevel 1 >>] >>",
    ),
    Some(extension_key(b"GLGR")),
    "PDF 2.0",
    context=extension_test_context(PdfVersion::{ major: 1, minor: 7 }, None),
  )
  expect_invalid_extension(
    @parser.parse_object(
      b"<< /GLGR << /BaseVersion /1.7 /ExtensionLevel 1 /ExtensionRevision (r1) >> >>",
    ),
    Some(extension_key(b"GLGR")),
    "PDF 2.0",
    context=extension_test_context(PdfVersion::{ major: 1, minor: 7 }, None),
  )
  expect_invalid_extension(
    @parser.parse_object(
      b"<< /GLGR [<< /BaseVersion /1.7 /ExtensionLevel 2 >><< /BaseVersion /1.7 /ExtensionLevel 1 >>] >>",
    ),
    Some(extension_key(b"GLGR")),
    "increase",
  )
}

///|
test "PdfDocument::extensions returns absence valid metadata and diagnostics" {
  let absent = PdfDocument::open(build_document_structure_single_page_fixture())
  assert_eq(absent.extensions() is None, true)

  let document = PdfDocument::open(
    build_extension_pdf20_fixture(
      b"/Version /2.0 /Extensions << /Type /Extensions /GLGR << /BaseVersion /1.7 /ExtensionLevel 1002 /URL (http://example.test/ext.pdf) >> >>",
    ),
  )
  match document.extensions() {
    Some(extensions) => {
      let entry = expect_extension_prefix(extensions, b"GLGR")
      assert_eq(entry.developers[0].extension_level, 1002)
      assert_eq(
        entry.developers[0].url == Some(b"http://example.test/ext.pdf"),
        true,
      )
    }
    None => fail("expected Catalog Extensions metadata")
  }
  assert_eq(document.page_count(), 1)
}

///|
test "PdfDocument::extensions enforces document version policy from catalog" {
  let header_too_old = PdfDocument::open(
    build_extension_pdf17_fixture(
      b"/Extensions << /GLGR << /BaseVersion /2.0 /ExtensionLevel 1 >> >>",
    ),
  )
  let header_result : Result[PdfExtensions?, PdfDocumentError] = try? header_too_old.extensions()
  match header_result {
    Err(InvalidExtension(object_id, prefix, reason)) => {
      assert_eq(object_id == Some(oid(1)), true)
      assert_eq(prefix == Some(extension_key(b"GLGR")), true)
      assert_eq(reason.contains("header"), true)
    }
    _ => fail("expected header version extension diagnostic")
  }

  let catalog_too_old = PdfDocument::open(
    build_extension_pdf20_fixture(
      b"/Version /1.7 /Extensions << /GLGR << /BaseVersion /2.0 /ExtensionLevel 1 >> >>",
    ),
  )
  let catalog_result : Result[PdfExtensions?, PdfDocumentError] = try? catalog_too_old.extensions()
  match catalog_result {
    Err(InvalidExtension(object_id, prefix, reason)) => {
      assert_eq(object_id == Some(oid(1)), true)
      assert_eq(prefix == Some(extension_key(b"GLGR")), true)
      assert_eq(reason.contains("Catalog"), true)
    }
    _ => fail("expected Catalog version extension diagnostic")
  }

  let indirect = PdfDocument::open(
    build_extension_pdf17_fixture(
      b"/Extensions 4 0 R",
      extra_object=Some(
        b"4 0 obj\n<< /GLGR << /BaseVersion /1.7 /ExtensionLevel 1 >> >>\nendobj\n",
      ),
    ),
  )
  let indirect_result : Result[PdfExtensions?, PdfDocumentError] = try? indirect.extensions()
  match indirect_result {
    Err(InvalidExtension(object_id, prefix, reason)) => {
      assert_eq(object_id == Some(oid(1)), true)
      assert_eq(prefix is None, true)
      assert_eq(reason.contains("direct"), true)
    }
    _ => fail("expected direct Extensions diagnostic")
  }
}

///|
fn extension_test_context(
  header_version : PdfVersion,
  catalog_version : PdfVersion?,
) -> ExtensionParseContext {
  ExtensionParseContext::{ catalog_id: oid(1), header_version, catalog_version }
}

///|
fn expect_extension_prefix(
  extensions : PdfExtensions,
  prefix_bytes : Bytes,
) -> PdfExtensionPrefixEntry raise {
  let prefix = extension_key(prefix_bytes)
  for entry in extensions.prefixes {
    if entry.prefix == prefix {
      return entry
    }
  }
  fail("missing expected extension prefix")
}

///|
fn expect_invalid_extension(
  object : @objects.PdfObject,
  expected_prefix : @objects.PdfName?,
  reason_fragment : String,
  context? : ExtensionParseContext = extension_test_context(
    PdfVersion::{ major: 2, minor: 0 },
    None,
  ),
) -> Unit raise {
  let result : Result[PdfExtensions, PdfDocumentError] = try? parse_extensions_dictionary(
    object, context,
  )
  match result {
    Err(InvalidExtension(object_id, prefix, reason)) => {
      assert_eq(object_id == Some(oid(1)), true)
      assert_eq(prefix == expected_prefix, true)
      assert_eq(reason.contains(reason_fragment), true)
    }
    _ => fail("expected InvalidExtension")
  }
}

///|
fn build_extension_pdf17_fixture(
  catalog_extra : Bytes,
  extra_object? : Bytes? = None,
) -> Bytes {
  build_extension_document_fixture(
    b"%PDF-1.7\r\n", catalog_extra, extra_object, false,
  )
}

///|
fn build_extension_pdf20_fixture(
  catalog_extra : Bytes,
  extra_object? : Bytes? = None,
) -> Bytes {
  build_extension_document_fixture(
    b"%PDF-2.0\r\n%\x80\x80\x80\x80\r\n", catalog_extra, extra_object, true,
  )
}

///|
fn build_extension_document_fixture(
  header : Bytes,
  catalog_extra : Bytes,
  extra_object : Bytes?,
  needs_id : Bool,
) -> Bytes {
  let prefix = b"garbage\n"
  let header_base = prefix.length().to_int64()
  let bytes = prefix + header
  let (bytes, catalog_offset) = append_indirect_object(
    bytes,
    header_base,
    1,
    0,
    b"<< /Type /Catalog /Pages 2 0 R " + catalog_extra + b" >>",
  )
  let (bytes, pages_offset) = append_indirect_object(
    bytes, header_base, 2, 0, b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let (bytes, page_offset) = append_indirect_object(
    bytes, header_base, 3, 0, b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] >>",
  )
  let mut bytes = bytes
  let mut object_count = 4
  let mut extra_offset = 0L
  match extra_object {
    Some(object_bytes) => {
      extra_offset = object_offset(bytes, header_base)
      bytes = bytes + object_bytes
      object_count = 5
    }
    None => ()
  }
  let xref_offset = object_offset(bytes, header_base)
  let mut xref = b"xref\r\n" +
    b"0 " +
    decimal_bytes(object_count.to_int64()) +
    b"\r\n" +
    xref_entry_line(0L, 65535, b'f') +
    xref_entry_line(catalog_offset, 0, b'n') +
    xref_entry_line(pages_offset, 0, b'n') +
    xref_entry_line(page_offset, 0, b'n')
  if object_count == 5 {
    xref = xref + xref_entry_line(extra_offset, 0, b'n')
  }
  let trailer = if needs_id {
    b"<< /Size " +
    decimal_bytes(object_count.to_int64()) +
    b" /Root 1 0 R /ID [(one) (two)] >>"
  } else {
    b"<< /Size " + decimal_bytes(object_count.to_int64()) + b" /Root 1 0 R >>"
  }
  bytes +
  xref +
  b"trailer\r\n" +
  trailer +
  b"\r\nstartxref\r\n" +
  decimal_bytes(xref_offset) +
  b"\r\n%%EOF\r\n"
}
