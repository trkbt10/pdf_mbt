///|
pub(all) enum OptionalContentDecision {
  Visible
  Hidden
  InertVisible
} derive(Eq, Debug)

///|
pub(all) enum OptionalContentPolicy {
  AllOn
  AnyOn
  AnyOff
  AllOff
} derive(Eq, Debug)

///|
pub(all) struct OptionalContentState {
  hidden_refs : Array[@objects.ObjectId]
  hidden_names : Array[@objects.PdfName]
  active_intents : Array[@objects.PdfName]
} derive(Eq, Debug)

///|
struct OptionalVisibilityStack {
  stack : Array[Bool]
} derive(Eq, Debug)

///|
pub fn OptionalContentState::visible() -> OptionalContentState {
  OptionalContentState::{
    hidden_refs: [],
    hidden_names: [],
    active_intents: [pdf_name(b"View")],
  }
}

///|
pub fn OptionalContentState::from_hidden(
  refs : Array[@objects.ObjectId],
  names : Array[@objects.PdfName],
) -> OptionalContentState {
  OptionalContentState::{
    hidden_refs: refs.copy(),
    hidden_names: names.copy(),
    active_intents: [pdf_name(b"View")],
  }
}

///|
pub fn parse_optional_content_properties(
  object : @objects.PdfObject?,
  offset : Int64,
) -> OptionalContentState raise PdfGraphicsError {
  match object {
    None => OptionalContentState::visible()
    Some(@objects.PdfObject::Null) => OptionalContentState::visible()
    Some(@objects.PdfObject::Dictionary(dict)) =>
      optional_content_state_from_properties(dict, offset)
    Some(_) =>
      raise PdfGraphicsError::InvalidOptionalContent(
        offset, "OCProperties must be a dictionary",
      )
  }
}

///|
pub fn OptionalContentState::evaluate(
  self : OptionalContentState,
  object : @objects.PdfObject?,
  offset : Int64,
) -> OptionalContentDecision raise PdfGraphicsError {
  match object {
    None => OptionalContentDecision::InertVisible
    Some(@objects.PdfObject::Null) => OptionalContentDecision::InertVisible
    Some(value) =>
      if evaluate_optional_content_object(self, value, offset) {
        OptionalContentDecision::Visible
      } else {
        OptionalContentDecision::Hidden
      }
  }
}

///|
fn OptionalContentState::is_visible_bool(
  self : OptionalContentState,
  object : @objects.PdfObject?,
  offset : Int64,
) -> Bool raise PdfGraphicsError {
  match self.evaluate(object, offset) {
    Hidden => false
    _ => true
  }
}

///|
fn OptionalVisibilityStack::new() -> OptionalVisibilityStack {
  OptionalVisibilityStack::{ stack: [true] }
}

///|
fn OptionalVisibilityStack::current(self : OptionalVisibilityStack) -> Bool {
  match self.stack.last() {
    Some(value) => value
    None => true
  }
}

///|
fn OptionalVisibilityStack::copy(
  self : OptionalVisibilityStack,
) -> OptionalVisibilityStack {
  OptionalVisibilityStack::{ stack: self.stack.copy() }
}

///|
fn OptionalVisibilityStack::push(
  self : OptionalVisibilityStack,
  visible : Bool,
) -> Unit {
  self.stack.push(self.current() && visible)
}

///|
fn OptionalVisibilityStack::pop(
  self : OptionalVisibilityStack,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if self.stack.length() <= 1 {
    raise PdfGraphicsError::InvalidOptionalContent(
      offset, "EMC without matching marked-content scope",
    )
  }
  self.stack.pop() |> ignore
}

