///|
pub fn PdfDocument::outline(
  self : PdfDocument,
) -> PdfOutline? raise PdfDocumentError {
  let owner = navigation_key(b"Outlines")
  match self.catalog.entry(owner) {
    Some(value) => {
      let root = require_navigation_dictionary(
        self.file,
        value,
        owner,
        "Outlines",
      )
      Some(PdfOutline::{
        count: outline_optional_count(root, owner),
        items: parse_outline_children(self, root, owner),
      })
    }
    None => None
  }
}

///|
fn parse_outline_children(
  document : PdfDocument,
  dict : @objects.PdfDictionary,
  owner : @objects.PdfName,
) -> Array[PdfOutlineItem] raise PdfDocumentError {
  match dict.get(navigation_key(b"First")) {
    Some(first) => {
      let seen : Map[@objects.ObjectId, Bool] = Map::new()
      parse_outline_sibling_list(document, first, owner, seen)
    }
    None => []
  }
}

///|
fn parse_outline_sibling_list(
  document : PdfDocument,
  first : @objects.PdfObject,
  owner : @objects.PdfName,
  seen : Map[@objects.ObjectId, Bool],
) -> Array[PdfOutlineItem] raise PdfDocumentError {
  let items : Array[PdfOutlineItem] = []
  let mut current : @objects.PdfObject? = Some(first)
  while current is Some(value) {
    let (object_id, dict) = load_outline_item_dictionary(
      document.file,
      value,
      owner,
      seen,
    )
    items.push(parse_outline_item(document, dict, owner, seen))
    current = match dict.get(navigation_key(b"Next")) {
      Some(next) => Some(next)
      None => None
    }
    let _ = object_id
  }
  items
}

///|
fn load_outline_item_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.PdfName,
  seen : Map[@objects.ObjectId, Bool],
) -> (@objects.ObjectId?, @objects.PdfDictionary) raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) => {
      if seen.contains(object_id) {
        raise PdfDocumentError::CycleDetected(
          object_id, "outline item cycle detected",
        )
      }
      seen[object_id] = true
      match load_navigation_object(file, object_id, owner, "outline item") {
        @objects.PdfObject::Dictionary(dict) => (Some(object_id), dict)
        _ => raise navigation_error(owner, "outline item must be a dictionary")
      }
    }
    @objects.PdfObject::Dictionary(dict) => (None, dict)
    _ => raise navigation_error(owner, "outline item must be a dictionary")
  }
}

///|
fn parse_outline_item(
  document : PdfDocument,
  dict : @objects.PdfDictionary,
  owner : @objects.PdfName,
  seen : Map[@objects.ObjectId, Bool],
) -> PdfOutlineItem raise PdfDocumentError {
  let title = match dict.get(navigation_key(b"Title")) {
    Some(value) => navigation_string(value, owner, "outline Title")
    None => raise navigation_error(owner, "outline item is missing /Title")
  }
  if dict.get(navigation_key(b"Dest")) is Some(_) &&
    dict.get(navigation_key(b"A")) is Some(_) {
    raise navigation_error(
      owner, "outline item must not contain both /Dest and /A",
    )
  }
  PdfOutlineItem::{
    title,
    count: outline_optional_count(dict, owner),
    color: outline_color(dict, owner),
    italic: outline_flag(dict, 1),
    bold: outline_flag(dict, 2),
    destination: outline_destination(document, dict, owner),
    action: dict.get(navigation_key(b"A")),
    structure_element: dict.get(navigation_key(b"SE")),
    children: match dict.get(navigation_key(b"First")) {
      Some(first) => parse_outline_sibling_list(document, first, owner, seen)
      None => []
    },
  }
}

///|
fn outline_optional_count(
  dict : @objects.PdfDictionary,
  owner : @objects.PdfName,
) -> Int? raise PdfDocumentError {
  match dict.get(navigation_key(b"Count")) {
    Some(value) => Some(navigation_int(value, owner, "outline Count"))
    None => None
  }
}

///|
fn outline_color(
  dict : @objects.PdfDictionary,
  owner : @objects.PdfName,
) -> Array[Double] raise PdfDocumentError {
  match dict.get(navigation_key(b"C")) {
    Some(value) => {
      let color = navigation_color_components(value, owner, "outline color", 3)
      if color.length() != 3 {
        raise navigation_error(
          owner, "outline color must have three components",
        )
      }
      color
    }
    None => []
  }
}

///|
fn outline_flag(dict : @objects.PdfDictionary, bit : Int64) -> Bool {
  match dict.get(navigation_key(b"F")) {
    Some(@objects.PdfObject::Integer(flags)) => (flags & bit) != 0L
    _ => false
  }
}

///|
fn outline_destination(
  document : PdfDocument,
  dict : @objects.PdfDictionary,
  owner : @objects.PdfName,
) -> PdfDestination? raise PdfDocumentError {
  match dict.get(navigation_key(b"Dest")) {
    Some(value) => Some(parse_destination_object(document, value, owner))
    None => None
  }
}
