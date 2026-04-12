///|
test "byte source rebases pdf offsets from the header percent byte" {
  let input = b"abc%PDF-2.0\r\nbody"
  let source = ByteSource::new(input, 3L)

  assert_eq(source.physical_offset(0L), 3L)
  assert_eq(source.slice_from_pdf_offset(0L), b"%PDF-2.0\r\nbody")
  assert_eq(source.slice_range(3L, 10L), b"%PDF-2.0\r\n")
}

///|
test "byte source rejects negative and out-of-range offsets before slicing" {
  let source = ByteSource::new(b"abc%PDF-2.0\r\nbody", 3L)

  let negative_physical : Result[Int64, PdfReaderError] = try? source.physical_offset(
    -1L,
  )
  match negative_physical {
    Err(InvalidXref(offset, reason)) => {
      assert_eq(offset, -1L)
      assert_eq(reason.contains("non-negative"), true)
    }
    _ => fail("expected negative pdf offset to fail")
  }

  let out_of_range_slice : Result[Bytes, PdfReaderError] = try? source.slice_from_pdf_offset(
    99L,
  )
  match out_of_range_slice {
    Err(InvalidXref(offset, reason)) => {
      assert_eq(offset, 102L)
      assert_eq(reason.contains("buffer"), true)
    }
    _ => fail("expected out-of-range pdf offset to fail")
  }

  let invalid_range : Result[Bytes, PdfReaderError] = try? source.slice_range(
    16L, 2L,
  )
  match invalid_range {
    Err(InvalidXref(offset, reason)) => {
      assert_eq(offset, 16L)
      assert_eq(reason.contains("buffer"), true)
    }
    _ => fail("expected out-of-range physical slice to fail")
  }
}

///|
test "byte source rejects oversized slice lengths before byte slicing" {
  let source = ByteSource::new(b"abc%PDF-2.0\r\nbody", 3L)

  let oversized_slice : Result[Bytes, PdfReaderError] = try? source.slice_range(
    3L, 9223372036854775807L,
  )
  match oversized_slice {
    Err(InvalidXref(offset, reason)) => {
      assert_eq(offset, 3L)
      assert_eq(reason.contains("beyond"), true)
    }
    _ => fail("expected oversized slice length to fail")
  }
}
