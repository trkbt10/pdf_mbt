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
/// Entries common to all PDF function dictionaries.
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
/// Typed direct PDF function variants.
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
pub(all) struct CalculatorProgram {
  token_count : Int
} derive(Eq, Debug)

///|
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
