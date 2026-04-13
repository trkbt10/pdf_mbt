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
test "apply_predictor leaves predictor 1 data unchanged" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(1L)
  raw[@objects.PdfName::new(b"Colors")] = @objects.PdfObject::Integer(3L)
  raw[@objects.PdfName::new(b"BitsPerComponent")] = @objects.PdfObject::Integer(
    8L,
  )
  raw[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(2L)
  let params = DecodeParams::{ raw: Some(raw) }
  let data = Bytes::from_array([
    b'\x10', b'\x20', b'\x30', b'\x40', b'\x50', b'\x60',
  ])

  let decoded : Result[Bytes, PdfFilterError] = try? apply_predictor(
    "FlateDecode", data, params,
  )
  match decoded {
    Ok(bytes) => assert_eq(bytes, data)
    _ => fail("expected predictor 1 to be a no-op")
  }
}

///|
test "apply_predictor leaves predictor 1 data unchanged when row geometry is invalid" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(1L)
  raw[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(0L)
  raw[@objects.PdfName::new(b"Colors")] = @objects.PdfObject::Integer(3L)
  raw[@objects.PdfName::new(b"BitsPerComponent")] = @objects.PdfObject::Integer(
    16L,
  )
  let params = DecodeParams::{ raw: Some(raw) }
  let data = Bytes::from_array([b'\x10', b'\x20', b'\x30', b'\x40'])

  let decoded : Result[Bytes, PdfFilterError] = try? apply_predictor(
    "FlateDecode", data, params,
  )
  match decoded {
    Ok(bytes) => assert_eq(bytes, data)
    _ => fail("expected predictor 1 to ignore invalid row geometry")
  }
}

///|
test "apply_predictor reconstructs TIFF rows for single-color data" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(2L)
  raw[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(4L)
  let params = DecodeParams::{ raw: Some(raw) }
  let data = Bytes::from_array([
    b'\x0a', b'\x14', b'\x1e', b'\x28', b'\x01', b'\x01', b'\x01', b'\x01',
  ])

  let decoded : Result[Bytes, PdfFilterError] = try? apply_predictor(
    "FlateDecode", data, params,
  )
  match decoded {
    Ok(bytes) =>
      assert_eq(
        bytes,
        Bytes::from_array([
          b'\x0a', b'\x1e', b'<', b'd', b'\x01', b'\x02', b'\x03', b'\x04',
        ]),
      )
    _ => fail("expected TIFF predictor to reconstruct single-color rows")
  }
}

///|
test "apply_predictor reconstructs TIFF rows for packed 1-bit data" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(2L)
  raw[@objects.PdfName::new(b"BitsPerComponent")] = @objects.PdfObject::Integer(
    1L,
  )
  raw[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(8L)
  let params = DecodeParams::{ raw: Some(raw) }
  let data = Bytes::from_array([b'\xaa'])

  let result : Result[Bytes, PdfFilterError] = try? apply_predictor(
    "FlateDecode", data, params,
  )
  match result {
    Ok(bytes) => assert_eq(bytes, Bytes::from_array([b'\xcc']))
    _ => fail("expected packed 1-bit TIFF predictor reconstruction")
  }
}

///|
test "apply_predictor reconstructs TIFF rows for packed 2-bit data" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(2L)
  raw[@objects.PdfName::new(b"BitsPerComponent")] = @objects.PdfObject::Integer(
    2L,
  )
  raw[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(4L)
  let params = DecodeParams::{ raw: Some(raw) }
  let data = Bytes::from_array([b'D'])

  let result : Result[Bytes, PdfFilterError] = try? apply_predictor(
    "FlateDecode", data, params,
  )
  match result {
    Ok(bytes) => assert_eq(bytes, Bytes::from_array([b'Z']))
    _ => fail("expected packed 2-bit TIFF predictor reconstruction")
  }
}

