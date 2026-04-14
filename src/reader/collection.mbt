///|
pub fn PdfDocument::collection(
  self : PdfDocument,
) -> PdfCollection? raise PdfDocumentError {
  let owner = navigation_key(b"Collection")
  match self.catalog.entry(owner) {
    Some(value) => {
      let dict = require_navigation_dictionary(
        self.file,
        value,
        owner,
        "Collection",
      )
      Some(PdfCollection::{
        schema: parse_collection_schema(
          dict.get(navigation_key(b"Schema")),
          owner,
        ),
        initial_document: parse_collection_initial_document(
          dict.get(navigation_key(b"D")),
          owner,
        ),
        view: parse_collection_view(dict.get(navigation_key(b"View")), owner),
        sort: parse_collection_sort(dict.get(navigation_key(b"Sort")), owner),
        colors: parse_collection_colors(dict.get(navigation_key(b"C")), owner),
        files: parse_collection_files(self),
        folders: parse_collection_folders(
          self,
          dict.get(navigation_key(b"Folders")),
        ),
        navigator: parse_collection_navigator(
          dict.get(navigation_key(b"Navigator")),
          owner,
          self.file,
        ),
        raw_dict: dict,
      })
    }
    None => None
  }
}

///|
fn parse_collection_schema(
  value : @objects.PdfObject?,
  owner : @objects.PdfName,
) -> Array[PdfCollectionSchemaField] raise PdfDocumentError {
  match value {
    Some(@objects.PdfObject::Dictionary(schema)) => {
      let fields : Array[PdfCollectionSchemaField] = []
      schema.each((key, item) => {
        match item {
          @objects.PdfObject::Dictionary(dict) =>
            fields.push(PdfCollectionSchemaField::{
              key,
              subtype: match dict.get(navigation_key(b"Subtype")) {
                Some(@objects.PdfObject::Name(name)) => Some(name)
                _ => None
              },
              name: match dict.get(navigation_key(b"N")) {
                Some(@objects.PdfObject::String(bytes)) => Some(bytes)
                _ => None
              },
              order: match dict.get(navigation_key(b"O")) {
                Some(value) =>
                  Some(navigation_int(value, owner, "collection field order"))
                None => None
              },
              visible: navigation_bool_or_default(
                dict,
                navigation_key(b"V"),
                true,
                owner,
              ),
              editable: navigation_bool_or_default(
                dict,
                navigation_key(b"E"),
                false,
                owner,
              ),
              raw_dict: dict,
            })
          _ =>
            raise navigation_error(
              owner, "collection schema fields must be dictionaries",
            )
        }
      })
      fields
    }
    Some(_) =>
      raise navigation_error(owner, "Collection Schema must be a dictionary")
    None => []
  }
}

///|
fn parse_collection_initial_document(
  value : @objects.PdfObject?,
  owner : @objects.PdfName,
) -> Bytes? raise PdfDocumentError {
  match value {
    Some(object) => Some(navigation_string(object, owner, "Collection D"))
    None => None
  }
}

///|
fn parse_collection_view(
  value : @objects.PdfObject?,
  owner : @objects.PdfName,
) -> PdfCollectionView raise PdfDocumentError {
  match value {
    Some(object) => {
      let name = navigation_name(object, owner, "Collection View")
      if name == navigation_key(b"D") {
        PdfCollectionView::Details
      } else if name == navigation_key(b"T") {
        PdfCollectionView::Tile
      } else if name == navigation_key(b"H") {
        PdfCollectionView::Hidden
      } else {
        PdfCollectionView::Custom(name)
      }
    }
    None => PdfCollectionView::Details
  }
}

///|
fn parse_collection_sort(
  value : @objects.PdfObject?,
  owner : @objects.PdfName,
) -> PdfCollectionSort? raise PdfDocumentError {
  match value {
    Some(@objects.PdfObject::Dictionary(dict)) => {
      let keys = parse_collection_sort_keys(
        dict.get(navigation_key(b"S")),
        owner,
      )
      Some(PdfCollectionSort::{
        keys,
        ascending: parse_collection_sort_ascending(
          dict.get(navigation_key(b"A")),
          keys.length(),
          owner,
        ),
        raw_dict: dict,
      })
    }
    Some(_) =>
      raise navigation_error(owner, "Collection Sort must be a dictionary")
    None => None
  }
}

