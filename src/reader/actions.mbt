///|
/// Parses a caller-supplied raw action object through this document's indirect
/// object loader. The parser returns structural metadata only.
pub fn PdfDocument::parse_action(
  self : PdfDocument,
  value : @objects.PdfObject,
) -> PdfAction raise PdfDocumentError {
  parse_action_object(self, value, PdfActionSource::RawObject(None))
}

///|
pub fn PdfDocument::parse_action_from_object(
  self : PdfDocument,
  value : @objects.PdfObject,
  object_id : @objects.ObjectId?,
) -> PdfAction raise PdfDocumentError {
  parse_action_object(self, value, PdfActionSource::RawObject(object_id))
}

///|
pub fn PdfDocument::open_action(
  self : PdfDocument,
) -> PdfCatalogOpenAction? raise PdfDocumentError {
  match self.catalog.entry(action_key(b"OpenAction")) {
    Some(value) => {
      let resolved = resolve_navigation_direct(
        self.file,
        value,
        action_key(b"OpenAction"),
        "Catalog OpenAction",
      )
      match resolved {
        @objects.PdfObject::Dictionary(dict) if dict.get(action_key(b"S"))
          is Some(_) =>
          Some(
            PdfCatalogOpenAction::Action(
              parse_action_object(
                self,
                value,
                PdfActionSource::Catalog(self.catalog.object_id),
              ),
            ),
          )
        _ =>
          Some(
            PdfCatalogOpenAction::Destination(
              parse_destination_object(self, value, action_key(b"OpenAction")),
            ),
          )
      }
    }
    None => None
  }
}

///|
pub fn PdfDocument::catalog_additional_actions(
  self : PdfDocument,
) -> PdfCatalogAdditionalActions? raise PdfDocumentError {
  match self.catalog.entry(action_key(b"AA")) {
    Some(value) =>
      Some(
        parse_catalog_additional_actions(
          self,
          value,
          PdfActionSource::Catalog(self.catalog.object_id),
        ),
      )
    None => None
  }
}

///|
pub fn PdfDocument::catalog_uri(
  self : PdfDocument,
) -> PdfCatalogUri? raise PdfDocumentError {
  match self.catalog.entry(action_key(b"URI")) {
    Some(value) => {
      let dict = resolve_catalog_uri_dictionary(self.file, value)
      let base = match dict.get(action_key(b"Base")) {
        Some(@objects.PdfObject::String(bytes)) => Some(bytes)
        Some(_) =>
          raise action_error(
            None,
            Some(action_key(b"URI")),
            "Catalog URI Base must be a string",
          )
        None => None
      }
      Some(PdfCatalogUri::{ base, raw_dict: dict })
    }
    None => None
  }
}

///|
pub fn PdfPage::additional_actions(
  self : PdfPage,
) -> PdfPageAdditionalActions? raise PdfDocumentError {
  match self.entry(action_key(b"AA")) {
    Some(value) => {
      let document = PdfDocument::{
        file: self.file,
        catalog: load_catalog(self.file),
        page_index: None,
      }
      Some(
        parse_page_additional_actions(
          document,
          value,
          PdfActionSource::Page(self.object_id()),
        ),
      )
    }
    None => None
  }
}

///|
/// Parses an annotation-owned action hand-off without executing it. The
/// annotation model also preserves text reply State and StateModel vocabulary
/// from Table 174 separately from action activation.
pub fn PdfDocument::annotation_action(
  self : PdfDocument,
  annotation : PdfAnnotation,
) -> PdfAction? raise PdfDocumentError {
  match annotation_action_value(annotation) {
    Some(value) =>
      Some(
        parse_action_object(
          self,
          value,
          PdfActionSource::Annotation(annotation.object_id),
        ),
      )
    None => None
  }
}

///|
pub fn PdfDocument::annotation_previous_uri_action(
  self : PdfDocument,
  annotation : PdfAnnotation,
) -> PdfAction? raise PdfDocumentError {
  match annotation.specific {
    PdfAnnotationSpecific::Link(link) =>
      match link.previous_uri_action {
        Some(value) =>
          Some(
            parse_action_object(
              self,
              value,
              PdfActionSource::Annotation(annotation.object_id),
            ),
          )
        None => None
      }
    _ => None
  }
}

