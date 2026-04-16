///|
/// Measure dictionary subtype names from ISO 32000-2 12.9.1 Table 266:
/// Rectilinear RL, geospatial GEO from 12.10, unknown subtypes, and absent
/// subtype defaulting.
pub(all) enum PdfMeasureKind {
  Rectilinear
  Geospatial
  Unknown(@objects.PdfName)
  Absent
} derive(Eq, Debug)

///|
/// Number format dictionary from 12.9.1 Table 268 and the 12.9.2 algorithm
/// for creating formatted text strings. U labels, C conversion factors, F/D
/// precision or denominator, RT/RD separators, PS/SS spacing, and O label
/// position are retained as descriptor data.
pub(all) struct PdfNumberFormatDescriptor {
  labels : Array[Bytes]
  conversion_factor : Double
  precision : Int?
  fraction_denominator : Int?
  decimal_separator : Bytes?
  thousands_separator : Bytes?
  label_position : @objects.PdfName?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Measure dictionary from ISO 32000-2 12.9.1 Table 266. Rectilinear
/// measurement dictionaries keep scale ratio R and number format arrays from
/// Table 267; geospatial measurement uses GEO entries defined in 12.10.
pub(all) struct PdfMeasure {
  kind : PdfMeasureKind
  subtype : @objects.PdfName?
  scale_ratio : Bytes?
  number_formats : Array[PdfNumberFormatDescriptor]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Viewport dictionary from ISO 32000-2 12.9.1 Table 265. A viewport is a
/// page rectangle with BBox, Name, Measure, and PtData, used to select the
/// measurement coordinate system for real-world graphics and geospatially
/// registered content.
pub(all) struct PdfViewport {
  bbox : PdfRectangle?
  name : Bytes?
  measure : PdfMeasure?
  point_data : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// True when the measure carries data beyond a bare subtype marker.
pub fn PdfMeasure::has_measurement_payload(self : PdfMeasure) -> Bool {
  if self.scale_ratio is Some(bytes) && bytes.length() > 0 {
    true
  } else if self.number_formats.length() > 0 {
    true
  } else {
    self.raw_dict.length() > 0 && self.subtype is Some(_)
  }
}
