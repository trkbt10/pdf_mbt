///|
fn mm_obj_dict(dict : @objects.PdfDictionary) -> @objects.PdfObject {
  @objects.PdfObject::Dictionary(dict)
}

///|
fn mm_dict(
  entries : Array[(@objects.PdfName, @objects.PdfObject)],
) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  for entry in entries {
    let (key, value) = entry
    dict[key] = value
  }
  dict
}

///|
fn mm_name(bytes : Bytes) -> @objects.PdfObject {
  @objects.PdfObject::Name(multimedia_key(bytes))
}

///|
fn mm_string(bytes : Bytes) -> @objects.PdfObject {
  @objects.PdfObject::String(bytes)
}

///|
fn mm_int(value : Int) -> @objects.PdfObject {
  @objects.PdfObject::Integer(value.to_int64())
}

///|
fn mm_real(value : Double) -> @objects.PdfObject {
  @objects.PdfObject::Real(value)
}

///|
fn mm_array(values : Array[@objects.PdfObject]) -> @objects.PdfObject {
  @objects.PdfObject::Array(values)
}

///|
fn mm_file() -> PdfFile raise PdfReaderError {
  PdfFile::open(build_multimedia_common_fixture())
}

///|
test "framework parsers cover renditions clips defaults offsets and viability" {
  let file = mm_file()
  let clip = mm_obj_dict(
    mm_dict([
      (multimedia_key(b"Type"), mm_name(b"MediaClip")),
      (multimedia_key(b"S"), mm_name(b"MCD")),
      (multimedia_key(b"N"), mm_string(b"clip")),
      (multimedia_key(b"D"), mm_string(b"file.mov")),
      (multimedia_key(b"CT"), mm_string(b"video/mp4")),
      (multimedia_key(b"BU"), mm_string(b"https://example.invalid/")),
      (
        multimedia_key(b"P"),
        mm_obj_dict(mm_dict([(multimedia_key(b"TF"), mm_name(b"TEMPNEVER"))])),
      ),
    ]),
  )
  let play = mm_obj_dict(
    mm_dict([
      (multimedia_key(b"C"), @objects.PdfObject::Boolean(false)),
      (
        multimedia_key(b"D"),
        mm_obj_dict(
          mm_dict([
            (multimedia_key(b"S"), mm_name(b"T")),
            (multimedia_key(b"T"), mm_real(4.5)),
          ]),
        ),
      ),
      (multimedia_key(b"RC"), mm_int(2)),
      (multimedia_key(b"V"), mm_real(0.5)),
    ]),
  )
  let screen = mm_obj_dict(
    mm_dict([
      (multimedia_key(b"S"), mm_name(b"SW")),
      (multimedia_key(b"M"), mm_name(b"P")),
    ]),
  )
  let rendition = parse_rendition(
    file,
    mm_obj_dict(
      mm_dict([
        (multimedia_key(b"Type"), mm_name(b"Rendition")),
        (multimedia_key(b"S"), mm_name(b"MR")),
        (multimedia_key(b"N"), mm_string(b"main")),
        (multimedia_key(b"C"), clip),
        (multimedia_key(b"P"), play),
        (multimedia_key(b"SP"), screen),
      ]),
    ),
  )
  match rendition {
    Media(media) => {
      assert_eq(media.common.name == Some(b"main"), true)
      match media.media_clip {
        Some(clip) => {
          assert_eq(clip.kind == PdfMediaClipKind::Data, true)
          assert_eq(clip.content_type == Some(b"video/mp4"), true)
          match clip.permissions {
            Some(p) =>
              assert_eq(p.temp_file == PdfTempFilePermission::Never, true)
            None => fail("expected permissions")
          }
        }
        None => fail("expected media clip")
      }
      assert_eq(media.play_params.controls, false)
      assert_eq(
        media.play_params.duration == PdfMediaDuration::Seconds(4.5),
        true,
      )
      assert_eq(media.play_params.repeat, 2.0)
      assert_eq(
        media.screen_params.monitor == PdfMonitorSpecifier::Primary,
        true,
      )
    }
    _ => fail("expected media rendition")
  }

  let selector = parse_rendition(
    file,
    mm_obj_dict(
      mm_dict([
        (multimedia_key(b"Type"), mm_name(b"Rendition")),
        (multimedia_key(b"S"), mm_name(b"SR")),
        (
          multimedia_key(b"R"),
          mm_array([
            mm_obj_dict(
              mm_dict([
                (multimedia_key(b"Type"), mm_name(b"Rendition")),
                (multimedia_key(b"S"), mm_name(b"MR")),
              ]),
            ),
          ]),
        ),
      ]),
    ),
  )
  match selector {
    Selector(value) => assert_eq(value.renditions.length(), 1)
    _ => fail("expected selector")
  }
  let report = evaluate_rendition_viability(selector, None)
  assert_eq(
    report.decision ==
    PdfViabilityDecision::NonViable("no viable selector child"),
    true,
  )

  let offset = parse_media_offset(
    file,
    mm_obj_dict(
      mm_dict([
        (multimedia_key(b"S"), mm_name(b"F")),
        (multimedia_key(b"F"), mm_int(12)),
      ]),
    ),
    None,
  )
  assert_eq(offset == PdfMediaOffset::Frame(12), true)
  let bad : Result[PdfRendition, PdfDocumentError] = try? parse_rendition(
    file,
    mm_obj_dict(
      mm_dict([
        (multimedia_key(b"Type"), mm_name(b"Rendition")),
        (multimedia_key(b"S"), mm_name(b"Bad")),
      ]),
    ),
  )
  match bad {
    Err(InvalidMultimedia(_, reason)) => assert_eq(reason.contains("S"), true)
    _ => fail("expected invalid subtype")
  }
}

