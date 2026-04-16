///|
/// FDF body object record from ISO 32000-2 12.7.8.2.3. FDF bodies contain
/// indirect objects of generation 0 for the catalog dictionary and referenced
/// content; duplicate object numbers are invalid at the file-structure layer.
pub(all) struct PdfFDFObjectRecord {
  object_id : @objects.ObjectId
  value : @objects.PdfObject
} derive(Eq, Debug)

///|
/// FDF file specification wrapper from 12.7.8.3.1 Table 246. F and ID identify
/// the source or target PDF file for interactive form data import or export,
/// while Target preserves the browser frame name hand-off.
pub(all) struct PdfFDFFileSpecification {
  file : @objects.PdfObject?
  identifier : @objects.PdfObject?
  target : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary?
} derive(Eq, Debug)

///|
/// FDF field dictionary from ISO 32000-2 12.7.8.3.2 and Table 249. It keeps
/// Kids, T partial field name, V value, Ff/SetFf/ClrFf field flags, widget F,
/// SetF, ClrF flags, AP appearance, APRef named page reference dictionary
/// from Table 253, IF icon fit, Opt choices, A, AA, RV, and raw dictionary
/// data for import into a same fully qualified field name.
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
/// FDF dictionary from ISO 32000-2 12.7.8.1 and 12.7.8.3.1 Table 246. It
/// models Forms Data Format application/vnd.fdf payloads for stand-alone
/// interactive form data, FDF field roots, status strings, FDF pages from
/// Table 251 with template dictionaries from Table 252 and named page
/// references from Table 253, FDF annotation dictionaries from Table 254
/// whose Page value uses ordinal page 0 for the first page, Differences
/// incremental updates, JavaScript import hooks, and encrypted EmbeddedFDFs
/// whose stream dictionaries may carry Table 247 EncryptionRevision.
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
/// FDF catalog dictionary from 12.7.8.3.1 Table 245. The Version name may
/// override the %FDF-1.2 header version, and FDF points at the required FDF
/// dictionary described by Table 246.
pub(all) struct PdfFDFCatalog {
  version : @objects.PdfName?
  fdf : PdfFDFDictionary?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// FDF document model for ISO 32000-2 12.7.8.2.1 through 12.7.8.2.4 and
/// Figure 85. It records the required one-line FDF header, FDF body object
/// sequence, optional cross-reference table, optional trailer with Root
/// catalog reference, and final %%EOF marker as parsed structural data.
pub(all) struct PdfFDFDocument {
  catalog : PdfFDFCatalog
  objects : Array[PdfFDFObjectRecord]
  trailer : @objects.PdfDictionary?
} derive(Eq, Debug)

///|
/// True when the record can serve as an FDF catalog object candidate.
pub fn PdfFDFObjectRecord::is_catalog_candidate(
  self : PdfFDFObjectRecord,
) -> Bool {
  match self.value {
    @objects.PdfObject::Dictionary(dict) =>
      dict.contains(@objects.PdfName::new(b"FDF"))
    _ => false
  }
}

///|
/// True when the FDF file spec carries any source or target locator.
pub fn PdfFDFFileSpecification::has_locator(
  self : PdfFDFFileSpecification,
) -> Bool {
  if self.file is Some(_) || self.identifier is Some(_) {
    true
  } else {
    self.target is Some(_) || self.raw_dict is Some(_)
  }
}

///|
/// True when the FDF field has value, child, or flag update data.
pub fn PdfFDFField::has_import_payload(self : PdfFDFField) -> Bool {
  if self.value is Some(_) || self.default_value is Some(_) {
    true
  } else if self.kids.length() > 0 {
    true
  } else {
    self.flags is Some(_) ||
    self.set_flags is Some(_) ||
    self.clear_flags is Some(_)
  }
}

///|
/// True when the FDF dictionary carries field, annotation, or update data.
pub fn PdfFDFDictionary::has_document_payload(self : PdfFDFDictionary) -> Bool {
  if self.fields.length() > 0 || self.annotations.length() > 0 {
    true
  } else if self.pages.length() > 0 || self.differences is Some(_) {
    true
  } else {
    self.embedded_fdf is Some(_) || self.javascript is Some(_)
  }
}

///|
/// True when the catalog points at an FDF dictionary or keeps raw entries.
pub fn PdfFDFCatalog::has_fdf_payload(self : PdfFDFCatalog) -> Bool {
  if self.fdf is Some(fdf) {
    fdf.has_document_payload()
  } else if self.version is Some(_) {
    true
  } else {
    self.raw_dict.length() > 0
  }
}

///|
/// Counts indirect body records preserved by this FDF document.
pub fn PdfFDFDocument::object_count(self : PdfFDFDocument) -> Int {
  let mut count = self.objects.length()
  if self.trailer is Some(_) {
    count += 1
  }
  count
}
