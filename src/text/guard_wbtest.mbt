///|
test "text interpretation limits reject excessive cmap inputs" {
  let limits = TextInterpretationLimits::{
    max_cmap_use_depth: 1,
    max_codespace_length: 4,
    max_range_expansion: 2,
    max_cache_entries: 1,
  }
  let context = TextErrorContext::with_resource(5L, "Font/F1/CMap")

  let depth : Result[Unit, PdfTextError] = try? limits.validate_cmap_use_depth(
    2, context,
  )
  match depth {
    Err(GuardLimitExceeded(found, reason)) => {
      assert_eq(found.resource, Some("Font/F1/CMap"))
      assert_eq(reason.contains("recursion"), true)
    }
    _ => fail("expected recursion guard")
  }

  let code_length : Result[Unit, PdfTextError] = try? limits.validate_codespace_length(
    5, context,
  )
  match code_length {
    Err(InvalidCMap(_, reason)) =>
      assert_eq(reason.contains("1 through 4"), true)
    _ => fail("expected codespace guard")
  }

  let range : Result[Unit, PdfTextError] = try? limits.validate_range_expansion(
    3, context,
  )
  match range {
    Err(GuardLimitExceeded(_, reason)) =>
      assert_eq(reason.contains("range"), true)
    _ => fail("expected range guard")
  }
}

///|
test "text interpretation cache is owned per interpretation" {
  let limits = TextInterpretationLimits::{
    max_cmap_use_depth: 8,
    max_codespace_length: 4,
    max_range_expansion: 8,
    max_cache_entries: 1,
  }
  let cache = TextInterpretationCache::new(limits)
  cache.track_entry(TextErrorContext::at(0L))
  let second : Result[Unit, PdfTextError] = try? cache.track_entry(
    TextErrorContext::at(1L),
  )
  match second {
    Err(GuardLimitExceeded(context, reason)) => {
      assert_eq(context.offset, 1L)
      assert_eq(reason.contains("cache"), true)
    }
    _ => fail("expected cache guard")
  }

  let other = TextInterpretationCache::new(limits)
  other.track_entry(TextErrorContext::at(2L))
  assert_eq(other.entry_count, 1)
}
