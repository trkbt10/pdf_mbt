///|
fn enumerate_number_tree(
  file : PdfFile,
  root : @objects.PdfObject,
  owner : @objects.PdfName,
) -> Array[PdfNumberTreeEntry] raise PdfDocumentError {
  let seen : Map[@objects.ObjectId, Bool] = Map::new()
  let entries : Array[PdfNumberTreeEntry] = []
  enumerate_number_tree_object(file, root, owner, seen, entries)
  sort_number_tree_entries(entries)
  reject_duplicate_number_tree_entries(entries, owner)
  entries
}

///|
fn lookup_number_tree_le(
  file : PdfFile,
  root : @objects.PdfObject,
  key : Int,
  owner : @objects.PdfName,
) -> PdfNumberTreeEntry? raise PdfDocumentError {
  let entries = enumerate_number_tree(file, root, owner)
  let mut found : PdfNumberTreeEntry? = None
  for entry in entries {
    if entry.key <= key {
      found = Some(entry)
    }
  }
  found
}

///|
fn enumerate_number_tree_object(
  file : PdfFile,
  node : @objects.PdfObject,
  owner : @objects.PdfName,
  seen : Map[@objects.ObjectId, Bool],
  entries : Array[PdfNumberTreeEntry],
) -> Unit raise PdfDocumentError {
  match node {
    @objects.PdfObject::Ref(object_id) => {
      if seen.contains(object_id) {
        raise PdfDocumentError::CycleDetected(
          object_id,
          owner.to_text() + " number tree cycle detected",
        )
      }
      seen[object_id] = true
      let loaded = load_navigation_object(file, object_id, owner, "number tree")
      enumerate_number_tree_object(file, loaded, owner, seen, entries)
    }
    @objects.PdfObject::Dictionary(dict) =>
      enumerate_number_tree_dictionary(file, dict, owner, seen, entries)
    _ => raise navigation_error(owner, "number tree node must be a dictionary")
  }
}

///|
fn enumerate_number_tree_dictionary(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  owner : @objects.PdfName,
  seen : Map[@objects.ObjectId, Bool],
  entries : Array[PdfNumberTreeEntry],
) -> Unit raise PdfDocumentError {
  let nums_key = @objects.PdfName::new(b"Nums")
  let kids_key = @objects.PdfName::new(b"Kids")
  match (dict.get(nums_key), dict.get(kids_key)) {
    (Some(_), Some(_)) =>
      raise navigation_error(
        owner, "number tree node must not contain both /Nums and /Kids",
      )
    (Some(nums), None) => enumerate_number_tree_nums(nums, owner, entries)
    (None, Some(kids)) =>
      enumerate_number_tree_kids(file, kids, owner, seen, entries)
    (None, None) =>
      raise navigation_error(owner, "number tree node must have /Nums or /Kids")
  }
}

///|
fn enumerate_number_tree_nums(
  nums_value : @objects.PdfObject,
  owner : @objects.PdfName,
  entries : Array[PdfNumberTreeEntry],
) -> Unit raise PdfDocumentError {
  let common_entries = try
    @common_data.validate_number_tree_pairs(nums_value)
  catch {
    error => raise number_tree_common_error(owner, error)
  } noraise {
    values => values
  }
  for entry in common_entries {
    entries.push(PdfNumberTreeEntry::{ key: entry.key, value: entry.value })
  }
}

///|
fn enumerate_number_tree_kids(
  file : PdfFile,
  kids_value : @objects.PdfObject,
  owner : @objects.PdfName,
  seen : Map[@objects.ObjectId, Bool],
  entries : Array[PdfNumberTreeEntry],
) -> Unit raise PdfDocumentError {
  let kids = navigation_array(kids_value, owner, "number tree /Kids")
  for kid in kids {
    match kid {
      @objects.PdfObject::Ref(object_id) => {
        if seen.contains(object_id) {
          raise PdfDocumentError::CycleDetected(
            object_id,
            owner.to_text() + " number tree cycle detected",
          )
        }
        seen[object_id] = true
        let loaded = load_navigation_object(
          file, object_id, owner, "number tree",
        )
        enumerate_number_tree_object(file, loaded, owner, seen, entries)
      }
      _ =>
        raise navigation_error(
          owner, "number tree /Kids entries must be indirect references",
        )
    }
  }
}

///|
fn sort_number_tree_entries(entries : Array[PdfNumberTreeEntry]) -> Unit {
  let mut index = 1
  while index < entries.length() {
    let current = entries[index]
    let mut slot = index
    while slot > 0 && entries[slot - 1].key > current.key {
      entries[slot] = entries[slot - 1]
      slot -= 1
    }
    entries[slot] = current
    index += 1
  }
}

///|
fn reject_duplicate_number_tree_entries(
  entries : Array[PdfNumberTreeEntry],
  owner : @objects.PdfName,
) -> Unit raise PdfDocumentError {
  let mut index = 1
  while index < entries.length() {
    if entries[index - 1].key == entries[index].key {
      raise navigation_error(owner, "number tree keys must be unique")
    }
    index += 1
  }
}
