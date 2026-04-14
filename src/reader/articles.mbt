///|
pub fn PdfDocument::threads(
  self : PdfDocument,
) -> Array[PdfArticleThread] raise PdfDocumentError {
  let owner = navigation_key(b"Threads")
  match self.catalog.entry(owner) {
    Some(value) => {
      let array = navigation_array(value, owner, "Threads")
      let threads : Array[PdfArticleThread] = []
      for item in array {
        threads.push(parse_article_thread(self, item, owner))
      }
      threads
    }
    None => []
  }
}

///|
pub fn PdfPage::article_beads(
  self : PdfPage,
) -> Array[PdfArticleBead] raise PdfDocumentError {
  let owner = navigation_key(b"B")
  match self.entry(owner) {
    Some(value) => {
      let array = navigation_array(value, owner, "page B")
      let beads : Array[PdfArticleBead] = []
      for item in array {
        beads.push(parse_article_bead_from_object(self.file, item, owner, None))
      }
      beads
    }
    None => []
  }
}

///|
fn parse_article_thread(
  document : PdfDocument,
  value : @objects.PdfObject,
  owner : @objects.PdfName,
) -> PdfArticleThread raise PdfDocumentError {
  let dict = require_navigation_dictionary(
    document.file,
    value,
    owner,
    "thread",
  )
  PdfArticleThread::{
    info: match dict.get(navigation_key(b"I")) {
      Some(@objects.PdfObject::Dictionary(info)) => Some(info)
      Some(_) => raise navigation_error(owner, "thread I must be a dictionary")
      None => None
    },
    metadata: dict.get(navigation_key(b"Metadata")),
    beads: match dict.get(navigation_key(b"F")) {
      Some(first) => parse_article_bead_ring(document, first, owner)
      None => []
    },
    raw_dict: dict,
  }
}

///|
fn parse_article_bead_ring(
  document : PdfDocument,
  first : @objects.PdfObject,
  owner : @objects.PdfName,
) -> Array[PdfArticleBead] raise PdfDocumentError {
  let seen : Map[@objects.ObjectId, Bool] = Map::new()
  let beads : Array[PdfArticleBead] = []
  let first_ref = match first {
    @objects.PdfObject::Ref(object_id) => Some(object_id)
    _ => None
  }
  let mut current : @objects.PdfObject? = Some(first)
  while current is Some(value) {
    let (object_id, dict) = load_article_bead_dictionary(
      document.file,
      value,
      owner,
      seen,
    )
    beads.push(parse_article_bead_dictionary(document, dict, owner))
    current = match dict.get(navigation_key(b"N")) {
      Some(@objects.PdfObject::Ref(next_id)) =>
        match (first_ref, object_id) {
          (Some(first_id), Some(_)) if next_id == first_id => None
          _ => Some(@objects.PdfObject::Ref(next_id))
        }
      Some(next) => Some(next)
      None => None
    }
  }
  beads
}

///|
fn load_article_bead_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.PdfName,
  seen : Map[@objects.ObjectId, Bool],
) -> (@objects.ObjectId?, @objects.PdfDictionary) raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) => {
      if seen.contains(object_id) {
        raise PdfDocumentError::CycleDetected(
          object_id, "article bead cycle detected",
        )
      }
      seen[object_id] = true
      match load_navigation_object(file, object_id, owner, "article bead") {
        @objects.PdfObject::Dictionary(dict) => (Some(object_id), dict)
        _ => raise navigation_error(owner, "article bead must be a dictionary")
      }
    }
    @objects.PdfObject::Dictionary(dict) => (None, dict)
    _ => raise navigation_error(owner, "article bead must be a dictionary")
  }
}

///|
fn parse_article_bead_dictionary(
  document : PdfDocument,
  dict : @objects.PdfDictionary,
  owner : @objects.PdfName,
) -> PdfArticleBead raise PdfDocumentError {
  let page_ref = match dict.get(navigation_key(b"P")) {
    Some(@objects.PdfObject::Ref(object_id)) => Some(object_id)
    Some(_) => raise navigation_error(owner, "bead P must be a page reference")
    None => None
  }
  let page_index = match page_ref {
    Some(object_id) => page_index_for_object_id(document, object_id)
    None => None
  }
  PdfArticleBead::{
    page_index,
    page_ref,
    rectangle: match dict.get(navigation_key(b"R")) {
      Some(value) => Some(navigation_rectangle(value, owner, "bead rectangle"))
      None => None
    },
    raw_dict: dict,
  }
}

///|
fn parse_article_bead_from_object(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.PdfName,
  page_ref : @objects.ObjectId?,
) -> PdfArticleBead raise PdfDocumentError {
  let dict = require_navigation_dictionary(file, value, owner, "page bead")
  PdfArticleBead::{
    page_index: None,
    page_ref,
    rectangle: match dict.get(navigation_key(b"R")) {
      Some(rect) => Some(navigation_rectangle(rect, owner, "bead rectangle"))
      None => None
    },
    raw_dict: dict,
  }
}
