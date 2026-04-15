///|
let jpeg_zigzag_order : Array[Int] = [
  0, 1, 8, 16, 9, 2, 3, 10, 17, 24, 32, 25, 18, 11, 4, 5, 12, 19, 26, 33, 40, 48,
  41, 34, 27, 20, 13, 6, 7, 14, 21, 28, 35, 42, 49, 56, 57, 50, 43, 36, 29, 22, 15,
  23, 30, 37, 44, 51, 58, 59, 52, 45, 38, 31, 39, 46, 53, 60, 61, 54, 47, 55, 62,
  63,
]

///|
priv struct JpegQuantTable {
  values : Array[Int]
}

///|
priv struct JpegHuffmanTable {
  rows : Array[Array[Int?]]
  max_bits : Int
}

///|
priv struct JpegComponent {
  id : Int
  horizontal_sampling : Int
  vertical_sampling : Int
  quant_table_id : Int
  dc_table_id : Int
  ac_table_id : Int
}

///|
priv struct JpegFrame {
  width : Int
  height : Int
  components : Array[JpegComponent]
  max_horizontal_sampling : Int
  max_vertical_sampling : Int
}

///|
priv struct JpegPlane {
  width : Int
  height : Int
  samples : Array[Byte]
}

///|
priv struct JpegDecoder {
  data : Bytes
  mut index : Int
  quant_tables : Array[JpegQuantTable?]
  dc_tables : Array[JpegHuffmanTable?]
  ac_tables : Array[JpegHuffmanTable?]
  mut frame : JpegFrame?
  mut restart_interval : Int
  mut adobe_color_transform : Int?
}

///|
priv struct JpegEntropyReader {
  data : Bytes
  mut index : Int
  mut current_byte : Int
  mut bits_left : Int
}

///|
/// Decodes image stream bytes with the DCTDecode baseline JPEG decoder.
///
/// DecodeParms such as ColorTransform are applied after entropy decoding and
/// inverse DCT so callers receive raw interleaved sample bytes.
pub fn decode_dct(
  data : Bytes,
  params : DecodeParams,
) -> Bytes raise PdfFilterError {
  JpegDecoder::new(data).decode(params)
}

///|
fn JpegDecoder::new(data : Bytes) -> JpegDecoder {
  JpegDecoder::{
    data,
    index: 0,
    quant_tables: Array::make(4, None),
    dc_tables: Array::make(4, None),
    ac_tables: Array::make(4, None),
    frame: None,
    restart_interval: 0,
    adobe_color_transform: None,
  }
}

///|
fn JpegDecoder::decode(
  self : JpegDecoder,
  params : DecodeParams,
) -> Bytes raise PdfFilterError {
  self.require_marker(0xd8, "missing SOI marker")
  while true {
    match self.next_marker() {
      0xc0 => self.parse_sof0()
      0xc2 =>
        raise PdfFilterError::UnsupportedFilter(
          "DCTDecode progressive JPEG is not supported",
        )
      0xc4 => self.parse_dht()
      0xdb => self.parse_dqt()
      0xdd => self.parse_dri()
      0xda => return self.decode_scan(params)
      0xd9 =>
        raise PdfFilterError::DecodeError("DCTDecode", "missing SOS marker")
      marker => self.skip_marker_segment(marker)
    }
  }
  raise PdfFilterError::DecodeError("DCTDecode", "missing SOS marker")
}

///|
fn JpegDecoder::decode_scan(
  self : JpegDecoder,
  params : DecodeParams,
) -> Bytes raise PdfFilterError {
  let frame = match self.frame {
    Some(value) => value
    None =>
      raise PdfFilterError::DecodeError("DCTDecode", "SOS before SOF0 marker")
  }
  self.parse_sos(frame)
  self.validate_frame(frame)
  let planes = self.decode_frame_planes(frame)
  self.consume_eoi_after_scan()
  self.interleave_output(frame, planes, params)
}

///|
fn JpegDecoder::require_marker(
  self : JpegDecoder,
  expected : Int,
  message : String,
) -> Unit raise PdfFilterError {
  if self.index + 1 >= self.data.length() ||
    self.data[self.index].to_int() != 0xff ||
    self.data[self.index + 1].to_int() != expected {
    raise PdfFilterError::DecodeError("DCTDecode", message)
  }
  self.index += 2
}

