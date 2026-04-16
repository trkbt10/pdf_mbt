///|
/// ISO source: spec/extracted/12.7-12.11-forms-signatures.spec.txt.
/// Vocabulary source: /users/terukichi/workspaces/moonbit/pdf/spec/extracted/12.7-12.11-forms-signatures.spec.txt.
/// Interactive form field type names from ISO 32000-2 12.7.5.1. Button
/// fields (Btn) cover push-buttons, check boxes, and radio buttons; text
/// fields (Tx), choice fields (Ch), signature fields (Sig), unknown FT names,
/// and absent inherited FT values are preserved structurally.
pub(all) enum PdfFormFieldType {
  Button
  Text
  Choice
  Signature
  Unknown(@objects.PdfName)
  Absent
} derive(Eq, Debug)

///|
/// Field dictionary Ff bitset from ISO 32000-2 Tables 227, 229, 231, and
/// 233. Common ReadOnly, Required, and NoExport flags share this storage with
/// button, text, and choice field-specific bits.
pub(all) struct PdfFormFieldFlags {
  bits : Int
} derive(Eq, Debug)

///|
/// True when Table 227 bit 1 ReadOnly is set.
pub fn PdfFormFieldFlags::read_only(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x000001) != 0
}

///|
/// True when Table 227 bit 2 Required is set.
pub fn PdfFormFieldFlags::required(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x000002) != 0
}

///|
/// True when Table 227 bit 3 NoExport is set for submit-form actions.
pub fn PdfFormFieldFlags::no_export(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x000004) != 0
}

///|
/// True when Table 231 bit 13 Multiline is set for text fields.
pub fn PdfFormFieldFlags::multiline(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x001000) != 0
}

///|
/// True when Table 231 bit 14 Password is set for text fields.
pub fn PdfFormFieldFlags::password(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x002000) != 0
}

///|
/// True when Table 229 bit 15 NoToggleToOff is set for radio buttons.
pub fn PdfFormFieldFlags::no_toggle_to_off(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x004000) != 0
}

///|
/// True when Table 229 bit 16 Radio is set and Pushbutton is clear.
pub fn PdfFormFieldFlags::radio(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x008000) != 0
}

///|
/// True when Table 229 bit 17 Pushbutton is set and no permanent V or DV
/// value should be retained for the button field.
pub fn PdfFormFieldFlags::push_button(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x010000) != 0
}

///|
/// True when Table 233 bit 18 Combo is set for a choice field.
pub fn PdfFormFieldFlags::combo(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x020000) != 0
}

///|
/// True when Table 233 bit 19 Edit is set for an editable combo box.
pub fn PdfFormFieldFlags::edit(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x040000) != 0
}

///|
/// True when Table 233 bit 20 Sort is set for choice option authoring.
pub fn PdfFormFieldFlags::sort(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x080000) != 0
}

///|
/// True when Table 231 bit 21 FileSelect is set for text fields.
pub fn PdfFormFieldFlags::file_select(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x100000) != 0
}

///|
/// True when Table 233 bit 22 MultiSelect is set for choice fields.
pub fn PdfFormFieldFlags::multi_select(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x200000) != 0
}

///|
/// True when Table 231 or Table 233 bit 23 DoNotSpellCheck is set.
pub fn PdfFormFieldFlags::do_not_spell_check(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x400000) != 0
}

///|
/// True when Table 231 bit 24 DoNotScroll is set for text fields.
pub fn PdfFormFieldFlags::do_not_scroll(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x800000) != 0
}

///|
/// True when Table 231 bit 25 Comb is set for text fields with MaxLen.
pub fn PdfFormFieldFlags::comb(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x1000000) != 0
}

///|
/// True when Table 231 bit 26 RichText is set for text fields.
pub fn PdfFormFieldFlags::rich_text(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x2000000) != 0
}

///|
/// True when Table 229 bit 26 RadiosInUnison is set for radio buttons.
pub fn PdfFormFieldFlags::radios_in_unison(self : PdfFormFieldFlags) -> Bool {
  (self.bits & 0x2000000) != 0
}

///|
/// True when Table 233 bit 27 CommitOnSelChange is set for choice fields.
pub fn PdfFormFieldFlags::commit_on_sel_change(
  self : PdfFormFieldFlags,
) -> Bool {
  (self.bits & 0x4000000) != 0
}

