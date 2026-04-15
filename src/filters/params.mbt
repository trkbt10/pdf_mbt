///|
fn normalize_pipeline(
  dict : @objects.PdfDictionary,
) -> Array[FilterSpec] raise PdfFilterError {
  let filter_key = @objects.PdfName::new(b"Filter")
  let decode_parms_key = @objects.PdfName::new(b"DecodeParms")
  let filter_entry = dict.get(filter_key)
  let decode_parms_entry = dict.get(decode_parms_key)

  match filter_entry {
    None => normalize_pipeline_without_filter(decode_parms_entry)
    Some(@objects.PdfObject::Name(name)) =>
      normalize_single_filter(name, decode_parms_entry)
    Some(@objects.PdfObject::Array(values)) =>
      normalize_filter_array(values, decode_parms_entry)
    Some(@objects.PdfObject::Null) =>
      raise PdfFilterError::InvalidFilterSpec("Filter entry must not be null")
    Some(@objects.PdfObject::Ref(_)) =>
      raise PdfFilterError::InvalidFilterSpec(
        "Filter entry must be a direct name or array",
      )
    Some(_) =>
      raise PdfFilterError::InvalidFilterSpec(
        "Filter entry must be a name or array",
      )
  }
}

///|
fn normalize_pipeline_without_filter(
  decode_parms_entry : @objects.PdfObject?,
) -> Array[FilterSpec] raise PdfFilterError {
  match decode_parms_entry {
    None => []
    Some(@objects.PdfObject::Null) => []
    Some(_) =>
      raise PdfFilterError::InvalidFilterSpec(
        "DecodeParms requires a Filter entry",
      )
  }
}

///|
fn normalize_single_filter(
  name : @objects.PdfName,
  decode_parms_entry : @objects.PdfObject?,
) -> Array[FilterSpec] raise PdfFilterError {
  let params = normalize_decode_parms_entry(decode_parms_entry, 1)
  [FilterSpec::new(parse_filter_name(name), params[0])]
}

///|
fn normalize_filter_array(
  values : Array[@objects.PdfObject],
  decode_parms_entry : @objects.PdfObject?,
) -> Array[FilterSpec] raise PdfFilterError {
  if values.length() == 0 {
    raise PdfFilterError::InvalidFilterSpec("Filter array must not be empty")
  }

  let filters : Array[FilterName] = []
  for value in values {
    match value {
      @objects.PdfObject::Name(name) => filters.push(parse_filter_name(name))
      @objects.PdfObject::Ref(_) =>
        raise PdfFilterError::InvalidFilterSpec(
          "Filter array entries must be direct names",
        )
      @objects.PdfObject::Null =>
        raise PdfFilterError::InvalidFilterSpec(
          "Filter array entries must not be null",
        )
      _ =>
        raise PdfFilterError::InvalidFilterSpec(
          "Filter array entries must be direct names",
        )
    }
  }

  let params = normalize_decode_parms_entry(
    decode_parms_entry,
    filters.length(),
  )
  let pipeline : Array[FilterSpec] = []
  let mut index = 0
  while index < filters.length() {
    pipeline.push(FilterSpec::new(filters[index], params[index]))
    index = index + 1
  }
  pipeline
}

///|
fn normalize_decode_parms_entry(
  decode_parms_entry : @objects.PdfObject?,
  filter_count : Int,
) -> Array[@objects.PdfDictionary?] raise PdfFilterError {
  match decode_parms_entry {
    None => build_empty_decode_parms(filter_count)
    Some(@objects.PdfObject::Null) => build_empty_decode_parms(filter_count)
    Some(@objects.PdfObject::Dictionary(dict)) =>
      if filter_count == 1 {
        [Some(dict)]
      } else {
        raise PdfFilterError::InvalidFilterSpec(
          "DecodeParms dictionary requires exactly one Filter",
        )
      }
    Some(@objects.PdfObject::Array(values)) =>
      normalize_decode_parms_array(values, filter_count)
    Some(@objects.PdfObject::Ref(_)) =>
      raise PdfFilterError::InvalidFilterSpec(
        "DecodeParms must be direct dictionaries or arrays",
      )
    Some(_) =>
      raise PdfFilterError::InvalidFilterSpec(
        "DecodeParms must be a dictionary, array, null, or absent",
      )
  }
}

///|
fn build_empty_decode_parms(
  filter_count : Int,
) -> Array[@objects.PdfDictionary?] {
  let params : Array[@objects.PdfDictionary?] = []
  let mut index = 0
  while index < filter_count {
    params.push(None)
    index = index + 1
  }
  params
}

///|
fn normalize_decode_parms_array(
  values : Array[@objects.PdfObject],
  filter_count : Int,
) -> Array[@objects.PdfDictionary?] raise PdfFilterError {
  if values.length() != filter_count {
    raise PdfFilterError::InvalidFilterSpec(
      "DecodeParms array length must match Filter array length",
    )
  }

  let params : Array[@objects.PdfDictionary?] = []
  for value in values {
    match value {
      @objects.PdfObject::Null => params.push(None)
      @objects.PdfObject::Dictionary(dict) => params.push(Some(dict))
      @objects.PdfObject::Ref(_) =>
        raise PdfFilterError::InvalidFilterSpec(
          "DecodeParms array entries must be direct values",
        )
      _ =>
        raise PdfFilterError::InvalidFilterSpec(
          "DecodeParms array entries must be dictionaries or null",
        )
    }
  }
  params
}

///|
fn parse_filter_name(name : @objects.PdfName) -> FilterName {
  let ascii_hex = @objects.PdfName::new(b"ASCIIHexDecode")
  let ascii85 = @objects.PdfName::new(b"ASCII85Decode")
  let flate = @objects.PdfName::new(b"FlateDecode")
  let lzw = @objects.PdfName::new(b"LZWDecode")
  let run_length = @objects.PdfName::new(b"RunLengthDecode")
  let dct = @objects.PdfName::new(b"DCTDecode")
  let ccitt = @objects.PdfName::new(b"CCITTFaxDecode")
  let jpx = @objects.PdfName::new(b"JPXDecode")

  if name == ascii_hex {
    ASCIIHexDecode
  } else if name == ascii85 {
    ASCII85Decode
  } else if name == flate {
    FlateDecode
  } else if name == lzw {
    LZWDecode
  } else if name == run_length {
    RunLengthDecode
  } else if name == dct {
    DCTDecode
  } else if name == ccitt {
    CCITTFaxDecode
  } else if name == jpx {
    JPXDecode
  } else {
    Unsupported(name.to_text())
  }
}
