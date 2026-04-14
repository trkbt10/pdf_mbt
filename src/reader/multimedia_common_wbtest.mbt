///|
test "multimedia common resolves dictionaries streams and MH BE policy" {
  let file = PdfFile::open(build_multimedia_common_fixture())
  let payload = resolve_multimedia_dictionary(
    file,
    multimedia_fixture_ref(4),
    "rendition dictionary",
  )
  assert_eq(payload.object_id == Some(oid(4)), true)
  require_multimedia_name_equals(
    payload.raw_dict,
    multimedia_key(b"Type"),
    multimedia_key(b"Rendition"),
    payload.object_id,
    "Type",
  )
  require_multimedia_name_equals(
    payload.raw_dict,
    multimedia_key(b"S"),
    multimedia_key(b"MR"),
    payload.object_id,
    "S",
  )
  assert_eq(
    multimedia_optional_string(
      payload.raw_dict,
      multimedia_key(b"N"),
      payload.object_id,
      "N",
    ) ==
    Some(b"clip"),
    true,
  )
  assert_eq(
    payload.raw_dict.get(multimedia_key(b"Z")) ==
    Some(@objects.PdfObject::String(b"opaque")),
    true,
  )

  let policy = parse_multimedia_mh_be_policy(
    file,
    payload.raw_dict,
    payload.object_id,
  )
  match policy.must_honor {
    Some(dict) =>
      assert_eq(
        dict.get(multimedia_key(b"C")) ==
        Some(@objects.PdfObject::Boolean(true)),
        true,
      )
    None => fail("expected MH dictionary")
  }
  match policy.best_effort {
    Some(dict) =>
      assert_eq(
        dict.get(multimedia_key(b"P")) ==
        Some(@objects.PdfObject::Boolean(true)),
        true,
      )
    None => fail("expected BE dictionary")
  }

  let stream = resolve_multimedia_stream(
    file,
    multimedia_fixture_ref(6),
    "media payload",
  )
  assert_eq(stream.object_id == Some(oid(6)), true)
  assert_eq(stream.raw_stream.data == b"media-data", true)

  match resolve_multimedia_payload(file, multimedia_fixture_ref(6), "payload") {
    PdfMultimediaPayload::Stream(raw_stream) =>
      assert_eq(raw_stream.raw_stream.data == b"media-data", true)
    _ => fail("expected raw stream payload")
  }
  match
    resolve_multimedia_payload(
      file,
      @objects.PdfObject::String(b"opaque-bytes"),
      "payload",
    ) {
    PdfMultimediaPayload::ByteString(raw_bytes) =>
      assert_eq(raw_bytes.bytes == b"opaque-bytes", true)
    _ => fail("expected byte-string payload")
  }
}

///|
test "multimedia common reports deterministic multimedia diagnostics" {
  let file = PdfFile::open(build_multimedia_common_fixture())

  let bad_required = resolve_multimedia_dictionary(
    file,
    multimedia_fixture_ref(11),
    "rendition dictionary",
  )
  let subtype_result : Result[Unit, PdfDocumentError] = try? require_multimedia_name_equals(
    bad_required.raw_dict,
    multimedia_key(b"S"),
    multimedia_key(b"MR"),
    bad_required.object_id,
    "S",
  )
  match subtype_result {
    Err(InvalidMultimedia(object_id, reason)) => {
      assert_eq(object_id == Some(oid(11)), true)
      assert_eq(reason == "S must be a name", true)
    }
    _ => fail("expected InvalidMultimedia for malformed required subtype")
  }

  let bad_policy = resolve_multimedia_dictionary(
    file,
    multimedia_fixture_ref(7),
    "rendition dictionary",
  )
  let policy_result : Result[PdfMhBePolicy, PdfDocumentError] = try? parse_multimedia_mh_be_policy(
    file,
    bad_policy.raw_dict,
    bad_policy.object_id,
  )
  match policy_result {
    Err(InvalidMultimedia(object_id, reason)) => {
      assert_eq(object_id == Some(oid(7)), true)
      assert_eq(reason == "MH must be a dictionary", true)
    }
    _ => fail("expected InvalidMultimedia for malformed MH dictionary")
  }

  let cycle_result : Result[PdfRawDictionaryPayload, PdfDocumentError] = try? resolve_multimedia_dictionary(
    file,
    multimedia_fixture_ref(8),
    "rendition dictionary",
  )
  match cycle_result {
    Err(InvalidMultimedia(object_id, reason)) => {
      assert_eq(object_id == Some(oid(8)), true)
      assert_eq(reason.contains("cycle"), true)
    }
    _ => fail("expected InvalidMultimedia cycle diagnostic")
  }
}

