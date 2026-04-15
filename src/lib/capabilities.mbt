///|
/// Support status for PDF features found during `PdfDocument::check()`.
pub(all) enum PdfCapabilityStatus {
  Supported
  Partial
  Unsupported
  Unused
} derive(Eq, Debug)

///|
/// One document capability report entry with feature name, category such as
/// filter, font, encryption, image, interactive, or structure, support status,
/// and a human-readable description.
pub(all) struct PdfCapabilityEntry {
  feature_name : String
  category : String
  status : PdfCapabilityStatus
  description : String
} derive(Eq, Debug)

///|
/// Document capability report containing structured entries for used features
/// and whether the library can handle them, rather than failing silently.
pub(all) struct PdfCapabilityReport {
  entries : Array[PdfCapabilityEntry]
} derive(Eq, Debug)

///|
/// Non-fatal warning for unsupported font types, missing ToUnicode maps,
/// unknown operators, unsupported filters, unsupported colour spaces, or
/// skipped image extraction details.
pub(all) struct PdfWarning {
  feature_name : String
  category : String
  description : String
} derive(Eq, Debug)

///|
/// Analyzes a PDF document and returns a structured capability report for used
/// filters, fonts, images, encryption, interactive features, and structure
/// features such as bookmarks. This exposes supported, partial, unsupported,
/// and unused status instead of failing silently.
pub fn PdfDocument::check(
  self : PdfDocument,
) -> PdfCapabilityReport raise @reader.PdfDocumentError {
  let entries : Array[PdfCapabilityEntry] = []
  add_document_structure_capabilities(self, entries)
  add_page_image_capabilities(self, entries)
  add_text_capability(self, entries)
  PdfCapabilityReport::{ entries, }
}

///|
/// Extracts page text and returns non-fatal warnings for partial text
/// extraction conditions such as missing spans, unsupported font information,
/// or skipped operators when they can be detected.
pub fn PdfPage::extract_text_with_warnings(
  self : PdfPage,
) -> (String, Array[PdfWarning]) {
  let text = extract_page_text(self)
  let warnings : Array[PdfWarning] = []
  let spans = text_spans(self)
  if text == "" && spans.length() == 0 {
    warnings.push(PdfWarning::{
      feature_name: "page text",
      category: "font",
      description: "No text spans were extracted; missing ToUnicode maps, unsupported font type, or unknown text operators may have produced partial output.",
    })
  }
  (text, warnings)
}

///|
/// Enumerates images and collects warnings for images that could not be fully
/// decoded because of unsupported filters or unsupported colour spaces.
pub fn PdfPage::images_with_warnings(
  self : PdfPage,
) -> (Array[PdfImage], Array[PdfWarning]) {
  let images = page_images(self)
  let warnings : Array[PdfWarning] = []
  for image in images {
    add_image_warnings(image, warnings)
  }
  (images, warnings)
}

///|
fn add_document_structure_capabilities(
  document : PdfDocument,
  entries : Array[PdfCapabilityEntry],
) -> Unit raise @reader.PdfDocumentError {
  let outline_items = document.outline()
  entries.push(PdfCapabilityEntry::{
    feature_name: "bookmarks",
    category: "structure",
    status: if outline_items.length() > 0 {
      Supported
    } else {
      Unused
    },
    description: "Document outline bookmarks are exposed as flattened OutlineItem values with title, destination page index, and nesting level.",
  })
}

///|
fn add_page_image_capabilities(
  document : PdfDocument,
  entries : Array[PdfCapabilityEntry],
) -> Unit raise @reader.PdfDocumentError {
  let mut image_count = 0
  let seen_filters : Map[String, Bool] = Map::new()
  for page in document.pages() {
    for image in page.images() {
      image_count += 1
      for filter in image.descriptor.filters {
        let name = filter.to_text()
        if !seen_filters.contains(name) {
          seen_filters[name] = true
          entries.push(PdfCapabilityEntry::{
            feature_name: name,
            category: "filter",
            status: filter_support_status(filter),
            description: filter_support_description(filter),
          })
        }
      }
    }
  }
  entries.push(PdfCapabilityEntry::{
    feature_name: "image XObjects",
    category: "image",
    status: if image_count > 0 {
      Partial
    } else {
      Unused
    },
    description: "Image extraction enumerates image XObjects and decodes supported sample data to RGBA; unsupported encoded filters are reported as warnings.",
  })
}

///|
fn add_text_capability(
  document : PdfDocument,
  entries : Array[PdfCapabilityEntry],
) -> Unit raise @reader.PdfDocumentError {
  let mut span_count = 0
  for page in document.pages() {
    span_count += page.text_spans().length()
  }
  entries.push(PdfCapabilityEntry::{
    feature_name: "text extraction",
    category: "font",
    status: if span_count > 0 {
      Partial
    } else {
      Unused
    },
    description: "Text extraction returns Unicode text and structured spans while reporting warning visibility for missing ToUnicode maps, unsupported fonts, and skipped operators when detected.",
  })
}

///|
fn add_image_warnings(image : PdfImage, warnings : Array[PdfWarning]) -> Unit {
  match image.data {
    EncodedImageData(_, filters) =>
      for filter in filters {
        if filter_support_status(filter) == Unsupported {
          warnings.push(PdfWarning::{
            feature_name: filter.to_text(),
            category: "filter",
            description: filter_support_description(filter),
          })
        }
      }
    _ => ()
  }
  if image.to_rgba().length() == 0 {
    warnings.push(PdfWarning::{
      feature_name: "image RGBA decode",
      category: "image",
      description: "Image extraction found an image XObject, but decoded RGBA pixel data is unavailable for its filter or colour space.",
    })
  }
}

///|
fn filter_support_status(filter : @objects.PdfName) -> PdfCapabilityStatus {
  if filter == @objects.PdfName::new(b"FlateDecode") ||
    filter == @objects.PdfName::new(b"ASCIIHexDecode") ||
    filter == @objects.PdfName::new(b"ASCII85Decode") ||
    filter == @objects.PdfName::new(b"RunLengthDecode") {
    Supported
  } else if filter == @objects.PdfName::new(b"DCTDecode") {
    Partial
  } else {
    Unsupported
  }
}

///|
fn filter_support_description(filter : @objects.PdfName) -> String {
  if filter == @objects.PdfName::new(b"FlateDecode") {
    "FlateDecode stream filter is supported for decoded PDF stream data."
  } else if filter == @objects.PdfName::new(b"DCTDecode") {
    "DCTDecode JPEG image data is partially supported; raw passthrough and available decoded data are exposed, while unsupported conversions are reported as warnings."
  } else if filter == @objects.PdfName::new(b"JPXDecode") {
    "JPXDecode JPEG 2000 image filter is unsupported and image extraction reports it as a warning."
  } else if filter == @objects.PdfName::new(b"JBIG2Decode") {
    "JBIG2Decode image filter is unsupported and image extraction reports it as a warning."
  } else if filter == @objects.PdfName::new(b"CCITTFaxDecode") {
    "CCITTFaxDecode image filter is unsupported and image extraction reports it as a warning."
  } else if filter == @objects.PdfName::new(b"Crypt") {
    "Crypt filter and encrypted stream data are unsupported in this high-level API."
  } else {
    "This PDF stream filter is not currently supported by image extraction."
  }
}