///|
pub fn PdfDocument::annotation_additional_actions(
  self : PdfDocument,
  annotation : PdfAnnotation,
) -> PdfAnnotationAdditionalActions? raise PdfDocumentError {
  match annotation_additional_action_value(annotation) {
    Some(value) =>
      Some(
        parse_annotation_additional_actions(
          self,
          value,
          PdfActionSource::Annotation(annotation.object_id),
        ),
      )
    None => None
  }
}

///|
pub fn PdfDocument::outline_item_action(
  self : PdfDocument,
  item : PdfOutlineItem,
) -> PdfAction? raise PdfDocumentError {
  match item.action {
    Some(value) =>
      Some(parse_action_object(self, value, PdfActionSource::Outline))
    None => None
  }
}

///|
pub fn PdfPage::navigation_node_forward_action(
  self : PdfPage,
  node : PdfNavigationNode,
) -> PdfAction? raise PdfDocumentError {
  match node.forward_action {
    Some(value) => {
      let document = PdfDocument::{
        file: self.file,
        catalog: load_catalog(self.file),
        page_index: None,
      }
      Some(
        parse_action_object(
          document,
          value,
          PdfActionSource::Presentation(Some(self.object_id())),
        ),
      )
    }
    None => None
  }
}

///|
pub fn PdfPage::navigation_node_backward_action(
  self : PdfPage,
  node : PdfNavigationNode,
) -> PdfAction? raise PdfDocumentError {
  match node.backward_action {
    Some(value) => {
      let document = PdfDocument::{
        file: self.file,
        catalog: load_catalog(self.file),
        page_index: None,
      }
      Some(
        parse_action_object(
          document,
          value,
          PdfActionSource::Presentation(Some(self.object_id())),
        ),
      )
    }
    None => None
  }
}

///|
pub fn PdfDocument::parse_annotation_additional_action_object(
  self : PdfDocument,
  value : @objects.PdfObject,
  object_id : @objects.ObjectId?,
) -> PdfAnnotationAdditionalActions raise PdfDocumentError {
  parse_annotation_additional_actions(
    self,
    value,
    PdfActionSource::Annotation(object_id),
  )
}

///|
pub fn PdfDocument::parse_form_field_additional_action_object(
  self : PdfDocument,
  value : @objects.PdfObject,
  object_id : @objects.ObjectId?,
) -> PdfFormFieldAdditionalActions raise PdfDocumentError {
  parse_form_field_additional_actions(
    self,
    value,
    PdfActionSource::FormField(object_id),
  )
}

///|
fn annotation_action_value(annotation : PdfAnnotation) -> @objects.PdfObject? {
  match annotation.specific {
    PdfAnnotationSpecific::Link(link) => link.action
    PdfAnnotationSpecific::Screen(screen) => screen.action
    PdfAnnotationSpecific::Widget(widget) => widget.action
    _ => None
  }
}

///|
fn annotation_additional_action_value(
  annotation : PdfAnnotation,
) -> @objects.PdfObject? {
  match annotation.common.additional_actions {
    Some(value) => Some(value)
    None =>
      match annotation.specific {
        PdfAnnotationSpecific::Screen(screen) => screen.additional_actions
        PdfAnnotationSpecific::Widget(widget) => widget.additional_actions
        _ => None
      }
  }
}

///|
fn resolve_catalog_uri_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
) -> @objects.PdfDictionary raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) => {
      let loaded = try file.load_object(object_id) catch {
        error => raise PdfDocumentError::ReaderError(error)
      } noraise {
        object => object
      }
      match loaded {
        @objects.PdfObject::Dictionary(dict) => dict
        _ =>
          raise action_error(
            Some(object_id),
            Some(action_key(b"URI")),
            "Catalog URI must resolve to a dictionary",
          )
      }
    }
    @objects.PdfObject::Dictionary(dict) => dict
    _ =>
      raise action_error(
        None,
        Some(action_key(b"URI")),
        "Catalog URI must be a dictionary",
      )
  }
}
