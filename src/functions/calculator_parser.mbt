///|
enum CalculatorLexeme {
  LeftBrace
  RightBrace
  LiteralNumber(Double)
  LiteralBoolean(Bool)
  OperatorName(CalculatorOperator)
} derive(Eq, Debug)

///|
/// Scanner for Type 4 PostScript calculator functions: the code stream is
/// enclosed in braces, comments are skipped, numbers/booleans/operators are
/// accepted, and strings, arrays, dictionaries, variables, names, and procedure
/// objects fail closed.
priv struct CalculatorScanner {
  data : Bytes
  mut position : Int
  offset : Int64
}

///|
fn CalculatorScanner::new(data : Bytes, offset : Int64) -> CalculatorScanner {
  CalculatorScanner::{ data, position: 0, offset }
}

///|
fn is_calculator_space(byte : Byte) -> Bool {
  byte == b'\x00' ||
  byte == b'\x09' ||
  byte == b'\x0a' ||
  byte == b'\x0c' ||
  byte == b'\x0d' ||
  byte == b' '
}

///|
fn is_digit(byte : Byte) -> Bool {
  byte >= b'0' && byte <= b'9'
}

///|
fn is_delimiter(byte : Byte) -> Bool {
  is_calculator_space(byte) ||
  byte == b'{' ||
  byte == b'}' ||
  byte == b'%' ||
  byte == b'[' ||
  byte == b']' ||
  byte == b'(' ||
  byte == b')' ||
  byte == b'<' ||
  byte == b'>' ||
  byte == b'/'
}

///|
fn CalculatorScanner::skip_space_and_comments(self : CalculatorScanner) -> Unit {
  let mut keep_going = true
  while keep_going && self.position < self.data.length() {
    if is_calculator_space(self.data[self.position]) {
      self.position = self.position + 1
    } else if self.data[self.position] == b'%' {
      while self.position < self.data.length() &&
            self.data[self.position] != b'\x0a' &&
            self.data[self.position] != b'\x0d' {
        self.position = self.position + 1
      }
    } else {
      keep_going = false
    }
  }
}

///|
fn bytes_equal_at(
  data : Bytes,
  start : Int,
  stop : Int,
  expected : Bytes,
) -> Bool {
  if stop - start != expected.length() {
    false
  } else {
    let mut same = true
    for index in 0..<expected.length() {
      if data[start + index] != expected[index] {
        same = false
      }
    }
    same
  }
}

///|
fn calculator_name_label(data : Bytes, start : Int, stop : Int) -> String {
  data[start:stop].to_owned().to_string()
}

///|
fn parse_calculator_operator(
  data : Bytes,
  start : Int,
  stop : Int,
  offset : Int64,
) -> CalculatorOperator raise PdfFunctionError {
  if bytes_equal_at(data, start, stop, b"abs") {
    Abs
  } else if bytes_equal_at(data, start, stop, b"add") {
    Add
  } else if bytes_equal_at(data, start, stop, b"atan") {
    Atan
  } else if bytes_equal_at(data, start, stop, b"ceiling") {
    Ceiling
  } else if bytes_equal_at(data, start, stop, b"cos") {
    Cos
  } else if bytes_equal_at(data, start, stop, b"cvi") {
    Cvi
  } else if bytes_equal_at(data, start, stop, b"cvr") {
    Cvr
  } else if bytes_equal_at(data, start, stop, b"div") {
    Div
  } else if bytes_equal_at(data, start, stop, b"exp") {
    Exp
  } else if bytes_equal_at(data, start, stop, b"floor") {
    Floor
  } else if bytes_equal_at(data, start, stop, b"idiv") {
    Idiv
  } else if bytes_equal_at(data, start, stop, b"ln") {
    Ln
  } else if bytes_equal_at(data, start, stop, b"log") {
    Log
  } else if bytes_equal_at(data, start, stop, b"mod") {
    Mod
  } else if bytes_equal_at(data, start, stop, b"mul") {
    Mul
  } else if bytes_equal_at(data, start, stop, b"neg") {
    Neg
  } else if bytes_equal_at(data, start, stop, b"round") {
    Round
  } else if bytes_equal_at(data, start, stop, b"sin") {
    Sin
  } else if bytes_equal_at(data, start, stop, b"sqrt") {
    Sqrt
  } else if bytes_equal_at(data, start, stop, b"sub") {
    Sub
  } else if bytes_equal_at(data, start, stop, b"truncate") {
    Truncate
  } else if bytes_equal_at(data, start, stop, b"and") {
    And
  } else if bytes_equal_at(data, start, stop, b"bitshift") {
    Bitshift
  } else if bytes_equal_at(data, start, stop, b"eq") {
    Eq
  } else if bytes_equal_at(data, start, stop, b"ge") {
    Ge
  } else if bytes_equal_at(data, start, stop, b"gt") {
    Gt
  } else if bytes_equal_at(data, start, stop, b"le") {
    Le
  } else if bytes_equal_at(data, start, stop, b"lt") {
    Lt
  } else if bytes_equal_at(data, start, stop, b"ne") {
    Ne
  } else if bytes_equal_at(data, start, stop, b"not") {
    Not
  } else if bytes_equal_at(data, start, stop, b"or") {
    Or
  } else if bytes_equal_at(data, start, stop, b"xor") {
    Xor
  } else if bytes_equal_at(data, start, stop, b"if") {
    If
  } else if bytes_equal_at(data, start, stop, b"ifelse") {
    Ifelse
  } else if bytes_equal_at(data, start, stop, b"copy") {
    Copy
  } else if bytes_equal_at(data, start, stop, b"dup") {
    Dup
  } else if bytes_equal_at(data, start, stop, b"exch") {
    Exch
  } else if bytes_equal_at(data, start, stop, b"index") {
    Index
  } else if bytes_equal_at(data, start, stop, b"pop") {
    Pop
  } else if bytes_equal_at(data, start, stop, b"roll") {
    Roll
  } else {
    raise function_error(
      offset,
      "unsupported calculator operator or name " +
      calculator_name_label(data, start, stop),
    )
  }
}

