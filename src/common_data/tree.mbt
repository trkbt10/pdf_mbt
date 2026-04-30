///|
/// Validates direct 7.9.6 name tree node dictionary shape. A name tree is
/// constructed of dictionary nodes and has exactly one root node. The root node
/// shall contain a single entry, either `/Kids` or `/Names` but not both; if the
/// root has `/Names`, it is the only node. Non-root intermediate and leaf nodes
/// must contain `/Limits` plus exactly one of `/Kids` or `/Names`. Loading
/// indirect child references, checking child range overlap, and cycle detection
/// remain reader-owned traversal responsibilities.
pub fn validate_name_tree_node_shape(
  dict : @objects.PdfDictionary,
  is_root~ : Bool,
) -> Unit raise PdfCommonDataError {
  validate_tree_node_shape(
    dict,
    is_root~,
    pairs_key=@objects.PdfName::new(b"Names"),
    kids_key=@objects.PdfName::new(b"Kids"),
    limits_key=@objects.PdfName::new(b"Limits"),
    label="name tree",
  )
}

///|
/// Validates direct 7.9.7 number tree node dictionary shape. The root node must
/// contain either `/Kids` or `/Nums` but not both; non-root intermediate and
/// leaf nodes must contain `/Limits` plus exactly one of `/Kids` or `/Nums`.
/// Loading indirect child references and cycle detection remain reader-owned
/// traversal responsibilities.
pub fn validate_number_tree_node_shape(
  dict : @objects.PdfDictionary,
  is_root~ : Bool,
) -> Unit raise PdfCommonDataError {
  validate_tree_node_shape(
    dict,
    is_root~,
    pairs_key=@objects.PdfName::new(b"Nums"),
    kids_key=@objects.PdfName::new(b"Kids"),
    limits_key=@objects.PdfName::new(b"Limits"),
    label="number tree",
  )
}

///|
/// Compares 7.9.6 name tree string keys by simple byte-by-byte lexical order.
/// If one key is a prefix of the other, the shorter key sorts before the
/// longer key.
pub fn compare_name_tree_keys(left : Bytes, right : Bytes) -> Int {
  let mut index = 0
  let left_length = left.length()
  let right_length = right.length()
  let limit = if left_length < right_length {
    left_length
  } else {
    right_length
  }
  while index < limit {
    if left[index] < right[index] {
      return -1
    } else if left[index] > right[index] {
      return 1
    }
    index += 1
  }
  if left_length < right_length {
    -1
  } else if left_length > right_length {
    1
  } else {
    0
  }
}

