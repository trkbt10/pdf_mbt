///|
pub(all) enum PdfMeasureKind {
  Rectilinear
  Geospatial
  Unknown(@objects.PdfName)
  Absent
} derive(Eq, Debug)

///|
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
pub(all) struct PdfMeasure {
  kind : PdfMeasureKind
  subtype : @objects.PdfName?
  scale_ratio : Bytes?
  number_formats : Array[PdfNumberFormatDescriptor]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfViewport {
  bbox : PdfRectangle?
  name : Bytes?
  measure : PdfMeasure?
  point_data : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)