///|
fn optional_content_state_from_properties(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> OptionalContentState raise PdfGraphicsError {
  let hidden_refs : Array[@objects.ObjectId] = []
  let hidden_names : Array[@objects.PdfName] = []
  let all_refs = collect_ocg_refs(optional_entry(dict, b"OCGs"), offset)
  let config = match optional_entry(dict, b"D") {
    Some(@objects.PdfObject::Dictionary(value)) => Some(value)
    Some(_) =>
      raise PdfGraphicsError::InvalidOptionalContent(
        offset, "default optional-content configuration must be a dictionary",
      )
    None => None
  }
  match config {
    Some(cfg) => {
      match optional_entry(cfg, b"BaseState") {
        Some(@objects.PdfObject::Name(name)) if name == pdf_name(b"OFF") =>
          hidden_refs.append(all_refs)
        Some(@objects.PdfObject::Name(_)) | None => ()
        Some(_) =>
          raise PdfGraphicsError::InvalidOptionalContent(
            offset, "BaseState must be a name",
          )
      }
      for object_id in collect_ocg_refs(optional_entry(cfg, b"ON"), offset) {
        remove_ref(hidden_refs, object_id)
      }
      for object_id in collect_ocg_refs(optional_entry(cfg, b"OFF"), offset) {
        add_ref(hidden_refs, object_id)
      }
    }
    None => ()
  }
  OptionalContentState::{
    hidden_refs,
    hidden_names,
    active_intents: [pdf_name(b"View")],
  }
}

///|
pub fn resolve_optional_content_property(
  resources : @content.ContentResources,
  property : @objects.PdfObject,
  offset : Int64,
) -> @objects.PdfObject? raise PdfGraphicsError {
  match property {
    @objects.PdfObject::Name(name) => {
      let object = try
        resources.lookup_resource(@content.ResourceCategory::Properties, name)
      catch {
        error => raise PdfGraphicsError::ContentFailure(error)
      } noraise {
        value => value
      }
      match object {
        None =>
          raise PdfGraphicsError::InvalidOptionalContent(
            offset,
            "missing Properties resource " + name.to_text(),
          )
        Some(value) => Some(value)
      }
    }
    @objects.PdfObject::Dictionary(_) | @objects.PdfObject::Ref(_) =>
      Some(property)
    @objects.PdfObject::Null => None
    _ =>
      raise PdfGraphicsError::InvalidOptionalContent(
        offset, "optional-content property must be a name, dictionary, or reference",
      )
  }
}

///|
fn evaluate_optional_content_object(
  state : OptionalContentState,
  object : @objects.PdfObject,
  offset : Int64,
) -> Bool raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Ref(id) => !contains_ref(state.hidden_refs, id)
    @objects.PdfObject::Dictionary(dict) =>
      evaluate_optional_content_dict(state, dict, offset)
    @objects.PdfObject::Null => true
    _ =>
      raise PdfGraphicsError::InvalidOptionalContent(
        offset, "optional-content entry must resolve to an OCG, OCMD, reference, or null",
      )
  }
}

