///|
pub fn PdfPage::presentation(
  self : PdfPage,
) -> PdfPresentation raise PdfDocumentError {
  PdfPresentation::{
    duration: match self.entry(navigation_key(b"Dur")) {
      Some(value) =>
        Some(navigation_number(value, navigation_key(b"Dur"), "page duration"))
      None => None
    },
    transition: match self.entry(navigation_key(b"Trans")) {
      Some(value) => Some(parse_transition(self.file, value))
      None => None
    },
  }
}

///|
pub fn PdfPage::navigation_nodes(
  self : PdfPage,
) -> Array[PdfNavigationNode] raise PdfDocumentError {
  let owner = navigation_key(b"PresSteps")
  match self.entry(owner) {
    Some(value) => {
      let seen : Map[@objects.ObjectId, Bool] = Map::new()
      parse_navigation_node_chain(self.file, value, owner, seen)
    }
    None => []
  }
}

///|
fn parse_transition(
  file : PdfFile,
  value : @objects.PdfObject,
) -> PdfTransition raise PdfDocumentError {
  let owner = navigation_key(b"Trans")
  let dict = require_navigation_dictionary(file, value, owner, "transition")
  PdfTransition::{
    style: parse_transition_style(dict.get(navigation_key(b"S")), owner),
    duration: match dict.get(navigation_key(b"D")) {
      Some(value) => navigation_number(value, owner, "transition D")
      None => 1.0
    },
    dimension: transition_optional_name(
      dict.get(navigation_key(b"DM")),
      owner,
      "DM",
    ),
    motion: transition_optional_name(dict.get(navigation_key(b"M")), owner, "M"),
    direction: match dict.get(navigation_key(b"Di")) {
      Some(value) =>
        Some(navigation_number(value, owner, "transition direction"))
      None => None
    },
    scale: match dict.get(navigation_key(b"SS")) {
      Some(value) => Some(navigation_number(value, owner, "transition scale"))
      None => None
    },
    opaque_area: navigation_bool_or_default(
      dict,
      navigation_key(b"B"),
      false,
      owner,
    ),
    raw_dict: dict,
  }
}

///|
fn parse_transition_style(
  value : @objects.PdfObject?,
  owner : @objects.PdfName,
) -> PdfTransitionStyle raise PdfDocumentError {
  let name = match value {
    Some(object) => navigation_name(object, owner, "transition S")
    None => navigation_key(b"R")
  }
  if name == navigation_key(b"Split") {
    PdfTransitionStyle::Split
  } else if name == navigation_key(b"Blinds") {
    PdfTransitionStyle::Blinds
  } else if name == navigation_key(b"Box") {
    PdfTransitionStyle::Box
  } else if name == navigation_key(b"Wipe") {
    PdfTransitionStyle::Wipe
  } else if name == navigation_key(b"Dissolve") {
    PdfTransitionStyle::Dissolve
  } else if name == navigation_key(b"Glitter") {
    PdfTransitionStyle::Glitter
  } else if name == navigation_key(b"R") {
    PdfTransitionStyle::R
  } else if name == navigation_key(b"Fly") {
    PdfTransitionStyle::Fly
  } else if name == navigation_key(b"Push") {
    PdfTransitionStyle::Push
  } else if name == navigation_key(b"Cover") {
    PdfTransitionStyle::Cover
  } else if name == navigation_key(b"Uncover") {
    PdfTransitionStyle::Uncover
  } else if name == navigation_key(b"Fade") {
    PdfTransitionStyle::Fade
  } else {
    PdfTransitionStyle::Unknown(name)
  }
}

///|
fn transition_optional_name(
  value : @objects.PdfObject?,
  owner : @objects.PdfName,
  label : String,
) -> @objects.PdfName? raise PdfDocumentError {
  match value {
    Some(object) => Some(navigation_name(object, owner, label))
    None => None
  }
}

///|
fn parse_navigation_node_chain(
  file : PdfFile,
  first : @objects.PdfObject,
  owner : @objects.PdfName,
  seen : Map[@objects.ObjectId, Bool],
) -> Array[PdfNavigationNode] raise PdfDocumentError {
  let nodes : Array[PdfNavigationNode] = []
  let mut current : @objects.PdfObject? = Some(first)
  while current is Some(value) {
    let dict = load_navigation_node_dictionary(file, value, owner, seen)
    nodes.push(PdfNavigationNode::{
      forward_action: dict.get(navigation_key(b"NA")),
      backward_action: dict.get(navigation_key(b"PA")),
      raw_dict: dict,
    })
    current = match dict.get(navigation_key(b"Next")) {
      Some(next) => Some(next)
      None => None
    }
  }
  nodes
}

///|
fn load_navigation_node_dictionary(
  file : PdfFile,
  value : @objects.PdfObject,
  owner : @objects.PdfName,
  seen : Map[@objects.ObjectId, Bool],
) -> @objects.PdfDictionary raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) => {
      if seen.contains(object_id) {
        raise PdfDocumentError::CycleDetected(
          object_id, "presentation navigation node cycle detected",
        )
      }
      seen[object_id] = true
      match load_navigation_object(file, object_id, owner, "navigation node") {
        @objects.PdfObject::Dictionary(dict) => dict
        _ =>
          raise navigation_error(owner, "navigation node must be a dictionary")
      }
    }
    @objects.PdfObject::Dictionary(dict) => dict
    _ => raise navigation_error(owner, "navigation node must be a dictionary")
  }
}
