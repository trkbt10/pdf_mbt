///|
pub fn PdfStructureElement::accessibility_properties(
  self : PdfStructureElement,
) -> PdfAccessibilityProperties {
  self.accessibility
}

///|
pub fn PdfStructureTree::effective_language(
  self : PdfStructureTree,
  element : PdfStructureElement,
) -> PdfEffectiveLanguage raise PdfDocumentError {
  match element.language {
    Some(language) =>
      PdfEffectiveLanguage::{
        language: Some(language),
        source: PdfEffectiveLanguageSource::Element(element.object_id),
      }
    None =>
      match inherited_structure_language(self, element) {
        Some(found) => found
        None =>
          match self.document_language {
            Some(language) =>
              PdfEffectiveLanguage::{
                language: Some(language),
                source: PdfEffectiveLanguageSource::Catalog,
              }
            None =>
              PdfEffectiveLanguage::{
                language: None,
                source: PdfEffectiveLanguageSource::Absent,
              }
          }
      }
  }
}

///|
fn parse_accessibility_properties(
  dict : @objects.PdfDictionary,
  owner : @objects.ObjectId?,
) -> PdfAccessibilityProperties raise PdfDocumentError {
  let phoneme = structure_optional_string(
    dict,
    structure_key(b"Phoneme"),
    owner,
    "structure element /Phoneme",
  )
  PdfAccessibilityProperties::{
    alternate_description: structure_optional_string(
      dict,
      structure_key(b"Alt"),
      owner,
      "structure element /Alt",
    ),
    replacement_text: structure_optional_string(
      dict,
      structure_key(b"ActualText"),
      owner,
      "structure element /ActualText",
    ),
    expansion_text: structure_optional_string(
      dict,
      structure_key(b"E"),
      owner,
      "structure element /E",
    ),
    phoneme,
    phonetic_alphabet: match dict.get(structure_key(b"PhoneticAlphabet")) {
      Some(value) =>
        Some(
          structure_name(value, owner, "structure element /PhoneticAlphabet"),
        )
      None =>
        match phoneme {
          Some(_) => Some(structure_key(b"ipa"))
          None => None
        }
    },
  }
}

///|
fn inherited_structure_language(
  tree : PdfStructureTree,
  element : PdfStructureElement,
) -> PdfEffectiveLanguage? {
  match element.parent {
    PdfStructureParent::Element(Some(parent_ref)) => {
      let mut current_ref = Some(parent_ref)
      while current_ref is Some(ref_value) {
        match structure_element_by_ref(tree.elements, ref_value) {
          Some(parent) =>
            match parent.language {
              Some(language) =>
                return Some(PdfEffectiveLanguage::{
                  language: Some(language),
                  source: PdfEffectiveLanguageSource::Element(parent.object_id),
                })
              None =>
                current_ref = match parent.parent {
                  PdfStructureParent::Element(Some(next_ref)) => Some(next_ref)
                  _ => None
                }
            }
          None => current_ref = None
        }
      }
      None
    }
    _ => None
  }
}

///|
fn structure_element_by_ref(
  elements : Array[PdfStructureElement],
  object_id : @objects.ObjectId,
) -> PdfStructureElement? {
  for element in elements {
    if element.object_id == Some(object_id) {
      return Some(element)
    }
  }
  None
}
