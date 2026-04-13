///|
test "ExtGState applies simple keys cumulatively and preserves deferred raw entries" {
  let ext : @objects.PdfDictionary = Map::new()
  ext[@objects.PdfName::new(b"LW")] = @objects.PdfObject::Real(2.5)
  ext[@objects.PdfName::new(b"LC")] = @objects.PdfObject::Integer(2L)
  ext[@objects.PdfName::new(b"D")] = @objects.PdfObject::Array([
    @objects.PdfObject::Array([
      @objects.PdfObject::Integer(3L),
      @objects.PdfObject::Integer(1L),
    ]),
    @objects.PdfObject::Integer(5L),
  ])
  ext[@objects.PdfName::new(b"Font")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(@objects.PdfName::new(b"F1")),
    @objects.PdfObject::Integer(12L),
  ])
  let ext_category : @objects.PdfDictionary = Map::new()
  ext_category[@objects.PdfName::new(b"GS1")] = @objects.PdfObject::Dictionary(
    ext,
  )
  let resource_dict : @objects.PdfDictionary = Map::new()
  resource_dict[@objects.PdfName::new(b"ExtGState")] = @objects.PdfObject::Dictionary(
    ext_category,
  )
  let resources = @content.ContentResources::from_dictionary(resource_dict)
  let patch = resolve_ext_gstate(resources, @objects.PdfName::new(b"GS1"), 9L)
  let state = GraphicsState::initial(GraphicsInitialState::default())
  state.apply_ext_gstate(patch, 9L)
  assert_eq(state.line_width, 2.5)
  assert_eq(state.line_cap == LineCapStyle::ProjectingSquareCap, true)
  assert_eq(state.dash_pattern.phase, 1.0)
  assert_eq(
    state.deferred_entries.contains(@objects.PdfName::new(b"Font")),
    true,
  )
}

///|
test "ExtGState reports missing names and malformed dash entries" {
  let resources = @content.ContentResources::empty()
  let missing : Result[ExtGStatePatch, PdfGraphicsError] = try? resolve_ext_gstate(
    resources,
    @objects.PdfName::new(b"Missing"),
    4L,
  )
  match missing {
    Err(ResourceFailure(offset, reason)) => {
      assert_eq(offset, 4L)
      assert_eq(reason.contains("ExtGState"), true)
    }
    _ => fail("expected missing ExtGState")
  }

  let ext : @objects.PdfDictionary = Map::new()
  ext[@objects.PdfName::new(b"D")] = @objects.PdfObject::Array([
    @objects.PdfObject::Array([@objects.PdfObject::Integer(0L)]),
    @objects.PdfObject::Integer(0L),
  ])
  let malformed : Result[ExtGStatePatch, PdfGraphicsError] = try? resolve_ext_gstate(
    resources_with_ext(ext),
    @objects.PdfName::new(b"GS1"),
    6L,
  )
  match malformed {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 6L)
      assert_eq(reason.contains("dash"), true)
    }
    _ => fail("expected malformed dash ExtGState")
  }
}

///|
fn resources_with_ext(
  ext : @objects.PdfDictionary,
) -> @content.ContentResources {
  let ext_category : @objects.PdfDictionary = Map::new()
  ext_category[@objects.PdfName::new(b"GS1")] = @objects.PdfObject::Dictionary(
    ext,
  )
  let resource_dict : @objects.PdfDictionary = Map::new()
  resource_dict[@objects.PdfName::new(b"ExtGState")] = @objects.PdfObject::Dictionary(
    ext_category,
  )
  @content.ContentResources::from_dictionary(resource_dict)
}