///|
fn JpegDecoder::next_marker(self : JpegDecoder) -> Int raise PdfFilterError {
  while self.index < self.data.length() &&
        self.data[self.index].to_int() != 0xff {
    self.index += 1
  }
  if self.index >= self.data.length() {
    raise PdfFilterError::DecodeError("DCTDecode", "missing JPEG marker")
  }
  while self.index < self.data.length() &&
        self.data[self.index].to_int() == 0xff {
    self.index += 1
  }
  if self.index >= self.data.length() {
    raise PdfFilterError::DecodeError("DCTDecode", "truncated JPEG marker")
  }
  let marker = self.data[self.index].to_int()
  self.index += 1
  if marker == 0x00 {
    raise PdfFilterError::DecodeError("DCTDecode", "unexpected stuffed byte")
  }
  marker
}

///|
fn JpegDecoder::read_u8(self : JpegDecoder) -> Int raise PdfFilterError {
  if self.index >= self.data.length() {
    raise PdfFilterError::DecodeError("DCTDecode", "truncated JPEG segment")
  }
  let value = self.data[self.index].to_int()
  self.index += 1
  value
}

///|
fn JpegDecoder::read_u16(self : JpegDecoder) -> Int raise PdfFilterError {
  let high = self.read_u8()
  let low = self.read_u8()
  high * 256 + low
}

///|
fn JpegDecoder::read_segment_bounds(
  self : JpegDecoder,
) -> Int raise PdfFilterError {
  let length = self.read_u16()
  if length < 2 || self.index + length - 2 > self.data.length() {
    raise PdfFilterError::DecodeError(
      "DCTDecode", "invalid JPEG segment length",
    )
  }
  self.index + length - 2
}

///|
fn JpegDecoder::skip_marker_segment(
  self : JpegDecoder,
  marker : Int,
) -> Unit raise PdfFilterError {
  if marker >= 0xd0 && marker <= 0xd7 {
    raise PdfFilterError::DecodeError(
      "DCTDecode", "restart marker outside scan data",
    )
  } else if marker == 0x01 {
    ()
  } else {
    let end = self.read_segment_bounds()
    if marker == 0xee {
      self.parse_app14_adobe(end)
    }
    self.index = end
  }
}

///|
fn JpegDecoder::parse_app14_adobe(self : JpegDecoder, end : Int) -> Unit {
  if end - self.index >= 12 &&
    self.data[self.index].to_int() == b'A'.to_int() &&
    self.data[self.index + 1].to_int() == b'd'.to_int() &&
    self.data[self.index + 2].to_int() == b'o'.to_int() &&
    self.data[self.index + 3].to_int() == b'b'.to_int() &&
    self.data[self.index + 4].to_int() == b'e'.to_int() {
    self.adobe_color_transform = Some(self.data[self.index + 11].to_int())
  }
}

///|
fn JpegDecoder::parse_dqt(self : JpegDecoder) -> Unit raise PdfFilterError {
  let end = self.read_segment_bounds()
  while self.index < end {
    let spec = self.read_u8()
    let precision = spec >> 4
    let table_id = spec & 0x0f
    if table_id >= 4 {
      raise PdfFilterError::DecodeError(
        "DCTDecode", "quantization table id out of range",
      )
    }
    let values = Array::make(64, 0)
    for index in 0..<64 {
      values[index] = if precision == 0 {
        self.read_u8()
      } else if precision == 1 {
        self.read_u16()
      } else {
        raise PdfFilterError::DecodeError(
          "DCTDecode", "unsupported quantization precision",
        )
      }
    }
    self.quant_tables[table_id] = Some(JpegQuantTable::{ values, })
  }
  if self.index != end {
    raise PdfFilterError::DecodeError("DCTDecode", "malformed DQT segment")
  }
}

