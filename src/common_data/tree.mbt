///|
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