///|
fn evaluate_optional_content_dict(
  state : OptionalContentState,
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Bool raise PdfGraphicsError {
  let type_name = image_optional_name(
    dict, b"Type", offset, "optional-content Type",
  )
  if type_name == Some(pdf_name(b"OCMD")) {
    match optional_entry(dict, b"VE") {
      Some(ve) => evaluate_visibility_expression(state, ve, offset)
      None => {
        let objects = ocmd_ocgs(dict, offset)
        evaluate_policy(policy_from_dict(dict, offset), objects, state, offset)
      }
    }
  } else {
    if type_name is Some(name) {
      if name != pdf_name(b"OCG") {
        raise PdfGraphicsError::InvalidOptionalContent(
          offset, "optional-content dictionary Type must be OCG or OCMD",
        )
      }
    }
    match optional_entry(dict, b"Name") {
      Some(@objects.PdfObject::Name(name)) =>
        !contains_name(state.hidden_names, name)
      Some(@objects.PdfObject::String(bytes)) =>
        !contains_name(state.hidden_names, @objects.PdfName::new(bytes))
      Some(_) =>
        raise PdfGraphicsError::InvalidOptionalContent(
          offset, "OCG Name must be a name or string",
        )
      None => true
    }
  }
}

///|
fn ocmd_ocgs(
  dict : @objects.PdfDictionary,
  _offset : Int64,
) -> Array[@objects.PdfObject] {
  match optional_entry(dict, b"OCGs") {
    None => []
    Some(@objects.PdfObject::Array(values)) => values
    Some(value) => [value]
  }
}

///|
fn policy_from_dict(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> OptionalContentPolicy raise PdfGraphicsError {
  match optional_entry(dict, b"P") {
    None => OptionalContentPolicy::AnyOn
    Some(@objects.PdfObject::Name(name)) if name == pdf_name(b"AllOn") =>
      OptionalContentPolicy::AllOn
    Some(@objects.PdfObject::Name(name)) if name == pdf_name(b"AnyOn") =>
      OptionalContentPolicy::AnyOn
    Some(@objects.PdfObject::Name(name)) if name == pdf_name(b"AnyOff") =>
      OptionalContentPolicy::AnyOff
    Some(@objects.PdfObject::Name(name)) if name == pdf_name(b"AllOff") =>
      OptionalContentPolicy::AllOff
    Some(_) =>
      raise PdfGraphicsError::InvalidOptionalContent(
        offset, "OCMD P must be AllOn, AnyOn, AnyOff, or AllOff",
      )
  }
}

///|
fn evaluate_policy(
  policy : OptionalContentPolicy,
  objects : Array[@objects.PdfObject],
  state : OptionalContentState,
  offset : Int64,
) -> Bool raise PdfGraphicsError {
  match policy {
    AllOn => {
      for object in objects {
        if !evaluate_optional_content_object(state, object, offset) {
          return false
        }
      }
      true
    }
    AnyOn => {
      if objects.length() == 0 {
        return true
      }
      for object in objects {
        if evaluate_optional_content_object(state, object, offset) {
          return true
        }
      }
      false
    }
    AnyOff => {
      for object in objects {
        if !evaluate_optional_content_object(state, object, offset) {
          return true
        }
      }
      false
    }
    AllOff => {
      for object in objects {
        if evaluate_optional_content_object(state, object, offset) {
          return false
        }
      }
      true
    }
  }
}

///|
fn evaluate_visibility_expression(
  state : OptionalContentState,
  object : @objects.PdfObject,
  offset : Int64,
) -> Bool raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Array(values) => {
      if values.length() == 0 {
        raise PdfGraphicsError::InvalidOptionalContent(
          offset, "visibility expression must not be empty",
        )
      }
      let op = require_name_value(
        values[0],
        offset,
        "visibility expression operator",
      )
      if op == pdf_name(b"And") {
        for index in 1..<values.length() {
          if !evaluate_visibility_expression(state, values[index], offset) {
            return false
          }
        }
        true
      } else if op == pdf_name(b"Or") {
        for index in 1..<values.length() {
          if evaluate_visibility_expression(state, values[index], offset) {
            return true
          }
        }
        false
      } else if op == pdf_name(b"Not") {
        if values.length() != 2 {
          raise PdfGraphicsError::InvalidOptionalContent(
            offset, "Not visibility expression requires one operand",
          )
        }
        !evaluate_visibility_expression(state, values[1], offset)
      } else {
        raise PdfGraphicsError::InvalidOptionalContent(
          offset, "unknown visibility expression operator",
        )
      }
    }
    _ => evaluate_optional_content_object(state, object, offset)
  }
}

///|
fn collect_ocg_refs(
  object : @objects.PdfObject?,
  offset : Int64,
) -> Array[@objects.ObjectId] raise PdfGraphicsError {
  match object {
    None => []
    Some(@objects.PdfObject::Array(values)) => {
      let refs : Array[@objects.ObjectId] = []
      for value in values {
        match value {
          @objects.PdfObject::Ref(id) => refs.push(id)
          @objects.PdfObject::Null => ()
          _ =>
            raise PdfGraphicsError::InvalidOptionalContent(
              offset, "OCGs entries must be indirect references",
            )
        }
      }
      refs
    }
    Some(@objects.PdfObject::Ref(id)) => [id]
    Some(@objects.PdfObject::Null) => []
    Some(_) =>
      raise PdfGraphicsError::InvalidOptionalContent(
        offset, "OCGs must be a reference or array of references",
      )
  }
}

///|
fn contains_ref(
  refs : Array[@objects.ObjectId],
  id : @objects.ObjectId,
) -> Bool {
  for object_id in refs {
    if object_id == id {
      return true
    }
  }
  false
}

///|
fn add_ref(refs : Array[@objects.ObjectId], id : @objects.ObjectId) -> Unit {
  if !contains_ref(refs, id) {
    refs.push(id)
  }
}

///|
fn remove_ref(refs : Array[@objects.ObjectId], id : @objects.ObjectId) -> Unit {
  let output : Array[@objects.ObjectId] = []
  for object_id in refs {
    if object_id != id {
      output.push(object_id)
    }
  }
  refs.clear()
  refs.append(output)
}

///|
fn contains_name(
  names : Array[@objects.PdfName],
  name : @objects.PdfName,
) -> Bool {
  for value in names {
    if value == name {
      return true
    }
  }
  false
}
