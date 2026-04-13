///|
/// Per-interpretation limits for untrusted CMap, ToUnicode, and mapping data.
pub(all) struct TextInterpretationLimits {
  max_cmap_use_depth : Int
  max_codespace_length : Int
  max_range_expansion : Int
  max_cache_entries : Int
} derive(Eq, Debug)

///|
/// Owned by one text interpretation pass. Later caches can hang off this value
/// without leaking data across pages or documents.
pub(all) struct TextInterpretationCache {
  limits : TextInterpretationLimits
  mut entry_count : Int
} derive(Eq, Debug)

///|
pub fn TextInterpretationLimits::default() -> TextInterpretationLimits {
  TextInterpretationLimits::{
    max_cmap_use_depth: 8,
    max_codespace_length: 4,
    max_range_expansion: 4096,
    max_cache_entries: 8192,
  }
}

///|
pub fn TextInterpretationLimits::validate_cmap_use_depth(
  self : TextInterpretationLimits,
  depth : Int,
  context : TextErrorContext,
) -> Unit raise PdfTextError {
  if depth < 0 || depth > self.max_cmap_use_depth {
    raise PdfTextError::GuardLimitExceeded(
      context, "CMap UseCMap recursion depth exceeds limit",
    )
  }
}

///|
pub fn TextInterpretationLimits::validate_codespace_length(
  self : TextInterpretationLimits,
  length : Int,
  context : TextErrorContext,
) -> Unit raise PdfTextError {
  if length <= 0 || length > self.max_codespace_length {
    raise PdfTextError::InvalidCMap(
      context, "CMap codespace length must be from 1 through 4 bytes",
    )
  }
}

///|
pub fn TextInterpretationLimits::validate_range_expansion(
  self : TextInterpretationLimits,
  count : Int,
  context : TextErrorContext,
) -> Unit raise PdfTextError {
  if count < 0 || count > self.max_range_expansion {
    raise PdfTextError::GuardLimitExceeded(
      context, "CMap mapping range expansion exceeds limit",
    )
  }
}

///|
pub fn TextInterpretationCache::new(
  limits : TextInterpretationLimits,
) -> TextInterpretationCache {
  TextInterpretationCache::{ limits, entry_count: 0 }
}

///|
pub fn TextInterpretationCache::with_default_limits() -> TextInterpretationCache {
  TextInterpretationCache::new(TextInterpretationLimits::default())
}

///|
pub fn TextInterpretationCache::track_entry(
  self : TextInterpretationCache,
  context : TextErrorContext,
) -> Unit raise PdfTextError {
  if self.entry_count + 1 > self.limits.max_cache_entries {
    raise PdfTextError::GuardLimitExceeded(
      context, "text interpretation cache entry limit exceeded",
    )
  }
  self.entry_count += 1
}
