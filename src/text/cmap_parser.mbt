///|
pub fn parse_cmap_stream(
  stream : @objects.PdfStream,
  offset : Int64,
  limits : TextInterpretationLimits,
) -> CMap raise PdfTextError {
  let decoded = try @filters.decode_stream(stream) catch {
    error =>
      raise PdfTextError::FilterFailure(TextErrorContext::at(offset), error)
  } noraise {
    bytes => bytes
  }
  parse_decoded_cmap(decoded, offset, limits)
}

///|
pub fn parse_decoded_cmap(
  input : Bytes,
  offset : Int64,
  limits : TextInterpretationLimits,
) -> CMap raise PdfTextError {
  let parser = CMapParser::new(input, offset, limits)
  parser.parse()
  parser.cmap
}

///|
pub fn parse_to_unicode_stream(
  stream : @objects.PdfStream,
  offset : Int64,
  limits : TextInterpretationLimits,
) -> ToUnicodeCMap raise PdfTextError {
  let decoded = try @filters.decode_stream(stream) catch {
    error =>
      raise PdfTextError::FilterFailure(TextErrorContext::at(offset), error)
  } noraise {
    bytes => bytes
  }
  parse_decoded_to_unicode_cmap(decoded, offset, limits)
}

///|
pub fn parse_decoded_to_unicode_cmap(
  input : Bytes,
  offset : Int64,
  limits : TextInterpretationLimits,
) -> ToUnicodeCMap raise PdfTextError {
  let parser = CMapParser::new(input, offset, limits)
  parser.parse()
  ToUnicodeCMap::{
    name: parser.cmap.name,
    use_cmap: parser.cmap.use_cmap,
    codespaces: parser.cmap.codespaces.copy(),
    mappings: parser.unicode_mappings.copy(),
  }
}

///|
priv struct CMapParser {
  reader : @content.ContentOperandReader
  offset : Int64
  limits : TextInterpretationLimits
  stack : Array[@objects.PdfObject]
  cmap : CMap
  unicode_mappings : Array[ToUnicodeCodeMapping]
}

///|
fn CMapParser::new(
  input : Bytes,
  offset : Int64,
  limits : TextInterpretationLimits,
) -> CMapParser {
  CMapParser::{
    reader: @content.ContentOperandReader::new(input),
    offset,
    limits,
    stack: [],
    cmap: CMap::empty(),
    unicode_mappings: [],
  }
}

///|
fn CMapParser::parse(self : CMapParser) -> Unit raise PdfTextError {
  while true {
    match self.next_token() {
      EndOfCMap => break
      CMapOperand(object) => self.stack.push(object)
      CMapOperator(name, op_offset) => self.handle_operator(name, op_offset)
    }
  }
}

///|
fn CMapParser::handle_operator(
  self : CMapParser,
  name : Bytes,
  op_offset : Int64,
) -> Unit raise PdfTextError {
  if name == b"begincodespacerange" {
    self.read_codespace_ranges(op_offset)
  } else if name == b"begincidchar" {
    self.read_cid_chars(op_offset, notdef=false)
  } else if name == b"beginnotdefchar" {
    self.read_cid_chars(op_offset, notdef=true)
  } else if name == b"begincidrange" {
    self.read_cid_ranges(op_offset, notdef=false)
  } else if name == b"beginnotdefrange" {
    self.read_cid_ranges(op_offset, notdef=true)
  } else if name == b"beginbfchar" {
    self.read_bf_chars(op_offset)
  } else if name == b"beginbfrange" {
    self.read_bf_ranges(op_offset)
  } else if name == b"def" {
    self.apply_definition(op_offset)
  } else if name == b"usecmap" {
    self.apply_use_cmap(op_offset)
  } else {
    self.stack.clear()
  }
}

///|
fn CMapParser::read_codespace_ranges(
  self : CMapParser,
  op_offset : Int64,
) -> Unit raise PdfTextError {
  let count = self.take_count(op_offset, "begincodespacerange")
  for _ in 0..<count {
    let low = self.expect_string_operand("codespace low", op_offset)
    let high = self.expect_string_operand("codespace high", op_offset)
    self.add_codespace_range(low, high, op_offset)
  }
  self.expect_end_operator(b"endcodespacerange", op_offset)
}

///|
fn CMapParser::read_cid_chars(
  self : CMapParser,
  op_offset : Int64,
  notdef~ : Bool,
) -> Unit raise PdfTextError {
  let count = self.take_count(op_offset, "begincidchar")
  for _ in 0..<count {
    let code = self.expect_string_operand("CID character code", op_offset)
    let cid = self.expect_int_operand("CID value", op_offset)
    self.add_cid_mapping(code, code, cid, notdef, op_offset)
  }
  self.expect_end_operator(
    if notdef {
      b"endnotdefchar"
    } else {
      b"endcidchar"
    },
    op_offset,
  )
}

