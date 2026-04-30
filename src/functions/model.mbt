///|
/// ISO 32000-2 clause 7.10 function dictionaries: FunctionType selects Type 0
/// sampled, Type 2 exponential interpolation, Type 3 stitching, or Type 4
/// PostScript calculator functions. Type 2 functions (PDF 1.3) include a set
/// of parameters that define an exponential interpolation of one input value
/// and n output values: f(x) = y0 through yn-1. Type 0 sampled functions use a sequence of
/// sample values in a stream, Size, BitsPerSample, Order, Encode, Decode, and
/// Range; the 21 by 31 sample example contains 326 bytes. Section 7.10.3 Type
/// 2 uses C0, C1, and N
/// exponent parameters for exponential interpolation of one input value and n
/// output values. In addition to the Table 38 entries common to all function
/// dictionaries, a Type 2 function dictionary includes the Table 40 additional
/// entries specific to a Type 2 function dictionary: C0 array, C1 array, and
/// required N number. C0 is optional and defaults to [0.0], C1 is optional and
/// defaults to [1.0], and N is required. C0 defines the function result when
/// x = 0.0, C1 defines the function result when x = 1.0, and N is the
/// interpolation exponent. Each input value x returns n values given by
/// yj = C0j + x^N * (C1j - C0j) for output component j. Values of Domain
/// constrain x so non-integer N has non-negative input and negative N has no
/// zero input; typically Domain is [0.0 1.0], N is positive, Range clips output
/// values, and N = 1 performs linear interpolation between C0 and C1 so the
/// function can also be expressed as a sampled Type 0 function. Section
/// 7.10.5.1 Type 4 PostScript calculator syntax defines lexical structure with
/// comments, no composite data structures such as strings or arrays, no
/// procedures, no variables or names, tokens, operators, and operands in a
/// brace-delimited code stream.
/// Section 7.10.5.2 Table 42 lists calculator operators: arithmetic abs add
/// atan ceiling cos cvi cvr div exp floor idiv ln log mod mul neg round sin
/// sqrt sub truncate; relational, boolean, and bitwise and bitshift eq false ge
/// gt le lt ne not or true xor; conditional if ifelse; and stack copy dup exch
/// index pop roll. Operators and operands in Type 4 functions follow Table 42;
/// PostScript language operator semantics are used without
/// requiring a full PostScript language compatible interpreter. The operand
/// syntax for Type 4 functions follows PDF conventions rather than PostScript
/// language conventions: the entire code stream defining the function is
/// enclosed in braces using left curly brace and right curly brace, and braces
/// delimit conditional expressions executed by boolean expression if and
/// boolean expression1 expression2 ifelse without procedure objects.
pub(all) enum FunctionType {
  Sampled
  /// Section 7.10.3 Type 2 exponential interpolation function.
  Exponential
  Stitching
  /// Section 7.10.5 Type 4 PostScript calculator function.
  Calculator
} derive(Eq, Debug)

///|
/// Returns the Table 38 FunctionType integer for a PDF function dictionary:
/// 0 sampled function, 2 exponential interpolation function, 3 stitching
/// function, or 4 PostScript calculator function.
pub fn FunctionType::pdf_code(self : FunctionType) -> Int {
  match self {
    Sampled => 0
    Exponential => 2
    Stitching => 3
    Calculator => 4
  }
}

///|
/// Closed numeric interval used by Table 38 Domain and Range arrays and by
/// Type 0 Encode and Decode arrays. Domain clips input values to the nearest
/// boundary value and Range clips output values to the nearest boundary value.
pub(all) struct FunctionInterval {
  min : Double
  max : Double
} derive(Eq, Debug)

///|
/// Entries common to all PDF function dictionaries from Table 38: FunctionType,
/// Domain as an array of 2*m numbers for m input values, and optional or
/// type-required Range as an array of 2*n numbers for n output values. Inputs
/// outside the declared domain are clipped to the nearest boundary value, and
/// outputs are clipped to Range when present.
pub(all) struct FunctionCommon {
  domain : Array[FunctionInterval]
  range : Array[FunctionInterval]?
} derive(Eq, Debug)

///|
/// A PDF function object may be a dictionary or a stream depending on the
/// FunctionType entry, and it may also be referenced indirectly from a PDF
/// object graph. This source model keeps direct function dictionaries or stream
/// functions separate from unresolved indirect references that a reader package
/// must load before evaluation.
pub(all) enum FunctionSource {
  DirectFunction(PdfFunction)
  IndirectFunction(@objects.ObjectId)
} derive(Eq, Debug)

///|
/// Reports whether the PDF function source already carries a direct dictionary
/// or stream function object instead of an indirect reference that still needs
/// to be materialized before the static, self-contained numerical
/// transformation can be evaluated.
pub fn FunctionSource::is_direct(self : FunctionSource) -> Bool {
  match self {
    DirectFunction(_) => true
    IndirectFunction(_) => false
  }
}

