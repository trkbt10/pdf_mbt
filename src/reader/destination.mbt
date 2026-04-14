///|
pub fn PdfDocument::named_destination(
  self : PdfDocument,
  name : Bytes,
) -> PdfNamedDestination? raise PdfDocumentError {
  match lookup_named_destination_value(self, name) {
    Some(value) =>
      Some(PdfNamedDestination::{
        name,
        destination: parse_destination_object(
          self,
          value,
          navigation_key(b"Dests"),
        ),
        raw_value: value,
      })
    None => None
  }
}

///|
pub fn PdfDocument::named_destinations(
  self : PdfDocument,
) -> Array[PdfNamedDestination] raise PdfDocumentError {
  let entries = self.name_tree_entries(NameTreeCategory::Dests)
  let destinations : Array[PdfNamedDestination] = []
  for entry in entries {
    destinations.push(PdfNamedDestination::{
      name: entry.key,
      destination: parse_destination_object(
        self,
        entry.value,
        navigation_key(b"Dests"),
      ),
      raw_value: entry.value,
    })
  }
  append_legacy_destinations(self, destinations)
  destinations
}

///|
fn lookup_named_destination_value(
  document : PdfDocument,
  name : Bytes,
) -> @objects.PdfObject? raise PdfDocumentError {
  match document.lookup_name(NameTreeCategory::Dests, name) {
    Some(value) => Some(value)
    None => lookup_legacy_destination(document, name)
  }
}

///|
fn lookup_legacy_destination(
  document : PdfDocument,
  name : Bytes,
) -> @objects.PdfObject? raise PdfDocumentError {
  let owner = navigation_key(b"Dests")
  match document.catalog.entry(owner) {
    Some(value) => {
      let dict = require_navigation_dictionary(
        document.file,
        value,
        owner,
        "Catalog Dests",
      )
      dict.get(@objects.PdfName::new(name))
    }
    None => None
  }
}

///|
fn append_legacy_destinations(
  document : PdfDocument,
  destinations : Array[PdfNamedDestination],
) -> Unit raise PdfDocumentError {
  let owner = navigation_key(b"Dests")
  match document.catalog.entry(owner) {
    Some(value) => {
      let dict = require_navigation_dictionary(
        document.file,
        value,
        owner,
        "Catalog Dests",
      )
      dict.each((name, value) => {
        destinations.push(PdfNamedDestination::{
          name: name.bytes,
          destination: parse_destination_object(document, value, owner),
          raw_value: value,
        })
      })
    }
    None => ()
  }
}

///|
fn parse_destination_object(
  document : PdfDocument,
  value : @objects.PdfObject,
  owner : @objects.PdfName,
) -> PdfDestination raise PdfDocumentError {
  let resolved = resolve_navigation_direct(
    document.file,
    value,
    owner,
    "destination",
  )
  match resolved {
    @objects.PdfObject::Array(values) =>
      parse_explicit_destination_array(document, values, owner, None)
    @objects.PdfObject::Dictionary(dict) =>
      match dict.get(navigation_key(b"D")) {
        Some(d_value) => {
          let d_resolved = resolve_navigation_direct(
            document.file,
            d_value,
            owner,
            "destination dictionary /D",
          )
          match d_resolved {
            @objects.PdfObject::Array(values) =>
              parse_explicit_destination_array(
                document,
                values,
                owner,
                Some(dict),
              )
            _ =>
              raise navigation_error(owner, "destination /D must be an array")
          }
        }
        None =>
          raise navigation_error(owner, "destination dictionary is missing /D")
      }
    @objects.PdfObject::Name(name) =>
      match lookup_legacy_destination(document, name.bytes) {
        Some(named) => parse_destination_object(document, named, owner)
        None => raise navigation_error(owner, "named destination was not found")
      }
    @objects.PdfObject::String(bytes) =>
      match document.lookup_name(NameTreeCategory::Dests, bytes) {
        Some(named) => parse_destination_object(document, named, owner)
        None => raise navigation_error(owner, "named destination was not found")
      }
    _ =>
      raise navigation_error(
        owner, "destination must be an array, name, string, or dictionary",
      )
  }
}