///|
test "multimedia fixtures build reusable clause 13 shells" {
  let dict = multimedia_fixture_dictionary()
  assert_eq(dict.length(), 0)

  let action = multimedia_fixture_rendition_action_payload(
    multimedia_fixture_ref(4),
    multimedia_fixture_ref(9),
  )
  let annotation = multimedia_fixture_annotation_shell(
    multimedia_key(b"Screen"),
    Some(@objects.PdfObject::Dictionary(action)),
  )
  assert_eq(
    annotation.get(multimedia_key(b"Subtype")) ==
    Some(multimedia_fixture_name_object(b"Screen")),
    true,
  )
  assert_eq(annotation.get(multimedia_key(b"A")) is Some(_), true)

  let entry = multimedia_fixture_name_tree_entry(
    b"clip",
    multimedia_fixture_ref(4),
  )
  assert_eq(entry.key == b"clip", true)
  assert_eq(entry.value == multimedia_fixture_ref(4), true)

  let array = multimedia_fixture_array([
    multimedia_fixture_name_object(b"Rendition"),
    multimedia_fixture_ref(4),
  ])
  assert_eq(
    array ==
    @objects.PdfObject::Array([
      multimedia_fixture_name_object(b"Rendition"),
      multimedia_fixture_ref(4),
    ]),
    true,
  )

  let stream_dict = multimedia_fixture_dictionary()
  stream_dict[multimedia_key(b"Type")] = multimedia_fixture_name_object(
    b"EmbeddedFile",
  )
  let stream = multimedia_fixture_stream(stream_dict, b"payload")
  assert_eq(stream.data == b"payload", true)
  assert_eq(
    stream.dict.get(multimedia_key(b"Type")) ==
    Some(multimedia_fixture_name_object(b"EmbeddedFile")),
    true,
  )
}

///|
test "multimedia common parses vector and matrix shapes" {
  let defaults = multimedia_fixture_dictionary()
  assert_eq(
    multimedia_optional_bool_default(
      defaults,
      multimedia_key(b"C"),
      Some(oid(20)),
      "C",
      true,
    ),
    true,
  )
  assert_eq(
    multimedia_optional_number_default(
      defaults,
      multimedia_key(b"RC"),
      Some(oid(20)),
      "RC",
      1.0,
    ),
    1.0,
  )
  assert_eq(
    multimedia_number_in_range(
      @objects.PdfObject::Real(0.5),
      Some(oid(20)),
      "V",
      -1.0,
      1.0,
    ),
    0.5,
  )

  let vector = parse_multimedia_vector(
    multimedia_fixture_array([
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::Real(2.5),
      @objects.PdfObject::Integer(3L),
    ]),
    Some(oid(20)),
    "CO",
  )
  assert_eq(vector == PdfThreeDVector::{ x: 1.0, y: 2.5, z: 3.0 }, true)

  let matrix = parse_multimedia_matrix(
    multimedia_fixture_array([
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::Integer(0L),
      @objects.PdfObject::Integer(0L),
      @objects.PdfObject::Integer(0L),
      @objects.PdfObject::Integer(0L),
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::Integer(0L),
      @objects.PdfObject::Integer(0L),
      @objects.PdfObject::Integer(0L),
      @objects.PdfObject::Integer(0L),
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::Integer(0L),
    ]),
    Some(oid(20)),
    "C2W",
  )
  assert_eq(matrix.values.length(), 12)

  let bad_vector : Result[PdfThreeDVector, PdfDocumentError] = try? parse_multimedia_vector(
    multimedia_fixture_array([
      @objects.PdfObject::Integer(1L),
      @objects.PdfObject::Integer(2L),
    ]),
    Some(oid(20)),
    "CO",
  )
  match bad_vector {
    Err(InvalidMultimedia(object_id, reason)) => {
      assert_eq(object_id == Some(oid(20)), true)
      assert_eq(reason == "CO has invalid length", true)
    }
    _ => fail("expected InvalidMultimedia for malformed vector")
  }

  let bad_range : Result[Double, PdfDocumentError] = try? multimedia_number_in_range(
    @objects.PdfObject::Real(2.0),
    Some(oid(20)),
    "V",
    -1.0,
    1.0,
  )
  match bad_range {
    Err(InvalidMultimedia(object_id, reason)) => {
      assert_eq(object_id == Some(oid(20)), true)
      assert_eq(reason == "V is out of range", true)
    }
    _ => fail("expected InvalidMultimedia for out-of-range number")
  }
}
