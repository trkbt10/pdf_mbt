///|
pub(all) struct TextPageOptions {
  initial_ctm : @text.TextMatrix?
  materialize_resources : Bool
} derive(Eq, Debug)

///|
pub fn TextPageOptions::default() -> TextPageOptions {
  TextPageOptions::{ initial_ctm: None, materialize_resources: true }
}

///|
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
pub fn PdfPage::text_program(
  self : PdfPage,
  options : TextPageOptions,
) -> @text.TextProgram raise PdfDocumentError {
  let text_resources = if options.materialize_resources {
    self.text_resources()
  } else {
    let content_resources = self.content_resources()
    try
      @text.TextResources::from_content_resources(content_resources, 0L)
    catch {
      error => raise PdfDocumentError::TextError(error)
    } noraise {
      resources => resources
    }
  }
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
pub fn PdfPage::extracted_text(
  self : PdfPage,
  options : TextPageOptions,
) -> @text.ExtractedText raise PdfDocumentError {
  @text.ExtractedText::from_spans(self.text_program(options).spans)
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
    Some(@objects.PdfObject::Dictionary(dict)) => {
      let materialized : @objects.PdfDictionary = Map::new()
      for resource_name, object in dict {
        materialized[resource_name] = materialize_text_resource_object(
          file, object, category, page_id,
        )
      }
      resources[key] = @objects.PdfObject::Dictionary(materialized)
    }
    Some(@objects.PdfObject::Ref(id)) => {
      let loaded = load_document_object(file, id)
      match loaded {
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
    }
    _ => ()
  }
}

///|
fn materialize_text_resource_object(
  file : PdfFile,
  object : @objects.PdfObject,
  category : Bytes,
  page_id : @objects.ObjectId,
) -> @objects.PdfObject raise PdfDocumentError {
  match object {
    @objects.PdfObject::Ref(id) => {
      let loaded = load_document_object(file, id)
      if category == b"Font" {
        materialize_font_object(file, loaded, page_id)
      } else {
        loaded
      }
    }
    _ =>
      if category == b"Font" {
        materialize_font_object(file, object, page_id)
      } else {
        object
      }
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
  materialize_font_entry(file, output, b"FontDescriptor", page_id)
  materialize_descendant_fonts(file, output, page_id)
  output
}

///|
fn materialize_font_entry(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  key : Bytes,
  page_id : @objects.ObjectId,
) -> Unit raise PdfDocumentError {
  let name = @objects.PdfName::new(key)
  match dict.get(name) {
    Some(@objects.PdfObject::Ref(id)) => {
      let loaded = load_document_object(file, id)
      dict[name] = if key == b"FontDescriptor" {
        materialize_font_descriptor(file, loaded, page_id)
      } else {
        loaded
      }
    }
    _ => ()
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
fn materialize_font_program(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  key : Bytes,
) -> Unit raise PdfDocumentError {
  let name = @objects.PdfName::new(key)
  match dict.get(name) {
    Some(@objects.PdfObject::Ref(id)) =>
      dict[name] = load_document_object(file, id)
    _ => ()
  }
}

///|
fn materialize_descendant_fonts(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  page_id : @objects.ObjectId,
) -> Unit raise PdfDocumentError {
  let key = @objects.PdfName::new(b"DescendantFonts")
  match dict.get(key) {
    Some(@objects.PdfObject::Array(values)) => {
      let output : Array[@objects.PdfObject] = []
      for value in values {
        match value {
          @objects.PdfObject::Ref(id) =>
            output.push(
              materialize_font_object(
                file,
                load_document_object(file, id),
                page_id,
              ),
            )
          _ => output.push(materialize_font_object(file, value, page_id))
        }
      }
      dict[key] = @objects.PdfObject::Array(output)
    }
    _ => ()
  }
}