///|
fn CMapParser::read_cid_ranges(
  self : CMapParser,
  op_offset : Int64,
  notdef~ : Bool,
) -> Unit raise PdfTextError {
  let count = self.take_count(op_offset, "begincidrange")
  for _ in 0..<count {
    let low = self.expect_string_operand("CID range low", op_offset)
    let high = self.expect_string_operand("CID range high", op_offset)
    let cid = self.expect_int_operand("CID range start", op_offset)
    self.add_cid_mapping(low, high, cid, notdef, op_offset)
  }
  self.expect_end_operator(
    if notdef {
      b"endnotdefrange"
    } else {
      b"endcidrange"
    },
    op_offset,
  )
}

///|
fn CMapParser::read_bf_chars(
  self : CMapParser,
  op_offset : Int64,
) -> Unit raise PdfTextError {
  let count = self.take_count(op_offset, "beginbfchar")
  for _ in 0..<count {
    let source = self.expect_string_operand("bfchar source", op_offset)
    let destination = self.expect_string_operand(
      "bfchar destination", op_offset,
    )
    let text = decode_utf16be_text(destination, TextErrorContext::at(op_offset))
    self.unicode_mappings.push(ToUnicodeCodeMapping::{
      low: source,
      high: source,
      values: [text],
    })
  }
  self.expect_end_operator(b"endbfchar", op_offset)
}

///|
fn CMapParser::read_bf_ranges(
  self : CMapParser,
  op_offset : Int64,
) -> Unit raise PdfTextError {
  let count = self.take_count(op_offset, "beginbfrange")
  for _ in 0..<count {
    let low = self.expect_string_operand("bfrange source low", op_offset)
    let high = self.expect_string_operand("bfrange source high", op_offset)
    let range_count = validate_code_range(low, high, op_offset)
    self.limits.validate_range_expansion(
      range_count,
      TextErrorContext::at(op_offset),
    )
    let destination = self.expect_object_operand(
      "bfrange destination", op_offset,
    )
    let values = match destination {
      @objects.PdfObject::String(bytes) =>
        expand_bfrange_string(bytes, range_count, op_offset)
      @objects.PdfObject::Array(items) =>
        decode_bfrange_array(items, range_count, op_offset)
      _ =>
        raise PdfTextError::InvalidCMap(
          TextErrorContext::at(op_offset),
          "bfrange destination must be a string or array",
        )
    }
    self.unicode_mappings.push(ToUnicodeCodeMapping::{ low, high, values })
  }
  self.expect_end_operator(b"endbfrange", op_offset)
}

///|
fn CMapParser::apply_definition(
  self : CMapParser,
  op_offset : Int64,
) -> Unit raise PdfTextError {
  if self.stack.length() < 2 {
    self.stack.clear()
    return
  }
  let value = self.pop_definition_operand(op_offset)
  let key_object = self.pop_definition_operand(op_offset)
  match key_object {
    @objects.PdfObject::Name(key) =>
      if key == @objects.PdfName::new(b"CMapName") {
        match value {
          @objects.PdfObject::Name(name) => self.cmap.name = Some(name)
          _ => self.invalid("CMapName must be a name", op_offset)
        }
      } else if key == @objects.PdfName::new(b"WMode") {
        let mode = object_int(value, "WMode", op_offset)
        if mode == 0 {
          self.cmap.writing_mode = WritingMode::Horizontal
        } else if mode == 1 {
          self.cmap.writing_mode = WritingMode::Vertical
        } else {
          self.invalid("WMode must be 0 or 1", op_offset)
        }
      } else if key == @objects.PdfName::new(b"CIDSystemInfo") {
        match value {
          @objects.PdfObject::Dictionary(dict) =>
            self.cmap.cid_system_info = Some(
              parse_cid_system_info(dict, op_offset),
            )
          _ => self.invalid("CIDSystemInfo must be a dictionary", op_offset)
        }
      }
    _ => ()
  }
  self.stack.clear()
}

///|
fn CMapParser::pop_definition_operand(
  self : CMapParser,
  op_offset : Int64,
) -> @objects.PdfObject raise PdfTextError {
  match self.stack.pop() {
    Some(object) => object
    None =>
      raise PdfTextError::InvalidCMap(
        TextErrorContext::at(op_offset),
        "definition stack underflow",
      )
  }
}

///|
fn CMapParser::apply_use_cmap(
  self : CMapParser,
  op_offset : Int64,
) -> Unit raise PdfTextError {
  match self.stack.pop() {
    Some(@objects.PdfObject::Name(name)) => self.cmap.use_cmap = Some(name)
    _ => self.invalid("UseCMap must reference a CMap name", op_offset)
  }
  self.stack.clear()
}

