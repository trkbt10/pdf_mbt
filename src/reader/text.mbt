///|
/// Options for downstream text extraction from a page after the file reader
/// has used random-access object loading to resolve page resources and
/// content streams from cross-reference data.
pub(all) struct TextPageOptions {
  initial_ctm : @text.TextMatrix?
  materialize_resources : Bool
} derive(Eq, Debug)

///|
pub fn TextPageOptions::default() -> TextPageOptions {
  TextPageOptions::{ initial_ctm: None, materialize_resources: true }
}

///|
/// Builds text resources from document-structure page resources that were
/// resolved through the opened `PdfFile` and its random-access object loading.
pub fn PdfPage::text_resources(
  self : PdfPage,
) -> @text.TextResources raise PdfDocumentError {
  let content_resources = self.materialized_text_content_resources()
  try @text.TextResources::from_content_resources(content_resources, 0L) catch {
    error => raise PdfDocumentError::TextError(error)
  } noraise {
    resources => resources
  }
}

///|
/// Parses a page content stream into a text program after the file-structure
/// reader has loaded the required indirect objects by object number and
/// generation number.
pub fn PdfPage::text_program(
  self : PdfPage,
  options : TextPageOptions,
) -> @text.TextProgram raise PdfDocumentError {
  let text_resources = self.text_resources_for_program(options)
  let decoded = self.decoded_content_bytes()
  let content = try
    @content.parse_decoded_content(decoded, text_resources.content_resources)
  catch {
    error => raise PdfDocumentError::ContentError(error)
  } noraise {
    stream => stream
  }
  let initial = @text.TextInitialState::{
    ctm: match options.initial_ctm {
      Some(value) => value
      None => @text.TextMatrix::identity()
    },
    text_knockout: true,
  }
  try @text.interpret_text(content, text_resources, initial) catch {
    error => raise PdfDocumentError::TextError(error)
  } noraise {
    program => program
  }
}

///|
/// Extracts text spans from a page using the file reader's resolved page
/// resources and content stream objects.
///
/// Errors propagate. The previous behaviour silently swallowed
/// `ReaderError`, `ContentError` and `TextError` and returned an empty
/// extraction — that swallow concealed real producer or decoder bugs
/// (e.g. a ToUnicode FlateDecode body whose trailing pad byte made the
/// stream look corrupt to a strict adler check, which then dropped the
/// whole CID-font CMap and let every page come back blank or with garbage
/// substitution glyphs without any visible signal). The caller layer
/// (CLI, capability reporting) is responsible for deciding whether to
/// surface, log or recover from a failed page extraction.
pub fn PdfPage::extracted_text(
  self : PdfPage,
  options : TextPageOptions,
) -> @text.ExtractedText raise PdfDocumentError {
  @text.ExtractedText::from_spans(self.text_program(options).spans)
}

///|
/// Returns a layout string from extracted text spans for sample validation
/// after `PdfFile` has parsed the header, trailer, and cross-reference data.
pub fn PdfPage::extract_text_layout(self : PdfPage) -> String {
  let result : Result[@text.ExtractedText, PdfDocumentError] = try? self.extracted_text(
    TextPageOptions::default(),
  )
  match result {
    Ok(extracted) => @layout.layout_text_spans(extracted.spans)
    Err(_) => ""
  }
}

///|
/// Returns the text resources for `text_program`. Materialization failures
/// propagate; the previous fallback to `unmaterialized_text_resources` was a
/// silent swallow that hid resolution bugs (the unmaterialized form is
/// strictly less informative — fonts arrive as `Ref` objects, the runtime
/// font parser then can't see Encoding/ToUnicode/Widths and falls through
/// to a degenerate Latin-encoded font, and the page renders as garbage
/// without any error visible to the user).
fn PdfPage::text_resources_for_program(
  self : PdfPage,
  options : TextPageOptions,
) -> @text.TextResources raise PdfDocumentError {
  if options.materialize_resources {
    self.text_resources()
  } else {
    self.unmaterialized_text_resources()
  }
}

