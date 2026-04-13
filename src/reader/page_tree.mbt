///|
fn build_page_tree_index(
  file : PdfFile,
  catalog : PdfCatalog,
) -> PageTreeIndex raise PdfDocumentError {
  let pages : Array[PageTreeRecord] = []
  let seen_pages : Map[@objects.ObjectId, Bool] = Map::new()
  let _ = traverse_pages_node(
    file,
    catalog.pages_ref,
    [],
    pages,
    seen_pages,
  )
  PageTreeIndex::{ pages }
}

///|
fn traverse_pages_node(
  file : PdfFile,
  node_id : @objects.ObjectId,
  ancestor_refs : Array[@objects.ObjectId],
  pages : Array[PageTreeRecord],
  seen_pages : Map[@objects.ObjectId, Bool],
) -> Int64 raise PdfDocumentError {
  if path_contains(ancestor_refs, node_id) {
    raise PdfDocumentError::CycleDetected(node_id, "page tree cycle detected")
  }

  if seen_pages.contains(node_id) {
    raise PdfDocumentError::InvalidPageTree(
      node_id,
      "page tree node is repeated",
    )
  }

  seen_pages[node_id] = true

  let node_dict = load_page_tree_dictionary(file, node_id, "page tree node")
  require_pages_node_type(node_id, node_dict)
  let kids = read_pages_kids(node_id, node_dict)
  let expected_count = read_pages_count(node_id, node_dict)

  let next_ancestors = copy_object_ids(ancestor_refs)
  next_ancestors.push(node_id)

  let mut actual_count = 0L
  for kid in kids {
    actual_count += traverse_page_tree_child(
      file,
      kid,
      node_id,
      next_ancestors,
      pages,
      seen_pages,
    )
  }

  if actual_count != expected_count {
    raise PdfDocumentError::InvalidPageTree(
      node_id,
      "page tree Count does not match descendant page count",
    )
  }

  actual_count
}

///|
fn traverse_page_tree_child(
  file : PdfFile,
  child_ref : @objects.ObjectId,
  parent_ref : @objects.ObjectId,
  ancestor_refs : Array[@objects.ObjectId],
  pages : Array[PageTreeRecord],
  seen_pages : Map[@objects.ObjectId, Bool],
) -> Int64 raise PdfDocumentError {
  let child_dict = load_page_tree_dictionary(file, child_ref, "page tree child")
  let type_name = read_type_name(child_dict, child_ref, "page tree child")
  match type_name {
    Some(name) if name == @objects.PdfName::new(b"Pages") =>
      traverse_pages_node(
        file, child_ref, ancestor_refs, pages, seen_pages,
      )
    Some(name) if name == @objects.PdfName::new(b"Page") =>
      append_page_record(
        child_ref,
        child_dict,
        parent_ref,
        ancestor_refs,
        pages,
      )
    Some(_) =>
      raise PdfDocumentError::InvalidPage(
        child_ref,
        "leaf page object must have /Type /Page",
      )
    None =>
      raise PdfDocumentError::InvalidPage(
        child_ref,
        "leaf page object must have /Type /Page",
      )
  }
}

///|
fn append_page_record(
  object_id : @objects.ObjectId,
  dict : @objects.PdfDictionary,
  parent_ref : @objects.ObjectId,
  ancestor_refs : Array[@objects.ObjectId],
  pages : Array[PageTreeRecord],
) -> Int64 raise PdfDocumentError {
  let page_index = pages.length()
  let record = PageTreeRecord::{
    object_id,
    dict,
    index: page_index,
    parent_ref: Some(parent_ref),
    ancestor_refs: copy_object_ids(ancestor_refs),
  }
  pages.push(record)
  1L
}

