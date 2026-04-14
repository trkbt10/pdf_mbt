///|
/// Coordinate system kind names from ISO 32000-2 12.10.3 Table 270 and
/// 12.10.4 Table 271: geographic GEOGCS, projected PROJCS, and unknown names.
pub(all) enum PdfCoordinateSystemKind {
  Geographic
  Projected
  Unknown(@objects.PdfName)
} derive(Eq, Debug)

///|
/// EPSG code or Well Known Text (WKT) descriptor for geographic and projected
/// coordinate system dictionaries. EPSG and WKT are mutually exclusive in
/// Tables 270 and 271.
pub(all) enum PdfCoordinateSystemDescriptor {
  EPSG(Int)
  WKT(Bytes)
} derive(Eq, Debug)

///|
/// Geographic or projected coordinate system dictionary from ISO 32000-2
/// 12.10.3 and 12.10.4. It may appear as GCS or DCS in a geospatial measure
/// dictionary and carries either EPSG or WKT data.
pub(all) struct PdfCoordinateSystem {
  kind : PdfCoordinateSystemKind
  descriptor : PdfCoordinateSystemDescriptor
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Geospatial measure dictionary from 12.10.1 and 12.10.2 Table 269. It keeps
/// Bounds, GCS, DCS, PDU, GPTS, LPTS, and PCSM data that relates PDF object
/// coordinates to earth-based geographic or projected coordinate systems.
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
/// Point data column names from 12.10.5 Table 272: LAT latitude, LON
/// longitude, ALT altitude, and custom names.
pub(all) enum PdfPointDataColumn {
  Latitude
  Longitude
  Altitude
  Custom(@objects.PdfName)
} derive(Eq, Debug)

///|
/// Point data dictionary from ISO 32000-2 12.10.5 Table 272. PtData subtype
/// Cloud supplies Names column headers and XPTS tuples for extended
/// geospatial point data associated with a Viewport, image XObject, or form
/// XObject.
pub(all) struct PdfPointData {
  subtype : @objects.PdfName?
  names : Array[PdfPointDataColumn]
  tuples : Array[Array[Double]]
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)