///|
fn CMapParser::add_codespace_range(
  self : CMapParser,
  low : Bytes,
  high : Bytes,
  op_offset : Int64,
) -> Unit raise PdfTextError {
  self.limits.validate_codespace_length(
    low.length(),
    TextErrorContext::at(op_offset),
  )
  if low.length() != high.length() || bytes_to_uint(low) > bytes_to_uint(high) {
    self.invalid("invalid CMap codespace range bounds", op_offset)
  }
  let next = CMapCodespaceRange::{ low, high }
  for existing in self.cmap.codespaces {
    if ranges_overlap(existing, next) {
      self.invalid("overlapping CMap codespace ranges", op_offset)
    }
  }
  self.cmap.codespaces.push(next)
}

///|
fn CMapParser::add_cid_mapping(
  self : CMapParser,
  low : Bytes,
  high : Bytes,
  cid_start : Int,
  notdef : Bool,
  op_offset : Int64,
) -> Unit raise PdfTextError {
  let range_count = validate_code_range(low, high, op_offset)
  self.limits.validate_range_expansion(
    range_count,
    TextErrorContext::at(op_offset),
  )
  if cid_start < 0 {
    self.invalid("CID values must be non-negative", op_offset)
  }
  let mapping = CMapCIDMapping::{ low, high, cid_start }
  if notdef {
    self.cmap.notdef_mappings.push(mapping)
  } else {
    self.cmap.cid_mappings.push(mapping)
  }
}

///|
fn CMapParser::take_count(
  self : CMapParser,
  op_offset : Int64,
  operator : String,
) -> Int raise PdfTextError {
  match self.stack.pop() {
    Some(@objects.PdfObject::Integer(value)) =>
      if value >= 0L && value <= 4096L {
        value.to_int()
      } else {
        raise PdfTextError::InvalidCMap(
          TextErrorContext::at(op_offset),
          operator + " count is outside supported bounds",
        )
      }
    _ =>
      raise PdfTextError::InvalidCMap(
        TextErrorContext::at(op_offset),
        operator + " must be preceded by an integer count",
      )
  }
}

///|
fn CMapParser::expect_string_operand(
  self : CMapParser,
  label : String,
  op_offset : Int64,
) -> Bytes raise PdfTextError {
  match self.expect_object_operand(label, op_offset) {
    @objects.PdfObject::String(bytes) => bytes
    _ =>
      raise PdfTextError::InvalidCMap(
        TextErrorContext::at(op_offset),
        label + " must be a string",
      )
  }
}

///|
fn CMapParser::expect_int_operand(
  self : CMapParser,
  label : String,
  op_offset : Int64,
) -> Int raise PdfTextError {
  object_int(self.expect_object_operand(label, op_offset), label, op_offset)
}

///|
fn CMapParser::expect_object_operand(
  self : CMapParser,
  label : String,
  op_offset : Int64,
) -> @objects.PdfObject raise PdfTextError {
  match self.next_token() {
    CMapOperand(object) => object
    CMapOperator(_, _) =>
      raise PdfTextError::InvalidCMap(
        TextErrorContext::at(op_offset),
        label + " is missing before end operator",
      )
    EndOfCMap =>
      raise PdfTextError::InvalidCMap(
        TextErrorContext::at(op_offset),
        label + " is missing before end of CMap",
      )
  }
}

///|
fn CMapParser::expect_end_operator(
  self : CMapParser,
  expected : Bytes,
  op_offset : Int64,
) -> Unit raise PdfTextError {
  match self.next_token() {
    CMapOperator(name, _) =>
      if name != expected {
        raise PdfTextError::InvalidCMap(
          TextErrorContext::at(op_offset),
          "expected " + @objects.PdfName::new(expected).to_text(),
        )
      }
    _ =>
      raise PdfTextError::InvalidCMap(
        TextErrorContext::at(op_offset),
        "missing " + @objects.PdfName::new(expected).to_text(),
      )
  }
}

///|
fn CMapParser::next_token(self : CMapParser) -> CMapToken raise PdfTextError {
  try self.reader.read_next() catch {
    error =>
      raise PdfTextError::ContentFailure(
        TextErrorContext::at(self.offset),
        error,
      )
  } noraise {
    result =>
      match result {
        @content.OperandReadResult::Operand(object) => CMapOperand(object)
        @content.OperandReadResult::OperatorCandidate(name, offset) =>
          CMapOperator(name, offset)
        @content.OperandReadResult::EndOfInput(_) => EndOfCMap
      }
  }
}