///|
fn parse_calculator_number(
  data : Bytes,
  start : Int,
  stop : Int,
  offset : Int64,
) -> Double raise PdfFunctionError {
  let mut index = start
  let mut sign = 1.0
  if index < stop && data[index] == b'-' {
    sign = -1.0
    index = index + 1
  } else if index < stop && data[index] == b'+' {
    index = index + 1
  }
  let mut seen_digit = false
  let mut integer = 0.0
  while index < stop && is_digit(data[index]) {
    seen_digit = true
    integer = integer * 10.0 +
      (data[index].to_int() - b'0'.to_int()).to_double()
    index = index + 1
  }
  let mut fraction = 0.0
  let mut scale = 0.1
  if index < stop && data[index] == b'.' {
    index = index + 1
    while index < stop && is_digit(data[index]) {
      seen_digit = true
      fraction = fraction +
        (data[index].to_int() - b'0'.to_int()).to_double() * scale
      scale = scale / 10.0
      index = index + 1
    }
  }
  if !seen_digit || index != stop {
    raise function_error(
      offset,
      "invalid calculator number " + calculator_name_label(data, start, stop),
    )
  }
  sign * (integer + fraction)
}

///|
fn CalculatorScanner::next_lexeme(
  self : CalculatorScanner,
) -> CalculatorLexeme? raise PdfFunctionError {
  self.skip_space_and_comments()
  if self.position >= self.data.length() {
    None
  } else {
    let byte = self.data[self.position]
    if byte == b'{' {
      self.position = self.position + 1
      Some(LeftBrace)
    } else if byte == b'}' {
      self.position = self.position + 1
      Some(RightBrace)
    } else if byte == b'[' ||
      byte == b']' ||
      byte == b'(' ||
      byte == b')' ||
      byte == b'<' ||
      byte == b'>' ||
      byte == b'/' {
      raise function_error(
        self.offset,
        "calculator composite data and names are not supported",
      )
    } else {
      let start = self.position
      while self.position < self.data.length() &&
            !is_delimiter(self.data[self.position]) {
        self.position = self.position + 1
      }
      let stop = self.position
      if bytes_equal_at(self.data, start, stop, b"true") {
        Some(LiteralBoolean(true))
      } else if bytes_equal_at(self.data, start, stop, b"false") {
        Some(LiteralBoolean(false))
      } else if is_digit(self.data[start]) ||
        self.data[start] == b'+' ||
        self.data[start] == b'-' ||
        self.data[start] == b'.' {
        Some(
          LiteralNumber(
            parse_calculator_number(self.data, start, stop, self.offset),
          ),
        )
      } else {
        Some(
          OperatorName(
            parse_calculator_operator(self.data, start, stop, self.offset),
          ),
        )
      }
    }
  }
}