///|
fn JpegDecoder::parse_dht(self : JpegDecoder) -> Unit raise PdfFilterError {
  let end = self.read_segment_bounds()
  while self.index < end {
    let spec = self.read_u8()
    let table_class = spec >> 4
    let table_id = spec & 0x0f
    if table_id >= 4 || table_class > 1 {
      raise PdfFilterError::DecodeError(
        "DCTDecode", "Huffman table id out of range",
      )
    }
    let counts = Array::make(17, 0)
    let mut symbol_count = 0
    for bits in 1..<=16 {
      counts[bits] = self.read_u8()
      symbol_count += counts[bits]
    }
    if self.index + symbol_count > end {
      raise PdfFilterError::DecodeError("DCTDecode", "truncated DHT symbols")
    }
    let symbols = Array::make(symbol_count, 0)
    for index in 0..<symbol_count {
      symbols[index] = self.read_u8()
    }
    let table = build_jpeg_huffman_table(counts, symbols)
    if table_class == 0 {
      self.dc_tables[table_id] = Some(table)
    } else {
      self.ac_tables[table_id] = Some(table)
    }
  }
  if self.index != end {
    raise PdfFilterError::DecodeError("DCTDecode", "malformed DHT segment")
  }
}

///|
fn JpegDecoder::parse_sof0(self : JpegDecoder) -> Unit raise PdfFilterError {
  let end = self.read_segment_bounds()
  let precision = self.read_u8()
  let height = self.read_u16()
  let width = self.read_u16()
  let component_count = self.read_u8()
  if precision != 8 {
    raise PdfFilterError::UnsupportedFilter(
      "DCTDecode only supports 8-bit baseline JPEG",
    )
  }
  if width <= 0 || height <= 0 {
    raise PdfFilterError::DecodeError("DCTDecode", "invalid JPEG dimensions")
  }
  if component_count != 1 && component_count != 3 {
    raise PdfFilterError::UnsupportedFilter(
      "DCTDecode only supports grayscale and three-component JPEG data",
    )
  }
  let components : Array[JpegComponent] = []
  let mut max_h = 1
  let mut max_v = 1
  for _ in 0..<component_count {
    let id = self.read_u8()
    let sampling = self.read_u8()
    let h = sampling >> 4
    let v = sampling & 0x0f
    let quant_table_id = self.read_u8()
    if h <= 0 || h > 4 || v <= 0 || v > 4 || quant_table_id >= 4 {
      raise PdfFilterError::DecodeError(
        "DCTDecode", "invalid component sampling or quantization table",
      )
    }
    if h > max_h {
      max_h = h
    }
    if v > max_v {
      max_v = v
    }
    components.push(JpegComponent::{
      id,
      horizontal_sampling: h,
      vertical_sampling: v,
      quant_table_id,
      dc_table_id: 0,
      ac_table_id: 0,
    })
  }
  if self.index != end {
    raise PdfFilterError::DecodeError("DCTDecode", "malformed SOF0 segment")
  }
  self.frame = Some(JpegFrame::{
    width,
    height,
    components,
    max_horizontal_sampling: max_h,
    max_vertical_sampling: max_v,
  })
}

///|
fn JpegDecoder::parse_dri(self : JpegDecoder) -> Unit raise PdfFilterError {
  let end = self.read_segment_bounds()
  self.restart_interval = self.read_u16()
  if self.index != end {
    raise PdfFilterError::DecodeError("DCTDecode", "malformed DRI segment")
  }
}

///|
fn JpegDecoder::parse_sos(
  self : JpegDecoder,
  frame : JpegFrame,
) -> Unit raise PdfFilterError {
  let end = self.read_segment_bounds()
  let component_count = self.read_u8()
  if component_count != frame.components.length() {
    raise PdfFilterError::DecodeError(
      "DCTDecode", "SOS component count does not match SOF0",
    )
  }
  for _ in 0..<component_count {
    let component_id = self.read_u8()
    let table_spec = self.read_u8()
    let component_index = find_jpeg_component(frame, component_id)
    frame.components[component_index] = JpegComponent::{
      ..frame.components[component_index],
      dc_table_id: table_spec >> 4,
      ac_table_id: table_spec & 0x0f,
    }
  }
  let spectral_start = self.read_u8()
  let spectral_end = self.read_u8()
  let approximation = self.read_u8()
  if spectral_start != 0 || spectral_end != 63 || approximation != 0 {
    raise PdfFilterError::UnsupportedFilter(
      "DCTDecode only supports baseline sequential scans",
    )
  }
  if self.index != end {
    raise PdfFilterError::DecodeError("DCTDecode", "malformed SOS segment")
  }
}

