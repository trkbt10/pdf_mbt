///|
test "transparency colour policy inherits page and parent blending spaces" {
  let page = @graphics.ColourSpace::Device(
    @graphics.DeviceColourSpace::DeviceRGB,
  )
  let parent = @graphics.ColourSpace::Device(
    @graphics.DeviceColourSpace::DeviceCMYK,
  )
  let page_resolution = resolve_transparency_colour_space(TransparencyColourSpaceRequest::{
    role: PageBlendingSpace,
    explicit_space: None,
    parent_space: None,
    page_space: page,
    default_device_space: None,
  })
  assert_eq(page_resolution.blending_space == page, true)
  assert_eq(page_resolution.inherited, true)

  let child_resolution = resolve_transparency_colour_space(TransparencyColourSpaceRequest::{
    role: NonIsolatedGroupBlendingSpace,
    explicit_space: None,
    parent_space: Some(parent),
    page_space: page,
    default_device_space: None,
  })
  assert_eq(child_resolution.blending_space == parent, true)
}

///|
test "transparency colour policy substitutes nearest supported ancestor" {
  let page = @graphics.ColourSpace::Device(
    @graphics.DeviceColourSpace::DeviceRGB,
  )
  let parent = @graphics.ColourSpace::Device(
    @graphics.DeviceColourSpace::DeviceCMYK,
  )
  let resolution = resolve_transparency_colour_space(TransparencyColourSpaceRequest::{
    role: IsolatedGroupBlendingSpace,
    explicit_space: Some(
      @graphics.ColourSpace::Pattern(@graphics.PatternParams::{
        underlying: None,
      }),
    ),
    parent_space: Some(parent),
    page_space: page,
    default_device_space: None,
  })
  assert_eq(resolution.blending_space == parent, true)
  assert_eq(resolution.uses_nearest_cie_ancestor, true)
}

///|
test "transparency colour policy reports missing provider for calibrated spaces" {
  let page = @graphics.ColourSpace::Device(
    @graphics.DeviceColourSpace::DeviceRGB,
  )
  let result : Result[TransparencyColourSpaceResolution, PdfRenderingError] = try? resolve_transparency_colour_space(TransparencyColourSpaceRequest::{
      role: PageBlendingSpace,
      explicit_space: Some(
        @graphics.ColourSpace::CalGray(@graphics.CalGrayParams::{
          white_point: [1.0, 1.0, 1.0],
          black_point: [0.0, 0.0, 0.0],
          gamma: 1.0,
        }),
      ),
      parent_space: None,
      page_space: page,
      default_device_space: None,
    },
  )
  match result {
    Err(ProviderFailure(provider, _)) =>
      assert_eq(provider, "CIE/ICC colour transform")
    _ => fail("expected missing colour transform provider")
  }
}
