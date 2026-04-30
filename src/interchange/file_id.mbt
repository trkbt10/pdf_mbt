///|
/// Compares the trailer ID array file identifiers from 14.4 File identifiers.
/// The ID array shall contain Two strings: the original ID and current ID.
/// A caller can use these byte strings with the 7.5.5 trailer vocabulary; the
/// literal 5 is part of that cross-reference, and PDF writers commonly derive
/// unique values with MD5 input from current time, location string, and size.
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
/// Helper for callers whose current trailer ID array is optional while still
/// comparing the reference original ID and current ID byte strings.
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
