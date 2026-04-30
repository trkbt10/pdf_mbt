///|
pub(all) enum TransparencyColourSpaceRole {
  PageBlendingSpace
  ParentGroupBlendingSpace
  IsolatedGroupBlendingSpace
  NonIsolatedGroupBlendingSpace
  SoftMaskGroupBlendingSpace
} derive(Eq, Debug)

///|
pub(all) struct TransparencyColourSpaceRequest {
  role : TransparencyColourSpaceRole
  explicit_space : @graphics.ColourSpace?
  parent_space : @graphics.ColourSpace?
  page_space : @graphics.ColourSpace
  default_device_space : @graphics.ColourSpace?
} derive(Eq, Debug)

///|
pub(all) struct TransparencyColourSpaceResolution {
  blending_space : @graphics.ColourSpace
  inherited : Bool
  requires_colour_transform_provider : Bool
  uses_nearest_cie_ancestor : Bool
} derive(Eq, Debug)

///|
pub fn resolve_transparency_colour_space(
  request : TransparencyColourSpaceRequest,
  providers? : RenderingProviders = RenderingProviders::none(),
) -> TransparencyColourSpaceResolution raise PdfRenderingError {
  let selected = match request.explicit_space {
    Some(space) => space
    None =>
      match request.role {
        PageBlendingSpace => request.page_space
        IsolatedGroupBlendingSpace =>
          request.default_device_space.unwrap_or(request.page_space)
        ParentGroupBlendingSpace
        | NonIsolatedGroupBlendingSpace
        | SoftMaskGroupBlendingSpace =>
          request.parent_space.unwrap_or(request.page_space)
      }
  }
  let blending = nearest_supported_blending_space(
    selected,
    request.parent_space,
    request.default_device_space,
  )
  let requires_provider = transparency_space_requires_provider(blending)
  if requires_provider && !providers.colour_transform {
    raise PdfRenderingError::ProviderFailure(
      "CIE/ICC colour transform", "missing colour transform provider for transparency blending colour space",
    )
  }
  TransparencyColourSpaceResolution::{
    blending_space: blending,
    inherited: request.explicit_space is None,
    requires_colour_transform_provider: requires_provider,
    uses_nearest_cie_ancestor: blending != selected,
  }
}

///|
fn nearest_supported_blending_space(
  selected : @graphics.ColourSpace,
  parent : @graphics.ColourSpace?,
  default_device : @graphics.ColourSpace?,
) -> @graphics.ColourSpace {
  if is_supported_blending_space(selected) {
    selected
  } else {
    match parent {
      Some(space) =>
        if is_supported_blending_space(space) {
          space
        } else {
          default_device.unwrap_or(
            @graphics.ColourSpace::Device(
              @graphics.DeviceColourSpace::DeviceRGB,
            ),
          )
        }
      None =>
        default_device.unwrap_or(
          @graphics.ColourSpace::Device(@graphics.DeviceColourSpace::DeviceRGB),
        )
    }
  }
}

///|
fn is_supported_blending_space(space : @graphics.ColourSpace) -> Bool {
  match space {
    @graphics.ColourSpace::Device(device) =>
      device == @graphics.DeviceColourSpace::DeviceGray ||
      device == @graphics.DeviceColourSpace::DeviceRGB ||
      device == @graphics.DeviceColourSpace::DeviceCMYK
    @graphics.ColourSpace::CalGray(_) | @graphics.ColourSpace::CalRGB(_) => true
    @graphics.ColourSpace::Lab(_) => false
    @graphics.ColourSpace::ICCBased(profile) =>
      profile.component_count() == 1 ||
      profile.component_count() == 3 ||
      profile.component_count() == 4
    _ => false
  }
}

///|
fn transparency_space_requires_provider(space : @graphics.ColourSpace) -> Bool {
  match space {
    @graphics.ColourSpace::Device(_) => false
    _ => true
  }
}
