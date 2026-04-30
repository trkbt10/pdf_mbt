///|
test "rendering providers expose strict preflight failures with context" {
  let providers = RenderingProviders::none().with_colour_transform(true)
  providers.strict_preflight(needs_colour_transform=true)

  try providers.strict_preflight(needs_glyph_rasterizer=true) catch {
    PdfRenderingError::ProviderFailure(provider, operation) => {
      assert_eq(provider, "glyph rasterizer")
      assert_eq(operation, "strict rendering preflight")
    }
    _ => fail("expected missing glyph provider failure")
  } noraise {
    _ => fail("expected missing glyph provider failure")
  }
}

///|
test "provider failure wrapper preserves provider operation and resource" {
  let error = wrap_provider_failure(
    RenderingProviderKind::ObjectResolverProvider,
    "halftone resolution",
    "HT",
  )
  match error {
    ProviderFailure(provider, context) => {
      assert_eq(provider, "object resolver")
      assert_eq(context, "halftone resolution: HT")
    }
    _ => fail("expected provider failure")
  }
}

///|
test "transparency providers expose transfer tint halftone and glyph contracts" {
  let providers = RenderingProviders::none()
    .with_function_evaluator(true)
    .with_transfer_function_evaluator(true)
    .with_tint_transform_evaluator(true)
    .with_halftone_processor(true)
    .with_glyph_rasterizer(true)
  providers.strict_preflight(
    needs_function_evaluator=true,
    needs_transfer_function_evaluator=true,
    needs_tint_transform_evaluator=true,
    needs_halftone_processor=true,
    needs_glyph_rasterizer=true,
  )
  try
    RenderingProviders::none().strict_preflight(
      needs_tint_transform_evaluator=true,
    )
  catch {
    PdfRenderingError::ProviderFailure(provider, operation) => {
      assert_eq(provider, "tint transform evaluator")
      assert_eq(operation, "strict rendering preflight")
    }
    _ => fail("expected tint transform provider failure")
  } noraise {
    _ => fail("expected tint transform provider failure")
  }
}
