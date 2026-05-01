///|
let max_indirect_resolution_depth = 32

///|
/// Shared indirect-object resolution for reader materialization passes.
///
/// This file owns the only `Ref -> PdfFile::load_object` bridge used by
/// resource materializers. Keeping it in `src/reader/` rather than beside a
/// specific materializer makes the contract visible to text, graphics,
/// annotations, structure, and optional-content readers: callers must resolve
/// indirect objects before variant matching, and cycles are reported instead
/// of being silently treated as non-matching values.
fn resolve_indirect(
  file : PdfFile,
  object : @objects.PdfObject,
) -> @objects.PdfObject raise PdfDocumentError {
  resolve_indirect_with_seen(file, object, Map::new(), depth=0)
}

///|
fn resolve_indirect_with_seen(
  file : PdfFile,
  object : @objects.PdfObject,
  seen : Map[@objects.ObjectId, Bool],
  depth~ : Int,
) -> @objects.PdfObject raise PdfDocumentError {
  match object {
    @objects.PdfObject::Ref(id) => {
      if depth >= max_indirect_resolution_depth {
        raise PdfDocumentError::CycleDetected(
          id, "indirect-object reference depth limit exceeded",
        )
      }
      if seen.contains(id) {
        raise PdfDocumentError::CycleDetected(
          id, "indirect-object reference cycle detected",
        )
      }
      seen[id] = true
      let loaded = load_document_object(file, id)
      if loaded == @objects.PdfObject::Null {
        raise PdfDocumentError::InvalidPage(id, "indirect reference is missing")
      }
      resolve_indirect_with_seen(file, loaded, seen, depth=depth + 1)
    }
    _ => object
  }
}

///|
fn load_document_object(
  file : PdfFile,
  id : @objects.ObjectId,
) -> @objects.PdfObject raise PdfDocumentError {
  try file.load_object(id) catch {
    error => raise PdfDocumentError::ReaderError(error)
  } noraise {
    object => object
  }
}

///|
/// Spec-alignment marker for the resource materialization lint and CI gate.
/// The executable gate is `scripts/lint_resource_materialization.mbt`, and it
/// rejects direct `load_document_object` calls outside this helper plus
/// materializer Array matches that occur before `resolve_indirect`.
fn resource_materialization_lint_ci_gate() -> Unit {
  ()
}

///|
fn contains_object_id(
  values : Array[@objects.ObjectId],
  id : @objects.ObjectId,
) -> Bool {
  for value in values {
    if value == id {
      return true
    }
  }
  false
}
