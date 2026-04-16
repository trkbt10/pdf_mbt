///|
pub(all) enum PdfFileSpecification {
  Simple(PdfSimpleFileSpecification)
  Full(PdfFileSpecificationDictionary)
} derive(Eq, Debug)

///|
pub(all) struct PdfResolvedFileSpecObject {
  object : @objects.PdfObject
  source_object_id : @objects.ObjectId?
  indirect : Bool
  raw_object : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfFileSpecPath {
  raw : Bytes
  absolute : Bool
  components : Array[Bytes]
} derive(Eq, Debug)

///|
pub(all) struct PdfSimpleFileSpecification {
  raw_string : Bytes
  path : PdfFileSpecPath
  source_object_id : @objects.ObjectId?
  indirect : Bool
  raw_object : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfFileSpecNameEntry {
  raw : Bytes
  path : PdfFileSpecPath?
} derive(Eq, Debug)

///|
pub(all) enum PdfFileSpecFileSystem {
  URL
  Other(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) struct PdfFileSpecIdentifier {
  first : Bytes
  second : Bytes
  raw_array : Array[@objects.PdfObject]
} derive(Eq, Debug)

///|
pub(all) struct PdfFileSpecificationDictionary {
  source_object_id : @objects.ObjectId?
  indirect : Bool
  file_system : PdfFileSpecFileSystem?
  f : PdfFileSpecNameEntry?
  uf : PdfFileSpecNameEntry?
  dos : PdfFileSpecNameEntry?
  mac : PdfFileSpecNameEntry?
  unix : PdfFileSpecNameEntry?
  selected_file_name : PdfFileSpecNameEntry?
  file_identifier : PdfFileSpecIdentifier?
  is_volatile : Bool
  embedded_files : Map[@objects.PdfName, PdfEmbeddedFile]
  related_files : Map[@objects.PdfName, Array[PdfRelatedFile]]
  description : Bytes?
  collection_item : PdfCollectionItem?
  thumbnail : PdfFileSpecStream?
  encrypted_payload : PdfEncryptedPayload?
  associated_relationship : PdfAssociatedFileRelationship
  raw_dict : @objects.PdfDictionary
  raw_object : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfEmbeddedFile {
  key : @objects.PdfName
  source_object_id : @objects.ObjectId?
  raw_stream : @objects.PdfStream
  subtype : @objects.PdfName?
  params : PdfEmbeddedFileParams?
  raw_dict : @objects.PdfDictionary
  raw_object : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfEmbeddedFileParams {
  size : Int64?
  creation_date : Bytes?
  modification_date : Bytes?
  mac : @objects.PdfDictionary?
  checksum : Bytes?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
pub(all) struct PdfRelatedFile {
  name : Bytes
  embedded_file : PdfEmbeddedFile
  raw_name : @objects.PdfObject
  raw_file : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfCollectionItem {
  source_object_id : @objects.ObjectId
  raw_dict : @objects.PdfDictionary
  raw_object : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfFileSpecStream {
  source_object_id : @objects.ObjectId?
  raw_stream : @objects.PdfStream
  raw_object : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) struct PdfEncryptedPayload {
  source_object_id : @objects.ObjectId?
  raw_dict : @objects.PdfDictionary
  raw_object : @objects.PdfObject
} derive(Eq, Debug)

///|
pub(all) enum PdfAssociatedFileRelationship {
  Source
  Data
  Alternative
  Supplement
  EncryptedPayload
  FormData
  Schema
  Unspecified
  Other(@objects.PdfName)
} derive(Eq, Debug)

///|
pub(all) struct PdfEmbeddedFileEntry {
  name : Bytes
  file_specification : PdfFileSpecification
  raw_value : @objects.PdfObject
} derive(Eq, Debug)

///|
/// True when a file specification carries embedded-file or related-file data.
pub fn PdfFileSpecification::has_embedded_payload(
  self : PdfFileSpecification,
) -> Bool {
  match self {
    Simple(simple) => simple.indirect && simple.path.components.length() > 0
    Full(full) =>
      full.embedded_files.length() > 0 ||
      full.related_files.length() > 0 ||
      full.encrypted_payload is Some(_)
  }
}

///|
/// True when path components are normalized enough for deterministic joining.
pub fn PdfFileSpecPath::is_normalized_relative(self : PdfFileSpecPath) -> Bool {
  if self.absolute || self.raw.length() == 0 {
    false
  } else {
    for component in self.components {
      if component.length() == 0 || component == b"." || component == b".." {
        return false
      }
    }
    true
  }
}

///|
/// Counts embedded, related, thumbnail, and encrypted payload attachments.
pub fn PdfFileSpecificationDictionary::attachment_count(
  self : PdfFileSpecificationDictionary,
) -> Int {
  let mut count = self.embedded_files.length()
  self.related_files.each((_, files) => count += files.length())
  if self.thumbnail is Some(_) {
    count += 1
  }
  if self.encrypted_payload is Some(_) {
    count += 1
  }
  count
}

///|
/// True when embedded-file parameters include size and integrity metadata.
pub fn PdfEmbeddedFileParams::has_integrity_metadata(
  self : PdfEmbeddedFileParams,
) -> Bool {
  if self.size is Some(size) && size < 0L {
    false
  } else if self.checksum is Some(bytes) && bytes.length() > 0 {
    true
  } else {
    self.creation_date is Some(_) || self.modification_date is Some(_)
  }
}
