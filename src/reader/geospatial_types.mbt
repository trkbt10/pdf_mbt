///|
pub(all) enum PdfCoordinateSystemKind {
  Geographic
  Projected
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) enum PdfCoordinateSystemDescriptor {
  EPSG(Int)
  WKT(Bytes)
} derive(Eq, Debug)

///|
pub(all) struct PdfCoordinateSystem {
  kind : PdfCoordinateSystemKind
  descriptor : PdfCoordinateSystemDescriptor
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfGeospatialMeasure {
  bounds : Array[Double]
  geographic_coordinate_system : PdfCoordinateSystem?
  display_coordinate_system : PdfCoordinateSystem?
  preferred_display_units : Array[@objects.PdfObject]
  gpts : Array[Double]
  lpts : Array[Double]
  pcsm : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) enum PdfPointDataColumn {
  Latitude
  Longitude
  Altitude
  Custom(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) struct PdfPointData {
  subtype : @objects.PdfName?
  names : Array[PdfPointDataColumn]
  tuples : Array[Array[Double]]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)