///|
fn parse_collection_sort_keys(
  value : @objects.PdfObject?,
  owner : @objects.PdfName,
) -> Array[@objects.PdfName] raise PdfDocumentError {
  let keys : Array[@objects.PdfName] = []
  match value {
    Some(@objects.PdfObject::Name(name)) => keys.push(name)
    Some(@objects.PdfObject::Array(values)) =>
      for item in values {
        keys.push(navigation_name(item, owner, "collection sort key"))
      }
    Some(_) =>
      raise navigation_error(owner, "Collection Sort S must be a name or array")
    None => ()
  }
  keys
}

///|
fn parse_collection_sort_ascending(
  value : @objects.PdfObject?,
  count : Int,
  owner : @objects.PdfName,
) -> Array[Bool] raise PdfDocumentError {
  let out : Array[Bool] = []
  match value {
    Some(@objects.PdfObject::Boolean(value)) => {
      let mut index = 0
      while index < count {
        out.push(value)
        index += 1
      }
    }
    Some(@objects.PdfObject::Array(values)) =>
      for item in values {
        match item {
          @objects.PdfObject::Boolean(value) => out.push(value)
          _ =>
            raise navigation_error(
              owner, "Collection Sort A entries must be booleans",
            )
        }
      }
    Some(_) =>
      raise navigation_error(
        owner, "Collection Sort A must be boolean or array",
      )
    None => {
      let mut index = 0
      while index < count {
        out.push(true)
        index += 1
      }
    }
  }
  out
}

///|
fn parse_collection_colors(
  value : @objects.PdfObject?,
  owner : @objects.PdfName,
) -> Array[Double] raise PdfDocumentError {
  match value {
    Some(object) =>
      navigation_color_components(object, owner, "collection color", 3)
    None => []
  }
}

///|
fn parse_collection_files(
  document : PdfDocument,
) -> Array[PdfCollectionFile] raise PdfDocumentError {
  let entries = document.name_tree_entries(NameTreeCategory::EmbeddedFiles)
  let files : Array[PdfCollectionFile] = []
  for entry in entries {
    files.push(PdfCollectionFile::{
      name: entry.key,
      file_spec: entry.value,
      folder_id: collection_folder_id_from_name(entry.key),
    })
  }
  files
}

///|
fn collection_folder_id_from_name(name : Bytes) -> Int? {
  if name.length() == 0 || name[0] != b'[' {
    return None
  }
  let mut index = 1
  let mut value = 0
  while index < name.length() {
    let byte = name[index]
    if byte >= b'0' && byte <= b'9' {
      value = value * 10 + byte.to_int() - b'0'.to_int()
      index += 1
    } else if byte == b']' && index > 1 {
      return Some(value)
    } else {
      return None
    }
  }
  None
}

///|
fn parse_collection_navigator(
  value : @objects.PdfObject?,
  owner : @objects.PdfName,
  file : PdfFile,
) -> PdfNavigator? raise PdfDocumentError {
  match value {
    Some(object) => {
      let dict = require_navigation_dictionary(
        file, object, owner, "collection navigator",
      )
      let layout = match dict.get(navigation_key(b"Layout")) {
        Some(item) => navigation_name(item, owner, "navigator Layout")
        None => navigation_key(b"D")
      }
      let fallbacks = parse_navigator_fallbacks(
        dict.get(navigation_key(b"Fallback")),
        owner,
      )
      if fallbacks.length() == 0 {
        fallbacks.push(navigation_key(b"D"))
      }
      Some(PdfNavigator::{ layout, fallback_layouts: fallbacks, raw_dict: dict })
    }
    None => None
  }
}

///|
fn parse_navigator_fallbacks(
  value : @objects.PdfObject?,
  owner : @objects.PdfName,
) -> Array[@objects.PdfName] raise PdfDocumentError {
  let out : Array[@objects.PdfName] = []
  match value {
    Some(@objects.PdfObject::Name(name)) => out.push(name)
    Some(@objects.PdfObject::Array(values)) =>
      for item in values {
        out.push(navigation_name(item, owner, "navigator fallback"))
      }
    Some(_) =>
      raise navigation_error(owner, "navigator fallback must be name or array")
    None => ()
  }
  out
}