///|
fn parse_explicit_destination_array(
  document : PdfDocument,
  values : Array[@objects.PdfObject],
  owner : @objects.PdfName,
  raw_attributes : @objects.PdfDictionary?,
) -> PdfDestination raise PdfDocumentError {
  if values.length() < 2 {
    raise navigation_error(
      owner, "explicit destination must contain target and view",
    )
  }
  PdfDestination::{
    target: parse_destination_target(document, values[0], owner),
    view: parse_destination_view(values, owner),
    raw_array: values,
    raw_attributes,
  }
}

///|
fn parse_destination_target(
  document : PdfDocument,
  value : @objects.PdfObject,
  owner : @objects.PdfName,
) -> PdfDestinationTarget raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) =>
      match page_index_for_object_id(document, object_id) {
        Some(_) => {
          require_page_object_id(document, object_id, owner)
          PdfDestinationTarget::LocalPage(object_id)
        }
        None =>
          PdfDestinationTarget::LocalStructure(
            value,
            first_page_object_id(document),
          )
      }
    @objects.PdfObject::Integer(index) =>
      PdfDestinationTarget::RemotePageIndex(index.to_int())
    @objects.PdfObject::String(bytes) =>
      PdfDestinationTarget::RemoteStructureId(bytes)
    @objects.PdfObject::Dictionary(_) =>
      PdfDestinationTarget::LocalStructure(
        value,
        first_page_object_id(document),
      )
    _ =>
      raise navigation_error(owner, "destination target has unsupported shape")
  }
}

///|
fn parse_destination_view(
  values : Array[@objects.PdfObject],
  owner : @objects.PdfName,
) -> PdfDestinationView raise PdfDocumentError {
  let view_name = navigation_name(values[1], owner, "destination view")
  if view_name == navigation_key(b"XYZ") {
    PdfDestinationView::XYZ(
      destination_optional_number(values, 2, owner, "left"),
      destination_optional_number(values, 3, owner, "top"),
      destination_optional_number(values, 4, owner, "zoom"),
    )
  } else if view_name == navigation_key(b"Fit") {
    PdfDestinationView::Fit
  } else if view_name == navigation_key(b"FitH") {
    PdfDestinationView::FitH(
      destination_optional_number(values, 2, owner, "top"),
    )
  } else if view_name == navigation_key(b"FitV") {
    PdfDestinationView::FitV(
      destination_optional_number(values, 2, owner, "left"),
    )
  } else if view_name == navigation_key(b"FitR") {
    if values.length() < 6 {
      raise navigation_error(
        owner, "FitR destination requires four coordinates",
      )
    }
    PdfDestinationView::FitR(
      navigation_number(values[2], owner, "left"),
      navigation_number(values[3], owner, "bottom"),
      navigation_number(values[4], owner, "right"),
      navigation_number(values[5], owner, "top"),
    )
  } else if view_name == navigation_key(b"FitB") {
    PdfDestinationView::FitB
  } else if view_name == navigation_key(b"FitBH") {
    PdfDestinationView::FitBH(
      destination_optional_number(values, 2, owner, "top"),
    )
  } else if view_name == navigation_key(b"FitBV") {
    PdfDestinationView::FitBV(
      destination_optional_number(values, 2, owner, "left"),
    )
  } else {
    PdfDestinationView::Unknown(view_name, destination_view_operands(values))
  }
}

///|
fn destination_optional_number(
  values : Array[@objects.PdfObject],
  index : Int,
  owner : @objects.PdfName,
  label : String,
) -> Double? raise PdfDocumentError {
  if index >= values.length() {
    None
  } else {
    navigation_optional_number(values[index], owner, label)
  }
}

///|
fn destination_view_operands(
  values : Array[@objects.PdfObject],
) -> Array[@objects.PdfObject] {
  let out : Array[@objects.PdfObject] = []
  let mut index = 2
  while index < values.length() {
    out.push(values[index])
    index += 1
  }
  out
}