///|
/// Compares 7.9.7 number tree integer keys in ascending numeric order.
pub fn compare_number_tree_keys(left : Int, right : Int) -> Int {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
/// Validates a name tree `/Names` pair array of the form key1 value1 key2
/// value2 through keyn valuen. Keys must be string objects sorted lexically in
/// ascending order by simple byte-by-byte equality and ordering; local duplicate
/// keys and descending keys are rejected, and associated values are preserved as
/// raw PDF objects.
pub fn validate_name_tree_pairs(
  object : @objects.PdfObject,
) -> Array[PdfNameTreeEntry] raise PdfCommonDataError {
  let values = require_tree_array(object, "name tree /Names")
  if values.length() % 2 != 0 {
    raise PdfCommonDataError::InvalidTreeNode(
      "name tree /Names must contain key/value pairs",
    )
  }
  let entries : Array[PdfNameTreeEntry] = []
  let mut previous : Bytes? = None
  let mut index = 0
  while index < values.length() {
    let key = match values[index] {
      @objects.PdfObject::String(bytes) => bytes
      _ =>
        raise PdfCommonDataError::InvalidTreeNode(
          "name tree keys must be strings",
        )
    }
    validate_name_key_order(previous, key)
    entries.push(PdfNameTreeEntry::{ key, value: values[index + 1] })
    previous = Some(key)
    index += 2
  }
  entries
}

///|
/// Validates a number tree `/Nums` pair array. Keys must be integer objects,
/// arity must be even, local duplicate keys and descending keys are rejected,
/// and associated values are preserved as raw PDF objects.
pub fn validate_number_tree_pairs(
  object : @objects.PdfObject,
) -> Array[PdfNumberTreeEntry] raise PdfCommonDataError {
  let values = require_tree_array(object, "number tree /Nums")
  if values.length() % 2 != 0 {
    raise PdfCommonDataError::InvalidTreeNode(
      "number tree /Nums must contain key/value pairs",
    )
  }
  let entries : Array[PdfNumberTreeEntry] = []
  let mut previous : Int? = None
  let mut index = 0
  while index < values.length() {
    let key = match values[index] {
      @objects.PdfObject::Integer(value) => value.to_int()
      _ =>
        raise PdfCommonDataError::InvalidTreeNode(
          "number tree keys must be integers",
        )
    }
    validate_number_key_order(previous, key)
    entries.push(PdfNumberTreeEntry::{ key, value: values[index + 1] })
    previous = Some(key)
    index += 2
  }
  entries
}

///|
/// Validates name tree `/Limits` as exactly two strings that specify the least
/// and greatest keys in a leaf node or descendant leaf nodes. The lower bound
/// must not exceed the upper bound under byte-wise name tree ordering.
pub fn validate_name_tree_limits(
  object : @objects.PdfObject,
) -> (Bytes, Bytes) raise PdfCommonDataError {
  let values = require_tree_array(object, "name tree /Limits")
  if values.length() != 2 {
    raise PdfCommonDataError::InvalidTreeNode(
      "name tree /Limits must contain exactly two strings",
    )
  }
  let lower = match values[0] {
    @objects.PdfObject::String(bytes) => bytes
    _ =>
      raise PdfCommonDataError::InvalidTreeNode(
        "name tree /Limits values must be strings",
      )
  }
  let upper = match values[1] {
    @objects.PdfObject::String(bytes) => bytes
    _ =>
      raise PdfCommonDataError::InvalidTreeNode(
        "name tree /Limits values must be strings",
      )
  }
  if compare_name_tree_keys(lower, upper) > 0 {
    raise PdfCommonDataError::InvalidTreeNode(
      "name tree /Limits lower bound must not exceed upper bound",
    )
  }
  (lower, upper)
}

///|
fn require_tree_array(
  object : @objects.PdfObject,
  label : String,
) -> Array[@objects.PdfObject] raise PdfCommonDataError {
  match object {
    @objects.PdfObject::Array(values) => values
    _ =>
      raise PdfCommonDataError::InvalidTreeNode(
        label + " must be an array, got " + common_object_kind(object),
      )
  }
}

///|
fn validate_name_key_order(
  previous : Bytes?,
  key : Bytes,
) -> Unit raise PdfCommonDataError {
  match previous {
    Some(value) =>
      if compare_name_tree_keys(value, key) >= 0 {
        raise PdfCommonDataError::InvalidTreeNode(
          "name tree keys must be strictly ascending",
        )
      }
    None => ()
  }
}

///|
fn validate_number_key_order(
  previous : Int?,
  key : Int,
) -> Unit raise PdfCommonDataError {
  match previous {
    Some(value) =>
      if compare_number_tree_keys(value, key) >= 0 {
        raise PdfCommonDataError::InvalidTreeNode(
          "number tree keys must be strictly ascending",
        )
      }
    None => ()
  }
}

///|
fn validate_tree_node_shape(
  dict : @objects.PdfDictionary,
  is_root~ : Bool,
  pairs_key~ : @objects.PdfName,
  kids_key~ : @objects.PdfName,
  limits_key~ : @objects.PdfName,
  label~ : String,
) -> Unit raise PdfCommonDataError {
  let has_pairs = dict.contains(pairs_key)
  let has_kids = dict.contains(kids_key)
  let has_limits = dict.contains(limits_key)
  if has_pairs && has_kids {
    raise PdfCommonDataError::InvalidTreeNode(
      label + " node must not contain both pair array and /Kids",
    )
  }
  if !has_pairs && !has_kids {
    raise PdfCommonDataError::InvalidTreeNode(
      label + " node must contain either pair array or /Kids",
    )
  }
  if is_root {
    if has_limits {
      raise PdfCommonDataError::InvalidTreeNode(
        label + " root node must not contain /Limits",
      )
    }
  } else if !has_limits {
    raise PdfCommonDataError::InvalidTreeNode(
      label + " non-root node must contain /Limits",
    )
  }
}
