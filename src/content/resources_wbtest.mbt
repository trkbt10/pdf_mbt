///|
test "content resources resolve every supported category by exact name" {
  let resources = ContentResources::from_dictionary(make_full_resource_dict())

  assert_eq(
    resources.lookup_resource(ExtGState, @objects.PdfName::new(b"GS1")) ==
    Some(@objects.PdfObject::Integer(1L)),
    true,
  )
  assert_eq(
    resources.lookup_resource(ColorSpace, @objects.PdfName::new(b"CS1")) ==
    Some(@objects.PdfObject::Integer(2L)),
    true,
  )
  assert_eq(
    resources.lookup_resource(Pattern, @objects.PdfName::new(b"P1")) ==
    Some(@objects.PdfObject::Integer(3L)),
    true,
  )
  assert_eq(
    resources.lookup_resource(Shading, @objects.PdfName::new(b"SH1")) ==
    Some(@objects.PdfObject::Integer(4L)),
    true,
  )
  assert_eq(
    resources.lookup_resource(XObject, @objects.PdfName::new(b"Im1")) ==
    Some(@objects.PdfObject::Integer(5L)),
    true,
  )
  assert_eq(
    resources.lookup_resource(Font, @objects.PdfName::new(b"F1")) ==
    Some(@objects.PdfObject::Integer(6L)),
    true,
  )
  assert_eq(
    resources.lookup_resource(Properties, @objects.PdfName::new(b"MC1")) ==
    Some(@objects.PdfObject::Integer(7L)),
    true,
  )
  assert_eq(
    resources.lookup_resource(ProcSet, @objects.PdfName::new(b"PDF")) ==
    Some(@objects.PdfObject::Name(@objects.PdfName::new(b"PDF"))),
    true,
  )
}

///|
test "content resources return missing values for absent categories and names" {
  let resources = ContentResources::empty()
  assert_eq(
    resources.lookup_resource(Font, @objects.PdfName::new(b"F1")) is None,
    true,
  )

  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Font")] = @objects.PdfObject::Dictionary(
    Map::new(),
  )
  let resources = ContentResources::from_dictionary(dict)
  assert_eq(
    resources.lookup_resource(Font, @objects.PdfName::new(b"Missing")) is None,
    true,
  )
}

///|
test "content resources preserve raw indirect object values without loading" {
  let font_dict : @objects.PdfDictionary = Map::new()
  let object_id = @objects.ObjectId::{ object_number: 10, generation_number: 0 }
  font_dict[@objects.PdfName::new(b"F1")] = @objects.PdfObject::Ref(object_id)

  let resources_dict : @objects.PdfDictionary = Map::new()
  resources_dict[@objects.PdfName::new(b"Font")] = @objects.PdfObject::Dictionary(
    font_dict,
  )
  let resources = ContentResources::from_dictionary(resources_dict)

  assert_eq(
    resources.lookup_resource(Font, @objects.PdfName::new(b"F1")) ==
    Some(@objects.PdfObject::Ref(object_id)),
    true,
  )
}

///|
test "content resources reject malformed explicit category values" {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"Font")] = @objects.PdfObject::Name(
    @objects.PdfName::new(b"Bad"),
  )
  let resources = ContentResources::from_dictionary(dict)

  let result : Result[@objects.PdfObject?, PdfContentError] = try? resources.lookup_resource(
    Font,
    @objects.PdfName::new(b"F1"),
  )
  match result {
    Err(ResourceFailure(_, reason)) => {
      assert_eq(reason.contains("Font"), true)
      assert_eq(reason.contains("dictionary"), true)
    }
    _ => fail("expected malformed category value to fail")
  }
}

///|
test "content resources reject malformed top-level resources object" {
  let result : Result[ContentResources, PdfContentError] = try? ContentResources::from_object(
    Some(@objects.PdfObject::String(b"bad")),
    12L,
  )
  match result {
    Err(ResourceFailure(offset, reason)) => {
      assert_eq(offset, 12L)
      assert_eq(reason.contains("Resources"), true)
    }
    _ => fail("expected malformed Resources object")
  }
}

///|
fn make_full_resource_dict() -> @objects.PdfDictionary {
  let resources : @objects.PdfDictionary = Map::new()
  put_resource_category(resources, ExtGState, b"GS1", 1L)
  put_resource_category(resources, ColorSpace, b"CS1", 2L)
  put_resource_category(resources, Pattern, b"P1", 3L)
  put_resource_category(resources, Shading, b"SH1", 4L)
  put_resource_category(resources, XObject, b"Im1", 5L)
  put_resource_category(resources, Font, b"F1", 6L)
  put_resource_category(resources, Properties, b"MC1", 7L)
  resources[@objects.PdfName::new(b"ProcSet")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(@objects.PdfName::new(b"PDF")),
  ])
  resources
}

///|
fn put_resource_category(
  resources : @objects.PdfDictionary,
  category : ResourceCategory,
  name : Bytes,
  value : Int64,
) -> Unit {
  let category_dict : @objects.PdfDictionary = Map::new()
  category_dict[@objects.PdfName::new(name)] = @objects.PdfObject::Integer(
    value,
  )
  resources[category.name()] = @objects.PdfObject::Dictionary(category_dict)
}