///|
/// Field values from Table 226 V and DV, including name states for check
/// boxes and radio buttons, text strings or streams for Tx fields, arrays for
/// multi-select choice fields, raw values, and absent values.
pub(all) enum PdfFormFieldValue {
  Name(@objects.PdfName)
  String(Bytes)
  Array(Array[@objects.PdfObject])
  Raw(@objects.PdfObject)
  Absent
} derive(Eq, Debug)

///|
/// Variable text descriptor for ISO 32000-2 12.7.4.3 and Table 228. It keeps
/// DA default appearance, Q quadding, DS default style, RV rich text, and DR
/// default resources from Table 224 without constructing appearance streams.
/// DA operators are checked against Figure 9 vocabulary by downstream
/// renderers; this reader only preserves the structural inputs.
pub(all) struct PdfVariableTextDescriptor {
  default_appearance : Bytes?
  quadding : Int?
  default_style : Bytes?
  rich_text : @objects.PdfObject?
  default_resources : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Widget annotation association for interactive forms from 12.7.2,
/// 12.7.4.1, and 12.5.6.19. It records separate widget annotations,
/// merged field/widget dictionaries, page index hints, Parent ownership, AP
/// appearance data, and raw dictionaries without rendering or dispatching UI.
pub(all) struct PdfFormWidgetRef {
  object_id : @objects.ObjectId?
  page_index : Int?
  merged_field_dictionary : Bool
  raw_annotation : PdfAnnotation?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Interactive form field dictionary model for 12.7.1 through 12.7.5. A
/// document-global AcroForm may contain hierarchical non-terminal and terminal
/// fields; T partial field names combine into fully qualified field names
/// separated by PERIOD (2Eh), while unnamed children are widget annotations.
/// FT, Parent, Kids, TU, TM, Ff, V, DV, AA, variable text, push-button,
/// check box, radio button, text field, choice field, and signature field
/// vocabulary is retained as structural reader data.
pub(all) struct PdfFormField {
  object_id : @objects.ObjectId?
  partial_name : Bytes?
  fully_qualified_name : Bytes?
  field_type : PdfFormFieldType
  flags : PdfFormFieldFlags
  value : PdfFormFieldValue
  default_value : PdfFormFieldValue
  parent : @objects.ObjectId?
  kids : Array[@objects.PdfObject]
  widgets : Array[PdfFormWidgetRef]
  variable_text : PdfVariableTextDescriptor?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Interactive form dictionary (AcroForm) from ISO 32000-2 12.7.1 through
/// 12.7.4 and Tables 224 and 225. It represents one global interactive form
/// spanning pages, with root Fields, deprecated NeedAppearances and XFA,
/// SigFlags, calculation order CO, default resources DR, default appearance
/// DA, Q quadding, and raw dictionary data. Non-interactive forms and
/// PrintField attributes from 12.7.9 remain separate page-content metadata.
pub(all) struct PdfAcroForm {
  root_fields : Array[PdfFormField]
  need_appearances : Bool?
  signature_flags : Int?
  calculation_order : Array[@objects.PdfObject]
  default_resources : @objects.PdfObject?
  default_appearance : Bytes?
  quadding : Int?
  xfa : @objects.PdfObject?
  raw_dict : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// True when the field type can carry a terminal V or DV value.
pub fn PdfFormFieldType::allows_value(self : PdfFormFieldType) -> Bool {
  match self {
    Button | Text | Choice | Signature => true
    Unknown(name) => name.to_text().length() > 0
    Absent => false
  }
}

///|
/// True when the field type may legally own child field dictionaries.
pub fn PdfFormFieldType::allows_kids(self : PdfFormFieldType) -> Bool {
  match self {
    Absent => true
    Unknown(_) => true
    Button | Text | Choice | Signature => false
  }
}

///|
/// Counts choice-field behavior flags that affect option selection semantics.
pub fn PdfFormFieldFlags::choice_behavior_count(
  self : PdfFormFieldFlags,
) -> Int {
  let mut count = 0
  if self.combo() {
    count += 1
  }
  if self.edit() {
    count += 1
  }
  if self.multi_select() {
    count += 1
  }
  if self.commit_on_sel_change() {
    count += 1
  }
  count
}

///|
/// True when button-specific flags describe incompatible button modes.
pub fn PdfFormFieldFlags::has_conflicting_button_flags(
  self : PdfFormFieldFlags,
) -> Bool {
  if self.push_button() && self.radio() {
    true
  } else if self.push_button() && self.no_toggle_to_off() {
    true
  } else {
    self.push_button() && self.radios_in_unison()
  }
}

///|
/// True when a field value contains exportable user-facing data.
pub fn PdfFormFieldValue::is_exportable(self : PdfFormFieldValue) -> Bool {
  match self {
    Name(name) => name.to_text().length() > 0
    String(bytes) => bytes.length() > 0
    Array(values) => values.length() > 0
    Raw(@objects.PdfObject::Null) | Absent => false
    Raw(_) => true
  }
}

///|
/// Counts selected values represented by name, string, array, or raw object.
pub fn PdfFormFieldValue::selection_count(self : PdfFormFieldValue) -> Int {
  match self {
    Name(name) => if name.to_text().length() > 0 { 1 } else { 0 }
    String(bytes) => if bytes.length() > 0 { 1 } else { 0 }
    Array(values) => values.length()
    Raw(@objects.PdfObject::Null) | Absent => 0
    Raw(_) => 1
  }
}

///|
/// True when variable text entries include styling or rich-text inputs.
pub fn PdfVariableTextDescriptor::has_styled_payload(
  self : PdfVariableTextDescriptor,
) -> Bool {
  if self.default_style is Some(bytes) && bytes.length() > 0 {
    true
  } else if self.rich_text is Some(_) {
    true
  } else {
    self.default_resources is Some(_) || self.quadding is Some(_)
  }
}

///|
/// True when the widget can be associated with a page or parsed annotation.
pub fn PdfFormWidgetRef::is_page_bound(self : PdfFormWidgetRef) -> Bool {
  if self.page_index is Some(index) && index >= 0 {
    true
  } else if self.raw_annotation is Some(_) {
    true
  } else {
    self.object_id is Some(_) && self.merged_field_dictionary
  }
}

///|
/// True when a field is terminal by value, widget, or explicit field type.
pub fn PdfFormField::is_terminal(self : PdfFormField) -> Bool {
  if self.widgets.length() > 0 {
    true
  } else if self.value.is_exportable() || self.default_value.is_exportable() {
    true
  } else {
    self.field_type.allows_value() && self.kids.length() == 0
  }
}

///|
/// True when field data suggests appearance streams may need regeneration.
pub fn PdfFormField::requires_appearance_generation(
  self : PdfFormField,
) -> Bool {
  if self.variable_text is Some(text) && text.has_styled_payload() {
    true
  } else if self.flags.rich_text() || self.flags.comb() {
    true
  } else {
    self.widgets.length() > 0 && self.value.is_exportable()
  }
}

///|
/// True when a field or its widgets carry additional-action dictionaries.
pub fn PdfFormField::has_action_hooks(self : PdfFormField) -> Bool {
  if self.raw_dict.contains(@objects.PdfName::new(b"AA")) {
    true
  } else {
    for widget in self.widgets {
      if widget.raw_dict.contains(@objects.PdfName::new(b"AA")) {
        return true
      }
    }
    false
  }
}

///|
/// Counts selected values from the current and default values.
pub fn PdfFormField::total_selection_count(self : PdfFormField) -> Int {
  let current = self.value.selection_count()
  let fallback = self.default_value.selection_count()
  if current > 0 {
    current
  } else {
    fallback
  }
}

///|
/// True when all page-indexed widgets refer to valid non-negative pages.
pub fn PdfFormField::widgets_have_valid_pages(self : PdfFormField) -> Bool {
  if self.widgets.length() == 0 {
    return false
  }
  for widget in self.widgets {
    if widget.page_index is Some(index) && index < 0 {
      return false
    }
  }
  true
}

///|
/// True when AcroForm data contains signature fields or signature flags.
pub fn PdfAcroForm::has_signature_workflow(self : PdfAcroForm) -> Bool {
  if self.signature_flags is Some(flags) && flags != 0 {
    true
  } else {
    for field in self.root_fields {
      if field.field_type == PdfFormFieldType::Signature {
        return true
      }
    }
    false
  }
}

///|
/// True when AcroForm entries require calculation-order handling.
pub fn PdfAcroForm::has_calculation_workflow(self : PdfAcroForm) -> Bool {
  if self.calculation_order.length() > 0 {
    true
  } else if self.need_appearances == Some(true) {
    true
  } else {
    self.default_appearance is Some(bytes) && bytes.length() > 0
  }
}
