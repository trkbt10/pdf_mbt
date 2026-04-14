///|
test "OCG Intent outside active configuration has no visibility effect" {
  let state = OptionalContentState::from_hidden([], [pdf_name(b"Layer")])
  let ocg = ocg_dictionary(b"Layer", Some(pdf_name(b"Design")))

  let decision = state.evaluate(Some(@objects.PdfObject::Dictionary(ocg)), 40L)

  assert_eq(decision == OptionalContentDecision::Visible, true)
}

///|
test "empty configuration Intent makes optional content groups inert" {
  let object_id = @objects.ObjectId::{ object_number: 4, generation_number: 0 }
  let properties : @objects.PdfDictionary = Map::new()
  properties[pdf_name(b"OCGs")] = @objects.PdfObject::Array([
    @objects.PdfObject::Ref(object_id),
  ])
  let config : @objects.PdfDictionary = Map::new()
  config[pdf_name(b"BaseState")] = @objects.PdfObject::Name(pdf_name(b"OFF"))
  config[pdf_name(b"Intent")] = @objects.PdfObject::Array([])
  properties[pdf_name(b"D")] = @objects.PdfObject::Dictionary(config)

  let state = parse_optional_content_properties(
    Some(@objects.PdfObject::Dictionary(properties)),
    41L,
  )
  assert_eq(state.hidden_refs.length(), 1)
  assert_eq(state.active_intents.length(), 0)

  let decision = state.evaluate(Some(@objects.PdfObject::Ref(object_id)), 42L)
  assert_eq(decision == OptionalContentDecision::Visible, true)
}

///|
test "configuration Intent All applies hidden OCG references" {
  let object_id = @objects.ObjectId::{ object_number: 5, generation_number: 0 }
  let properties : @objects.PdfDictionary = Map::new()
  properties[pdf_name(b"OCGs")] = @objects.PdfObject::Array([
    @objects.PdfObject::Ref(object_id),
  ])
  let config : @objects.PdfDictionary = Map::new()
  config[pdf_name(b"BaseState")] = @objects.PdfObject::Name(pdf_name(b"OFF"))
  config[pdf_name(b"Intent")] = @objects.PdfObject::Name(pdf_name(b"All"))
  properties[pdf_name(b"D")] = @objects.PdfObject::Dictionary(config)

  let state = parse_optional_content_properties(
    Some(@objects.PdfObject::Dictionary(properties)),
    43L,
  )
  let decision = state.evaluate(Some(@objects.PdfObject::Ref(object_id)), 44L)
  assert_eq(decision == OptionalContentDecision::Hidden, true)
}

///|
fn ocg_dictionary(
  name : Bytes,
  intent : @objects.PdfName?,
) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_name(b"Type")] = @objects.PdfObject::Name(pdf_name(b"OCG"))
  dict[pdf_name(b"Name")] = @objects.PdfObject::Name(pdf_name(name))
  if intent is Some(value) {
    dict[pdf_name(b"Intent")] = @objects.PdfObject::Name(value)
  }
  dict
}
