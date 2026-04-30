///|
fn reader_function_id(number : Int) -> @objects.ObjectId {
  @objects.ObjectId::{ object_number: number, generation_number: 0 }
}

///|
fn reader_function_file() -> PdfFile {
  PdfFile::{
    bytes: b"",
    header: PdfHeader::{
      version: PdfVersion::{ major: 1, minor: 7 },
      base_offset: 0L,
      has_binary_indicator: false,
    },
    trailer: TrailerInfo::{
      size: 32,
      root: Some(reader_function_id(1)),
      prev: None,
      encrypt: None,
      info: None,
      id: None,
      xref_stm: None,
      raw_dict: Map::new(),
    },
    sections: [],
    xref_index: Map::new(),
    encryption: None,
    cache: Map::new(),
    object_stream_tables: Map::new(),
  }
}

///|
fn reader_numeric_array(values : Array[Double]) -> @objects.PdfObject {
  let objects : Array[@objects.PdfObject] = []
  for value in values {
    objects.push(@objects.PdfObject::Real(value))
  }
  @objects.PdfObject::Array(objects)
}

///|
fn reader_type2_function(c0 : Double, c1 : Double) -> @objects.PdfObject {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"FunctionType")] = @objects.PdfObject::Integer(2L)
  dict[@objects.PdfName::new(b"Domain")] = reader_numeric_array([0.0, 1.0])
  dict[@objects.PdfName::new(b"C0")] = reader_numeric_array([c0])
  dict[@objects.PdfName::new(b"C1")] = reader_numeric_array([c1])
  dict[@objects.PdfName::new(b"N")] = @objects.PdfObject::Real(1.0)
  @objects.PdfObject::Dictionary(dict)
}

///|
fn reader_type3_function() -> @objects.PdfObject {
  let dict : @objects.PdfDictionary = Map::new()
  dict[@objects.PdfName::new(b"FunctionType")] = @objects.PdfObject::Integer(3L)
  dict[@objects.PdfName::new(b"Domain")] = reader_numeric_array([0.0, 1.0])
  dict[@objects.PdfName::new(b"Range")] = reader_numeric_array([0.0, 2.0])
  dict[@objects.PdfName::new(b"Functions")] = @objects.PdfObject::Array([
    @objects.PdfObject::Ref(reader_function_id(2)),
    @objects.PdfObject::Ref(reader_function_id(3)),
  ])
  dict[@objects.PdfName::new(b"Bounds")] = reader_numeric_array([0.5])
  dict[@objects.PdfName::new(b"Encode")] = reader_numeric_array([
    0.0, 1.0, 0.0, 1.0,
  ])
  @objects.PdfObject::Dictionary(dict)
}

///|
test "reader materializes an indirect Type 2 function for evaluation" {
  let file = reader_function_file()
  file.cache[reader_function_id(10)] = reader_type2_function(0.0, 2.0)
  let function = file.load_function(
    reader_function_id(10),
    @functions.FunctionLimits::default(),
  )
  let output = function.evaluate([0.25], @functions.FunctionLimits::default())
  assert_eq(output.length(), 1)
  inspect(output[0], content="0.5")
}

///|
test "reader materializes nested Type 3 stitching functions" {
  let file = reader_function_file()
  file.cache[reader_function_id(1)] = reader_type3_function()
  file.cache[reader_function_id(2)] = reader_type2_function(0.0, 1.0)
  file.cache[reader_function_id(3)] = reader_type2_function(1.0, 2.0)
  let function = file.load_function(
    reader_function_id(1),
    @functions.FunctionLimits::default(),
  )
  match function {
    @functions.PdfFunction::StitchingFunction(stitching) =>
      for source in stitching.functions {
        match source {
          @functions.FunctionSource::DirectFunction(_) => ()
          @functions.FunctionSource::IndirectFunction(_) =>
            fail("expected materialized stitching subfunction")
        }
      }
    _ => fail("expected Type 3 stitching function")
  }
  let low = function.evaluate([0.25], @functions.FunctionLimits::default())
  let high = function.evaluate([0.75], @functions.FunctionLimits::default())
  inspect(low[0], content="0.5")
  inspect(high[0], content="1.5")
}

///|
test "reader reports missing or malformed function references as document errors" {
  let missing_file = reader_function_file()
  let missing : Result[@functions.PdfFunction, PdfDocumentError] = try? missing_file.load_function(
    reader_function_id(99),
    @functions.FunctionLimits::default(),
  )
  match missing {
    Err(FunctionError(id, @functions.PdfFunctionError::InvalidFunction(_, _))) =>
      assert_eq(id == reader_function_id(99), true)
    _ => fail("expected missing function to preserve function parse error")
  }

  let malformed_file = reader_function_file()
  malformed_file.cache[reader_function_id(4)] = @objects.PdfObject::String(
    b"not a function",
  )
  let malformed : Result[@functions.PdfFunction, PdfDocumentError] = try? malformed_file.load_function(
    reader_function_id(4),
    @functions.FunctionLimits::default(),
  )
  match malformed {
    Err(FunctionError(id, @functions.PdfFunctionError::InvalidFunction(_, _))) =>
      assert_eq(id == reader_function_id(4), true)
    _ => fail("expected malformed function to preserve function parse error")
  }
}
