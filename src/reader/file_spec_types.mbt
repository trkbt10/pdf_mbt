///|
/// PDF file specification model for Section 7.11.1 General.
///
/// A PDF file can refer to the contents of another file by using a file
/// specification. A simple file specification gives the target file name in a
/// standard format independent of any particular file system and may be a
/// string or dictionary; a full file specification is represented as a
/// dictionary with file-system-specific information. The target can be an
/// internal file, external file, URL, or embedded file, and this model keeps the
/// reference file system independent even when the file is external to or
/// embedded within the PDF file.
///
/// Section 7.11.4.2 Related files arrays covers the RF entry in a file
/// specification dictionary. A related files array identifies a group of
/// related files, such as the files that make up a DCS 1.0 colour-separated
/// image; the file specification explicitly names only one file through the F
/// entry, and the rest are embedded as filename / file specification pairs in
/// the RF entry.
///
/// Section 7.11.5 URL specifications covers the URL file system. When the FS
/// entry in a file specification dictionary has the value URL, the F entry is
/// not a file specification string but a uniform resource locator URL of the
/// form defined in Internet RFC 3986, and the URL shall follow URL escaping and
/// character-encoding requirements from Internet RFC 3986.
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
/// Parsed file specification string path from Section 7.11.2.1.
///
/// A file specification string uses the standard platform-independent,
/// Unix-style format where component substrings are separated by Slash
/// characters, the SOLIDUS character 2Fh (/). Slash characters inside a
/// component are escaped with REVERSE SOLIDUS 5Ch so values stay bytes passed
/// without interpretation. The resulting path can be absolute or relative, for
/// example /c/dir/file.pdf.
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
/// URL specification per Section 7.11.5 "URL specifications" of
/// ISO 32000-2.
///
/// When the FS entry in a file specification dictionary has the value
/// URL, the value of the F entry in that dictionary is not a file
/// specification string, but a uniform resource locator (URL) of the
/// form defined in Internet RFC 3986.
///
/// EXAMPLE: << /FS /URL /F (ftp://www.beatles.com/Movies/AbbeyRoad.mov) >>
///
/// The URL shall adhere to the character-encoding requirements
/// specified in Internet RFC 3986. Because 7-bit U.S. ASCII is a
/// strict subset of PDFDocEncoding, this value shall also be
/// considered to be in PDFDocEncoding.
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
/// Full file specification dictionary for Section 7.11.3 and related entries.
///
/// The dictionary may carry EF embedded file mappings and an RF entry whose
/// value is a related files array as described by Section 7.11.4.2 Related
/// files arrays. The related_files map preserves the RF entry arrays associated
/// with each F entry, so each group of related files can remain paired with the
/// file specification dictionary that explicitly names the primary file.
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
/// Related files array (PDF 1.3) per Section 7.11.4.2 "Related files
/// arrays" of ISO 32000-2.
///
/// In some circumstances, a PDF file can refer to a group of related
/// files, such as the set of five files that make up a DCS 1.0
/// colour-separated image. The file specification explicitly names
/// only one of the files; the rest shall be identified by some
/// systematic variation of that file name (such as by altering the
/// extension). When such a file is to be embedded in a PDF file, the
/// related files shall be embedded as well.
///
/// This is accomplished by including a related files array (PDF 1.3)
/// as the value of the RF entry in the file specification dictionary.
/// The array shall have 2 × n elements, which shall be paired in the
/// form [string1 stream1 string2 stream2 ... stringn streamn].
///
/// The first element of each pair shall be a string giving the name
/// of one of the related files; the second element shall be an
/// embedded file stream holding the file's contents.
///
/// EXAMPLE: object 31 is an embedded file stream containing
/// Encapsulated PostScript File (EPSF) file Sunset.eps. The file
/// specification dictionary's RF entry specifies an array (object 30)
/// identifying a set of embedded files forming a DCS 1.0 set.
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
/// Related files array (PDF 1.3) per Section 7.11.4.2 "Related files
/// arrays" of ISO 32000-2.
///
/// In some circumstances, a PDF file can refer to a group of related
/// files, such as the set of five files that make up a DCS 1.0
/// colour-separated image. The file specification explicitly names
/// only one of the files; the rest shall be identified by some
/// systematic variation of that file name (such as by altering the
/// extension). When such a file is to be embedded in a PDF file, the
/// related files shall be embedded as well.
///
/// This is accomplished by including a related files array (PDF 1.3)
/// as the value of the RF entry in the file specification dictionary.
/// The array shall have 2 × n elements, which shall be paired in the
/// form [string1 stream1 string2 stream2 ... stringn streamn].
///
/// The first element of each pair shall be a string giving the name
/// of one of the related files; the second element shall be an
/// embedded file stream holding the file's contents.
///
/// EXAMPLE: object 31 is an embedded file stream containing
/// Encapsulated PostScript File (EPSF) file Sunset.eps. The file
/// specification dictionary's RF entry specifies an array (object 30)
/// identifying a set of embedded files forming a DCS 1.0 set.
pub fn PdfFileSpecificationDictionary::related_files_array_count(
  self : PdfFileSpecificationDictionary,
) -> Int {
  let mut count = 0
  self.related_files.each((_, files) => if files.length() > 0 { count += 1 })
  count
}

///|
/// URL specification per Section 7.11.5 "URL specifications" of
/// ISO 32000-2.
///
/// When the FS entry in a file specification dictionary has the value
/// URL, the value of the F entry in that dictionary is not a file
/// specification string, but a uniform resource locator (URL) of the
/// form defined in Internet RFC 3986.
///
/// EXAMPLE: << /FS /URL /F (ftp://www.beatles.com/Movies/AbbeyRoad.mov) >>
///
/// The URL shall adhere to the character-encoding requirements
/// specified in Internet RFC 3986. Because 7-bit U.S. ASCII is a
/// strict subset of PDFDocEncoding, this value shall also be
/// considered to be in PDFDocEncoding.
pub fn PdfFileSpecificationDictionary::is_url_specification(
  self : PdfFileSpecificationDictionary,
) -> Bool {
  self.file_system == Some(PdfFileSpecFileSystem::URL)
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

///|
/// True when the embedded file has a declared subtype or parameter payload.
pub fn PdfEmbeddedFile::has_file_metadata(self : PdfEmbeddedFile) -> Bool {
  if self.subtype is Some(_) {
    true
  } else if self.params is Some(params) {
    params.has_integrity_metadata()
  } else {
    self.raw_dict.length() > 0
  }
}
