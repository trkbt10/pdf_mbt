///|
priv struct PredictorContext {
  predictor : Int
  colors : Int
  bits_per_component : Int
  columns : Int
  row_bytes : Int
}

///|
fn DecodeParams::predictor_context(
  self : DecodeParams,
  filter_name : String,
) -> PredictorContext raise PdfFilterError {
  let raw = self.raw
  let predictor = read_predictor_value(filter_name, raw)
  let colors = read_positive_parameter(filter_name, raw, "Colors", 1)
  let bits_per_component = read_positive_parameter(
    filter_name, raw, "BitsPerComponent", 8,
  )
  let columns = read_positive_parameter(filter_name, raw, "Columns", 1)
  let row_bytes = row_byte_width(colors, bits_per_component, columns)
  PredictorContext::{
    predictor,
    colors,
    bits_per_component,
    columns,
    row_bytes,
  }
}

///|
fn apply_predictor(
  filter_name : String,
  data : Bytes,
  params : DecodeParams,
) -> Bytes raise PdfFilterError {
  let context = params.predictor_context(filter_name)
  match context.predictor {
    1 => data
    2 | 10..<16 =>
      raise PdfFilterError::DecodeError(
        filter_name, "Predictor reconstruction not implemented",
      )
    _ =>
      raise PdfFilterError::DecodeError(
        filter_name, "Predictor reconstruction not implemented",
      )
  }
}

///|
fn read_predictor_value(
  filter_name : String,
  raw : @objects.PdfDictionary?,
) -> Int raise PdfFilterError {
  match read_integer_parameter(filter_name, raw, "Predictor", 1) {
    1 => 1
    2 => 2
    10 => 10
    11 => 11
    12 => 12
    13 => 13
    14 => 14
    15 => 15
    other =>
      raise PdfFilterError::InvalidDecodeParms(
        filter_name,
        "Predictor must be 1, 2, or 10-15, got " + other.to_string(),
      )
  }
}

///|
fn read_positive_parameter(
  filter_name : String,
  raw : @objects.PdfDictionary?,
  key : String,
  default : Int,
) -> Int raise PdfFilterError {
  let value = read_integer_parameter(filter_name, raw, key, default)
  if value <= 0 {
    raise PdfFilterError::InvalidDecodeParms(
      filter_name,
      key + " must be a positive integer",
    )
  }
  value
}

///|
fn read_integer_parameter(
  filter_name : String,
  raw : @objects.PdfDictionary?,
  key : String,
  default : Int,
) -> Int raise PdfFilterError {
  match raw {
    None => default
    Some(dict) => {
      let name = @objects.PdfName::new(@utf8.encode(key))
      match dict.get(name) {
        None => default
        Some(@objects.PdfObject::Integer(value)) => value.to_int()
        Some(@objects.PdfObject::Null) =>
          raise PdfFilterError::InvalidDecodeParms(
            filter_name,
            key + " must be an integer",
          )
        Some(@objects.PdfObject::Ref(_)) =>
          raise PdfFilterError::InvalidDecodeParms(
            filter_name,
            key + " must be a direct integer",
          )
        Some(_) =>
          raise PdfFilterError::InvalidDecodeParms(
            filter_name,
            key + " must be an integer",
          )
      }
    }
  }
}

///|
fn row_byte_width(colors : Int, bits_per_component : Int, columns : Int) -> Int {
  let total_bits = colors * bits_per_component * columns
  (total_bits + 7) / 8
}