///|
fn CMapParser::invalid(
  _self : CMapParser,
  message : String,
  offset : Int64,
) -> Unit raise PdfTextError {
  raise PdfTextError::InvalidCMap(TextErrorContext::at(offset), message)
}

///|
priv enum CMapToken {
  CMapOperand(@objects.PdfObject)
  CMapOperator(Bytes, Int64)
  EndOfCMap
}

///|
fn parse_cid_system_info(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> CIDSystemInfo raise PdfTextError {
  CIDSystemInfo::{
    registry: dictionary_string(dict, b"Registry", offset),
    ordering: dictionary_string(dict, b"Ordering", offset),
    supplement: dictionary_int(dict, b"Supplement", offset),
  }
}

///|
fn dictionary_string(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> String raise PdfTextError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(@objects.PdfObject::String(bytes)) =>
      @objects.PdfName::new(bytes).to_text()
    _ =>
      raise PdfTextError::InvalidCMap(
        TextErrorContext::at(offset),
        @objects.PdfName::new(key).to_text() + " must be a string",
      )
  }
}

///|
fn dictionary_int(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
) -> Int raise PdfTextError {
  match dict.get(@objects.PdfName::new(key)) {
    Some(@objects.PdfObject::Integer(value)) =>
      if value >= 0L {
        value.to_int()
      } else {
        raise PdfTextError::InvalidCMap(
          TextErrorContext::at(offset),
          @objects.PdfName::new(key).to_text() + " must be non-negative",
        )
      }
    _ =>
      raise PdfTextError::InvalidCMap(
        TextErrorContext::at(offset),
        @objects.PdfName::new(key).to_text() + " must be an integer",
      )
  }
}

///|
fn object_int(
  object : @objects.PdfObject,
  label : String,
  offset : Int64,
) -> Int raise PdfTextError {
  match object {
    @objects.PdfObject::Integer(value) =>
      if value >= 0L {
        value.to_int()
      } else {
        raise PdfTextError::InvalidCMap(
          TextErrorContext::at(offset),
          label + " must be non-negative",
        )
      }
    _ =>
      raise PdfTextError::InvalidCMap(
        TextErrorContext::at(offset),
        label + " must be an integer",
      )
  }
}

///|
fn validate_code_range(
  low : Bytes,
  high : Bytes,
  offset : Int64,
) -> Int raise PdfTextError {
  if low.length() == 0 ||
    low.length() > 4 ||
    low.length() != high.length() ||
    bytes_to_uint(low) > bytes_to_uint(high) {
    raise PdfTextError::InvalidCMap(
      TextErrorContext::at(offset),
      "invalid CMap mapping range bounds",
    )
  }
  bytes_to_uint(high) - bytes_to_uint(low) + 1
}

///|
fn expand_bfrange_string(
  bytes : Bytes,
  count : Int,
  offset : Int64,
) -> Array[String] raise PdfTextError {
  if bytes.length() == 0 || bytes.length() % 2 != 0 {
    raise PdfTextError::UnicodeConversion(
      TextErrorContext::at(offset),
      "bfrange destination string must contain UTF-16BE code units",
    )
  }
  let values : Array[String] = []
  let base_tail = read_u16be(bytes, bytes.length() - 2)
  for index in 0..<count {
    let tail = base_tail + index
    if tail > 0xffff {
      raise PdfTextError::InvalidCMap(
        TextErrorContext::at(offset),
        "bfrange destination increment overflows UTF-16BE",
      )
    }
    let incremented = replace_last_u16be(bytes, tail)
    values.push(decode_utf16be_text(incremented, TextErrorContext::at(offset)))
  }
  values
}

///|
fn decode_bfrange_array(
  items : Array[@objects.PdfObject],
  count : Int,
  offset : Int64,
) -> Array[String] raise PdfTextError {
  if items.length() != count {
    raise PdfTextError::InvalidCMap(
      TextErrorContext::at(offset),
      "bfrange destination array length must match source range",
    )
  }
  let values : Array[String] = []
  for item in items {
    match item {
      @objects.PdfObject::String(bytes) =>
        values.push(decode_utf16be_text(bytes, TextErrorContext::at(offset)))
      _ =>
        raise PdfTextError::InvalidCMap(
          TextErrorContext::at(offset),
          "bfrange destination array entries must be strings",
        )
    }
  }
  values
}

///|
fn replace_last_u16be(bytes : Bytes, value : Int) -> Bytes {
  let output : Array[Byte] = []
  for index in 0..<bytes.length() {
    if index == bytes.length() - 2 {
      output.push((value / 256).to_byte())
    } else if index == bytes.length() - 1 {
      output.push((value % 256).to_byte())
    } else {
      output.push(bytes[index])
    }
  }
  Bytes::from_array(output)
}