///|
fn JpegDecoder::validate_frame(
  self : JpegDecoder,
  frame : JpegFrame,
) -> Unit raise PdfFilterError {
  for component in frame.components {
    if component.quant_table_id >= self.quant_tables.length() ||
      self.quant_tables[component.quant_table_id] is None {
      raise PdfFilterError::DecodeError(
        "DCTDecode", "missing quantization table",
      )
    }
    if component.dc_table_id >= self.dc_tables.length() ||
      self.dc_tables[component.dc_table_id] is None ||
      component.ac_table_id >= self.ac_tables.length() ||
      self.ac_tables[component.ac_table_id] is None {
      raise PdfFilterError::DecodeError("DCTDecode", "missing Huffman table")
    }
  }
}

///|
fn JpegDecoder::decode_frame_planes(
  self : JpegDecoder,
  frame : JpegFrame,
) -> Array[JpegPlane] raise PdfFilterError {
  let planes = create_jpeg_planes(frame)
  let reader = JpegEntropyReader::new(self.data, self.index)
  let dc_predictors = Array::make(frame.components.length(), 0)
  let mcu_cols = ceil_div(frame.width, frame.max_horizontal_sampling * 8)
  let mcu_rows = ceil_div(frame.height, frame.max_vertical_sampling * 8)
  let mut mcu_count = 0
  let mut expected_restart = 0
  for mcu_y in 0..<mcu_rows {
    for mcu_x in 0..<mcu_cols {
      for component_index in 0..<frame.components.length() {
        let component = frame.components[component_index]
        for block_y in 0..<component.vertical_sampling {
          for block_x in 0..<component.horizontal_sampling {
            let block = self.decode_block(
              reader, component, dc_predictors, component_index,
            )
            put_jpeg_block(
              planes[component_index],
              component,
              mcu_x,
              mcu_y,
              block_x,
              block_y,
              block,
            )
          }
        }
      }
      mcu_count += 1
      if self.restart_interval > 0 &&
        mcu_count % self.restart_interval == 0 &&
        mcu_count < mcu_cols * mcu_rows {
        reader.consume_restart_marker(expected_restart)
        expected_restart = (expected_restart + 1) % 8
        reset_int_array(dc_predictors)
      }
    }
  }
  reader.align_to_byte()
  self.index = reader.index
  planes
}

///|
fn JpegDecoder::decode_block(
  self : JpegDecoder,
  reader : JpegEntropyReader,
  component : JpegComponent,
  dc_predictors : Array[Int],
  component_index : Int,
) -> Array[Byte] raise PdfFilterError {
  let dc_table = self.require_dc_table(component.dc_table_id)
  let ac_table = self.require_ac_table(component.ac_table_id)
  let quant_table = self.require_quant_table(component.quant_table_id)
  let coefficients = Array::make(64, 0)
  let dc_size = dc_table.decode_symbol(reader)
  if dc_size > 11 {
    raise PdfFilterError::DecodeError(
      "DCTDecode", "invalid DC coefficient size",
    )
  }
  let dc_diff = reader.receive_extend(dc_size)
  dc_predictors[component_index] += dc_diff
  coefficients[0] = dc_predictors[component_index]

  let mut index = 1
  while index < 64 {
    let symbol = ac_table.decode_symbol(reader)
    if symbol == 0x00 {
      break
    } else if symbol == 0xf0 {
      index += 16
    } else {
      let run = symbol >> 4
      let size = symbol & 0x0f
      index += run
      if index >= 64 {
        raise PdfFilterError::DecodeError(
          "DCTDecode", "AC coefficient run exceeds block",
        )
      }
      coefficients[index] = reader.receive_extend(size)
      index += 1
    }
  }
  dequantize_and_idct(coefficients, quant_table)
}

///|
fn JpegDecoder::require_quant_table(
  self : JpegDecoder,
  table_id : Int,
) -> JpegQuantTable raise PdfFilterError {
  if table_id >= 0 && table_id < self.quant_tables.length() {
    match self.quant_tables[table_id] {
      Some(table) => return table
      None => ()
    }
  }
  raise PdfFilterError::DecodeError("DCTDecode", "missing quantization table")
}

