///|
fn parse_annotation_additional_actions(
  document : PdfDocument,
  value : @objects.PdfObject,
  source : PdfActionSource,
) -> PdfAnnotationAdditionalActions raise PdfDocumentError {
  let dict = resolve_additional_action_dictionary(document.file, value, source)
  PdfAnnotationAdditionalActions::{
    enter: parse_trigger_action(document, dict, action_key(b"E"), source),
    exit: parse_trigger_action(document, dict, action_key(b"X"), source),
    down: parse_trigger_action(document, dict, action_key(b"D"), source),
    up: parse_trigger_action(document, dict, action_key(b"U"), source),
    focus: parse_trigger_action(document, dict, action_key(b"Fo"), source),
    blur: parse_trigger_action(document, dict, action_key(b"Bl"), source),
    page_open: parse_trigger_action(document, dict, action_key(b"PO"), source),
    page_close: parse_trigger_action(document, dict, action_key(b"PC"), source),
    page_visible: parse_trigger_action(
      document,
      dict,
      action_key(b"PV"),
      source,
    ),
    page_invisible: parse_trigger_action(
      document,
      dict,
      action_key(b"PI"),
      source,
    ),
    raw_dict: dict,
  }
}

///|
fn parse_page_additional_actions(
  document : PdfDocument,
  value : @objects.PdfObject,
  source : PdfActionSource,
) -> PdfPageAdditionalActions raise PdfDocumentError {
  let dict = resolve_additional_action_dictionary(document.file, value, source)
  PdfPageAdditionalActions::{
    open: parse_trigger_action(document, dict, action_key(b"O"), source),
    close: parse_trigger_action(document, dict, action_key(b"C"), source),
    raw_dict: dict,
  }
}

///|
fn parse_form_field_additional_actions(
  document : PdfDocument,
  value : @objects.PdfObject,
  source : PdfActionSource,
) -> PdfFormFieldAdditionalActions raise PdfDocumentError {
  let dict = resolve_additional_action_dictionary(document.file, value, source)
  PdfFormFieldAdditionalActions::{
    keystroke: parse_trigger_action(document, dict, action_key(b"K"), source),
    format: parse_trigger_action(document, dict, action_key(b"F"), source),
    validate: parse_trigger_action(document, dict, action_key(b"V"), source),
    calculate: parse_trigger_action(document, dict, action_key(b"C"), source),
    raw_dict: dict,
  }
}

///|
fn parse_catalog_additional_actions(
  document : PdfDocument,
  value : @objects.PdfObject,
  source : PdfActionSource,
) -> PdfCatalogAdditionalActions raise PdfDocumentError {
  let dict = resolve_additional_action_dictionary(document.file, value, source)
  PdfCatalogAdditionalActions::{
    before_close: parse_trigger_action(
      document,
      dict,
      action_key(b"WC"),
      source,
    ),
    before_save: parse_trigger_action(document, dict, action_key(b"WS"), source),
    after_save: parse_trigger_action(document, dict, action_key(b"DS"), source),
    before_print: parse_trigger_action(
      document,
      dict,
      action_key(b"WP"),
      source,
    ),
    after_print: parse_trigger_action(document, dict, action_key(b"DP"), source),
    raw_dict: dict,
  }
}

///|
fn parse_trigger_action(
  document : PdfDocument,
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  source : PdfActionSource,
) -> PdfAction? raise PdfDocumentError {
  match dict.get(key) {
    Some(value) => Some(parse_action_object(document, value, source))
    None => None
  }
}

///|
fn resolve_additional_action_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
  source : PdfActionSource,
) -> @objects.PdfDictionary raise PdfDocumentError {
  let _ = source
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
            None,
            "additional-action dictionary must resolve to a dictionary",
          )
      }
    }
    @objects.PdfObject::Dictionary(dict) => dict
    _ =>
      raise action_error(
        None,
        None,
        "additional-action entry must be a dictionary",
      )
  }
}

///|
/// Returns standard action-trigger ordering notes as structural metadata. No
/// viewer event is dispatched by this helper.
pub fn PdfActionTriggerOrdering::standard() -> PdfActionTriggerOrdering {
  PdfActionTriggerOrdering::{
    activation_precedence: [
      PdfActionTrigger::AnnotationActivation,
      PdfActionTrigger::AnnotationMouseUp,
    ],
    page_open_order: [
      PdfActionTrigger::CatalogOpenAction,
      PdfActionTrigger::PageOpen,
      PdfActionTrigger::AnnotationPageOpen,
    ],
    page_close_order: [
      PdfActionTrigger::AnnotationPageClose,
      PdfActionTrigger::PageClose,
    ],
  }
}
