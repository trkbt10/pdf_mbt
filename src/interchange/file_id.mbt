///|
/// Compares current and reference file identifiers by exact byte equality.
pub fn compare_file_identifier_bytes(
  current_first : Bytes,
  current_second : Bytes,
  reference_first : Bytes,
  reference_second : Bytes,
) -> PdfFileIdMatch {
  if current_first == reference_first && current_second == reference_second {
    PdfFileIdMatch::ExactFileAndVersion
  } else if current_first == reference_first {
    PdfFileIdMatch::SameOriginalDifferentVersion
  } else {
    PdfFileIdMatch::DifferentFile
  }
}

///|
/// Helper for callers whose current file identifier is optional.
pub fn compare_optional_file_identifier_bytes(
  current_first : Bytes?,
  current_second : Bytes?,
  reference_first : Bytes,
  reference_second : Bytes,
) -> PdfFileIdMatch {
  match (current_first, current_second) {
    (Some(first), Some(second)) =>
      compare_file_identifier_bytes(
        first, second, reference_first, reference_second,
      )
    _ => PdfFileIdMatch::MissingCurrentIdentifier
  }
}
