///|
/// Public resource dictionary category model for content streams per §7.8.3:
/// graphics state ExtGState, ColorSpace, Pattern, Shading, XObject, Font,
/// Properties, and deprecated ProcSet procedure sets.
pub(all) enum ResourceCategory {
  ExtGState
  ColorSpace
  Pattern
  Shading
  XObject
  Font
  Properties
  ProcSet
} derive(Eq, Debug)

///|
/// Resource context for content stream parsing. It preserves the raw page or
/// content resource dictionary, supports exact category/name lookup, returns
/// absent categories and absent names as missing values, and never recursively
/// loads indirect objects.
pub(all) struct ContentResources {
  dictionary : @objects.PdfDictionary?
} derive(Eq, Debug)

///|
/// Creates an empty content resource context for pages or streams with no
/// explicit resource dictionary.
pub fn ContentResources::empty() -> ContentResources {
  ContentResources::{ dictionary: None }
}

///|
/// Creates a content resource context from a direct resource dictionary.
pub fn ContentResources::from_dictionary(
  dictionary : @objects.PdfDictionary,
) -> ContentResources {
  ContentResources::{ dictionary: Some(dictionary) }
}

///|
/// Creates a content resource context from an optional page Resources object.
/// `None` and `Null` become an empty context; malformed explicit resource
/// dictionary shapes are reported as content resource failures.
pub fn ContentResources::from_object(
  object : @objects.PdfObject?,
  offset : Int64,
) -> ContentResources raise PdfContentError {
  match object {
    None => ContentResources::empty()
    Some(Null) => ContentResources::empty()
    Some(Dictionary(dictionary)) =>
      ContentResources::from_dictionary(dictionary)
    Some(_) =>
      raise ResourceFailure(
        offset, "Resources entry for content stream must be a dictionary",
      )
  }
}

///|
/// Returns the raw resource category object for graphics state, ColorSpace,
/// Pattern, Shading, XObject, Font, Properties, or ProcSet. Missing categories
/// return `None`; malformed explicit category values raise `ResourceFailure`.
pub fn ContentResources::category_object(
  self : ContentResources,
  category : ResourceCategory,
) -> @objects.PdfObject? raise PdfContentError {
  match self.dictionary {
    None => None
    Some(dictionary) =>
      match dictionary.get(category.name()) {
        None => None
        Some(value) => {
          validate_resource_category_value(category, value)
          Some(value)
        }
      }
  }
}

///|
/// Resolves a named resource by exact resource name from the selected category
/// subdictionary without recursively loading indirect objects. Absent
/// categories and absent names return `None`.
pub fn ContentResources::lookup_resource(
  self : ContentResources,
  category : ResourceCategory,
  name : @objects.PdfName,
) -> @objects.PdfObject? raise PdfContentError {
  match self.category_object(category) {
    None => None
    Some(Dictionary(dictionary)) => dictionary.get(name)
    Some(Array(values)) if category == ProcSet => lookup_proc_set(values, name)
    Some(_) =>
      raise ResourceFailure(
        0L,
        "resource category " +
        category.label() +
        " must be a dictionary for named lookup",
      )
  }
}

///|
/// Selects the resource scope for a Form XObject content stream. When the Form
/// XObject stream dictionary provides its own `Resources` entry, that
/// dictionary is used instead of the parent/page resource context; when absent,
/// lookup falls back to the parent resources. Malformed Form XObject resource
/// shapes are reported as content errors.
pub fn ContentResources::for_form_xobject(
  self : ContentResources,
  stream : @objects.PdfStream,
  offset : Int64,
) -> ContentResources raise PdfContentError {
  match stream.dict.get(@objects.PdfName::new(b"Resources")) {
    None => self
    Some(Dictionary(dictionary)) =>
      ContentResources::from_dictionary(dictionary)
    Some(_) =>
      raise ResourceFailure(
        offset, "Form XObject Resources entry must be a dictionary",
      )
  }
}

///|
pub fn ResourceCategory::name(self : ResourceCategory) -> @objects.PdfName {
  @objects.PdfName::new(self.label_bytes())
}

///|
fn ResourceCategory::label(self : ResourceCategory) -> String {
  self.name().to_text()
}

///|
fn ResourceCategory::label_bytes(self : ResourceCategory) -> Bytes {
  match self {
    ExtGState => b"ExtGState"
    ColorSpace => b"ColorSpace"
    Pattern => b"Pattern"
    Shading => b"Shading"
    XObject => b"XObject"
    Font => b"Font"
    Properties => b"Properties"
    ProcSet => b"ProcSet"
  }
}

///|
fn validate_resource_category_value(
  category : ResourceCategory,
  value : @objects.PdfObject,
) -> Unit raise PdfContentError {
  match value {
    Dictionary(_) => ()
    Array(_) if category == ProcSet => ()
    _ =>
      raise ResourceFailure(
        0L,
        "resource category " + category.label() + " must be a dictionary",
      )
  }
}

///|
fn lookup_proc_set(
  values : Array[@objects.PdfObject],
  name : @objects.PdfName,
) -> @objects.PdfObject? {
  for value in values {
    match value {
      Name(proc_name) if proc_name == name => return Some(value)
      _ => ()
    }
  }
  None
}
