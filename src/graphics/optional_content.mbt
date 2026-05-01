///|
/// Visibility result for optional content in ISO 32000-2 8.11. Optional
/// content groups (OCGs), optional content membership dictionaries (OCMDs),
/// and visibility expressions (VE) determine whether graphical content is
/// visible for a configuration and intent. Usage dictionaries describe content
/// controlled by a group, such as language, magnification, view, print, export,
/// user, zoom, creator information, subtype, and suggested automatic state in
/// Table 100 entries of an optional content usage dictionary.
/// Hidden suppresses drawing, Visible draws, and InertVisible means no
/// OCProperties, OCG, OCMD, or active optional-content control affected the
/// content.
pub(all) enum OptionalContentDecision {
  Visible
  Hidden
  InertVisible
} derive(Eq, Debug)

///|
/// Optional content membership dictionary policy (`P`) from ISO 32000-2
/// 8.11.2.1 and 8.11.2.2. Optional content groups are named graphic layers
/// that may be made visible or invisible dynamically by PDF processors. An
/// OCG dictionary has Type OCG, a user-interface Name text string, Intent such
/// as View or Design, and a Usage dictionary. An OCMD combines one or more
/// OCGs through AllOn, AnyOn, AnyOff, or AllOff over the OCGs entry, unless a
/// VE visibility expression takes precedence.
pub(all) enum OptionalContentPolicy {
  AllOn
  AnyOn
  AnyOff
  AllOff
} derive(Eq, Debug)

///|
/// Lightweight optional content group state for visibility policy checks. A
/// missing explicit visibility inherits the caller's default configuration.
pub(all) struct OptionalContentGroup {
  name : String
  visible : Bool?
} derive(Eq, Debug)

///|
/// Lightweight optional content membership policy over named groups. The
/// policy determines whether the associated content should be rendered from
/// the set of currently visible group names.
pub(all) struct OptionalContentMembership {
  groups : Array[String]
  policy : OptionalContentPolicy
} derive(Eq, Debug)

///|
/// Optional content state derived from Catalog OCProperties, the OCGs array,
/// default and alternate optional-content configuration dictionaries, D,
/// Configs, BaseState, ON and OFF arrays, Intent, Order, ListMode, RBGroups,
/// and Locked entries. It represents how a PDF processor determines the
/// initial state of optional content groups: apply BaseState to all groups,
/// adjust groups listed in ON or OFF, then apply matching usage application
/// dictionaries according to processor type. Configuration dictionaries
/// provide presentation metadata and group state for viewers, design
/// applications, aggregating applications, and printing applications. Usage
/// dictionaries and usage application dictionaries for View, Print, Export,
/// Zoom, User, and Language contexts are represented at this state boundary by
/// caller-selected hidden groups and active intents. Missing OCProperties
/// makes optional-content structures inert and visible.
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
/// Creates a visible optional-content state. Missing OCProperties makes
/// optional content structures inert and visible, as required by 8.11.4.1 and
/// 8.11.4.2. Optional content is useful for CAD drawings, layered artwork,
/// maps, and multi-language documents whose graphics can be viewed or hidden
/// by document authors or consumers. The PDF structures are optional content
/// groups, making graphical content optional, and configuring optional content.
pub fn OptionalContentState::visible() -> OptionalContentState {
  OptionalContentState::{
    hidden_refs: [],
    hidden_names: [],
    active_intents: [pdf_name(b"View")],
  }
}

///|
/// Creates a test or caller-provided optional-content state with hidden OCG
/// references or OCG names under the default View intent.
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
/// Parses the document catalog OCProperties dictionary into initial optional
/// content group state. It applies the default configuration dictionary `D`,
/// BaseState, ON and OFF arrays, and configuration Intent; missing
/// OCProperties leaves all optional content visible.
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
/// Evaluates an OC entry, optional content group (OCG), optional content
/// membership dictionary (OCMD), or visibility expression (VE) against the
/// current state. VE takes precedence over OCGs and P policies.
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
/// Resolves this group's visibility against the default optional-content
/// configuration. Explicit group state wins; otherwise the configured default
/// state supplies the visibility result.
pub fn OptionalContentGroup::is_visible(
  self : OptionalContentGroup,
  default_on : Bool,
) -> Bool {
  match self.visible {
    Some(value) => {
      let explicit_state = value
      explicit_state
    }
    None => {
      let inherited_state = default_on
      inherited_state
    }
  }
}