///|
test "apply_predictor reconstructs TIFF rows for packed 4-bit data" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(2L)
  raw[@objects.PdfName::new(b"BitsPerComponent")] = @objects.PdfObject::Integer(
    4L,
  )
  raw[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(2L)
  let params = DecodeParams::{ raw: Some(raw) }
  let data = Bytes::from_array([b'\x1f'])

  let result : Result[Bytes, PdfFilterError] = try? apply_predictor(
    "FlateDecode", data, params,
  )
  match result {
    Ok(bytes) => assert_eq(bytes, Bytes::from_array([b'\x10']))
    _ => fail("expected packed 4-bit TIFF predictor reconstruction")
  }
}

///|
test "apply_predictor reconstructs TIFF rows for 16-bit data" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(2L)
  raw[@objects.PdfName::new(b"BitsPerComponent")] = @objects.PdfObject::Integer(
    16L,
  )
  raw[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(2L)
  let params = DecodeParams::{ raw: Some(raw) }
  let data = Bytes::from_array([b'\x01', b'\x02', b'\x00', b'\xff'])

  let result : Result[Bytes, PdfFilterError] = try? apply_predictor(
    "FlateDecode", data, params,
  )
  match result {
    Ok(bytes) =>
      assert_eq(bytes, Bytes::from_array([b'\x01', b'\x02', b'\x02', b'\x01']))
    _ => fail("expected 16-bit TIFF predictor reconstruction")
  }
}

///|
test "apply_predictor rejects unsupported bits per component" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(2L)
  raw[@objects.PdfName::new(b"BitsPerComponent")] = @objects.PdfObject::Integer(
    3L,
  )
  let params = DecodeParams::{ raw: Some(raw) }
  let data = Bytes::from_array([b'\x00'])

  let result : Result[Bytes, PdfFilterError] = try? apply_predictor(
    "FlateDecode", data, params,
  )
  match result {
    Err(InvalidDecodeParms(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("BitsPerComponent"), true)
    }
    _ => fail("expected invalid bits per component to be rejected")
  }
}

///|
test "apply_predictor reconstructs TIFF rows for multi-color data" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(2L)
  raw[@objects.PdfName::new(b"Colors")] = @objects.PdfObject::Integer(3L)
  raw[@objects.PdfName::new(b"BitsPerComponent")] = @objects.PdfObject::Integer(
    8L,
  )
  raw[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(2L)
  let params = DecodeParams::{ raw: Some(raw) }
  let data = Bytes::from_array([
    b'\x01', b'\x02', b'\x03', b'\x04', b'\x05', b'\x06', b'\x01', b'\x01', b'\x01',
    b'\x01', b'\x01', b'\x01',
  ])

  let result : Result[Bytes, PdfFilterError] = try? apply_predictor(
    "FlateDecode", data, params,
  )
  match result {
    Ok(bytes) =>
      assert_eq(
        bytes,
        Bytes::from_array([
          b'\x01', b'\x02', b'\x03', b'\x05', b'\x07', b'\t', b'\x01', b'\x01', b'\x01',
          b'\x02', b'\x02', b'\x02',
        ]),
      )
    _ => fail("expected TIFF predictor to reconstruct multi-color rows")
  }
}

///|
test "apply_predictor rejects incomplete TIFF rows" {
  let raw : @objects.PdfDictionary = Map::new()
  raw[@objects.PdfName::new(b"Predictor")] = @objects.PdfObject::Integer(2L)
  raw[@objects.PdfName::new(b"Columns")] = @objects.PdfObject::Integer(2L)
  let params = DecodeParams::{ raw: Some(raw) }
  let data = Bytes::from_array([b'\x01', b'\x02', b'\x03'])

  let result : Result[Bytes, PdfFilterError] = try? apply_predictor(
    "FlateDecode", data, params,
  )
  match result {
    Err(DecodeError(filter_name, reason)) => {
      assert_eq(filter_name, "FlateDecode")
      assert_eq(reason.contains("row"), true)
    }
    _ => fail("expected incomplete TIFF row data to be rejected")
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