///|
/// Typed static, self-contained numerical transformations for Table 38
/// FunctionType values: Type 0 sampled, Type 2 exponential interpolation,
/// Type 3 stitching, and Type 4 PostScript calculator functions. The Type 2
/// variant carries the section 7.10.3 function dictionary with C0, C1, and N
/// exponent parameters; the Type 4 variant carries the section 7.10.5
/// PostScript calculator function program, lexical tokens, operands,
/// operators, and Table 42 operator set.
pub(all) enum PdfFunction {
  SampledFunction(SampledFunction)
  /// Type 2 exponential interpolation function dictionary from section 7.10.3:
  /// one input value, n output values, C0 array, C1 array, required N exponent,
  /// Domain constraints, optional Range clipping, and Table 40 entries.
  ExponentialFunction(ExponentialFunction)
  StitchingFunction(StitchingFunction)
  /// Type 4 PostScript calculator function from section 7.10.5: section
  /// 7.10.5.1 syntax and lexical structure, lexical tokens, operands, operators,
  /// brace-delimited code stream, and section 7.10.5.2 Table 42 operators.
  CalculatorFunction(CalculatorFunction)
} derive(Eq, Debug)

///|
/// Type 0 sampled function Order value from the additional entries specific to
/// a Type 0 function dictionary: 1 specifies linear interpolation and 3
/// specifies cubic spline interpolation, ignored when the sampled Size in an
/// input dimension is less than 4.
pub(all) enum SampleOrder {
  Linear
  Cubic
} derive(Eq, Debug)

///|
/// Type 0 sampled function table values decoded from a stream of bytes that
/// forms a continuous bit stream with the high-order bit of each byte first.
/// Each sample value uses BitsPerSample bits, the first input dimension varies
/// fastest, output components are stored in Range order, and the declared
/// sample table is determined by Size, Range, and BitsPerSample.
pub(all) struct SampleTable {
  values : Array[Double]
  output_count : Int
} derive(Eq, Debug)

///|
/// Returns how many complete Type 0 sample table entries are present. Each
/// sampled function table entry has n output components stored in the same
/// order as Range after the sample values are decoded from BitsPerSample bits.
pub fn SampleTable::sample_count(self : SampleTable) -> Int {
  if self.output_count <= 0 {
    0
  } else {
    self.values.length() / self.output_count
  }
}

///|
/// Type 0 sampled function model from section 7.10.2: Size gives the number of
/// samples in each input dimension, BitsPerSample gives the bits per sample,
/// Order chooses linear or cubic spline interpolation, Encode maps input values
/// into the sample table, Decode maps sample values into output values, Range
/// clips decoded outputs, and Domain clips input values.
pub(all) struct SampledFunction {
  common : FunctionCommon
  size : Array[Int]
  bits_per_sample : Int
  order : SampleOrder
  encode : Array[FunctionInterval]
  decode : Array[FunctionInterval]
  table : SampleTable
} derive(Eq, Debug)

///|
/// Type 2 (exponential interpolation) function (PDF 1.3) per
/// "7.10.3 Exponential interpolation functions" of ISO 32000-2.
///
/// Defines an exponential interpolation of one input value and n
/// output values: f(x) = y_0, ..., y_{n-1}.
///
/// Table 40 — Additional entries specific to a Type 2 function
/// dictionary defines:
/// - C0 (Optional, array of n numbers): function result when x = 0.0.
///   Default value: [0.0].
/// - C1 (Optional, array of n numbers): function result when x = 1.0.
///   Default value: [1.0].
/// - N (Required, number): the interpolation exponent. For each
///   input value x the function returns n values, given by
///   y_j = C0_j + x^N × (C1_j − C0_j), for 0 ≤ j < n.
///
/// Domain values shall constrain x so that when N is not an integer
/// all values of x are non-negative, and when N is negative no value
/// of x is zero. Typically Domain is [0.0 1.0] and N is a positive
/// number. The Range attribute shall be used to clip output values.
/// When N is 1, the function performs a linear interpolation between
/// C0 and C1, therefore the function can also be expressed as a
/// sampled function (Type 0).
///
/// Type 2 functions (PDF 1.3) include a set of parameters that
/// define an exponential interpolation of one input value and n output
/// values. C0 is an array that shall define the function result when
/// x = 0.0. C1 is an array that shall define the function result when
/// x = 1.0. N is a number and the required interpolation exponent.
/// Each input value x shall return n values, given by
/// yj = C0j + x N × (C1j − C0j), for 0 ≤ j < n.
/// Values of Domain shall constrain x in such a way that if N is not
/// an integer, all values of x will be non-negative, and if N is
/// negative, no value of x will be zero.
pub(all) struct ExponentialFunction {
  common : FunctionCommon
  c0 : Array[Double]
  c1 : Array[Double]
  exponent : Double
} derive(Eq, Debug)

///|
/// Type 3 stitching function from section 7.10.4: combines k 1-input functions
/// into a single 1-input function over one Domain. Bounds partition the domain
/// into subdomains, Functions supplies the k functions, and Encode maps each x
/// value from the selected subdomain into the domain of the selected function.
pub(all) struct StitchingFunction {
  common : FunctionCommon
  functions : Array[FunctionSource]
  bounds : Array[Double]
  encode : Array[FunctionInterval]
} derive(Eq, Debug)

