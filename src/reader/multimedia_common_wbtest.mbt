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

///|
test "multimedia public models cover clause 13 alignment vocabulary" {
  let dict : @objects.PdfDictionary = Map::new()
  let policy = PdfMhBePolicy::{ must_honor: None, best_effort: Some(dict) }
  let version = PdfVersionArray::{ components: [1, 2, 0], is_infinite: false }
  let infinity = PdfVersionArray::{ components: [], is_infinite: true }
  let uri = PdfSoftwareNameUri::{
    scheme: Some(b"vnd.adobe.swname"),
    name: b"ADBE_Acrobat",
    raw: b"vnd.adobe.swname:ADBE_Acrobat",
  }
  let identifier = PdfSoftwareIdentifier::{
    names: [uri],
    operating_systems: [b"win"],
    lower_version: Some(version),
    upper_version: Some(infinity),
    lower_inclusive: true,
    upper_inclusive: true,
    raw_dict: dict,
  }
  let player = PdfMediaPlayerInfo::{
    software_identifiers: [identifier],
    must_honor_best_effort: policy,
    raw_dict: dict,
  }
  let criteria = PdfMediaCriteria::{
    audio_descriptions: Some(true),
    captions: Some(false),
    overdubs: None,
    subtitles: Some(true),
    bandwidth_bits_per_second: Some(128000),
    minimum_bit_depth: Some(PdfMinimumBitDepth::{
      value: 24,
      monitor: PdfMonitorSpecifier::Primary,
      raw_dict: dict,
    }),
    minimum_screen_size: Some(PdfMinimumScreenSize::{
      width: 1920,
      height: 1080,
      monitor: PdfMonitorSpecifier::Monitor(4),
      raw_dict: dict,
    }),
    software_identifiers: player.software_identifiers,
    pdf_versions: [multimedia_key(b"2.0")],
    languages: [b"en-US"],
    raw_dict: dict,
  }
  assert_eq(criteria.bandwidth_bits_per_second == Some(128000), true)
  match criteria.minimum_screen_size {
    Some(size) => assert_eq(size.height, 1080)
    None => fail("expected minimum screen size")
  }

  let units = PdfThreeDUnits::{
    creation_time_units: Some(PdfThreeDUnitSpec::{
      model_units: 1.0,
      real_units: 1.0,
      label: b"mm",
    }),
    user_override_units: None,
    display_units: Some(PdfThreeDUnitSpec::{
      model_units: 1.0,
      real_units: 10.0,
      label: b"cm",
    }),
    raw_dict: dict,
  }
  match units.display_units {
    Some(display) => assert_eq(display.label == b"cm", true)
    None => fail("expected display units")
  }

  let measurement = PdfThreeDMeasurement::{
    object_id: Some(oid(80)),
    kind: PdfThreeDMeasurementKind::LinearDimension,
    name: Some(b"Measurement 1"),
    annotation_plane: Some(PdfThreeDVector::{ x: 0.0, y: 0.0, z: 1.0 }),
    anchors: [
      PdfThreeDVector::{ x: 0.0, y: 0.0, z: 0.0 },
      PdfThreeDVector::{ x: 1.0, y: 0.0, z: 0.0 },
    ],
    leader_directions: [],
    text_anchor: Some(PdfThreeDVector::{ x: 0.5, y: 0.2, z: 0.0 }),
    text_x_direction: None,
    text_y_direction: Some(PdfThreeDVector::{ x: 0.0, y: 1.0, z: 0.0 }),
    value: Some(1.0),
    units: Some(b"cm"),
    precision: Some(3),
    projection_annotation: Some(@objects.PdfObject::Ref(oid(90))),
    raw_dict: dict,
  }
  assert_eq(measurement.anchors.length(), 2)
  let markup = PdfThreeDMarkupExternalData::{
    annotation: @objects.PdfObject::Ref(oid(81)),
    view: @objects.PdfObject::Ref(oid(82)),
    md5: Some(b"1234567890123456"),
    raw_dict: dict,
  }
  match markup.md5 {
    Some(md5) => assert_eq(md5.length(), 16)
    None => fail("expected md5")
  }
  let projection = PdfThreeDMeasurementExternalData::{
    measurement: @objects.PdfObject::Ref(oid(80)),
    raw_dict: dict,
  }
  assert_eq(projection.measurement == @objects.PdfObject::Ref(oid(80)), true)

  let position = PdfRichMediaPosition::{
    horizontal_align: multimedia_key(b"Far"),
    vertical_align: multimedia_key(b"Near"),
    horizontal_offset: 18.0,
    vertical_offset: 18.0,
    raw_dict: dict,
  }
  let window = PdfRichMediaWindow::{
    width: PdfRichMediaWindowDimension::{
      default_value: 288.0,
      min: 72.0,
      max: 576.0,
    },
    height: PdfRichMediaWindowDimension::{
      default_value: 216.0,
      min: 72.0,
      max: 432.0,
    },
    position: Some(position),
    raw_dict: dict,
  }
  let animation = PdfRichMediaAnimation::{
    subtype: multimedia_key(b"Linear"),
    play_count: -1,
    speed: 1.0,
    raw_dict: dict,
  }
  let presentation = PdfRichMediaPresentation::{
    style: multimedia_key(b"Windowed"),
    window: Some(window),
    transparent: false,
    navigation_pane: false,
    toolbar: Some(false),
    pass_context_click: false,
    raw_dict: dict,
  }
  let activation = PdfRichMediaActivation::{
    condition: multimedia_key(b"XA"),
    animation: Some(animation),
    view: Some(@objects.PdfObject::Ref(oid(83))),
    configuration: Some(@objects.PdfObject::Ref(oid(84))),
    presentation: Some(presentation),
    scripts: [@objects.PdfObject::Ref(oid(85))],
    raw_dict: dict,
  }
  assert_eq(activation.scripts.length(), 1)
  let deactivation = PdfRichMediaDeactivation::{
    condition: multimedia_key(b"XD"),
    raw_dict: dict,
  }
  assert_eq(deactivation.condition == multimedia_key(b"XD"), true)
}