///|
fn require_pages_node_type(
  object_id : @objects.ObjectId,
  dict : @objects.PdfDictionary,
) -> Unit raise PdfDocumentError {
  let type_name = read_type_name(dict, object_id, "page tree node")
  match type_name {
    Some(name) if name == @objects.PdfName::new(b"Pages") => ()
    Some(_) =>
      raise PdfDocumentError::InvalidPageTree(
        object_id,
        "page tree node must have /Type /Pages",
      )
    None =>
      raise PdfDocumentError::InvalidPageTree(
        object_id,
        "page tree node must have /Type /Pages",
      )
  }
}

///|
fn read_pages_kids(
  object_id : @objects.ObjectId,
  dict : @objects.PdfDictionary,
) -> Array[@objects.ObjectId] raise PdfDocumentError {
  let kids_key = @objects.PdfName::new(b"Kids")
  let kids_value = match dict.get(kids_key) {
    Some(value) => value
    None =>
      raise PdfDocumentError::InvalidPageTree(
        object_id,
        "page tree node is missing /Kids",
      )
  }

  let kids_array = match kids_value {
    @objects.PdfObject::Array(values) => values
    _ =>
      raise PdfDocumentError::InvalidPageTree(
        object_id,
        "page tree /Kids entry must be an array of indirect references",
      )
  }

  let kids : Array[@objects.ObjectId] = []
  for kid in kids_array {
    match kid {
      @objects.PdfObject::Ref(object_id) => kids.push(object_id)
      _ =>
        raise PdfDocumentError::InvalidPageTree(
          object_id,
          "page tree /Kids entries must be indirect references",
        )
    }
  }
  kids
}

///|
fn read_pages_count(
  object_id : @objects.ObjectId,
  dict : @objects.PdfDictionary,
) -> Int64 raise PdfDocumentError {
  let count_key = @objects.PdfName::new(b"Count")
  let count_value = match dict.get(count_key) {
    Some(value) => value
    None =>
      raise PdfDocumentError::InvalidPageTree(
        object_id,
        "page tree node is missing /Count",
      )
  }

  let count = match count_value {
    @objects.PdfObject::Integer(value) => value
    _ =>
      raise PdfDocumentError::InvalidPageTree(
        object_id,
        "page tree /Count entry must be an integer",
      )
  }

  if count < 0L {
    raise PdfDocumentError::InvalidPageTree(
      object_id,
      "page tree /Count entry must be non-negative",
    )
  }
  count
}

///|
fn load_page_tree_dictionary(
  file : PdfFile,
  object_id : @objects.ObjectId,
  context : String,
) -> @objects.PdfDictionary raise PdfDocumentError {
  let object = try file.load_object(object_id) catch {
    error => raise PdfDocumentError::ReaderError(error)
  } noraise {
    value => value
  }

  match object {
    @objects.PdfObject::Dictionary(dict) => dict
    @objects.PdfObject::Null =>
      raise PdfDocumentError::InvalidPageTree(
        object_id,
        "\{context} is missing",
      )
    _ =>
      raise PdfDocumentError::InvalidPageTree(
        object_id,
        "\{context} must be a dictionary",
      )
  }
}

///|
fn read_type_name(
  dict : @objects.PdfDictionary,
  object_id : @objects.ObjectId,
  context : String,
) -> @objects.PdfName? raise PdfDocumentError {
  let type_key = @objects.PdfName::new(b"Type")
  match dict.get(type_key) {
    Some(@objects.PdfObject::Name(name)) => Some(name)
    Some(_) =>
      raise PdfDocumentError::InvalidPageTree(
        object_id,
        "\{context} /Type entry must be a name",
      )
    None => None
  }
}

///|
fn copy_object_ids(
  source : Array[@objects.ObjectId],
) -> Array[@objects.ObjectId] {
  let copy : Array[@objects.ObjectId] = []
  for object_id in source {
    copy.push(object_id)
  }
  copy
}

///|
fn path_contains(
  path : Array[@objects.ObjectId],
  object_id : @objects.ObjectId,
) -> Bool {
  for current in path {
    if current == object_id {
      return true
    }
  }
  false
}
