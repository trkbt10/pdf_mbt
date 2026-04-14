///|
/// Rendering failures owned by the clause 10 raster layer. Device and limit
/// errors are raised before allocation or painting; unsupported capability and
/// provider failures may also be recorded in best-effort reports.
pub(all) suberror PdfRenderingError {
  InvalidDevice(String)
  InvalidResource(String)
  UnsupportedCapability(String)
  ProviderFailure(String, String)
  LimitExceeded(String, Int, Int)
  PixelOutOfBounds(Int, Int)
} derive(Eq, Debug)

///|
pub(all) enum RenderStrictness {
  Strict
  BestEffort
} derive(Eq, Debug)

///|
pub(all) struct RenderOptions {
  strictness : RenderStrictness
} derive(Eq, Debug)

///|
pub(all) enum SkippedRenderReason {
  UnsupportedResource(String)
  ProviderUnavailable(String)
  GuardLimit(String)
} derive(Eq, Debug)

///|
pub(all) struct SkippedRenderOperation {
  offset : Int64
  operation : String
  reason : SkippedRenderReason
} derive(Eq, Debug)

///|
pub(all) struct ProviderFallbackUse {
  provider : String
  fallback : String
  resource : String
} derive(Eq, Debug)

///|
pub(all) struct RenderLimitObservation {
  name : String
  observed : Int
  limit : Int
} derive(Eq, Debug)

///|
pub(all) struct RenderReport {
  mut paint_count : Int
  mut skipped_operations : Array[SkippedRenderOperation]
  mut provider_fallbacks : Array[ProviderFallbackUse]
  mut limit_observations : Array[RenderLimitObservation]
} derive(Eq, Debug)

///|
pub fn RenderOptions::strict() -> RenderOptions {
  RenderOptions::{ strictness: RenderStrictness::Strict }
}

///|
pub fn RenderOptions::best_effort() -> RenderOptions {
  RenderOptions::{ strictness: RenderStrictness::BestEffort }
}

///|
pub fn RenderOptions::default() -> RenderOptions {
  RenderOptions::strict()
}

///|
pub fn RenderOptions::is_strict(self : RenderOptions) -> Bool {
  self.strictness == RenderStrictness::Strict
}

///|
pub fn RenderReport::empty() -> RenderReport {
  RenderReport::{
    paint_count: 0,
    skipped_operations: [],
    provider_fallbacks: [],
    limit_observations: [],
  }
}

///|
pub fn RenderReport::record_paint(self : RenderReport) -> Unit {
  self.paint_count += 1
}

///|
pub fn RenderReport::record_skip(
  self : RenderReport,
  offset : Int64,
  operation : String,
  reason : SkippedRenderReason,
) -> Unit {
  self.skipped_operations.push(SkippedRenderOperation::{
    offset,
    operation,
    reason,
  })
}

///|
pub fn RenderReport::record_provider_fallback(
  self : RenderReport,
  provider : String,
  fallback : String,
  resource : String,
) -> Unit {
  self.provider_fallbacks.push(ProviderFallbackUse::{
    provider,
    fallback,
    resource,
  })
}

///|
pub fn RenderReport::observe_limit(
  self : RenderReport,
  name : String,
  observed : Int,
  limit : Int,
) -> Unit {
  self.limit_observations.push(RenderLimitObservation::{ name, observed, limit })
}