///|
test "media player policy follows software identifier and player algorithms" {
  let dict : @objects.PdfDictionary = Map::new()
  let uri = PdfSoftwareNameUri::{
    scheme: Some(b"vnd.adobe.swname"),
    name: b"ADBE_Acrobat",
    raw: b"vnd.adobe.swname:ADBE_Acrobat",
  }
  let identifier = PdfSoftwareIdentifier::{
    names: [uri],
    operating_systems: [b"win"],
    lower_version: Some(PdfVersionArray::{ components: [1], is_infinite: false }),
    upper_version: Some(PdfVersionArray::{ components: [5], is_infinite: false }),
    lower_inclusive: true,
    upper_inclusive: false,
    raw_dict: dict,
  }
  let player = PdfSoftwareIdentity::{
    name: b"ADBE_Acrobat",
    uri_scheme: Some(b"VND.ADOBE.SWNAME"),
    operating_system: Some(b"win"),
    version: PdfVersionArray::{ components: [4, 2], is_infinite: false },
    content_types: [b"video/mp4"],
  }
  assert_eq(software_identifier_matches(identifier, player) == Viable, true)
  assert_eq(
    compare_version_arrays(
      PdfVersionArray::{ components: [5], is_infinite: false },
      PdfVersionArray::{ components: [5, 0, 0], is_infinite: false },
    ),
    0,
  )
  assert_eq(
    compare_version_arrays(
      PdfVersionArray::{ components: [], is_infinite: true },
      PdfVersionArray::{ components: [999], is_infinite: false },
    ),
    1,
  )

  let info = PdfMediaPlayerInfo::{
    software_identifiers: [identifier],
    must_honor_best_effort: PdfMhBePolicy::{
      must_honor: None,
      best_effort: None,
    },
    raw_dict: dict,
  }
  let allowed_policy = PdfMediaPlayerPolicy::{
    must_use: [info],
    allowed: [],
    not_allowed: [],
    raw_dict: dict,
  }
  assert_eq(
    media_player_may_be_used(allowed_policy, player, Some(b"video/mp4")) ==
    Viable,
    true,
  )
  assert_eq(
    media_player_may_be_used(allowed_policy, player, Some(b"audio/wav")) ==
    NonViable("player does not support content type"),
    true,
  )

  let blocked_policy = PdfMediaPlayerPolicy::{
    must_use: [],
    allowed: [info],
    not_allowed: [info],
    raw_dict: dict,
  }
  assert_eq(
    media_player_may_be_used(blocked_policy, player, None) ==
    NonViable("player is in NU"),
    true,
  )
}