///|
test "player policy parser exposes software identity inputs" {
  let file = mm_file()
  let software = mm_obj_dict(
    mm_dict([
      (multimedia_key(b"U"), mm_string(b"vnd.adobe.swname:ADBE_Acrobat")),
      (multimedia_key(b"OS"), mm_array([mm_string(b"win")])),
      (multimedia_key(b"L"), mm_array([mm_int(1)])),
      (multimedia_key(b"H"), mm_array([])),
    ]),
  )
  let info = mm_obj_dict(
    mm_dict([(multimedia_key(b"PID"), mm_array([software]))]),
  )
  let policy = parse_media_player_policy(
    file,
    mm_obj_dict(mm_dict([(multimedia_key(b"MU"), mm_array([info]))])),
  )
  let player = PdfSoftwareIdentity::{
    name: b"ADBE_Acrobat",
    uri_scheme: Some(b"vnd.adobe.swname"),
    operating_system: Some(b"win"),
    version: PdfVersionArray::{ components: [2], is_infinite: false },
    content_types: [b"video/mp4"],
  }
  assert_eq(
    media_player_may_be_used(policy, player, Some(b"video/mp4")) ==
    PdfViabilityDecision::Viable,
    true,
  )
  let bad_version : Result[PdfSoftwareIdentifier, PdfDocumentError] = try? parse_software_identifier(
    file,
    mm_obj_dict(
      mm_dict([
        (multimedia_key(b"U"), mm_string(b"Player")),
        (multimedia_key(b"L"), mm_array([mm_int(-1)])),
      ]),
    ),
  )
  match bad_version {
    Err(InvalidMultimedia(_, reason)) =>
      assert_eq(reason.contains("negative"), true)
    _ => fail("expected negative version rejection")
  }
}

///|
test "legacy media parsers preserve sound movie and slideshow payloads" {
  let file = mm_file()
  let stream = @objects.PdfObject::Stream(@objects.PdfStream::{
    dict: mm_dict([
      (multimedia_key(b"R"), mm_real(44100.0)),
      (multimedia_key(b"C"), mm_int(2)),
      (multimedia_key(b"B"), mm_int(16)),
      (multimedia_key(b"E"), mm_name(b"Signed")),
      (multimedia_key(b"CO"), mm_name(b"FlateDecode")),
    ]),
    data: b"sound-data",
  })
  let sound = parse_sound_object(file, stream)
  assert_eq(sound.raw_stream.data == b"sound-data", true)
  assert_eq(sound.channels, 2)

  let movie = parse_movie_dictionary(
    file,
    mm_obj_dict(
      mm_dict([
        (multimedia_key(b"Type"), mm_name(b"Movie")),
        (multimedia_key(b"F"), mm_string(b"movie.mov")),
        (multimedia_key(b"Aspect"), mm_array([mm_int(16), mm_int(9)])),
        (
          multimedia_key(b"A"),
          mm_obj_dict(mm_dict([(multimedia_key(b"Mode"), mm_name(b"Repeat"))])),
        ),
      ]),
    ),
  )
  assert_eq(movie.aspect.length(), 2)
  match movie.activation {
    Some(activation) =>
      assert_eq(activation.mode == PdfMovieActivationMode::Repeat, true)
    None => fail("expected activation")
  }

  let slideshow = parse_slideshow(
    file,
    mm_obj_dict(
      mm_dict([
        (multimedia_key(b"Type"), mm_name(b"SlideShow")),
        (multimedia_key(b"Subtype"), mm_name(b"Embedded")),
        (multimedia_key(b"StartResource"), mm_string(b"start.swf")),
        (multimedia_key(b"Resources"), mm_obj_dict(Map::new())),
      ]),
    ),
  )
  assert_eq(slideshow.start_resource == b"start.swf", true)
}

