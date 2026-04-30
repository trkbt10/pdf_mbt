///|
/// Loads an indirect PDF function object through the reader-owned object access
/// path and materializes it into a direct evaluable function. Nested Type 3
/// stitching function references are resolved here as well, keeping lazy object
/// loading in the reader layer and preserving function-domain failures inside
/// document-level diagnostics.
pub fn PdfFile::load_function(
  self : PdfFile,
  object_id : @objects.ObjectId,
  limits : @functions.FunctionLimits,
) -> @functions.PdfFunction raise PdfDocumentError {
  load_function_with_path(self, object_id, limits, [])
}

///|
fn load_function_with_path(
  file : PdfFile,
  object_id : @objects.ObjectId,
  limits : @functions.FunctionLimits,
  path : Array[@objects.ObjectId],
) -> @functions.PdfFunction raise PdfDocumentError {
  if object_id_path_contains(path, object_id) {
    raise PdfDocumentError::CycleDetected(
      object_id, "function reference cycle detected",
    )
  }

  let object = try file.load_object(object_id) catch {
    error => raise PdfDocumentError::ReaderError(error)
  } noraise {
    value => value
  }
  let parsed = try @functions.parse_direct_function(object, limits, 0L) catch {
    error => raise PdfDocumentError::FunctionError(object_id, error)
  } noraise {
    value => value
  }
  let next_path = copy_function_object_path(path)
  next_path.push(object_id)
  materialize_nested_functions(file, parsed, limits, next_path)
}

///|
fn materialize_nested_functions(
  file : PdfFile,
  function : @functions.PdfFunction,
  limits : @functions.FunctionLimits,
  path : Array[@objects.ObjectId],
) -> @functions.PdfFunction raise PdfDocumentError {
  match function {
    @functions.PdfFunction::StitchingFunction(stitching) => {
      let sources : Array[@functions.FunctionSource] = []
      for source in stitching.functions {
        sources.push(materialize_function_source(file, source, limits, path))
      }
      @functions.PdfFunction::StitchingFunction(@functions.StitchingFunction::{
        common: stitching.common,
        functions: sources,
        bounds: stitching.bounds,
        encode: stitching.encode,
      })
    }
    _ => function
  }
}

///|
fn materialize_function_source(
  file : PdfFile,
  source : @functions.FunctionSource,
  limits : @functions.FunctionLimits,
  path : Array[@objects.ObjectId],
) -> @functions.FunctionSource raise PdfDocumentError {
  match source {
    @functions.FunctionSource::DirectFunction(function) =>
      @functions.FunctionSource::DirectFunction(
        materialize_nested_functions(file, function, limits, path),
      )
    @functions.FunctionSource::IndirectFunction(object_id) =>
      @functions.FunctionSource::DirectFunction(
        load_function_with_path(file, object_id, limits, path),
      )
  }
}

///|
fn copy_function_object_path(
  source : Array[@objects.ObjectId],
) -> Array[@objects.ObjectId] {
  let copy : Array[@objects.ObjectId] = []
  for object_id in source {
    copy.push(object_id)
  }
  copy
}

///|
fn object_id_path_contains(
  path : Array[@objects.ObjectId],
  object_id : @objects.ObjectId,
) -> Bool {
  for current in path {
    if current == object_id {
      return true
    }
  }
  false
}
