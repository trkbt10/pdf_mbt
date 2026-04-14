///|
pub(all) struct PdfFDFObjectRecord {
  object_id : @objects.ObjectId
  value : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfFDFFileSpecification {
  file : @objects.PdfObject?
  identifier : @objects.PdfObject?
  target : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary?
} derive(Eq, Debug)

///|
pub(all) struct PdfFDFField {
  partial_name : Bytes?
  value : @objects.PdfObject?
  default_value : @objects.PdfObject?
  kids : Array[PdfFDFField]
  flags : Int?
  set_flags : Int?
  clear_flags : Int?
  widget_flags : Int?
  set_widget_flags : Int?
  clear_widget_flags : Int?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfFDFDictionary {
  file : PdfFDFFileSpecification?
  fields : Array[PdfFDFField]
  status : Bytes?
  pages : Array[@objects.PdfObject]
  encoding : @objects.PdfName?
  annotations : Array[@objects.PdfObject]
  differences : @objects.PdfObject?
  target : @objects.PdfObject?
  embedded_fdf : @objects.PdfObject?
  javascript : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfFDFCatalog {
  version : @objects.PdfName?
  fdf : PdfFDFDictionary?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfFDFDocument {
  catalog : PdfFDFCatalog
  objects : Array[PdfFDFObjectRecord]
  trailer : @objects.PdfDictionary?
} derive(Eq, Debug)