///|
fn parse_calculator_block(
  scanner : CalculatorScanner,
  depth : Int,
  limits : FunctionLimits,
  token_count : Ref[Int],
) -> Array[CalculatorInstruction] raise PdfFunctionError {
  check_limit("calculator block depth", depth, limits.max_recursion_depth)
  let instructions : Array[CalculatorInstruction] = []
  let mut done = false
  while !done {
    match scanner.next_lexeme() {
      None =>
        raise function_error(scanner.offset, "unbalanced calculator braces")
      Some(RightBrace) => done = true
      Some(LeftBrace) => {
        token_count.val = token_count.val + 1
        check_limit(
          "calculator tokens",
          token_count.val,
          limits.max_calculator_tokens,
        )
        instructions.push(
          CalculatorBlock(
            parse_calculator_block(scanner, depth + 1, limits, token_count),
          ),
        )
      }
      Some(LiteralNumber(value)) => {
        token_count.val = token_count.val + 1
        check_limit(
          "calculator tokens",
          token_count.val,
          limits.max_calculator_tokens,
        )
        instructions.push(CalculatorNumber(value))
      }
      Some(LiteralBoolean(value)) => {
        token_count.val = token_count.val + 1
        check_limit(
          "calculator tokens",
          token_count.val,
          limits.max_calculator_tokens,
        )
        instructions.push(CalculatorBoolean(value))
      }
      Some(OperatorName(operator)) => {
        token_count.val = token_count.val + 1
        check_limit(
          "calculator tokens",
          token_count.val,
          limits.max_calculator_tokens,
        )
        instructions.push(CalculatorOperator(operator))
      }
    }
  }
  validate_calculator_conditional_blocks(instructions, scanner.offset)
  instructions
}

///|
fn is_operator(
  instruction : CalculatorInstruction,
  operator : CalculatorOperator,
) -> Bool {
  match instruction {
    CalculatorOperator(found) => found == operator
    _ => false
  }
}

///|
fn validate_calculator_conditional_blocks(
  instructions : Array[CalculatorInstruction],
  offset : Int64,
) -> Unit raise PdfFunctionError {
  let mut index = 0
  while index < instructions.length() {
    match instructions[index] {
      CalculatorBlock(block) => {
        validate_calculator_conditional_blocks(block, offset)
        if index + 1 < instructions.length() &&
          is_operator(instructions[index + 1], If) {
          index = index + 2
        } else if index + 2 < instructions.length() {
          match instructions[index + 1] {
            CalculatorBlock(other) => {
              validate_calculator_conditional_blocks(other, offset)
              if is_operator(instructions[index + 2], Ifelse) {
                index = index + 3
              } else {
                raise function_error(
                  offset, "calculator brace blocks are only allowed before if or ifelse",
                )
              }
            }
            _ =>
              raise function_error(
                offset, "calculator brace blocks are only allowed before if or ifelse",
              )
          }
        } else {
          raise function_error(
            offset, "calculator brace blocks are only allowed before if or ifelse",
          )
        }
      }
      _ => index = index + 1
    }
  }
}

///|
fn parse_calculator_program(
  decoded_stream : Bytes,
  limits : FunctionLimits,
  offset : Int64,
) -> CalculatorProgram raise PdfFunctionError {
  let scanner = CalculatorScanner::new(decoded_stream, offset)
  match scanner.next_lexeme() {
    Some(LeftBrace) => ()
    _ =>
      raise function_error(
        offset, "calculator stream must start with left brace",
      )
  }
  let token_count : Ref[Int] = { val: 0 }
  let instructions = parse_calculator_block(scanner, 1, limits, token_count)
  match scanner.next_lexeme() {
    None => ()
    _ =>
      raise function_error(
        offset, "calculator stream must contain one top-level brace block",
      )
  }
  CalculatorProgram::{ token_count: token_count.val, instructions }
}

///|
fn parse_calculator_function(
  input : DirectFunctionParseInput,
) -> CalculatorFunction raise PdfFunctionError {
  let decoded_stream = match input.decoded_stream {
    Some(bytes) => bytes
    None =>
      raise function_error(
        input.offset,
        "Type 4 calculator functions must be streams",
      )
  }
  CalculatorFunction::{
    common: input.common,
    program: parse_calculator_program(
      decoded_stream,
      input.limits,
      input.offset,
    ),
  }
}