///|
test "3D parsers expose streams views references annotations and diagnostics" {
  let file = mm_file()
  let view = mm_obj_dict(
    mm_dict([
      (multimedia_key(b"IN"), mm_string(b"front")),
      (
        multimedia_key(b"C2W"),
        mm_array([
          mm_int(1),
          mm_int(0),
          mm_int(0),
          mm_int(0),
          mm_int(0),
          mm_int(1),
          mm_int(0),
          mm_int(0),
          mm_int(0),
          mm_int(0),
          mm_int(1),
          mm_int(0),
        ]),
      ),
      (multimedia_key(b"CO"), mm_array([mm_int(0), mm_int(1), mm_int(2)])),
      (
        multimedia_key(b"P"),
        mm_obj_dict(mm_dict([(multimedia_key(b"Subtype"), mm_name(b"P"))])),
      ),
    ]),
  )
  let stream = @objects.PdfObject::Stream(@objects.PdfStream::{
    dict: mm_dict([
      (multimedia_key(b"Subtype"), mm_name(b"U3D")),
      (multimedia_key(b"VA"), mm_array([view])),
    ]),
    data: b"u3d",
  })
  let parsed = parse_three_d_stream(file, stream)
  assert_eq(parsed.subtype == Some(multimedia_key(b"U3D")), true)
  assert_eq(parsed.views.length(), 1)
  assert_eq(parsed.raw_stream.data == b"u3d", true)

  let annot = parse_three_d_annotation(
    file,
    mm_obj_dict(
      mm_dict([
        (multimedia_key(b"Subtype"), mm_name(b"3D")),
        (multimedia_key(b"3DD"), stream),
        (multimedia_key(b"3DV"), mm_string(b"front")),
      ]),
    ),
  )
  match annot {
    Some(value) =>
      assert_eq(value.default_view == Some(mm_string(b"front")), true)
    None => fail("expected 3D annotation")
  }
  let mismatch = parse_three_d_annotation(
    file,
    mm_obj_dict(mm_dict([(multimedia_key(b"Subtype"), mm_name(b"Text"))])),
  )
  assert_eq(mismatch is None, true)
}

///|
test "RichMedia parsers retain assets instances content views and state" {
  let file = mm_file()
  let params = mm_obj_dict(
    mm_dict([
      (multimedia_key(b"Binding"), mm_name(b"Foreground")),
      (multimedia_key(b"Data"), mm_string(b"opaque-state")),
    ]),
  )
  let instance = mm_obj_dict(
    mm_dict([
      (multimedia_key(b"Subtype"), mm_name(b"3D")),
      (multimedia_key(b"Asset"), mm_string(b"asset.u3d")),
      (multimedia_key(b"Params"), params),
    ]),
  )
  let config = mm_obj_dict(
    mm_dict([
      (multimedia_key(b"Subtype"), mm_name(b"3D")),
      (multimedia_key(b"Instances"), mm_array([instance])),
    ]),
  )
  let view = mm_obj_dict(
    mm_dict([
      (multimedia_key(b"Name"), mm_string(b"default")),
      (multimedia_key(b"Snapshot"), mm_string(b"snapshot-stream-ref")),
      (multimedia_key(b"Params"), params),
    ]),
  )
  let content = mm_obj_dict(
    mm_dict([
      (multimedia_key(b"Type"), mm_name(b"RichMediaContent")),
      (
        multimedia_key(b"Assets"),
        mm_obj_dict(
          mm_dict([
            (
              multimedia_key(b"Names"),
              mm_array([mm_string(b"asset.u3d"), mm_string(b"file-spec")]),
            ),
          ]),
        ),
      ),
      (multimedia_key(b"Configurations"), mm_array([config])),
      (multimedia_key(b"Views"), mm_array([view])),
    ]),
  )
  let annotation = parse_richmedia_annotation(
    file,
    mm_obj_dict(
      mm_dict([
        (multimedia_key(b"Subtype"), mm_name(b"RichMedia")),
        (multimedia_key(b"RichMediaContent"), content),
        (multimedia_key(b"RichMediaSettings"), mm_obj_dict(mm_dict([]))),
      ]),
    ),
  )
  match annotation {
    Some(rich) => {
      assert_eq(rich.content.assets.length(), 1)
      assert_eq(rich.content.assets[0].valid_name, true)
      assert_eq(rich.content.configurations[0].instances.length(), 1)
      assert_eq(
        rich.content.views[0].snapshot ==
        Some(mm_string(b"snapshot-stream-ref")),
        true,
      )
    }
    None => fail("expected RichMedia annotation")
  }
  let invalid_assets = parse_richmedia_assets(
    file,
    mm_array([mm_string(b"bad/name"), mm_string(b"file")]),
    None,
  )
  assert_eq(invalid_assets[0].valid_name, false)
}