///|
/// Type 4 PostScript calculator operands are numbers or booleans consumed by
/// the Table 42 operators. The section 7.10.5 lexical structure permits
/// comments and operator tokens but no composite data structures, strings,
/// arrays, procedures, variables, or names outside the allowed operators.
pub(all) enum CalculatorValue {
  Number(Double)
  Boolean(Bool)
} derive(Eq, Debug)

///|
/// Operators usable in Type 4 (PostScript calculator) functions, per
/// "7.10.5.2 PostScript calculator operators and operands" of
/// ISO 32000-2.
///
/// Table 42 — Operators in Type 4 functions categorises:
/// - Arithmetic operators: abs, add, atan, ceiling, cos, cvi, cvr,
///   div, exp, floor, idiv, ln, log, mod, mul, neg, round, sin, sqrt,
///   sub, truncate.
/// - Relational, boolean, and bitwise operators: and, bitshift, eq,
///   false, ge, gt, le, lt, ne, not, or, true, xor.
/// - Conditional operators: if, ifelse.
/// - Stack operators: copy, dup, exch, index, pop, roll.
///
/// The PostScript Language Reference, Third Edition defines the
/// semantics of these operators; a full PostScript language
/// compatible interpreter is not required. The operand syntax for
/// Type 4 functions follows PDF conventions rather than PostScript
/// language conventions. The entire code stream defining the
/// function shall be enclosed in braces { } (LEFT CURLY BRACE (7Bh)
/// and RIGHT CURLY BRACE (7Dh)). Braces also delimit expressions
/// executed conditionally by the if and ifelse operators:
///   boolean {expression} if
///   boolean {expression1} {expression2} ifelse
/// This construct is purely syntactic; unlike PostScript, no
/// procedure objects are involved.
pub(all) enum CalculatorOperator {
  Abs
  Add
  Atan
  Ceiling
  Cos
  Cvi
  Cvr
  Div
  Exp
  Floor
  Idiv
  Ln
  Log
  Mod
  Mul
  Neg
  Round
  Sin
  Sqrt
  Sub
  Truncate
  And
  Bitshift
  Eq
  False
  Ge
  Gt
  Le
  Lt
  Ne
  Not
  Or
  True
  Xor
  If
  Ifelse
  Copy
  Dup
  Exch
  Index
  Pop
  Roll
} derive(Eq, Debug)

///|
/// Type 4 calculator instruction parsed from PDF operand syntax. The entire
/// code stream is enclosed in braces; braces also delimit expressions executed
/// conditionally by `boolean {expression} if` and `boolean {expression1}
/// {expression2} ifelse`. Comments, numbers, booleans, allowed operator names,
/// and nested conditional blocks are accepted; strings, arrays, dictionaries,
/// variables, unknown names, and procedure objects fail closed.
pub(all) enum CalculatorInstruction {
  CalculatorNumber(Double)
  CalculatorBoolean(Bool)
  CalculatorOperator(CalculatorOperator)
  CalculatorBlock(Array[CalculatorInstruction])
} derive(Eq, Debug)

///|
/// Type 4 PostScript calculator function program from ISO 32000-2 section
/// 7.10.5, including the section 7.10.5.1 syntax and lexical structure. The
/// parser reads lexical tokens from the calculator stream: numbers, boolean
/// operands, operator names, comments, and brace-delimited conditional blocks.
/// Braces delimit `boolean {expression} if` and `boolean {expression1}
/// {expression2} ifelse`; they do not create PostScript procedure objects.
pub(all) struct CalculatorProgram {
  token_count : Int
  instructions : Array[CalculatorInstruction]
} derive(Eq, Debug)

///|
/// Type 4 PostScript calculator function (PDF 1.3), represented as a stream
/// containing code in the small subset of the PostScript language allowed for
/// PDF functions: comments, numbers, booleans, no composite data structures
/// such as strings or arrays, no procedures, and no variables or names outside
/// the allowed operators. Calculator streams still use the Table 38 common
/// FunctionType, Domain, and Range entries before arithmetic, relational,
/// boolean, bitwise, conditional, and stack operators are evaluated.
pub(all) struct CalculatorFunction {
  common : FunctionCommon
  program : CalculatorProgram
} derive(Eq, Debug)

///|
/// Direct parser handoff for a PDF function dictionary or stream, carrying the
/// Table 38 FunctionType, common Domain and Range entries, decoded Type 0 or
/// Type 4 stream bytes, implementation limits, and source offset before the
/// parser builds a sampled, exponential interpolation, stitching, or
/// PostScript calculator function.
pub(all) struct DirectFunctionParseInput {
  function_type : FunctionType
  common : FunctionCommon
  dict : @objects.PdfDictionary
  decoded_stream : Bytes?
  limits : FunctionLimits
  offset : Int64
} derive(Eq, Debug)
