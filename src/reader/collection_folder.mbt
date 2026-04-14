///|
fn parse_collection_folders(
  document : PdfDocument,
  value : @objects.PdfObject?,
) -> Array[PdfCollectionFolder] raise PdfDocumentError {
  let owner = navigation_key(b"Folders")
  match value {
    Some(root) => {
      let seen_objects : Map[@objects.ObjectId, Bool] = Map::new()
      let seen_ids : Map[Int, Bool] = Map::new()
      parse_collection_folder_siblings(
        document.file,
        root,
        None,
        owner,
        seen_objects,
        seen_ids,
      )
    }
    None => []
  }
}

///|
fn parse_collection_folder_siblings(
  file : PdfFile,
  first : @objects.PdfObject,
  parent_id : Int?,
  owner : @objects.PdfName,
  seen_objects : Map[@objects.ObjectId, Bool],
  seen_ids : Map[Int, Bool],
) -> Array[PdfCollectionFolder] raise PdfDocumentError {
  let folders : Array[PdfCollectionFolder] = []
  let mut current : @objects.PdfObject? = Some(first)
  while current is Some(value) {
    let dict = load_collection_folder_dictionary(
      file, value, owner, seen_objects,
    )
    let folder = parse_collection_folder(
      file, dict, parent_id, owner, seen_objects, seen_ids,
    )
    current = match dict.get(navigation_key(b"Next")) {
      Some(next) => Some(next)
      None => None
    }
    folders.push(folder)
  }
  folders
}

///|
fn load_collection_folder_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.PdfName,
  seen_objects : Map[@objects.ObjectId, Bool],
) -> @objects.PdfDictionary raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) => {
      if seen_objects.contains(object_id) {
        raise PdfDocumentError::CycleDetected(
          object_id, "collection folder cycle detected",
        )
      }
      seen_objects[object_id] = true
      match
        load_navigation_object(file, object_id, owner, "collection folder") {
        @objects.PdfObject::Dictionary(dict) => dict
        _ =>
          raise navigation_error(
            owner, "collection folder must be a dictionary",
          )
      }
    }
    @objects.PdfObject::Dictionary(dict) => dict
    _ => raise navigation_error(owner, "collection folder must be a dictionary")
  }
}

///|
fn parse_collection_folder(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  parent_id : Int?,
  owner : @objects.PdfName,
  seen_objects : Map[@objects.ObjectId, Bool],
  seen_ids : Map[Int, Bool],
) -> PdfCollectionFolder raise PdfDocumentError {
  let id = match dict.get(navigation_key(b"ID")) {
    Some(value) => navigation_int(value, owner, "folder ID")
    None => raise navigation_error(owner, "collection folder is missing /ID")
  }
  if id < 0 {
    raise navigation_error(owner, "collection folder ID must be non-negative")
  }
  if seen_ids.contains(id) {
    raise navigation_error(owner, "collection folder ID is repeated")
  }
  seen_ids[id] = true
  let name = match dict.get(navigation_key(b"Name")) {
    Some(value) => navigation_string(value, owner, "folder Name")
    None => raise navigation_error(owner, "collection folder is missing /Name")
  }
  PdfCollectionFolder::{
    id,
    name,
    parent_id,
    children: match dict.get(navigation_key(b"Child")) {
      Some(child) =>
        parse_collection_folder_siblings(
          file,
          child,
          Some(id),
          owner,
          seen_objects,
          seen_ids,
        )
      None => []
    },
    raw_dict: dict,
  }
}
