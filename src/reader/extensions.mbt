///|
priv struct ExtensionParseContext {
  catalog_id : @objects.ObjectId
  header_version : PdfVersion
  catalog_version : PdfVersion?
}

///|
/// Returns typed Catalog Extensions metadata when the Catalog has a direct
/// Extensions dictionary. Missing metadata is not an error; malformed present
/// metadata raises InvalidExtension without resolving indirect objects inside
/// the extension tree.
pub fn PdfDocument::extensions(
  self : PdfDocument,
) -> PdfExtensions? raise PdfDocumentError {
  match self.catalog.entry(extension_key(b"Extensions")) {
    None => None
    Some(value) => {
      let context = ExtensionParseContext::{
        catalog_id: self.catalog.object_id,
        header_version: self.file.version(),
        catalog_version: parse_catalog_extension_version(self.catalog),
      }
      Some(parse_extensions_dictionary(value, context))
    }
  }
}

///|
fn extension_key(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn extension_error(
  context : ExtensionParseContext,
  prefix : @objects.PdfName?,
  reason : String,
) -> PdfDocumentError {
  PdfDocumentError::InvalidExtension(Some(context.catalog_id), prefix, reason)
}

///|
fn parse_catalog_extension_version(
  catalog : PdfCatalog,
) -> PdfVersion? raise PdfDocumentError {
  match catalog.entry(extension_key(b"Version")) {
    None => None
    Some(@objects.PdfObject::Name(name)) => {
      let context = ExtensionParseContext::{
        catalog_id: catalog.object_id,
        header_version: PdfVersion::{ major: 9999, minor: 9999 },
        catalog_version: None,
      }
      Some(
        parse_extension_version_name(name, "Catalog /Version", context, None),
      )
    }
    Some(_) =>
      raise PdfDocumentError::InvalidExtension(
        Some(catalog.object_id),
        None,
        "Catalog /Version must be a direct name",
      )
  }
}

///|
fn parse_extensions_dictionary(
  value : @objects.PdfObject,
  context : ExtensionParseContext,
) -> PdfExtensions raise PdfDocumentError {
  let dict = match value {
    @objects.PdfObject::Dictionary(dict) => dict
    @objects.PdfObject::Ref(_) =>
      raise extension_error(context, None, "Catalog /Extensions must be direct")
    _ =>
      raise extension_error(
        context,
        None,
        "Catalog /Extensions must be a dictionary",
      )
  }

  validate_extensions_type(dict, context)
  let prefixes : Array[PdfExtensionPrefixEntry] = []
  for prefix, raw_value in dict {
    if prefix != extension_key(b"Type") {
      let developers = parse_extension_prefix_value(prefix, raw_value, context)
      prefixes.push(PdfExtensionPrefixEntry::{ prefix, developers, raw_value })
    }
  }
  if prefixes.length() == 0 {
    raise extension_error(
      context,
      None,
      "Extensions dictionary must contain at least one developer prefix",
    )
  }
  PdfExtensions::{ prefixes, raw_dict: dict }
}

///|
fn validate_extensions_type(
  dict : @objects.PdfDictionary,
  context : ExtensionParseContext,
) -> Unit raise PdfDocumentError {
  match dict.get(extension_key(b"Type")) {
    None => ()
    Some(@objects.PdfObject::Name(name)) if name == extension_key(b"Extensions") =>
      ()
    Some(@objects.PdfObject::Name(_)) =>
      raise extension_error(
        context,
        None,
        "Extensions /Type entry must be /Extensions",
      )
    Some(_) =>
      raise extension_error(
        context,
        None,
        "Extensions /Type entry must be a direct name",
      )
  }
}

///|
fn parse_extension_prefix_value(
  prefix : @objects.PdfName,
  value : @objects.PdfObject,
  context : ExtensionParseContext,
) -> Array[PdfDeveloperExtension] raise PdfDocumentError {
  match value {
    @objects.PdfObject::Dictionary(_) =>
      [parse_developer_extension(prefix, value, context)]
    @objects.PdfObject::Array(values) => {
      require_pdf20_extension_syntax(
        context,
        Some(prefix),
        "developer extension array form",
      )
      let developers : Array[PdfDeveloperExtension] = []
      for item in values {
        match item {
          @objects.PdfObject::Dictionary(_) =>
            developers.push(parse_developer_extension(prefix, item, context))
          @objects.PdfObject::Ref(_) =>
            raise extension_error(
              context,
              Some(prefix),
              "developer extension array members must be direct dictionaries",
            )
          _ =>
            raise extension_error(
              context,
              Some(prefix),
              "developer extension array members must be dictionaries",
            )
        }
      }
      if developers.length() == 0 {
        raise extension_error(
          context,
          Some(prefix),
          "developer extension array must contain at least one dictionary",
        )
      }
      validate_extension_level_order(prefix, developers, context)
      developers
    }
    @objects.PdfObject::Ref(_) =>
      raise extension_error(
        context,
        Some(prefix),
        "developer prefix value must be direct",
      )
    _ =>
      raise extension_error(
        context,
        Some(prefix),
        "developer prefix value must be a dictionary or array",
      )
  }
}

///|
fn parse_developer_extension(
  prefix : @objects.PdfName,
  value : @objects.PdfObject,
  context : ExtensionParseContext,
) -> PdfDeveloperExtension raise PdfDocumentError {
  let dict = match value {
    @objects.PdfObject::Dictionary(dict) => dict
    @objects.PdfObject::Ref(_) =>
      raise extension_error(
        context,
        Some(prefix),
        "developer extension dictionary must be direct",
      )
    _ =>
      raise extension_error(
        context,
        Some(prefix),
        "developer extension value must be a dictionary",
      )
  }

  validate_developer_entries_direct(prefix, dict, context)
  validate_developer_extension_type(prefix, dict, context)
  let base_name = require_developer_name(
    prefix, dict, context, b"BaseVersion", "developer extension /BaseVersion",
  )
  let base_version = parse_extension_version_name(
    base_name,
    "developer extension /BaseVersion",
    context,
    Some(prefix),
  )
  validate_base_version(base_version, context, Some(prefix))
  let extension_level = require_developer_integer(
    prefix, dict, context, b"ExtensionLevel", "developer extension /ExtensionLevel",
  )
  let url = parse_developer_optional_string(
    prefix, dict, context, b"URL", "developer extension /URL",
  )
  let extension_revision = parse_developer_optional_string(
    prefix, dict, context, b"ExtensionRevision", "developer extension /ExtensionRevision",
  )
  PdfDeveloperExtension::{
    prefix,
    base_version,
    extension_level,
    url,
    extension_revision,
    raw_dict: dict,
  }
}

///|
fn validate_developer_entries_direct(
  prefix : @objects.PdfName,
  dict : @objects.PdfDictionary,
  context : ExtensionParseContext,
) -> Unit raise PdfDocumentError {
  for _, raw_value in dict {
    match raw_value {
      @objects.PdfObject::Ref(_) =>
        raise extension_error(
          context,
          Some(prefix),
          "developer extension entries must be direct objects",
        )
      _ => ()
    }
  }
}

///|
fn validate_developer_extension_type(
  prefix : @objects.PdfName,
  dict : @objects.PdfDictionary,
  context : ExtensionParseContext,
) -> Unit raise PdfDocumentError {
  match dict.get(extension_key(b"Type")) {
    None => ()
    Some(@objects.PdfObject::Name(name)) if name ==
      extension_key(b"DeveloperExtensions") => ()
    Some(@objects.PdfObject::Name(_)) =>
      raise extension_error(
        context,
        Some(prefix),
        "developer extension /Type entry must be /DeveloperExtensions",
      )
    Some(_) =>
      raise extension_error(
        context,
        Some(prefix),
        "developer extension /Type entry must be a direct name",
      )
  }
}

///|
fn require_developer_name(
  prefix : @objects.PdfName,
  dict : @objects.PdfDictionary,
  context : ExtensionParseContext,
  key_bytes : Bytes,
  label : String,
) -> @objects.PdfName raise PdfDocumentError {
  match dict.get(extension_key(key_bytes)) {
    Some(@objects.PdfObject::Name(name)) => name
    Some(@objects.PdfObject::Ref(_)) =>
      raise extension_error(context, Some(prefix), label + " must be direct")
    Some(_) =>
      raise extension_error(context, Some(prefix), label + " must be a name")
    None => raise extension_error(context, Some(prefix), label + " is required")
  }
}

///|
fn require_developer_integer(
  prefix : @objects.PdfName,
  dict : @objects.PdfDictionary,
  context : ExtensionParseContext,
  key_bytes : Bytes,
  label : String,
) -> Int raise PdfDocumentError {
  match dict.get(extension_key(key_bytes)) {
    Some(@objects.PdfObject::Integer(value)) => value.to_int()
    Some(@objects.PdfObject::Ref(_)) =>
      raise extension_error(context, Some(prefix), label + " must be direct")
    Some(_) =>
      raise extension_error(
        context,
        Some(prefix),
        label + " must be an integer",
      )
    None => raise extension_error(context, Some(prefix), label + " is required")
  }
}

///|
fn parse_developer_optional_string(
  prefix : @objects.PdfName,
  dict : @objects.PdfDictionary,
  context : ExtensionParseContext,
  key_bytes : Bytes,
  label : String,
) -> Bytes? raise PdfDocumentError {
  match dict.get(extension_key(key_bytes)) {
    None => None
    Some(@objects.PdfObject::String(bytes)) => {
      require_pdf20_extension_syntax(context, Some(prefix), label)
      Some(bytes)
    }
    Some(@objects.PdfObject::Ref(_)) =>
      raise extension_error(context, Some(prefix), label + " must be direct")
    Some(_) =>
      raise extension_error(context, Some(prefix), label + " must be a string")
  }
}

///|
fn parse_extension_version_name(
  name : @objects.PdfName,
  label : String,
  context : ExtensionParseContext,
  prefix : @objects.PdfName?,
) -> PdfVersion raise PdfDocumentError {
  let bytes = name.bytes
  let mut dot_index = -1
  for index in 0..<bytes.length() {
    if bytes[index] == b'.' {
      if dot_index >= 0 {
        raise extension_error(
          context,
          prefix,
          label + " must contain one period",
        )
      }
      dot_index = index
    }
  }
  if dot_index <= 0 || dot_index >= bytes.length() - 1 {
    raise extension_error(
      context,
      prefix,
      label + " must be two integer components separated by one period",
    )
  }
  let major = parse_extension_version_component(
    bytes, 0, dot_index, label, context, prefix,
  )
  let minor = parse_extension_version_component(
    bytes,
    dot_index + 1,
    bytes.length(),
    label,
    context,
    prefix,
  )
  PdfVersion::{ major, minor }
}

///|
fn parse_extension_version_component(
  bytes : Bytes,
  start : Int,
  end : Int,
  label : String,
  context : ExtensionParseContext,
  prefix : @objects.PdfName?,
) -> Int raise PdfDocumentError {
  let mut value = 0
  for index in start..<end {
    let byte = bytes[index]
    if byte < b'0' || byte > b'9' {
      raise extension_error(
        context,
        prefix,
        label + " components must contain only decimal digits",
      )
    }
    value = value * 10 + byte.to_int() - b'0'.to_int()
  }
  value
}

///|
fn compare_pdf_versions(left : PdfVersion, right : PdfVersion) -> Int {
  if left.major < right.major {
    -1
  } else if left.major > right.major {
    1
  } else if left.minor < right.minor {
    -1
  } else if left.minor > right.minor {
    1
  } else {
    0
  }
}

///|
fn validate_base_version(
  base : PdfVersion,
  context : ExtensionParseContext,
  prefix : @objects.PdfName?,
) -> Unit raise PdfDocumentError {
  if compare_pdf_versions(base, context.header_version) > 0 {
    raise extension_error(
      context, prefix, "developer extension /BaseVersion exceeds the PDF header version",
    )
  }
  match context.catalog_version {
    Some(catalog_version) =>
      if compare_pdf_versions(base, catalog_version) > 0 {
        raise extension_error(
          context, prefix, "developer extension /BaseVersion exceeds Catalog /Version",
        )
      }
    None => ()
  }
}

///|
fn pdf20_extension_syntax_allowed(context : ExtensionParseContext) -> Bool {
  let header_allows = compare_pdf_versions(context.header_version, PdfVersion::{
      major: 2,
      minor: 0,
    }) >=
    0
  let catalog_allows = match context.catalog_version {
    Some(version) =>
      compare_pdf_versions(version, PdfVersion::{ major: 2, minor: 0 }) >= 0
    None => true
  }
  header_allows && catalog_allows
}

///|
fn require_pdf20_extension_syntax(
  context : ExtensionParseContext,
  prefix : @objects.PdfName?,
  label : String,
) -> Unit raise PdfDocumentError {
  if !pdf20_extension_syntax_allowed(context) {
    raise extension_error(
      context,
      prefix,
      label + " is only allowed for PDF 2.0 extension metadata",
    )
  }
}

///|
fn validate_extension_level_order(
  prefix : @objects.PdfName,
  developers : Array[PdfDeveloperExtension],
  context : ExtensionParseContext,
) -> Unit raise PdfDocumentError {
  for index in 0..<developers.length() {
    for previous_index in 0..<index {
      let previous = developers[previous_index]
      let current = developers[index]
      if previous.base_version == current.base_version &&
        previous.extension_level > current.extension_level {
        raise extension_error(
          context,
          Some(prefix),
          "developer extension levels must increase for the same BaseVersion",
        )
      }
    }
  }
}
