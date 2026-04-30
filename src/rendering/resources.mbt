///|
/// Caller-supplied rendering provider availability. The renderer keeps object
/// resolution, PDF function evaluation, CIE/ICC transforms, and glyph masks at
/// the boundary so src/rendering does not import the reader or font engines.
pub(all) struct RenderingProviders {
  object_resolver : Bool
  function_evaluator : Bool
  colour_transform : Bool
  glyph_rasterizer : Bool
} derive(Eq, Debug)

///|
pub(all) enum RenderingProviderKind {
  ObjectResolverProvider
  PdfFunctionEvaluatorProvider
  ColourTransformProvider
  GlyphRasterizerProvider
} derive(Eq, Debug)

///|
pub fn RenderingProviders::none() -> RenderingProviders {
  RenderingProviders::{
    object_resolver: false,
    function_evaluator: false,
    colour_transform: false,
    glyph_rasterizer: false,
  }
}

///|
pub fn RenderingProviders::all() -> RenderingProviders {
  RenderingProviders::{
    object_resolver: true,
    function_evaluator: true,
    colour_transform: true,
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
    colour_transform: self.colour_transform,
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
    colour_transform: self.colour_transform,
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
    colour_transform: available,
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
    colour_transform: self.colour_transform,
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
    ColourTransformProvider => self.colour_transform
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
  needs_colour_transform? : Bool = false,
  needs_glyph_rasterizer? : Bool = false,
) -> Unit raise PdfRenderingError {
  if needs_object_resolver {
    self.require(ObjectResolverProvider, "strict rendering preflight")
  }
  if needs_function_evaluator {
    self.require(PdfFunctionEvaluatorProvider, "strict rendering preflight")
  }
  if needs_colour_transform {
    self.require(ColourTransformProvider, "strict rendering preflight")
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
    ColourTransformProvider => "CIE/ICC colour transform"
    GlyphRasterizerProvider => "glyph rasterizer"
  }
}
