///|
/// Clause 13 multimedia byte string payload retained from
/// spec/extracted/13-multimedia.spec.txt.
pub(all) struct PdfMultimediaByteString {
  bytes : Bytes
} derive(Eq, Debug)

///|
/// Clause 13 indirect object reference used by multimedia, 3D, and RichMedia
/// structures when a typed reader keeps a raw hand-off edge.
pub(all) struct PdfMultimediaObjectReference {
  object_id : @objects.ObjectId
} derive(Eq, Debug)

///|
/// Forward-compatible unknown name with the dictionary context that made the
/// multimedia value unrecognized or only partially recognized.
pub(all) struct PdfMultimediaUnknownName {
  name : @objects.PdfName
  context : Bytes?
} derive(Eq, Debug)

///|
/// Raw dictionary payload retained for clause 13 dictionaries whose media,
/// script, U3D, PRC, ECMAScript, or state data is not decoded by the reader.
pub(all) struct PdfRawDictionaryPayload {
  object_id : @objects.ObjectId?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Raw stream payload retained for embedded files, Sound streams, 3D streams,
/// snapshots, scripts, and other opaque clause 13 stream data.
pub(all) struct PdfRawStreamPayload {
  object_id : @objects.ObjectId?
  raw_stream : @objects.PdfStream
} derive(Eq, Debug)

///|
/// Opaque multimedia payload carrier for object, byte-string, dictionary,
/// stream, and reference values preserved without playback or decoding.
pub(all) enum PdfMultimediaPayload {
  Object(@objects.PdfObject)
  ByteString(PdfMultimediaByteString)
  Reference(PdfMultimediaObjectReference)
  Dictionary(PdfRawDictionaryPayload)
  Stream(PdfRawStreamPayload)
} derive(Eq, Debug)

///|
/// 13.2.2 Viability MH and BE policy dictionaries. `must_honor` models MH
/// requirements; `best_effort` models BE options and defaults.
pub(all) struct PdfMhBePolicy {
  must_honor : @objects.PdfDictionary?
  best_effort : @objects.PdfDictionary?
} derive(Eq, Debug)

///|
/// Viability decision for clause 13 media objects: viable, non-viable, or
/// unknown when a caller has not supplied enough viewer environment data.
pub(all) enum PdfViabilityDecision {
  Viable
  NonViable(String)
  Unknown(String)
} derive(Eq, Debug)

///|
/// Entry-level trace for MH/BE and media criteria viability decisions.
pub(all) struct PdfViabilityTraceEntry {
  key : @objects.PdfName?
  decision : PdfViabilityDecision
  reason : String
} derive(Eq, Debug)

///|
/// Side-effect-free viability report for renditions, media clips, media play
/// parameters from Table 290, media screen parameters, players, and selector
/// choices.
pub(all) struct PdfViabilityReport {
  decision : PdfViabilityDecision
  trace : Array[PdfViabilityTraceEntry]
} derive(Eq, Debug)

///|
/// 13.2.3.1 Table 277 common rendition dictionary entries: Type Rendition,
/// subtype S, optional name N, and MH/BE Table 278 media criteria policy.
pub(all) struct PdfRenditionCommon {
  object_id : @objects.ObjectId?
  name : Bytes?
  must_honor_best_effort : PdfMhBePolicy
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.2.3 rendition object: media rendition MR, selector rendition SR, or an
/// unknown subtype retained for forward-compatible diagnostics. Media
/// renditions carry C/P/SP relationships, MH/BE viability, and Table 290 play
/// parameters through the typed media variant.
pub(all) enum PdfRendition {
  Media(PdfMediaRendition)
  Selector(PdfSelectorRendition)
  Unknown(PdfUnknownRendition)
} derive(Eq, Debug)

///|
/// 13.2.3.2 Media renditions, Table 282. It links C media clip, P media
/// play parameters from Table 290, and SP media screen parameters from
/// Table 293.
pub(all) struct PdfMediaRendition {
  common : PdfRenditionCommon
  media_clip : PdfMediaClip?
  play_params : PdfMediaPlayParams
  screen_params : PdfMediaScreenParams
} derive(Eq, Debug)

///|
/// 13.2.3.3 selector rendition, Table 283. `renditions` preserves the ordered
/// R array used for depth-first first-viable media rendition selection.
pub(all) struct PdfSelectorRendition {
  common : PdfRenditionCommon
  renditions : Array[PdfRendition]
} derive(Eq, Debug)

///|
/// Unknown rendition subtype whose raw common dictionary is retained because
/// the S name is not MR or SR.
pub(all) struct PdfUnknownRendition {
  common : PdfRenditionCommon
  subtype : @objects.PdfName
} derive(Eq, Debug)

///|
/// 13.2.3.1 Table 279 media criteria dictionary. Entries capture accessibility
/// preferences, bandwidth, bit depth, screen size, software IDs, PDF version
/// range, and language identifiers used to decide rendition viability.
pub(all) struct PdfMediaCriteria {
  audio_descriptions : Bool?
  captions : Bool?
  overdubs : Bool?
  subtitles : Bool?
  bandwidth_bits_per_second : Int?
  minimum_bit_depth : PdfMinimumBitDepth?
  minimum_screen_size : PdfMinimumScreenSize?
  software_identifiers : Array[PdfSoftwareIdentifier]
  pdf_versions : Array[@objects.PdfName]
  languages : Array[Bytes]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.2.3.1 Table 280 minimum bit depth dictionary, including monitor
/// specifier values from Table 304.
pub(all) struct PdfMinimumBitDepth {
  value : Int
  monitor : PdfMonitorSpecifier
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.2.3.1 Table 281 minimum screen size dictionary, including width, height,
/// and monitor specifier values from Table 304.
pub(all) struct PdfMinimumScreenSize {
  width : Int
  height : Int
  monitor : PdfMonitorSpecifier
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.2.4.1 Table 284 media clip subtype: MCD media clip data, MCS media clip
/// section, or an unknown name retained for non-viable reporting.
pub(all) enum PdfMediaClipKind {
  Data
  Section
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
/// 13.2.4.2 Table 286 temporary file permission TF values: TEMPALWAYS,
/// TEMPEXTRACT, TEMPNEVER, TEMPACCESS, or an unknown value.
pub(all) enum PdfTempFilePermission {
  Always
  Extract
  Never
  TempAccess
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
/// 13.2.4.2 media permissions dictionary, Table 286. It records TF temporary
/// file policy without writing files or enforcing document permissions.
pub(all) struct PdfMediaPermissions {
  temp_file : PdfTempFilePermission
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.2.6.2 media offset dictionary, Tables 296, 297, 298, and 299. Time
/// offsets use Table 300 timespan dictionary seconds; frame offsets start at 0; marker
/// offsets keep text string names.
pub(all) enum PdfMediaOffset {
  Time(Double)
  Frame(Int)
  Marker(Bytes)
  Raw(@objects.PdfObject)
} derive(Eq, Debug)

///|
/// 13.2.5 Table 292 media duration dictionary: intrinsic I, infinity F,
/// explicit T Table 300 timespan dictionary seconds, or raw future subtype data.
pub(all) enum PdfMediaDuration {
  Intrinsic
  Infinite
  Seconds(Double)
  Raw(@objects.PdfObject)
} derive(Eq, Debug)

///|
/// 13.2.6.3 timespan dictionary, Table 300, and section offsets. `begin`
/// and `end` carry Table 289 B/E media clip section boundaries when present.
pub(all) struct PdfTimespan {
  subtype : @objects.PdfName
  begin : PdfMediaOffset?
  end : PdfMediaOffset?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.2.4 media clip dictionary. It covers 13.2.4.1 common entries, 13.2.4.2
/// media clip data with D, CT, P, Alt, PL, MH/BE, BU base URL, and 13.2.4.3
/// media clip section data with next-level clip and B/E offsets that may use
/// Table 300 timespan dictionaries.
pub(all) struct PdfMediaClip {
  object_id : @objects.ObjectId?
  kind : PdfMediaClipKind
  name : Bytes?
  data : @objects.PdfObject?
  permissions : PdfMediaPermissions?
  content_type : Bytes?
  base_url : Bytes?
  section : PdfTimespan?
  must_honor_best_effort : PdfMhBePolicy
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.2.5 media play parameters dictionary, Table 290 and Table 291. Controls
/// include controller UI C, media duration D, repeat count RC, and volume V.
pub(all) struct PdfMediaPlayParams {
  object_id : @objects.ObjectId?
  controls : Bool
  duration : PdfMediaDuration
  repeat : Double
  volume : Double
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.2.7.5 Table 304 monitor specifier values: document largest/smallest
/// section, primary monitor, greatest colour depth, greatest area, greatest
/// height, greatest width, or an unknown extension name.
pub(all) enum PdfMonitorSpecifier {
  Largest
  Smallest
  Primary
  Monitor(Int)
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
/// 13.2.6.1 floating window parameters dictionary, Table 295, retained raw
/// for D, RT, P, O, T, UC, R, and TT screen placement options.
pub(all) struct PdfFloatingWindowParams {
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.2.6.1 media screen parameters dictionary, Tables 293, 294, and 295.
/// It records W window placement, B background, O opacity, M monitor, and F
/// floating window parameters without displaying media.
pub(all) struct PdfMediaScreenParams {
  object_id : @objects.ObjectId?
  subtype : @objects.PdfName?
  monitor : PdfMonitorSpecifier
  floating_window : PdfFloatingWindowParams?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.2.7.4.4 version array with non-negative subversion components and an
/// empty-array infinity marker for version comparisons.
pub(all) struct PdfVersionArray {
  components : Array[Int]
  is_infinite : Bool
} derive(Eq, Debug)

///|
/// 13.2.7.4.3 software URI. The defined scheme is vnd.adobe.swname, and the
/// escaped software name is compared case-sensitively after URI handling.
pub(all) struct PdfSoftwareNameUri {
  scheme : Bytes?
  name : Bytes
  raw : Bytes
} derive(Eq, Debug)

///|
/// 13.2.7.4.1 Table 303 software identifier dictionary. It preserves U URI
/// names, L/H version arrays, LI/HI inclusivity defaults, OS identifiers, and
/// raw entries for partially recognized contexts.
pub(all) struct PdfSoftwareIdentifier {
  names : Array[PdfSoftwareNameUri]
  operating_systems : Array[Bytes]
  lower_version : PdfVersionArray?
  upper_version : PdfVersionArray?
  lower_inclusive : Bool
  upper_inclusive : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Caller-supplied software identity for 13.2.7.4 matching and 13.2.7.2 media
/// player eligibility. No installed-player or OS inventory lookup is performed.
pub(all) struct PdfSoftwareIdentity {
  name : Bytes
  uri_scheme : Bytes?
  operating_system : Bytes?
  version : PdfVersionArray
  content_types : Array[Bytes]
} derive(Eq, Debug)

///|
/// 13.2.7.3 Table 302 media player info dictionary with 4 entries. PID
/// points to the 13.2.7.4 software identifier dictionary for player versions
/// and operating systems; MH/BE dictionaries have no currently defined
/// entries but are retained for viability reporting.
pub(all) struct PdfMediaPlayerInfo {
  software_identifiers : Array[PdfSoftwareIdentifier]
  must_honor_best_effort : PdfMhBePolicy
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.2.7.2 Table 301 media players dictionary. MU is `must_use`, A is
/// `allowed`, and NU is `not_allowed` for the media player algorithm.
pub(all) struct PdfMediaPlayerPolicy {
  must_use : Array[PdfMediaPlayerInfo]
  allowed : Array[PdfMediaPlayerInfo]
  not_allowed : Array[PdfMediaPlayerInfo]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.3 Sound object, Table 305. Deprecated in PDF 2.0 and superseded by
/// RichMedia; this model keeps sampling rate R, channels C, bits B, encoding
/// E, compression CO, and the raw stream without playing audio.
pub(all) struct PdfSoundObject {
  object_id : @objects.ObjectId?
  sampling_rate : Double
  channels : Int
  bits_per_sample : Int
  encoding : @objects.PdfName
  compression : @objects.PdfName?
  raw_stream : @objects.PdfStream
} derive(Eq, Debug)

///|
/// 13.4 Table 307 movie activation Mode names: Once, Open, Repeat,
/// Palindrome, or unknown extension names.
pub(all) enum PdfMovieActivationMode {
  Once
  Open
  Repeat
  Palindrome
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
/// 13.4 movie activation dictionary, Table 307. It keeps Start, Duration,
/// Rate, Volume, and Mode while leaving playback, controller UI, and floating
/// window behavior to callers.
pub(all) struct PdfMovieActivation {
  start : @objects.PdfObject?
  duration : @objects.PdfObject?
  rate : Double
  volume : Double
  mode : PdfMovieActivationMode
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.4 movie dictionary, Table 306. Deprecated in PDF 2.0; it stores F file
/// specification, Aspect, Rotate, Poster, and activation metadata raw enough
/// for inspection without locating or playing a movie file.
pub(all) struct PdfMovieDictionary {
  object_id : @objects.ObjectId?
  file_specification : @objects.PdfObject
  aspect : Array[Int]
  rotation : Int
  poster : @objects.PdfObject?
  activation : PdfMovieActivation?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.5 Alternate presentations name-tree entry that pairs a name with a
/// SlideShow dictionary from Table 308.
pub(all) struct PdfAlternatePresentation {
  name : Bytes
  slideshow : PdfSlideShow
  raw_value : @objects.PdfObject
} derive(Eq, Debug)

///|
/// 13.5 Table 308 slideshow dictionary: Type SlideShow, Subtype Embedded,
/// Resources name tree, and StartResource byte string for alternate
/// presentations. No slideshow JavaScript or media runtime is executed.
pub(all) struct PdfSlideShow {
  object_id : @objects.ObjectId?
  start_resource : Bytes
  resources : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.6.5 3D vector in world, artwork, or camera coordinates.
pub(all) struct PdfThreeDVector {
  x : Double
  y : Double
  z : Double
} derive(Eq, Debug)

///|
/// 13.6.5 12-number 3D transformation matrix used for camera-to-world,
/// artwork-to-world, and node transforms.
pub(all) struct PdfThreeDMatrix {
  values : Array[Double]
} derive(Eq, Debug)

///|
/// 13.6.2 Table 309 and 13.6.3.3 Table 314 artwork source: direct 3D stream,
/// 3DRef reference dictionary, or raw future value.
pub(all) enum PdfThreeDArtworkSource {
  Stream(PdfThreeDStream)
  Reference(PdfThreeDReference)
  Raw(@objects.PdfObject)
} derive(Eq, Debug)

///|
/// 13.6.1 and 13.6.2 3D annotation metadata, including Table 309 entries 3DD,
/// 3DV, 3DA activation from Table 310, 3DB view box, and 3DU units hand-off.
pub(all) struct PdfThreeDAnnotation {
  object_id : @objects.ObjectId?
  artwork : PdfThreeDArtworkSource
  default_view : @objects.PdfObject?
  activation : @objects.PdfDictionary?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.6.3.1 Table 311 3D stream. Subtype identifies U3D or PRC; VA views are
/// parsed structurally while U3D/PRC bytes remain opaque.
pub(all) struct PdfThreeDStream {
  object_id : @objects.ObjectId?
  subtype : @objects.PdfName?
  views : Array[PdfThreeDView]
  raw_stream : @objects.PdfStream
} derive(Eq, Debug)

///|
/// 13.6.3.3 Table 314 3D reference dictionary that shares a run-time artwork
/// instance by pointing to a 3D stream through 3DD.
pub(all) struct PdfThreeDReference {
  object_id : @objects.ObjectId?
  target : @objects.PdfObject
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.6.4.1 Table 315 3D view dictionary. It records external/internal names,
/// C2W camera-to-world matrix, CO center of orbit, projection P, and raw view
/// entries such as MA measurements, BG, RM, LS, SA, NA, and NR.
pub(all) struct PdfThreeDView {
  object_id : @objects.ObjectId?
  name : Bytes?
  camera_to_world : PdfThreeDMatrix?
  center_of_orbit : PdfThreeDVector?
  projection : PdfThreeDProjection?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.6.4.2 projection dictionary, Table 316, plus adjacent Table 317 3D
/// background references from views. The reader stores perspective P,
/// orthographic O, or unknown projection subtype data without projecting.
pub(all) enum PdfThreeDProjection {
  Perspective(@objects.PdfDictionary)
  Orthographic(@objects.PdfDictionary)
  Unknown(@objects.PdfName, @objects.PdfDictionary)
} derive(Eq, Debug)

///|
/// 13.6.7.2 Table 325 unit mapping "m model units = n real/display units".
pub(all) struct PdfThreeDUnitSpec {
  model_units : Double
  real_units : Double
  label : Bytes
} derive(Eq, Debug)

///|
/// 13.6.7.2 Table 325 3D units dictionary. Creation time, user override, and
/// display units are retained so callers can resolve measurement display
/// scaling without rendering or modifying the 3D annotation.
pub(all) struct PdfThreeDUnits {
  creation_time_units : PdfThreeDUnitSpec?
  user_override_units : PdfThreeDUnitSpec?
  display_units : PdfThreeDUnitSpec?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.6.7.3 Table 326 measurement subtype names: LD3, PD3, AD3, RD3, 3DC,
/// or an unknown PDF 2.0 extension.
pub(all) enum PdfThreeDMeasurementKind {
  LinearDimension
  PerpendicularDimension
  AngularDimension
  RadialDimension
  CommentNote
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
/// 13.6.7.3 Tables 326 through 331 3D measurement/markup dictionary. It
/// preserves common geometry points, direction vectors, value/unit text,
/// precision, projection annotation comment reference, and raw subtype data.
pub(all) struct PdfThreeDMeasurement {
  object_id : @objects.ObjectId?
  kind : PdfThreeDMeasurementKind
  name : Bytes?
  annotation_plane : PdfThreeDVector?
  anchors : Array[PdfThreeDVector]
  leader_directions : Array[PdfThreeDVector]
  text_anchor : PdfThreeDVector?
  text_x_direction : PdfThreeDVector?
  text_y_direction : PdfThreeDVector?
  value : Double?
  units : Bytes?
  precision : Int?
  projection_annotation : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.6.6 Table 324 Markup3D ExData dictionary linking markup annotations to
/// a 3D annotation, a 3D view, and optional MD5 checksum bytes.
pub(all) struct PdfThreeDMarkupExternalData {
  annotation : @objects.PdfObject
  view : @objects.PdfObject
  md5 : Bytes?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.6.7.4 Table 332 3DM ExData dictionary linking a projection annotation
/// back to a 3D measurement dictionary through M3DREF.
pub(all) struct PdfThreeDMeasurementExternalData {
  measurement : @objects.PdfObject
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.7.2.1 Table 333 RichMedia annotation. It connects required
/// RichMediaContent and optional RichMediaSettings dictionaries while the
/// normal appearance stream remains the compatibility display.
pub(all) struct PdfRichMediaAnnotation {
  object_id : @objects.ObjectId?
  content : PdfRichMediaContent
  settings : PdfRichMediaSettings
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.7.2.2.1 Table 334 RichMediaSettings dictionary. Activation and
/// Deactivation are currently retained raw; typed RichMediaActivation and
/// RichMediaDeactivation models document the same vocabulary for explicit
/// parser work.
pub(all) struct PdfRichMediaSettings {
  object_id : @objects.ObjectId?
  activation : @objects.PdfDictionary?
  deactivation : @objects.PdfDictionary?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.7.2.2.2 Table 335 RichMediaActivation dictionary. It records activation
/// Condition, Animation, View, Configuration, Presentation, and Scripts
/// references without executing ECMAScript or runtime events.
pub(all) struct PdfRichMediaActivation {
  condition : @objects.PdfName
  animation : PdfRichMediaAnimation?
  view : @objects.PdfObject?
  configuration : @objects.PdfObject?
  presentation : PdfRichMediaPresentation?
  scripts : Array[@objects.PdfObject]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.7.2.2.3 Table 336 RichMediaDeactivation dictionary. It keeps the
/// Condition name XD, PC, PI, or an extension value without unloading media.
pub(all) struct PdfRichMediaDeactivation {
  condition : @objects.PdfName
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.7.2.2.4 Table 337 RichMediaAnimation dictionary. It stores Subtype,
/// PlayCount, and Speed preferences for keyframe animation without driving a
/// timeline.
pub(all) struct PdfRichMediaAnimation {
  subtype : @objects.PdfName
  play_count : Int
  speed : Double
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.7.2.2.5 Table 338 RichMediaPresentation dictionary. It records Embedded
/// or Windowed style, transparency, navigation pane, toolbar, context-click,
/// and optional RichMediaWindow layout data.
pub(all) struct PdfRichMediaPresentation {
  style : @objects.PdfName
  window : PdfRichMediaWindow?
  transparent : Bool
  navigation_pane : Bool
  toolbar : Bool?
  pass_context_click : Bool
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.7.2.2.6 Table 339 RichMediaWindow size interval in default user space.
pub(all) struct PdfRichMediaWindowDimension {
  default_value : Double
  min : Double
  max : Double
} derive(Eq, Debug)

///|
/// 13.7.2.2.6 Table 340 RichMediaPosition dictionary. HAlign and VAlign use
/// Near, Center, and Far with default offsets in the presentation area.
pub(all) struct PdfRichMediaPosition {
  horizontal_align : @objects.PdfName
  vertical_align : @objects.PdfName
  horizontal_offset : Double
  vertical_offset : Double
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.7.2.2.6 Table 339 RichMediaWindow dictionary for non-printing
/// Windowed presentation layout.
pub(all) struct PdfRichMediaWindow {
  width : PdfRichMediaWindowDimension
  height : PdfRichMediaWindowDimension
  position : PdfRichMediaPosition?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.7.2.3.1 Table 341 RichMediaContent dictionary. Assets, Configurations,
/// and Views are preserved structurally so shared content can be reused by
/// multiple annotations.
pub(all) struct PdfRichMediaContent {
  object_id : @objects.ObjectId?
  assets : Array[PdfRichMediaAsset]
  configurations : Array[PdfRichMediaConfiguration]
  views : Array[PdfRichMediaView]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.7.2.3.2 assets name tree entry. It preserves the file name and
/// file-specification reference plus validation status for F/UF and relative
/// URI filename restrictions.
pub(all) struct PdfRichMediaAsset {
  name : Bytes
  file_specification : @objects.PdfObject
  valid_name : Bool
} derive(Eq, Debug)

///|
/// 13.7.2.3.3 Table 342 RichMediaConfiguration dictionary. Subtype may be 3D,
/// Sound, Video, or absent, and Instances retain RichMediaInstance entries.
pub(all) struct PdfRichMediaConfiguration {
  object_id : @objects.ObjectId?
  subtype : @objects.PdfName?
  instances : Array[PdfRichMediaInstance]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.7.2.3.4 Table 343 RichMediaInstance dictionary. It binds a required
/// Asset reference and optional View Params to a content subtype.
pub(all) struct PdfRichMediaInstance {
  object_id : @objects.ObjectId?
  subtype : @objects.PdfName?
  asset : @objects.PdfObject?
  params : PdfRichMediaViewParams?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.7.2.3.5 Table 344 extended 3D view dictionary for RichMedia. Snapshot
/// and Params are retained without replacing active artwork or invoking media.
pub(all) struct PdfRichMediaView {
  object_id : @objects.ObjectId?
  name : Bytes?
  params : PdfRichMediaViewParams?
  snapshot : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// 13.7.2.3.6.1 Table 345 View Params dictionary. Instance links to a
/// RichMediaInstance and Data stores opaque state used by 13.7.2.3.6.2 saving
/// state data and 13.7.2.3.6.3 loading state data.
pub(all) struct PdfRichMediaViewParams {
  object_id : @objects.ObjectId?
  binding : @objects.PdfName?
  data : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Typed annotation-level clause 13 union for Sound, Movie, 3D, RichMedia, or
/// raw dictionaries when a subtype is intentionally left opaque.
pub(all) enum PdfMultimediaAnnotation {
  Sound(PdfSoundObject)
  Movie(PdfMovieDictionary)
  ThreeD(PdfThreeDAnnotation)
  RichMedia(PdfRichMediaAnnotation)
  Raw(PdfRawDictionaryPayload)
} derive(Eq, Debug)

///|
/// Typed clause 13 object union for renditions, media clips, legacy media, 3D
/// streams, RichMedia content, and raw dictionary or stream payloads.
pub(all) enum PdfMultimediaObject {
  Rendition(PdfRendition)
  MediaClip(PdfMediaClip)
  Sound(PdfSoundObject)
  Movie(PdfMovieDictionary)
  ThreeDStream(PdfThreeDStream)
  RichMediaContent(PdfRichMediaContent)
  RawDictionary(PdfRawDictionaryPayload)
  RawStream(PdfRawStreamPayload)
} derive(Eq, Debug)