///|
fn PdfPage::unmaterialized_text_resources(
  self : PdfPage,
) -> @text.TextResources raise PdfDocumentError {
  let content_resources = self.content_resources()
  try @text.TextResources::from_content_resources(content_resources, 0L) catch {
    error => raise PdfDocumentError::TextError(error)
  } noraise {
    resources => resources
  }
}

///|
fn PdfPage::materialized_text_content_resources(
  self : PdfPage,
) -> @content.ContentResources raise PdfDocumentError {
  let object = resolve_optional_page_object(self.file, self.resources())
  match object {
    None => @content.ContentResources::empty()
    Some(@objects.PdfObject::Null) => @content.ContentResources::empty()
    Some(@objects.PdfObject::Dictionary(dict)) =>
      @content.ContentResources::from_dictionary(
        materialize_text_resource_dictionary(self.file, dict, self.object_id()),
      )
    Some(_) =>
      raise PdfDocumentError::ContentError(
        @content.PdfContentError::ResourceFailure(
          0L, "Resources entry for text extraction must be a dictionary",
        ),
      )
  }
}

///|
fn materialize_text_resource_dictionary(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  page_id : @objects.ObjectId,
) -> @objects.PdfDictionary raise PdfDocumentError {
  let output = dict.copy()
  materialize_text_named_resource_category(file, output, b"Font", page_id)
  materialize_text_named_resource_category(file, output, b"ExtGState", page_id)
  output
}

///|
fn materialize_text_named_resource_category(
  file : PdfFile,
  resources : @objects.PdfDictionary,
  category : Bytes,
  page_id : @objects.ObjectId,
) -> Unit raise PdfDocumentError {
  let key = @objects.PdfName::new(category)
  match resources.get(key) {
    Some(raw) =>
      match resolve_indirect(file, raw) {
        @objects.PdfObject::Dictionary(dict) => {
          let materialized : @objects.PdfDictionary = Map::new()
          for resource_name, object in dict {
            materialized[resource_name] = materialize_text_resource_object(
              file, object, category, page_id,
            )
          }
          resources[key] = @objects.PdfObject::Dictionary(materialized)
        }
        _ =>
          raise PdfDocumentError::InvalidPage(
            page_id,
            @objects.PdfName::new(category).to_text() +
            " text resource category must resolve to a dictionary",
          )
      }
    None => ()
  }
}

///|
/// Resolves a single resource entry (Font or ExtGState) to a direct
/// dictionary so the runtime parsers don't have to chase indirect refs.
///
/// Errors propagate. The previous swallow (`Err(_) => object`) hid broken
/// indirect references inside resource dictionaries; the runtime parser
/// would then try to operate on the bare `Ref` value, fail with
/// "ToUnicode must be a materialized stream" (or the equivalent for the
/// affected entry), and the user got a misleading downstream symptom for
/// what was really a cross-reference / missing-object issue.
fn materialize_text_resource_object(
  file : PdfFile,
  object : @objects.PdfObject,
  category : Bytes,
  page_id : @objects.ObjectId,
) -> @objects.PdfObject raise PdfDocumentError {
  let resolved = resolve_indirect(file, object)
  if category == b"Font" {
    materialize_font_object(file, resolved, page_id)
  } else {
    resolved
  }
}

///|
fn materialize_font_object(
  file : PdfFile,
  object : @objects.PdfObject,
  page_id : @objects.ObjectId,
) -> @objects.PdfObject raise PdfDocumentError {
  match object {
    @objects.PdfObject::Dictionary(dict) =>
      @objects.PdfObject::Dictionary(
        materialize_font_dictionary(file, dict, page_id),
      )
    @objects.PdfObject::Null =>
      raise PdfDocumentError::InvalidPage(page_id, "Font reference is missing")
    _ => object
  }
}

