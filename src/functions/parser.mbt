///|
fn decode_function_stream(
  stream : @objects.PdfStream,
  limits : FunctionLimits,
) -> Bytes raise PdfFunctionError {
  let decoded = @filters.decode_stream(stream) catch {
    error => raise PdfFunctionError::FilterFailure(error)
  }
  check_limit(
    "decoded function stream bytes",
    decoded.length(),
    limits.max_decoded_stream_bytes,
  )
  decoded
}

///|
fn direct_input_from_object(
  object : @objects.PdfObject,
  limits : FunctionLimits,
  offset : Int64,
) -> DirectFunctionParseInput raise PdfFunctionError {
  let (dict, decoded_stream) = match object {
    @objects.PdfObject::Dictionary(dict) => (dict, None)
    @objects.PdfObject::Stream(stream) =>
      (stream.dict, Some(decode_function_stream(stream, limits)))
    _ =>
      raise PdfFunctionError::InvalidFunction(
        offset,
        "function object must be a dictionary or stream, got \{object_kind_label(object)}",
      )
  }
  DirectFunctionParseInput::{
    function_type: parse_function_type(dict, offset),
    common: parse_function_common(dict, limits, offset),
    dict,
    decoded_stream,
    limits,
    offset,
  }
}

///|
fn parse_registered_direct_function(
  input : DirectFunctionParseInput,
) -> PdfFunction raise PdfFunctionError {
  match input.function_type {
    Sampled => {
      require_range(input.common, input.offset, "Type 0") |> ignore
      raise PdfFunctionError::InvalidFunction(
        input.offset,
        "Type 0 function parser is not registered yet",
      )
    }
    Exponential =>
      raise PdfFunctionError::InvalidFunction(
        input.offset,
        "Type 2 function parser is not registered yet",
      )
    Stitching =>
      raise PdfFunctionError::InvalidFunction(
        input.offset,
        "Type 3 function parser is not registered yet",
      )
    Calculator => {
      require_range(input.common, input.offset, "Type 4") |> ignore
      raise PdfFunctionError::InvalidFunction(
        input.offset,
        "Type 4 function parser is not registered yet",
      )
    }
  }
}

///|
pub fn parse_direct_function(
  object : @objects.PdfObject,
  limits : FunctionLimits,
  offset : Int64,
) -> PdfFunction raise PdfFunctionError {
  match object {
    @objects.PdfObject::Ref(object_id) =>
      raise PdfFunctionError::UnresolvedFunctionReference(object_id)
    _ =>
      parse_registered_direct_function(
        direct_input_from_object(object, limits, offset),
      )
  }
}

///|
pub fn parse_function_object(
  object : @objects.PdfObject,
  limits : FunctionLimits,
  offset : Int64,
) -> FunctionSource raise PdfFunctionError {
  match object {
    @objects.PdfObject::Ref(object_id) => IndirectFunction(object_id)
    @objects.PdfObject::Dictionary(_) | @objects.PdfObject::Stream(_) =>
      DirectFunction(parse_direct_function(object, limits, offset))
    _ =>
      raise PdfFunctionError::InvalidFunction(
        offset,
        "function source must be a dictionary, stream, or indirect reference, got \{object_kind_label(object)}",
      )
  }
}