///|
fn JpegDecoder::require_dc_table(
  self : JpegDecoder,
  table_id : Int,
) -> JpegHuffmanTable raise PdfFilterError {
  if table_id >= 0 && table_id < self.dc_tables.length() {
    match self.dc_tables[table_id] {
      Some(table) => return table
      None => ()
    }
  }
  raise PdfFilterError::DecodeError("DCTDecode", "missing DC Huffman table")
}

///|
fn JpegDecoder::require_ac_table(
  self : JpegDecoder,
  table_id : Int,
) -> JpegHuffmanTable raise PdfFilterError {
  if table_id >= 0 && table_id < self.ac_tables.length() {
    match self.ac_tables[table_id] {
      Some(table) => return table
      None => ()
    }
  }
  raise PdfFilterError::DecodeError("DCTDecode", "missing AC Huffman table")
}

///|
fn JpegDecoder::consume_eoi_after_scan(
  self : JpegDecoder,
) -> Unit raise PdfFilterError {
  let marker = self.next_marker()
  if marker != 0xd9 {
    raise PdfFilterError::DecodeError("DCTDecode", "missing EOI marker")
  }
}

///|
fn JpegDecoder::interleave_output(
  self : JpegDecoder,
  frame : JpegFrame,
  planes : Array[JpegPlane],
  params : DecodeParams,
) -> Bytes raise PdfFilterError {
  if frame.components.length() == 1 {
    interleave_grayscale(frame, planes[0])
  } else {
    let color_transform = self.resolve_color_transform(
      params,
      frame.components.length(),
    )
    interleave_three_component(frame, planes, color_transform)
  }
}

///|
fn JpegDecoder::resolve_color_transform(
  self : JpegDecoder,
  params : DecodeParams,
  component_count : Int,
) -> Int raise PdfFilterError {
  match self.adobe_color_transform {
    Some(value) => value
    None =>
      read_integer_parameter(
        "DCTDecode",
        params.raw,
        "ColorTransform",
        if component_count == 3 {
          1
        } else {
          0
        },
      )
  }
}

///|
fn JpegEntropyReader::new(data : Bytes, index : Int) -> JpegEntropyReader {
  JpegEntropyReader::{ data, index, current_byte: 0, bits_left: 0 }
}

///|
fn JpegEntropyReader::read_bit(
  self : JpegEntropyReader,
) -> Int raise PdfFilterError {
  if self.bits_left == 0 {
    self.current_byte = self.read_entropy_byte()
    self.bits_left = 8
  }
  self.bits_left -= 1
  (self.current_byte >> self.bits_left) & 1
}

///|
fn JpegEntropyReader::read_bits(
  self : JpegEntropyReader,
  bit_count : Int,
) -> Int raise PdfFilterError {
  let mut value = 0
  for _ in 0..<bit_count {
    value = (value << 1) | self.read_bit()
  }
  value
}

///|
fn JpegEntropyReader::receive_extend(
  self : JpegEntropyReader,
  bit_count : Int,
) -> Int raise PdfFilterError {
  if bit_count == 0 {
    0
  } else {
    let value = self.read_bits(bit_count)
    let threshold = 1 << (bit_count - 1)
    if value < threshold {
      value - ((1 << bit_count) - 1)
    } else {
      value
    }
  }
}

///|
fn JpegEntropyReader::read_entropy_byte(
  self : JpegEntropyReader,
) -> Int raise PdfFilterError {
  if self.index >= self.data.length() {
    raise PdfFilterError::DecodeError("DCTDecode", "truncated entropy data")
  }
  let value = self.data[self.index].to_int()
  self.index += 1
  if value != 0xff {
    value
  } else {
    while self.index < self.data.length() &&
          self.data[self.index].to_int() == 0xff {
      self.index += 1
    }
    if self.index >= self.data.length() {
      raise PdfFilterError::DecodeError("DCTDecode", "truncated entropy marker")
    }
    let marker = self.data[self.index].to_int()
    self.index += 1
    if marker == 0x00 {
      0xff
    } else {
      raise PdfFilterError::DecodeError(
        "DCTDecode", "unexpected marker inside entropy data",
      )
    }
  }
}

