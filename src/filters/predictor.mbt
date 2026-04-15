///|
priv struct PredictorContext {
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
  let colors = read_positive_parameter(filter_name, raw, "Colors", 1)
  let bits_per_component = read_bits_per_component(filter_name, raw)
  let columns = self.columns(filter_name, 1)
  let row_bytes = row_byte_width(colors, bits_per_component, columns)
  PredictorContext::{ colors, bits_per_component, columns, row_bytes }
}

///|
fn apply_predictor(
  filter_name : String,
  data : Bytes,
  params : DecodeParams,
) -> Bytes raise PdfFilterError {
  match read_predictor_value(filter_name, params.raw) {
    1 => data
    2 =>
      reconstruct_tiff_predictor(
        filter_name,
        data,
        params.predictor_context(filter_name),
      )
    10..<16 =>
      reconstruct_png_predictor(
        filter_name,
        data,
        params.predictor_context(filter_name),
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
fn read_bits_per_component(
  filter_name : String,
  raw : @objects.PdfDictionary?,
) -> Int raise PdfFilterError {
  let value = read_integer_parameter(filter_name, raw, "BitsPerComponent", 8)
  match value {
    1 => 1
    2 => 2
    4 => 4
    8 => 8
    16 => 16
    _ =>
      raise PdfFilterError::InvalidDecodeParms(
        filter_name, "BitsPerComponent must be 1, 2, 4, 8, or 16",
      )
  }
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

///|
fn predictor_sample_count(context : PredictorContext) -> Int {
  context.colors * context.columns
}

///|
fn png_bytes_per_pixel(context : PredictorContext) -> Int {
  let sample_bits = context.colors * context.bits_per_component
  let bytes_per_pixel = (sample_bits + 7) / 8
  if bytes_per_pixel < 1 {
    1
  } else {
    bytes_per_pixel
  }
}

///|
fn reconstruct_tiff_predictor(
  filter_name : String,
  data : Bytes,
  context : PredictorContext,
) -> Bytes raise PdfFilterError {
  let row_bytes = context.row_bytes
  if data.length() % row_bytes != 0 {
    raise PdfFilterError::DecodeError(
      filter_name, "Predictor input length must divide into complete rows",
    )
  }

  let sample_count = predictor_sample_count(context)
  let row_count = data.length() / row_bytes
  let reconstructed : Array[Byte] = []
  let mut row_index = 0

  while row_index < row_count {
    let start = row_index * row_bytes
    let end = start + row_bytes
    let row = data[start:end].to_array()
    let samples = unpack_tiff_row_samples(
      row,
      sample_count,
      context.bits_per_component,
    )
    reconstruct_tiff_row_samples(
      samples,
      context.colors,
      context.bits_per_component,
    )
    reconstructed.append(
      pack_tiff_row_samples(
        filter_name,
        samples,
        context.bits_per_component,
        row_bytes,
      ),
    )
    row_index = row_index + 1
  }

  Bytes::from_array(reconstructed)
}

///|
fn reconstruct_png_predictor(
  filter_name : String,
  data : Bytes,
  context : PredictorContext,
) -> Bytes raise PdfFilterError {
  let row_width = context.row_bytes + 1
  if data.length() % row_width != 0 {
    raise PdfFilterError::DecodeError(
      filter_name, "Predictor input length must divide into complete rows",
    )
  }

  let row_count = data.length() / row_width
  let bytes_per_pixel = png_bytes_per_pixel(context)
  let reconstructed : Array[Byte] = []
  let mut row_index = 0
  let mut previous_row : Array[Byte] = []

  while row_index < row_count {
    let start = row_index * row_width
    let end = start + row_width
    let filter = data[start].to_int()
    let row = data[start + 1:end].to_array()
    let output_row = reconstruct_png_row(
      filter_name, filter, row, previous_row, bytes_per_pixel,
    )
    reconstructed.append(output_row)
    previous_row = output_row
    row_index = row_index + 1
  }

  Bytes::from_array(reconstructed)
}

///|
fn reconstruct_png_row(
  filter_name : String,
  filter : Int,
  encoded_row : Array[Byte],
  previous_row : Array[Byte],
  bytes_per_pixel : Int,
) -> Array[Byte] raise PdfFilterError {
  let output : Array[Byte] = []
  let mut index = 0

  while index < encoded_row.length() {
    let encoded = encoded_row[index].to_int()
    let left = if index >= bytes_per_pixel {
      output[index - bytes_per_pixel].to_int()
    } else {
      0
    }
    let up = if index < previous_row.length() {
      previous_row[index].to_int()
    } else {
      0
    }
    let upper_left = if index >= bytes_per_pixel &&
      index - bytes_per_pixel < previous_row.length() {
      previous_row[index - bytes_per_pixel].to_int()
    } else {
      0
    }
    let value = match filter {
      0 => encoded
      1 => encoded + left
      2 => encoded + up
      3 => encoded + (left + up) / 2
      4 => encoded + paeth_predictor(left, up, upper_left)
      _ =>
        raise PdfFilterError::DecodeError(
          filter_name,
          "Unknown PNG predictor row filter: " + filter.to_string(),
        )
    }
    output.push((value & 0xff).to_byte())
    index = index + 1
  }

  output
}

///|
fn paeth_predictor(a : Int, b : Int, c : Int) -> Int {
  let p = a + b - c
  let pa = abs_int(p - a)
  let pb = abs_int(p - b)
  let pc = abs_int(p - c)

  if pa <= pb && pa <= pc {
    a
  } else if pb <= pc {
    b
  } else {
    c
  }
}

///|
fn abs_int(value : Int) -> Int {
  if value < 0 {
    0 - value
  } else {
    value
  }
}

///|
fn unpack_tiff_row_samples(
  row : Array[Byte],
  sample_count : Int,
  bits_per_component : Int,
) -> Array[Int] {
  let samples : Array[Int] = []
  let mut sample_index = 0
  let mut bit_offset = 0

  while sample_index < sample_count {
    let mut sample = 0
    let mut remaining_bits = bits_per_component

    while remaining_bits > 0 {
      let byte_index = bit_offset / 8
      let bit_index = bit_offset % 8
      let available_bits = 8 - bit_index
      let take = if remaining_bits < available_bits {
        remaining_bits
      } else {
        available_bits
      }
      let shift = available_bits - take
      let mask = (1 << take) - 1
      let chunk = (row[byte_index].to_int() >> shift) & mask
      sample = (sample << take) | chunk
      bit_offset = bit_offset + take
      remaining_bits = remaining_bits - take
    }

    samples.push(sample)
    sample_index = sample_index + 1
  }

  samples
}

///|
fn reconstruct_tiff_row_samples(
  samples : Array[Int],
  colors : Int,
  bits_per_component : Int,
) -> Unit {
  let mask = (1 << bits_per_component) - 1
  let mut index = colors
  while index < samples.length() {
    samples[index] = (samples[index] + samples[index - colors]) & mask
    index = index + 1
  }
}

///|
fn pack_tiff_row_samples(
  filter_name : String,
  samples : Array[Int],
  bits_per_component : Int,
  row_bytes : Int,
) -> Array[Byte] raise PdfFilterError {
  let packed : Array[Byte] = []
  let mut current = 0
  let mut bits_filled = 0

  for sample in samples {
    let mut remaining_bits = bits_per_component
    while remaining_bits > 0 {
      let free_bits = 8 - bits_filled
      let take = if remaining_bits < free_bits {
        remaining_bits
      } else {
        free_bits
      }
      let shift = remaining_bits - take
      let chunk = (sample >> shift) & ((1 << take) - 1)
      current = (current << take) | chunk
      bits_filled = bits_filled + take
      remaining_bits = remaining_bits - take

      if bits_filled == 8 {
        packed.push(current.to_byte())
        current = 0
        bits_filled = 0
      }
    }
  }

  if bits_filled > 0 {
    packed.push((current << (8 - bits_filled)).to_byte())
  }

  if packed.length() != row_bytes {
    raise PdfFilterError::DecodeError(
      filter_name, "Predictor reconstruction produced an invalid row length",
    )
  }

  packed
}
