///|
test "ExtGState applies typed transparency parameters" {
  let ext : @objects.PdfDictionary = Map::new()
  ext[pdf_name(b"BM")] = @objects.PdfObject::Array([
    @objects.PdfObject::Name(pdf_name(b"FutureMode")),
    @objects.PdfObject::Name(pdf_name(b"Multiply")),
  ])
  ext[pdf_name(b"SMask")] = @objects.PdfObject::Name(pdf_name(b"None"))
  ext[pdf_name(b"CA")] = @objects.PdfObject::Real(0.25)
  ext[pdf_name(b"ca")] = @objects.PdfObject::Real(0.75)
  ext[pdf_name(b"AIS")] = @objects.PdfObject::Boolean(true)
  ext[pdf_name(b"TK")] = @objects.PdfObject::Boolean(false)
  let state = GraphicsState::initial(GraphicsInitialState::default())
  state.apply_ext_gstate(
    resolve_ext_gstate(resources_with_ext(ext), pdf_name(b"GS1"), 11L),
    11L,
  )
  assert_eq(state.blend_mode == BlendMode::Multiply, true)
  assert_eq(state.soft_mask.source == SoftMaskSource::NoSoftMask, true)
  assert_eq(state.alpha_stroking, 0.25)
  assert_eq(state.alpha_nonstroking, 0.75)
  assert_eq(state.alpha_is_shape, true)
  assert_eq(state.text_knockout, false)
}

///|
test "ExtGState captures soft mask establishment CTM and validates alpha" {
  let ext : @objects.PdfDictionary = Map::new()
  ext[pdf_name(b"SMask")] = @objects.PdfObject::Dictionary(
    soft_mask_dictionary(@objects.PdfObject::Stream(soft_mask_group_stream()), [
      0.1, 0.2, 0.3,
    ]),
  )
  let state = GraphicsState::initial(GraphicsInitialState::default())
  let matrix = GraphicsMatrix::from_six(1.0, 0.0, 0.0, 1.0, 12.0, 34.0)
  state.concat_ctm(matrix)
  state.apply_ext_gstate(
    resolve_ext_gstate(resources_with_ext(ext), pdf_name(b"GS1"), 12L),
    12L,
  )
  match state.soft_mask.source {
    AlphaMask(mask) => {
      assert_eq(mask.backdrop_colour, [0.1, 0.2, 0.3])
      assert_eq(
        mask.transfer_function ==
        SoftMaskTransferFunction::IdentityTransferFunction,
        true,
      )
    }
    _ => fail("expected alpha soft mask")
  }
  assert_eq(state.soft_mask.established_ctm == Some(state.ctm), true)

  let bad : @objects.PdfDictionary = Map::new()
  bad[pdf_name(b"CA")] = @objects.PdfObject::Real(1.5)
  let result : Result[ExtGStatePatch, PdfGraphicsError] = try? resolve_ext_gstate(
    resources_with_ext(bad),
    pdf_name(b"GS1"),
    13L,
  )
  match result {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 13L)
      assert_eq(reason.contains("CA"), true)
    }
    _ => fail("expected alpha validation error")
  }
}

///|
test "transparency group entry resets child transparency parameters" {
  let content = @content.parse_decoded_content(
    b"/GS1 gs /Fm1 Do",
    transparent_form_resource_context(),
  )
  let program = interpret_content(content, GraphicsInitialState::default())
  assert_eq(program.final_state.blend_mode == BlendMode::Multiply, true)
  match program.events[1] {
    FormXObjectBegan(_, form, _) => assert_eq(form.group is Some(_), true)
    _ => fail("expected form begin")
  }
  match program.events[2] {
    PathPainted(_, FillPath(NonZero), _, state) => {
      assert_eq(state.blend_mode == BlendMode::Normal, true)
      assert_eq(state.alpha_nonstroking, 1.0)
      assert_eq(state.soft_mask.source == SoftMaskSource::NoSoftMask, true)
    }
    _ => fail("expected reset transparency state inside form")
  }
}

///|
fn transparent_form_resource_context() -> @content.ContentResources {
  let ext : @objects.PdfDictionary = Map::new()
  ext[pdf_name(b"BM")] = @objects.PdfObject::Name(pdf_name(b"Multiply"))
  ext[pdf_name(b"ca")] = @objects.PdfObject::Real(0.25)
  let ext_category : @objects.PdfDictionary = Map::new()
  ext_category[pdf_name(b"GS1")] = @objects.PdfObject::Dictionary(ext)
  let xobjects : @objects.PdfDictionary = Map::new()
  xobjects[pdf_name(b"Fm1")] = @objects.PdfObject::Stream(
    transparent_form_stream(b"0 0 5 5 re f"),
  )
  let resources : @objects.PdfDictionary = Map::new()
  resources[pdf_name(b"ExtGState")] = @objects.PdfObject::Dictionary(
    ext_category,
  )
  resources[pdf_name(b"XObject")] = @objects.PdfObject::Dictionary(xobjects)
  @content.ContentResources::from_dictionary(resources)
}