///|
fn JpegEntropyReader::align_to_byte(self : JpegEntropyReader) -> Unit {
  self.bits_left = 0
}

///|
fn JpegEntropyReader::consume_restart_marker(
  self : JpegEntropyReader,
  expected : Int,
) -> Unit raise PdfFilterError {
  self.align_to_byte()
  if self.index >= self.data.length() || self.data[self.index].to_int() != 0xff {
    raise PdfFilterError::DecodeError("DCTDecode", "missing restart marker")
  }
  while self.index < self.data.length() &&
        self.data[self.index].to_int() == 0xff {
    self.index += 1
  }
  if self.index >= self.data.length() {
    raise PdfFilterError::DecodeError("DCTDecode", "truncated restart marker")
  }
  let marker = self.data[self.index].to_int()
  self.index += 1
  if marker != 0xd0 + expected {
    raise PdfFilterError::DecodeError("DCTDecode", "unexpected restart marker")
  }
}

///|
fn JpegHuffmanTable::decode_symbol(
  self : JpegHuffmanTable,
  reader : JpegEntropyReader,
) -> Int raise PdfFilterError {
  let mut code = 0
  for bits in 1..<=self.max_bits {
    code = (code << 1) | reader.read_bit()
    let row = self.rows[bits]
    if code < row.length() {
      match row[code] {
        Some(symbol) => return symbol
        None => ()
      }
    }
  }
  raise PdfFilterError::DecodeError("DCTDecode", "invalid Huffman code")
}

///|
fn build_jpeg_huffman_table(
  counts : Array[Int],
  symbols : Array[Int],
) -> JpegHuffmanTable raise PdfFilterError {
  let rows : Array[Array[Int?]] = []
  let mut bits = 0
  while bits <= 16 {
    rows.push(Array::make(1 << bits, None))
    bits += 1
  }

  let mut code = 0
  let mut symbol_index = 0
  let mut max_bits = 0
  for length in 1..<=16 {
    let count = counts[length]
    if count > 0 {
      max_bits = length
    }
    for _ in 0..<count {
      if symbol_index >= symbols.length() || code >= 1 << length {
        raise PdfFilterError::DecodeError("DCTDecode", "invalid Huffman table")
      }
      rows[length][code] = Some(symbols[symbol_index])
      symbol_index += 1
      code += 1
    }
    code = code << 1
  }
  if symbol_index != symbols.length() {
    raise PdfFilterError::DecodeError("DCTDecode", "malformed Huffman table")
  }
  JpegHuffmanTable::{ rows, max_bits }
}

///|
fn find_jpeg_component(
  frame : JpegFrame,
  component_id : Int,
) -> Int raise PdfFilterError {
  for index in 0..<frame.components.length() {
    if frame.components[index].id == component_id {
      return index
    }
  }
  raise PdfFilterError::DecodeError("DCTDecode", "unknown SOS component id")
}

///|
fn create_jpeg_planes(frame : JpegFrame) -> Array[JpegPlane] {
  let planes : Array[JpegPlane] = []
  for component in frame.components {
    let width = ceil_div(
      frame.width * component.horizontal_sampling,
      frame.max_horizontal_sampling,
    )
    let height = ceil_div(
      frame.height * component.vertical_sampling,
      frame.max_vertical_sampling,
    )
    planes.push(JpegPlane::{
      width,
      height,
      samples: Array::make(width * height, jpeg_byte(0)),
    })
  }
  planes
}

///|
fn put_jpeg_block(
  plane : JpegPlane,
  component : JpegComponent,
  mcu_x : Int,
  mcu_y : Int,
  block_x : Int,
  block_y : Int,
  block : Array[Byte],
) -> Unit {
  let start_x = (mcu_x * component.horizontal_sampling + block_x) * 8
  let start_y = (mcu_y * component.vertical_sampling + block_y) * 8
  for y in 0..<8 {
    let target_y = start_y + y
    if target_y < plane.height {
      for x in 0..<8 {
        let target_x = start_x + x
        if target_x < plane.width {
          plane.samples[target_y * plane.width + target_x] = block[y * 8 + x]
        }
      }
    }
  }
}

