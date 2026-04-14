///|
fn multimedia_bytes_array_contains(
  values : Array[Bytes],
  target : Bytes,
) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn multimedia_ascii_lower(byte : Byte) -> Byte {
  if byte >= b'A' && byte <= b'Z' {
    (byte.to_int() + 32).to_byte()
  } else {
    byte
  }
}

///|
fn multimedia_bytes_equal_ascii_case_insensitive(
  left : Bytes,
  right : Bytes,
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if multimedia_ascii_lower(left[index]) !=
      multimedia_ascii_lower(right[index]) {
      return false
    }
  }
  true
}

///|
fn multimedia_software_uri_matches(
  uri : PdfSoftwareNameUri,
  software : PdfSoftwareIdentity,
) -> Bool {
  if uri.name != software.name {
    return false
  }
  match uri.scheme {
    Some(expected) =>
      match software.uri_scheme {
        Some(actual) =>
          multimedia_bytes_equal_ascii_case_insensitive(expected, actual)
        None => false
      }
    None => true
  }
}

///|
fn multimedia_version_component(version : PdfVersionArray, index : Int) -> Int {
  if index < version.components.length() {
    version.components[index]
  } else {
    0
  }
}

///|
/// 13.2.7.4.4 Algorithm: Comparing version arrays. Empty arrays marked as
/// infinity compare greater than any finite version array.
pub fn compare_version_arrays(
  left : PdfVersionArray,
  right : PdfVersionArray,
) -> Int {
  if left.is_infinite && right.is_infinite {
    return 0
  }
  if left.is_infinite {
    return 1
  }
  if right.is_infinite {
    return -1
  }
  let length = if left.components.length() > right.components.length() {
    left.components.length()
  } else {
    right.components.length()
  }
  for index in 0..<length {
    let left_value = multimedia_version_component(left, index)
    let right_value = multimedia_version_component(right, index)
    if left_value < right_value {
      return -1
    }
    if left_value > right_value {
      return 1
    }
  }
  0
}

///|
fn multimedia_version_is_non_negative(version : PdfVersionArray) -> Bool {
  for component in version.components {
    if component < 0 {
      return false
    }
  }
  true
}

///|
fn multimedia_version_after_lower_bound(
  actual : PdfVersionArray,
  lower : PdfVersionArray?,
  inclusive : Bool,
) -> Bool {
  let bound = match lower {
    Some(value) => value
    None => PdfVersionArray::{ components: [0], is_infinite: false }
  }
  let comparison = compare_version_arrays(actual, bound)
  comparison > 0 || (inclusive && comparison == 0)
}

///|
fn multimedia_version_before_upper_bound(
  actual : PdfVersionArray,
  upper : PdfVersionArray?,
  inclusive : Bool,
) -> Bool {
  let bound = match upper {
    Some(value) => value
    None => PdfVersionArray::{ components: [], is_infinite: true }
  }
  let comparison = compare_version_arrays(actual, bound)
  comparison < 0 || (inclusive && comparison == 0)
}

///|
/// 13.2.7.4.2 Algorithm: software identifier. It matches U software URI names,
/// L/H/LI/HI version bounds, and OS identifiers without querying the host.
pub fn software_identifier_matches(
  identifier : PdfSoftwareIdentifier,
  software : PdfSoftwareIdentity,
) -> PdfViabilityDecision {
  let mut name_matches = false
  for uri in identifier.names {
    if multimedia_software_uri_matches(uri, software) {
      name_matches = true
    }
  }
  if !name_matches {
    return PdfViabilityDecision::NonViable("software name does not match")
  }
  match software.operating_system {
    Some(os) =>
      if identifier.operating_systems.length() > 0 &&
        !multimedia_bytes_array_contains(identifier.operating_systems, os) {
        return PdfViabilityDecision::NonViable(
          "operating system does not match",
        )
      }
    None =>
      if identifier.operating_systems.length() > 0 {
        return PdfViabilityDecision::Unknown("operating system is unknown")
      }
  }
  if !multimedia_version_is_non_negative(software.version) {
    return PdfViabilityDecision::NonViable("software version is negative")
  }
  if !multimedia_version_after_lower_bound(
      software.version,
      identifier.lower_version,
      identifier.lower_inclusive,
    ) {
    return PdfViabilityDecision::NonViable("software version is below range")
  }
  if !multimedia_version_before_upper_bound(
      software.version,
      identifier.upper_version,
      identifier.upper_inclusive,
    ) {
    return PdfViabilityDecision::NonViable("software version is above range")
  }
  PdfViabilityDecision::Viable
}

///|
fn media_player_info_matches(
  info : PdfMediaPlayerInfo,
  player : PdfSoftwareIdentity,
) -> Bool {
  for identifier in info.software_identifiers {
    if software_identifier_matches(identifier, player) ==
      PdfViabilityDecision::Viable {
      return true
    }
  }
  false
}

///|
fn media_player_info_array_matches(
  infos : Array[PdfMediaPlayerInfo],
  player : PdfSoftwareIdentity,
) -> Bool {
  for info in infos {
    if media_player_info_matches(info, player) {
      return true
    }
  }
  false
}

///|
/// 13.2.7.2.2 Algorithm: Media Player. Applies content type, NU, MU, and A
/// policy arrays of 4-entry Table 302 media player info dictionaries with
/// PID and MH/BE viability for a caller-supplied player identity without
/// discovering or launching installed media players.
pub fn media_player_may_be_used(
  policy : PdfMediaPlayerPolicy,
  player : PdfSoftwareIdentity,
  content_type : Bytes?,
) -> PdfViabilityDecision {
  match content_type {
    Some(value) =>
      if !multimedia_bytes_array_contains(player.content_types, value) {
        return PdfViabilityDecision::NonViable(
          "player does not support content type",
        )
      }
    None => ()
  }
  if media_player_info_array_matches(policy.not_allowed, player) {
    return PdfViabilityDecision::NonViable("player is in NU")
  }
  if policy.must_use.length() > 0 &&
    !media_player_info_array_matches(policy.must_use, player) {
    return PdfViabilityDecision::NonViable("player is not in MU")
  }
  if policy.must_use.length() == 0 &&
    content_type is None &&
    !media_player_info_array_matches(policy.allowed, player) {
    return PdfViabilityDecision::NonViable(
      "content type is unknown and player is not in A",
    )
  }
  PdfViabilityDecision::Viable
}
