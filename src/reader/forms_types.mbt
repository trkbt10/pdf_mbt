///|
pub(all) enum PdfFormFieldType {
  Button
  Text
  Choice
  Signature
  Unknown(@objects.PdfName)
  Absent
} derive(Eq, Debug)

///|
pub(all) struct PdfFormFieldFlags {
  bits : Int
} derive(Eq, Debug)

///|
pub(all) enum PdfFormFieldValue {
  Name(@objects.PdfName)
  String(Bytes)
  Array(Array[@objects.PdfObject])
  Raw(@objects.PdfObject)
  Absent
} derive(Eq, Debug)

///|
pub(all) struct PdfVariableTextDescriptor {
  default_appearance : Bytes?
  quadding : Int?
  default_style : Bytes?
  rich_text : @objects.PdfObject?
  default_resources : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfFormWidgetRef {
  object_id : @objects.ObjectId?
  page_index : Int?
  merged_field_dictionary : Bool
  raw_annotation : PdfAnnotation?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfFormField {
  object_id : @objects.ObjectId?
  partial_name : Bytes?
  fully_qualified_name : Bytes?
  field_type : PdfFormFieldType
  flags : PdfFormFieldFlags
  value : PdfFormFieldValue
  default_value : PdfFormFieldValue
  parent : @objects.ObjectId?
  kids : Array[@objects.PdfObject]
  widgets : Array[PdfFormWidgetRef]
  variable_text : PdfVariableTextDescriptor?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfAcroForm {
  root_fields : Array[PdfFormField]
  need_appearances : Bool?
  signature_flags : Int?
  calculation_order : Array[@objects.PdfObject]
  default_resources : @objects.PdfObject?
  default_appearance : Bytes?
  quadding : Int?
  xfa : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)