///|
/// Evaluates an optional-content membership policy against visible group names.
/// AllOn and AnyOn require visible groups, while AllOff and AnyOff render when
/// the referenced groups are absent from the visible set.
pub fn OptionalContentMembership::evaluate_visibility(
  self : OptionalContentMembership,
  visible_groups : Array[String],
) -> Bool {
  match self.policy {
    AllOn => membership_all_on(self.groups, visible_groups)
    AnyOn => membership_any_on(self.groups, visible_groups)
    AllOff => membership_all_off(self.groups, visible_groups)
    AnyOff => membership_any_off(self.groups, visible_groups)
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
    active_intents: optional_content_config_intents(config, offset),
  }
}

///|
/// Resolves marked-content OC property lists through the current Properties
/// resource dictionary for BDC and DP operators. The property may be a named
/// OCG or OCMD resource, a direct dictionary, an unresolved reference, or null.
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
    @objects.PdfObject::Ref(id) =>
      if state.active_intents.length() == 0 {
        true
      } else {
        !contains_ref(state.hidden_refs, id)
      }
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
    // Producers in the wild (e.g. presentation PDFs) ship optional-content
    // dictionaries whose /Type is missing or non-standard. ISO 32000-2 8.11
    // says it should be OCG or OCMD, but rejecting unknown values aborts the
    // entire page's graphics walk over a single permissive marker. Treat any
    // non-OCMD value as an OCG so visibility evaluation continues.
    if !ocg_intent_applies(state, dict, offset) {
      return true
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
fn optional_content_config_intents(
  config : @objects.PdfDictionary?,
  offset : Int64,
) -> Array[@objects.PdfName] raise PdfGraphicsError {
  match config {
    None => [pdf_name(b"View")]
    Some(dict) =>
      match optional_entry(dict, b"Intent") {
        None => [pdf_name(b"View")]
        Some(value) => optional_content_intent_names(value, offset, "Intent")
      }
  }
}

///|
fn ocg_intent_applies(
  state : OptionalContentState,
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> Bool raise PdfGraphicsError {
  if state.active_intents.length() == 0 {
    return false
  }
  if contains_name(state.active_intents, pdf_name(b"All")) {
    return true
  }
  let intents = match optional_entry(dict, b"Intent") {
    None => [pdf_name(b"View")]
    Some(value) => optional_content_intent_names(value, offset, "OCG Intent")
  }
  for intent in intents {
    if contains_name(state.active_intents, intent) {
      return true
    }
  }
  false
}

///|
fn optional_content_intent_names(
  object : @objects.PdfObject,
  offset : Int64,
  label : String,
) -> Array[@objects.PdfName] raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Name(name) => [name]
    @objects.PdfObject::Array(values) => {
      let names : Array[@objects.PdfName] = []
      for value in values {
        names.push(require_name_value(value, offset, label))
      }
      names
    }
    _ =>
      raise PdfGraphicsError::InvalidOptionalContent(
        offset,
        label + " must be a name or array of names",
      )
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

///|
fn membership_all_on(
  groups : Array[String],
  visible_groups : Array[String],
) -> Bool {
  for group in groups {
    if !contains_visible_group_name(visible_groups, group) {
      return false
    }
  }
  true
}

///|
fn membership_any_on(
  groups : Array[String],
  visible_groups : Array[String],
) -> Bool {
  if groups.length() == 0 {
    return true
  }
  for group in groups {
    if contains_visible_group_name(visible_groups, group) {
      return true
    }
  }
  false
}

///|
fn membership_all_off(
  groups : Array[String],
  visible_groups : Array[String],
) -> Bool {
  for group in groups {
    if contains_visible_group_name(visible_groups, group) {
      return false
    }
  }
  true
}

///|
fn membership_any_off(
  groups : Array[String],
  visible_groups : Array[String],
) -> Bool {
  for group in groups {
    if !contains_visible_group_name(visible_groups, group) {
      return true
    }
  }
  false
}

///|
fn contains_visible_group_name(names : Array[String], name : String) -> Bool {
  for value in names {
    if value == name {
      return true
    }
  }
  false
}
