///|
test "apply_predictor returns data unchanged for default predictor settings" {
  let params = DecodeParams::{ raw: None }
  let data = Bytes::from_array([b'\x10', b'\x20', b'\x30', b'\x40'])
  let decoded : Result[Bytes, PdfFilterError] = try? apply_predictor(
    "FlateDecode", data, params,
  )
  match decoded {
    Ok(bytes) => assert_eq(bytes, data)
    _ => fail("expected default predictor settings to be a no-op")
  }
}

///|
test "apply_predictor reports decode error for predictor 2" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(2L)
  let params = DecodeParams::{ raw: Some(raw) }
  let data = Bytes::from_array([b'\x10', b'\x20', b'\x30', b'\x40'])

  let result : Result[Bytes, PdfFilterError] = try? apply_predictor(
    "FlateDecode", data, params,
  )
  match result {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("Predictor"), true)
    }
    Err(UnsupportedFilter(filter_name)) =>
      fail(
        "expected DecodeError for predictor 2, got UnsupportedFilter(" +
        filter_name +
        ")",
      )
    _ => fail("expected predictor 2 to report a filter-specific decode error")
  }
}

///|
test "predictor context applies defaults and rounds row width" {
  let params = DecodeParams::{ raw: None }
  let context = params.predictor_context("FlateDecode")

  assert_eq(context.predictor, 1)
  assert_eq(context.colors, 1)
  assert_eq(context.bits_per_component, 8)
  assert_eq(context.columns, 1)
  assert_eq(context.row_bytes, 1)
}

///|
test "predictor context rounds row width from colors bits and columns" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"Colors")] = @objects.PdfObject::Integer(3L)
  raw[@objects.PdfName::new(b"BitsPerComponent")] = @objects.PdfObject::Integer(
    1L,
  )
  raw[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(10L)
  let params = DecodeParams::{ raw: Some(raw) }

  let context = params.predictor_context("FlateDecode")
  assert_eq(context.row_bytes, 4)
}

///|
test "predictor context rejects unsupported predictor values" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(9L)
  let params = DecodeParams::{ raw: Some(raw) }

  let result : Result[PredictorContext, PdfFilterError] = try? params.predictor_context(
    "FlateDecode",
  )
  match result {
    Err(InvalidDecodeParms(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("Predictor"), true)
    }
    _ => fail("expected unsupported predictor to be rejected")
  }
}

///|
test "predictor context rejects non-positive row parameters" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(0L)
  let params = DecodeParams::{ raw: Some(raw) }

  let result : Result[PredictorContext, PdfFilterError] = try? params.predictor_context(
    "FlateDecode",
  )
  match result {
    Err(InvalidDecodeParms(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("Columns"), true)
    }
    _ => fail("expected invalid row parameters to be rejected")
  }
}