///|
fn dequantize_and_idct(
  coefficients : Array[Int],
  quant_table : JpegQuantTable,
) -> Array[Byte] {
  let block = Array::make(64, 0.0)
  for index in 0..<64 {
    let natural_index = jpeg_zigzag_order[index]
    block[natural_index] = (coefficients[index] * quant_table.values[index]).to_double()
  }
  idct_8x8(block)
}

///|
fn idct_8x8(coefficients : Array[Double]) -> Array[Byte] {
  let output = Array::make(64, jpeg_byte(0))
  for y in 0..<8 {
    for x in 0..<8 {
      let mut sum = 0.0
      for v in 0..<8 {
        for u in 0..<8 {
          let cu = if u == 0 { 0.7071067811865476 } else { 1.0 }
          let cv = if v == 0 { 0.7071067811865476 } else { 1.0 }
          sum += cu *
            cv *
            coefficients[v * 8 + u] *
            @math.cos(((2 * x + 1) * u).to_double() * 3.141592653589793 / 16.0) *
            @math.cos(((2 * y + 1) * v).to_double() * 3.141592653589793 / 16.0)
        }
      }
      output[y * 8 + x] = clamp_byte_from_double(sum * 0.25 + 128.0)
    }
  }
  output
}

///|
fn interleave_grayscale(frame : JpegFrame, plane : JpegPlane) -> Bytes {
  let output : Array[Byte] = []
  for y in 0..<frame.height {
    let source_y = y * plane.height / frame.height
    for x in 0..<frame.width {
      let source_x = x * plane.width / frame.width
      output.push(plane.samples[source_y * plane.width + source_x])
    }
  }
  Bytes::from_array(output)
}

///|
fn interleave_three_component(
  frame : JpegFrame,
  planes : Array[JpegPlane],
  color_transform : Int,
) -> Bytes raise PdfFilterError {
  if color_transform != 0 && color_transform != 1 {
    raise PdfFilterError::InvalidDecodeParms(
      "DCTDecode", "ColorTransform must be 0 or 1",
    )
  }
  let output : Array[Byte] = []
  for y in 0..<frame.height {
    for x in 0..<frame.width {
      let c0 = sample_jpeg_plane(planes[0], frame.width, frame.height, x, y)
      let c1 = sample_jpeg_plane(planes[1], frame.width, frame.height, x, y)
      let c2 = sample_jpeg_plane(planes[2], frame.width, frame.height, x, y)
      if color_transform == 1 {
        let (red, green, blue) = ycbcr_to_rgb(c0, c1, c2)
        output.push(red)
        output.push(green)
        output.push(blue)
      } else {
        output.push(c0)
        output.push(c1)
        output.push(c2)
      }
    }
  }
  Bytes::from_array(output)
}

///|
fn sample_jpeg_plane(
  plane : JpegPlane,
  image_width : Int,
  image_height : Int,
  x : Int,
  y : Int,
) -> Byte {
  let source_x = x * plane.width / image_width
  let source_y = y * plane.height / image_height
  plane.samples[source_y * plane.width + source_x]
}

///|
fn ycbcr_to_rgb(y : Byte, cb : Byte, cr : Byte) -> (Byte, Byte, Byte) {
  let yy = y.to_int().to_double()
  let cbb = cb.to_int().to_double() - 128.0
  let crr = cr.to_int().to_double() - 128.0
  (
    clamp_byte_from_double(yy + 1.402 * crr),
    clamp_byte_from_double(yy - 0.344136 * cbb - 0.714136 * crr),
    clamp_byte_from_double(yy + 1.772 * cbb),
  )
}

///|
fn clamp_byte_from_double(value : Double) -> Byte {
  let rounded = @math.floor(value + 0.5).to_int()
  if rounded < 0 {
    jpeg_byte(0)
  } else if rounded > 255 {
    jpeg_byte(255)
  } else {
    rounded.to_byte()
  }
}

///|
fn jpeg_byte(value : Int) -> Byte {
  value.to_byte()
}

///|
fn ceil_div(value : Int, divisor : Int) -> Int {
  (value + divisor - 1) / divisor
}

///|
fn reset_int_array(values : Array[Int]) -> Unit {
  for index in 0..<values.length() {
    values[index] = 0
  }
}
