///|
/// Classifies ISO standard structure type names. Custom names return None and
/// remain valid only when role-map resolution maps them to a known type.
pub fn standard_structure_type(
  name : @objects.PdfName,
) -> PdfStandardStructureType? {
  if name == structure_key(b"Document") {
    return Some(
      standard_type(name, PdfStandardStructureCategory::Document, None),
    )
  }
  if name == structure_key(b"DocumentFragment") {
    return Some(
      standard_type(name, PdfStandardStructureCategory::Document, None),
    )
  }
  if name == structure_key(b"Part") ||
    name == structure_key(b"Art") ||
    name == structure_key(b"Sect") ||
    name == structure_key(b"Div") ||
    name == structure_key(b"Aside") ||
    name == structure_key(b"NonStruct") ||
    name == structure_key(b"Private") {
    return Some(
      standard_type(name, PdfStandardStructureCategory::Grouping, None),
    )
  }
  if name == structure_key(b"Title") {
    return Some(
      standard_type(name, PdfStandardStructureCategory::Contextual, None),
    )
  }
  if name == structure_key(b"FENote") {
    return Some(
      standard_type(name, PdfStandardStructureCategory::Contextual, None),
    )
  }
  if name == structure_key(b"P") ||
    name == structure_key(b"H") ||
    name == structure_key(b"Lbl") ||
    name == structure_key(b"BlockQuote") {
    return Some(standard_type(name, PdfStandardStructureCategory::Block, None))
  }
  match standard_heading_level(name) {
    Some(level) =>
      return Some(
        standard_type(name, PdfStandardStructureCategory::Block, Some(level)),
      )
    None => ()
  }
  if name == structure_key(b"Caption") {
    return Some(
      standard_type(name, PdfStandardStructureCategory::Caption, None),
    )
  }
  if name == structure_key(b"TOC") ||
    name == structure_key(b"TOCI") ||
    name == structure_key(b"Index") ||
    name == structure_key(b"Quote") ||
    name == structure_key(b"Note") ||
    name == structure_key(b"Reference") ||
    name == structure_key(b"BBox") ||
    name == structure_key(b"BibEntry") {
    return Some(standard_type(name, PdfStandardStructureCategory::Block, None))
  }
  if name == structure_key(b"Sub") {
    return Some(
      standard_type(name, PdfStandardStructureCategory::SubBlock, None),
    )
  }
  if name == structure_key(b"Span") ||
    name == structure_key(b"Em") ||
    name == structure_key(b"Strong") ||
    name == structure_key(b"Code") {
    return Some(standard_type(name, PdfStandardStructureCategory::Inline, None))
  }
  if name == structure_key(b"Link") ||
    name == structure_key(b"Annot") ||
    name == structure_key(b"Form") {
    return Some(
      standard_type(name, PdfStandardStructureCategory::Contextual, None),
    )
  }
  if name == structure_key(b"RB") ||
    name == structure_key(b"RT") ||
    name == structure_key(b"RP") {
    return Some(standard_type(name, PdfStandardStructureCategory::Ruby, None))
  }
  if name == structure_key(b"Ruby") {
    return Some(standard_type(name, PdfStandardStructureCategory::Ruby, None))
  }
  if name == structure_key(b"Warichu") ||
    name == structure_key(b"WT") ||
    name == structure_key(b"WP") {
    return Some(
      standard_type(name, PdfStandardStructureCategory::Warichu, None),
    )
  }
  if name == structure_key(b"L") ||
    name == structure_key(b"LI") ||
    name == structure_key(b"LBody") {
    return Some(standard_type(name, PdfStandardStructureCategory::List, None))
  }
  if name == structure_key(b"Table") ||
    name == structure_key(b"TR") ||
    name == structure_key(b"TH") ||
    name == structure_key(b"TD") ||
    name == structure_key(b"THead") ||
    name == structure_key(b"TBody") ||
    name == structure_key(b"TFoot") {
    return Some(standard_type(name, PdfStandardStructureCategory::Table, None))
  }
  if name == structure_key(b"Figure") {
    return Some(standard_type(name, PdfStandardStructureCategory::Figure, None))
  }
  if name == structure_key(b"Formula") {
    return Some(
      standard_type(name, PdfStandardStructureCategory::Formula, None),
    )
  }
  if name == structure_key(b"Artifact") {
    return Some(
      standard_type(name, PdfStandardStructureCategory::Artifact, None),
    )
  }
  None
}

///|
pub fn PdfStructureTree::standard_structure_report(
  self : PdfStructureTree,
) -> Array[PdfStandardNestingDiagnostic] raise PdfDocumentError {
  let diagnostics : Array[PdfStandardNestingDiagnostic] = []
  for element in self.elements {
    let resolved = self.resolve_structure_type(element)
    if resolved.standard_target is None && resolved.custom_terminal is Some(_) {
      diagnostics.push(PdfStandardNestingDiagnostic::{
        code: structure_key(b"MissingRoleMap"),
        message: "custom structure type does not resolve to a standard type",
        element_index: Some(element.index),
        severity: PdfTaggedPdfSeverity::Warning,
      })
    }
    if resolved.cycle {
      diagnostics.push(PdfStandardNestingDiagnostic::{
        code: structure_key(b"RoleMapCycle"),
        message: "structure role-map chain is circular",
        element_index: Some(element.index),
        severity: PdfTaggedPdfSeverity::Warning,
      })
    }
  }
  diagnostics
}

///|
fn standard_type(
  name : @objects.PdfName,
  category : PdfStandardStructureCategory,
  heading_level : Int?,
) -> PdfStandardStructureType {
  PdfStandardStructureType::{ name, category, heading_level }
}

///|
fn standard_heading_level(name : @objects.PdfName) -> Int? {
  let bytes = name.bytes
  if bytes.length() < 2 {
    return None
  }
  if bytes[0] != b'H' {
    return None
  }
  let first = bytes[1]
  if first < b'1' || first > b'9' {
    return None
  }
  let mut value = first.to_int() - b'0'.to_int()
  let mut index = 2
  while index < bytes.length() {
    let byte = bytes[index]
    if byte < b'0' || byte > b'9' {
      return None
    }
    value = value * 10 + (byte.to_int() - b'0'.to_int())
    index += 1
  }
  Some(value)
}