///|
fn materialize_font_dictionary(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  page_id : @objects.ObjectId,
) -> @objects.PdfDictionary raise PdfDocumentError {
  let output = dict.copy()
  materialize_font_entry(file, output, b"Encoding", page_id)
  materialize_font_entry(file, output, b"ToUnicode", page_id)
  materialize_font_entry(file, output, b"Widths", page_id)
  materialize_font_entry(file, output, b"FontDescriptor", page_id)
  // CID font (Type0 descendant) metrics. ISO 32000-2 §9.7.4.3 places the
  // per-CID width table in `W` (and rarely `W2`) on the descendant CIDFont
  // dict; producers commonly hide it behind an indirect reference. Without
  // resolving these here, parse_descendant_cid_widths sees a Ref instead of
  // an Array, gives up, and every CID falls back to DW (= 1000), which
  // surfaces as Latin-in-CID text rendered at full em width — the
  // "S e e   t h e   I n s t r u c t i o n" symptom.
  materialize_font_entry(file, output, b"W", page_id)
  materialize_font_entry(file, output, b"W2", page_id)
  // CIDToGIDMap is frequently a Ref to a stream that maps CIDs to glyph
  // indexes inside the embedded TrueType. Resolve it so glyph rendering can
  // walk the table directly without re-fetching the indirect object.
  materialize_font_entry(file, output, b"CIDToGIDMap", page_id)
  // CIDSystemInfo can be Ref-wrapped on some producers; the runtime parser
  // expects a direct Dictionary.
  materialize_font_entry(file, output, b"CIDSystemInfo", page_id)
  materialize_descendant_fonts(file, output, page_id)
  output
}

///|
/// Resolves a single entry on a font dict so the runtime font parser sees a
/// direct value (Stream / Dict / Array) rather than the originating
/// indirect reference.
///
/// Errors propagate. The previous implementation silently swallowed every
/// resolution failure and left the entry as the original `Ref`, which then
/// surfaced one layer up as `InvalidFont: ToUnicode must be a materialized
/// stream` — masking the real failure (a broken cross-reference, a missing
/// indirect target, etc.) and producing the same useless symptom for every
/// distinct cause. Letting the typed reader error escape lets callers
/// either fix the broken object or, if they really want to tolerate
/// missing referents, decide to do so explicitly with a Warning rather
/// than from within this primitive.
fn materialize_font_entry(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  key : Bytes,
  page_id : @objects.ObjectId,
) -> Unit raise PdfDocumentError {
  let name = @objects.PdfName::new(key)
  match dict.get(name) {
    Some(object) => {
      let value = resolve_indirect(file, object)
      dict[name] = if key == b"FontDescriptor" {
        materialize_font_descriptor(file, value, page_id)
      } else {
        value
      }
    }
    None => ()
  }
}

///|
fn materialize_font_descriptor(
  file : PdfFile,
  object : @objects.PdfObject,
  _page_id : @objects.ObjectId,
) -> @objects.PdfObject raise PdfDocumentError {
  match object {
    @objects.PdfObject::Dictionary(dict) => {
      let output = dict.copy()
      materialize_font_program(file, output, b"FontFile")
      materialize_font_program(file, output, b"FontFile2")
      materialize_font_program(file, output, b"FontFile3")
      @objects.PdfObject::Dictionary(output)
    }
    _ => object
  }
}

///|
/// Resolves the optional FontFile / FontFile2 / FontFile3 stream reference
/// on a FontDescriptor dictionary so downstream consumers see a direct
/// Stream object. Errors propagate (no silent fallback) — callers that
/// want to tolerate a missing or unresolvable embedded font program must
/// catch the typed reader error and emit an explicit warning.
fn materialize_font_program(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  key : Bytes,
) -> Unit raise PdfDocumentError {
  let name = @objects.PdfName::new(key)
  match dict.get(name) {
    Some(object) => dict[name] = resolve_indirect(file, object)
    None => ()
  }
}

///|
fn materialize_descendant_fonts(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  page_id : @objects.ObjectId,
) -> Unit raise PdfDocumentError {
  let key = @objects.PdfName::new(b"DescendantFonts")
  let raw = match dict.get(key) {
    Some(object) => resolve_indirect(file, object)
    None => return
  }
  match raw {
    @objects.PdfObject::Array(values) => {
      let output : Array[@objects.PdfObject] = []
      for value in values {
        output.push(
          materialize_font_object(file, resolve_indirect(file, value), page_id),
        )
      }
      dict[key] = @objects.PdfObject::Array(output)
    }
    _ => ()
  }
}
