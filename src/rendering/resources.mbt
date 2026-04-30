///|
/// Caller-supplied rendering provider availability. The renderer keeps object
/// resolution, PDF function evaluation, CIE/ICC transforms, and glyph masks at
/// the boundary so src/rendering does not import the reader or font engines.
pub(all) struct RenderingProviders {
  object_resolver : Bool
  function_evaluator : Bool
  transfer_function_evaluator : Bool
  tint_transform_evaluator : Bool
  colour_transform : Bool
  halftone_processor : Bool
  glyph_rasterizer : Bool
} derive(Eq, Debug)

///|
pub(all) enum RenderingProviderKind {
  ObjectResolverProvider
  PdfFunctionEvaluatorProvider
  TransferFunctionEvaluatorProvider
  TintTransformEvaluatorProvider
  ColourTransformProvider
  HalftoneProcessorProvider
  GlyphRasterizerProvider
} derive(Eq, Debug)

///|
pub fn RenderingProviders::none() -> RenderingProviders {
  RenderingProviders::{
    object_resolver: false,
    function_evaluator: false,
    transfer_function_evaluator: false,
    tint_transform_evaluator: false,
    colour_transform: false,
    halftone_processor: false,
    glyph_rasterizer: false,
  }
}

///|
pub fn RenderingProviders::all() -> RenderingProviders {
  RenderingProviders::{
    object_resolver: true,
    function_evaluator: true,
    transfer_function_evaluator: true,
    tint_transform_evaluator: true,
    colour_transform: true,
    halftone_processor: true,
    glyph_rasterizer: true,
  }
}

///|
pub fn RenderingProviders::with_object_resolver(
  self : RenderingProviders,
  available : Bool,
) -> RenderingProviders {
  RenderingProviders::{
    object_resolver: available,
    function_evaluator: self.function_evaluator,
    transfer_function_evaluator: self.transfer_function_evaluator,
    tint_transform_evaluator: self.tint_transform_evaluator,
    colour_transform: self.colour_transform,
    halftone_processor: self.halftone_processor,
    glyph_rasterizer: self.glyph_rasterizer,
  }
}

///|
pub fn RenderingProviders::with_function_evaluator(
  self : RenderingProviders,
  available : Bool,
) -> RenderingProviders {
  RenderingProviders::{
    object_resolver: self.object_resolver,
    function_evaluator: available,
    transfer_function_evaluator: self.transfer_function_evaluator,
    tint_transform_evaluator: self.tint_transform_evaluator,
    colour_transform: self.colour_transform,
    halftone_processor: self.halftone_processor,
    glyph_rasterizer: self.glyph_rasterizer,
  }
}

///|
pub fn RenderingProviders::with_transfer_function_evaluator(
  self : RenderingProviders,
  available : Bool,
) -> RenderingProviders {
  RenderingProviders::{
    object_resolver: self.object_resolver,
    function_evaluator: self.function_evaluator,
    transfer_function_evaluator: available,
    tint_transform_evaluator: self.tint_transform_evaluator,
    colour_transform: self.colour_transform,
    halftone_processor: self.halftone_processor,
    glyph_rasterizer: self.glyph_rasterizer,
  }
}

///|
pub fn RenderingProviders::with_tint_transform_evaluator(
  self : RenderingProviders,
  available : Bool,
) -> RenderingProviders {
  RenderingProviders::{
    object_resolver: self.object_resolver,
    function_evaluator: self.function_evaluator,
    transfer_function_evaluator: self.transfer_function_evaluator,
    tint_transform_evaluator: available,
    colour_transform: self.colour_transform,
    halftone_processor: self.halftone_processor,
    glyph_rasterizer: self.glyph_rasterizer,
  }
}

///|
pub fn RenderingProviders::with_colour_transform(
  self : RenderingProviders,
  available : Bool,
) -> RenderingProviders {
  RenderingProviders::{
    object_resolver: self.object_resolver,
    function_evaluator: self.function_evaluator,
    transfer_function_evaluator: self.transfer_function_evaluator,
    tint_transform_evaluator: self.tint_transform_evaluator,
    colour_transform: available,
    halftone_processor: self.halftone_processor,
    glyph_rasterizer: self.glyph_rasterizer,
  }
}

