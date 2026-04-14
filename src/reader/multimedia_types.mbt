///|
pub(all) struct PdfMultimediaByteString {
  bytes : Bytes
} derive(Eq, Debug)

///|
pub(all) struct PdfMultimediaObjectReference {
  object_id : @objects.ObjectId
} derive(Eq, Debug)

///|
pub(all) struct PdfMultimediaUnknownName {
  name : @objects.PdfName
  context : Bytes?
} derive(Eq, Debug)

///|
pub(all) struct PdfRawDictionaryPayload {
  object_id : @objects.ObjectId?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfRawStreamPayload {
  object_id : @objects.ObjectId?
  raw_stream : @objects.PdfStream
} derive(Eq, Debug)

///|
pub(all) enum PdfMultimediaPayload {
  Object(@objects.PdfObject)
  ByteString(PdfMultimediaByteString)
  Reference(PdfMultimediaObjectReference)
  Dictionary(PdfRawDictionaryPayload)
  Stream(PdfRawStreamPayload)
} derive(Eq, Debug)

///|
pub(all) struct PdfMhBePolicy {
  must_honor : @objects.PdfDictionary?
  best_effort : @objects.PdfDictionary?
} derive(Eq, Debug)

///|
pub(all) enum PdfViabilityDecision {
  Viable
  NonViable(String)
  Unknown(String)
} derive(Eq, Debug)

///|
pub(all) struct PdfViabilityTraceEntry {
  key : @objects.PdfName?
  decision : PdfViabilityDecision
  reason : String
} derive(Eq, Debug)

///|
pub(all) struct PdfViabilityReport {
  decision : PdfViabilityDecision
  trace : Array[PdfViabilityTraceEntry]
} derive(Eq, Debug)

///|
pub(all) struct PdfRenditionCommon {
  object_id : @objects.ObjectId?
  name : Bytes?
  must_honor_best_effort : PdfMhBePolicy
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfRendition {
  Media(PdfMediaRendition)
  Selector(PdfSelectorRendition)
  Unknown(PdfUnknownRendition)
} derive(Eq, Debug)

///|
pub(all) struct PdfMediaRendition {
  common : PdfRenditionCommon
  media_clip : PdfMediaClip?
  play_params : PdfMediaPlayParams
  screen_params : PdfMediaScreenParams
} derive(Eq, Debug)

///|
pub(all) struct PdfSelectorRendition {
  common : PdfRenditionCommon
  renditions : Array[PdfRendition]
} derive(Eq, Debug)

///|
pub(all) struct PdfUnknownRendition {
  common : PdfRenditionCommon
  subtype : @objects.PdfName
} derive(Eq, Debug)

///|
pub(all) enum PdfMediaClipKind {
  Data
  Section
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) enum PdfTempFilePermission {
  Always
  Extract
  Never
  TempAccess
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) struct PdfMediaPermissions {
  temp_file : PdfTempFilePermission
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfMediaOffset {
  Time(Double)
  Frame(Int)
  Marker(Bytes)
  Raw(@objects.PdfObject)
} derive(Eq, Debug)

///|
pub(all) enum PdfMediaDuration {
  Intrinsic
  Infinite
  Seconds(Double)
  Raw(@objects.PdfObject)
} derive(Eq, Debug)

///|
pub(all) struct PdfTimespan {
  subtype : @objects.PdfName
  begin : PdfMediaOffset?
  end : PdfMediaOffset?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
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
pub(all) struct PdfMediaPlayParams {
  object_id : @objects.ObjectId?
  controls : Bool
  duration : PdfMediaDuration
  repeat : Double
  volume : Double
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfMonitorSpecifier {
  Largest
  Smallest
  Primary
  Monitor(Int)
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) struct PdfFloatingWindowParams {
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfMediaScreenParams {
  object_id : @objects.ObjectId?
  subtype : @objects.PdfName?
  monitor : PdfMonitorSpecifier
  floating_window : PdfFloatingWindowParams?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfVersionArray {
  components : Array[Int]
  is_infinite : Bool
} derive(Eq, Debug)

///|
pub(all) struct PdfSoftwareNameUri {
  scheme : Bytes?
  name : Bytes
  raw : Bytes
} derive(Eq, Debug)

///|
pub(all) struct PdfSoftwareIdentifier {
  names : Array[PdfSoftwareNameUri]
  operating_systems : Array[Bytes]
  lower_version : PdfVersionArray?
  upper_version : PdfVersionArray?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfSoftwareIdentity {
  name : Bytes
  uri_scheme : Bytes?
  operating_system : Bytes?
  version : PdfVersionArray
  content_types : Array[Bytes]
} derive(Eq, Debug)

///|
pub(all) struct PdfMediaPlayerInfo {
  software_identifiers : Array[PdfSoftwareIdentifier]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfMediaPlayerPolicy {
  must_use : Array[PdfMediaPlayerInfo]
  allowed : Array[PdfMediaPlayerInfo]
  not_allowed : Array[PdfMediaPlayerInfo]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
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
pub(all) enum PdfMovieActivationMode {
  Once
  Open
  Repeat
  Palindrome
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) struct PdfMovieActivation {
  start : @objects.PdfObject?
  duration : @objects.PdfObject?
  rate : Double
  volume : Double
  mode : PdfMovieActivationMode
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
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
pub(all) struct PdfAlternatePresentation {
  name : Bytes
  slideshow : PdfSlideShow
  raw_value : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfSlideShow {
  object_id : @objects.ObjectId?
  start_resource : Bytes
  resources : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfThreeDVector {
  x : Double
  y : Double
  z : Double
} derive(Eq, Debug)

///|
pub(all) struct PdfThreeDMatrix {
  values : Array[Double]
} derive(Eq, Debug)

///|
pub(all) enum PdfThreeDArtworkSource {
  Stream(PdfThreeDStream)
  Reference(PdfThreeDReference)
  Raw(@objects.PdfObject)
} derive(Eq, Debug)

///|
pub(all) struct PdfThreeDAnnotation {
  object_id : @objects.ObjectId?
  artwork : PdfThreeDArtworkSource
  default_view : @objects.PdfObject?
  activation : @objects.PdfDictionary?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfThreeDStream {
  object_id : @objects.ObjectId?
  subtype : @objects.PdfName?
  views : Array[PdfThreeDView]
  raw_stream : @objects.PdfStream
} derive(Eq, Debug)

///|
pub(all) struct PdfThreeDReference {
  object_id : @objects.ObjectId?
  target : @objects.PdfObject
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfThreeDView {
  object_id : @objects.ObjectId?
  name : Bytes?
  camera_to_world : PdfThreeDMatrix?
  center_of_orbit : PdfThreeDVector?
  projection : PdfThreeDProjection?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfThreeDProjection {
  Perspective(@objects.PdfDictionary)
  Orthographic(@objects.PdfDictionary)
  Unknown(@objects.PdfName, @objects.PdfDictionary)
} derive(Eq, Debug)

///|
pub(all) struct PdfRichMediaAnnotation {
  object_id : @objects.ObjectId?
  content : PdfRichMediaContent
  settings : PdfRichMediaSettings
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfRichMediaSettings {
  object_id : @objects.ObjectId?
  activation : @objects.PdfDictionary?
  deactivation : @objects.PdfDictionary?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfRichMediaContent {
  object_id : @objects.ObjectId?
  assets : Array[PdfRichMediaAsset]
  configurations : Array[PdfRichMediaConfiguration]
  views : Array[PdfRichMediaView]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfRichMediaAsset {
  name : Bytes
  file_specification : @objects.PdfObject
  valid_name : Bool
} derive(Eq, Debug)

///|
pub(all) struct PdfRichMediaConfiguration {
  object_id : @objects.ObjectId?
  subtype : @objects.PdfName?
  instances : Array[PdfRichMediaInstance]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfRichMediaInstance {
  object_id : @objects.ObjectId?
  subtype : @objects.PdfName?
  asset : @objects.PdfObject?
  params : PdfRichMediaViewParams?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfRichMediaView {
  object_id : @objects.ObjectId?
  name : Bytes?
  params : PdfRichMediaViewParams?
  snapshot : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfRichMediaViewParams {
  object_id : @objects.ObjectId?
  binding : @objects.PdfName?
  data : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfMultimediaAnnotation {
  Sound(PdfSoundObject)
  Movie(PdfMovieDictionary)
  ThreeD(PdfThreeDAnnotation)
  RichMedia(PdfRichMediaAnnotation)
  Raw(PdfRawDictionaryPayload)
} derive(Eq, Debug)

///|
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
