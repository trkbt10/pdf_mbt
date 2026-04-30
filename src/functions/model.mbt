///|
/// PDF function types supported by ISO 32000-2 clause 7.10.
pub(all) enum FunctionType {
  Sampled
  Exponential
  Stitching
  Calculator
} derive(Eq, Debug)

///|
/// Returns the PDF FunctionType integer for dictionary round-tripping.
pub fn FunctionType::pdf_code(self : FunctionType) -> Int {
  match self {
    Sampled => 0
    Exponential => 2
    Stitching => 3
    Calculator => 4
  }
}

///|
/// Closed numeric interval used by Domain, Range, Encode, and Decode arrays.
pub(all) struct FunctionInterval {
  min : Double
  max : Double
} derive(Eq, Debug)

///|
/// Entries common to all PDF function dictionaries from Table 38: FunctionType,
/// Domain, and optional or type-required Range. Inputs are clipped to Domain
/// and outputs are clipped to Range when present.
pub(all) struct FunctionCommon {
  domain : Array[FunctionInterval]
  range : Array[FunctionInterval]?
} derive(Eq, Debug)

///|
/// A function source is either already materialized or an unresolved indirect
/// reference that must be loaded by a higher-level reader package.
pub(all) enum FunctionSource {
  DirectFunction(PdfFunction)
  IndirectFunction(@objects.ObjectId)
} derive(Eq, Debug)

///|
/// Reports whether the source already carries a direct function value.
pub fn FunctionSource::is_direct(self : FunctionSource) -> Bool {
  match self {
    DirectFunction(_) => true
    IndirectFunction(_) => false
  }
}

///|
/// Typed direct PDF function variants for the Table 38 FunctionType values:
/// Type 0 sampled, Type 2 exponential interpolation, Type 3 stitching, and
/// Type 4 PostScript calculator functions.
pub(all) enum PdfFunction {
  SampledFunction(SampledFunction)
  ExponentialFunction(ExponentialFunction)
  StitchingFunction(StitchingFunction)
  CalculatorFunction(CalculatorFunction)
} derive(Eq, Debug)

///|
pub(all) enum SampleOrder {
  Linear
  Cubic
} derive(Eq, Debug)

///|
/// Sampled function table values decoded from a continuous high-order-bit-first
/// sample stream. The first input dimension varies fastest, output components
/// are stored in Range order, and the declared table may match the 326 bytes
/// example for 21 by 31 samples at 4 bits per sample.
pub(all) struct SampleTable {
  values : Array[Double]
  output_count : Int
} derive(Eq, Debug)

///|
/// Returns how many complete output samples the table contains.
pub fn SampleTable::sample_count(self : SampleTable) -> Int {
  if self.output_count <= 0 {
    0
  } else {
    self.values.length() / self.output_count
  }
}

///|
/// Type 0 sampled function model: Size, BitsPerSample, Order, Encode, Decode,
/// decoded sample table, required Range, and Table 38 common Domain entries.
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
/// Type 2 exponential interpolation function (PDF 1.3): a one-input function
/// with parameters `C0`, `C1`, and required `N` that defines `f(x) = y0 ...`
/// with `yj = C0j + x^N * (C1j - C0j)`. Default `C0` is `[0.0]`, default `C1`
/// is `[1.0]`, output count is inferred from coefficient arrays, and optional
/// Range clips output values. Domain preconditions reject negative input for a
/// non-integer exponent and zero input for a negative exponent. Table 40
/// vocabulary: C0 array defines function result when x = 0.0; C1 array defines
/// function result when x = 1.0; N number is the interpolation exponent.
pub(all) struct ExponentialFunction {
  common : FunctionCommon
  c0 : Array[Double]
  c1 : Array[Double]
  exponent : Double
} derive(Eq, Debug)

///|
pub(all) struct StitchingFunction {
  common : FunctionCommon
  functions : Array[FunctionSource]
  bounds : Array[Double]
  encode : Array[FunctionInterval]
} derive(Eq, Debug)

///|
pub(all) enum CalculatorValue {
  Number(Double)
  Boolean(Bool)
} derive(Eq, Debug)

///|
/// Operators allowed by Type 4 PostScript calculator functions from Table 42:
/// arithmetic operators, relational boolean and bitwise operators, conditional
/// `if` and `ifelse`, and stack operators. No variables, names outside this
/// set, composite data structures, or procedure objects are represented.
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
/// Type 4 calculator instruction parsed from PDF brace syntax. Comments,
/// numbers, booleans, allowed operator names, and nested conditional blocks are
/// accepted; strings, arrays, dictionaries, variables, unknown names, and
/// procedure-like unsupported syntax fail closed.
pub(all) enum CalculatorInstruction {
  CalculatorNumber(Double)
  CalculatorBoolean(Bool)
  CalculatorOperator(CalculatorOperator)
  CalculatorBlock(Array[CalculatorInstruction])
} derive(Eq, Debug)

///|
/// Type 4 PostScript calculator program parsed from one outer brace-delimited
/// stream. Braces delimit conditional expressions only: `boolean {expression}
/// if` and `boolean {expression1} {expression2} ifelse`; they do not create
/// PostScript procedure objects.
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
pub(all) struct DirectFunctionParseInput {
  function_type : FunctionType
  common : FunctionCommon
  dict : @objects.PdfDictionary
  decoded_stream : Bytes?
  limits : FunctionLimits
  offset : Int64
} derive(Eq, Debug)