///|
pub fn RenderingProviders::with_halftone_processor(
  self : RenderingProviders,
  available : Bool,
) -> RenderingProviders {
  RenderingProviders::{
    object_resolver: self.object_resolver,
    function_evaluator: self.function_evaluator,
    transfer_function_evaluator: self.transfer_function_evaluator,
    tint_transform_evaluator: self.tint_transform_evaluator,
    colour_transform: self.colour_transform,
    halftone_processor: available,
    glyph_rasterizer: self.glyph_rasterizer,
  }
}

///|
pub fn RenderingProviders::with_glyph_rasterizer(
  self : RenderingProviders,
  available : Bool,
) -> RenderingProviders {
  RenderingProviders::{
    object_resolver: self.object_resolver,
    function_evaluator: self.function_evaluator,
    transfer_function_evaluator: self.transfer_function_evaluator,
    tint_transform_evaluator: self.tint_transform_evaluator,
    colour_transform: self.colour_transform,
    halftone_processor: self.halftone_processor,
    glyph_rasterizer: available,
  }
}

///|
pub fn RenderingProviders::has(
  self : RenderingProviders,
  kind : RenderingProviderKind,
) -> Bool {
  match kind {
    ObjectResolverProvider => self.object_resolver
    PdfFunctionEvaluatorProvider => self.function_evaluator
    TransferFunctionEvaluatorProvider => self.transfer_function_evaluator
    TintTransformEvaluatorProvider => self.tint_transform_evaluator
    ColourTransformProvider => self.colour_transform
    HalftoneProcessorProvider => self.halftone_processor
    GlyphRasterizerProvider => self.glyph_rasterizer
  }
}

///|
pub fn RenderingProviders::require(
  self : RenderingProviders,
  kind : RenderingProviderKind,
  operation : String,
) -> Unit raise PdfRenderingError {
  if !self.has(kind) {
    raise PdfRenderingError::ProviderFailure(
      provider_kind_label(kind),
      operation,
    )
  }
}

///|
pub fn RenderingProviders::strict_preflight(
  self : RenderingProviders,
  needs_object_resolver? : Bool = false,
  needs_function_evaluator? : Bool = false,
  needs_transfer_function_evaluator? : Bool = false,
  needs_tint_transform_evaluator? : Bool = false,
  needs_colour_transform? : Bool = false,
  needs_halftone_processor? : Bool = false,
  needs_glyph_rasterizer? : Bool = false,
) -> Unit raise PdfRenderingError {
  if needs_object_resolver {
    self.require(ObjectResolverProvider, "strict rendering preflight")
  }
  if needs_function_evaluator {
    self.require(PdfFunctionEvaluatorProvider, "strict rendering preflight")
  }
  if needs_transfer_function_evaluator {
    self.require(
      TransferFunctionEvaluatorProvider,
      "strict rendering preflight",
    )
  }
  if needs_tint_transform_evaluator {
    self.require(TintTransformEvaluatorProvider, "strict rendering preflight")
  }
  if needs_colour_transform {
    self.require(ColourTransformProvider, "strict rendering preflight")
  }
  if needs_halftone_processor {
    self.require(HalftoneProcessorProvider, "strict rendering preflight")
  }
  if needs_glyph_rasterizer {
    self.require(GlyphRasterizerProvider, "strict rendering preflight")
  }
}

///|
pub fn wrap_provider_failure(
  provider : RenderingProviderKind,
  operation : String,
  resource : String,
) -> PdfRenderingError {
  PdfRenderingError::ProviderFailure(
    provider_kind_label(provider),
    operation + ": " + resource,
  )
}

///|
fn provider_kind_label(kind : RenderingProviderKind) -> String {
  match kind {
    ObjectResolverProvider => "object resolver"
    PdfFunctionEvaluatorProvider => "PDF function evaluator"
    TransferFunctionEvaluatorProvider => "transfer function evaluator"
    TintTransformEvaluatorProvider => "tint transform evaluator"
    ColourTransformProvider => "CIE/ICC colour transform"
    HalftoneProcessorProvider => "halftone processor"
    GlyphRasterizerProvider => "glyph rasterizer"
  }
}
