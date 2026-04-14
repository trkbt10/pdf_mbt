///|
fn parse_set_ocg_state_action(
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
  dict : @objects.PdfDictionary,
) -> PdfSetOCGStateAction raise PdfDocumentError {
  let state = match
    action_required_raw(dict, action_key(b"State"), object_id, action_name) {
    @objects.PdfObject::Array(values) => values
    _ =>
      raise action_error(object_id, Some(action_name), "State must be an array")
  }
  PdfSetOCGStateAction::{
    operations: parse_ocg_state_operations(state, object_id, action_name),
    preserve_rb: action_optional_bool(
      dict,
      action_key(b"PreserveRB"),
      object_id,
      action_name,
      true,
    ),
    raw_dict: dict,
  }
}

///|
fn parse_ocg_state_operations(
  values : Array[@objects.PdfObject],
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
) -> Array[PdfOCGStateOperation] raise PdfDocumentError {
  let operations : Array[PdfOCGStateOperation] = []
  let mut current_operator : PdfOCGStateOperator? = None
  let current_groups : Array[@objects.PdfObject] = []
  for item in values {
    match item {
      @objects.PdfObject::Name(name) =>
        if name == action_key(b"ON") ||
          name == action_key(b"OFF") ||
          name == action_key(b"Toggle") {
          flush_ocg_operation(
            operations, current_operator, current_groups, object_id, action_name,
          )
          current_groups.clear()
          current_operator = Some(parse_ocg_operator(name))
        } else {
          raise action_error(
            object_id,
            Some(action_name),
            "State operator must be ON, OFF, or Toggle",
          )
        }
      @objects.PdfObject::Dictionary(_) | @objects.PdfObject::Ref(_) => {
        if current_operator is None {
          raise action_error(
            object_id,
            Some(action_name),
            "State must begin with an operator",
          )
        }
        current_groups.push(item)
      }
      _ =>
        raise action_error(
          object_id,
          Some(action_name),
          "State group must be a dictionary or reference",
        )
    }
  }
  flush_ocg_operation(
    operations, current_operator, current_groups, object_id, action_name,
  )
  operations
}

///|
fn flush_ocg_operation(
  operations : Array[PdfOCGStateOperation],
  operator : PdfOCGStateOperator?,
  groups : Array[@objects.PdfObject],
  object_id : @objects.ObjectId?,
  action_name : @objects.PdfName,
) -> Unit raise PdfDocumentError {
  match operator {
    Some(value) => {
      if groups.length() == 0 {
        raise action_error(
          object_id,
          Some(action_name),
          "State operator must have at least one group",
        )
      }
      let group_copy : Array[@objects.PdfObject] = []
      for group in groups {
        group_copy.push(group)
      }
      operations.push(PdfOCGStateOperation::{
        operator: value,
        groups: group_copy,
      })
    }
    None => ()
  }
}

///|
fn parse_ocg_operator(name : @objects.PdfName) -> PdfOCGStateOperator {
  if name == action_key(b"ON") {
    PdfOCGStateOperator::ON
  } else if name == action_key(b"OFF") {
    PdfOCGStateOperator::OFF
  } else {
    PdfOCGStateOperator::Toggle
  }
}
