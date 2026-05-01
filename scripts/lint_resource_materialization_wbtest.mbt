///|
test "resource materialization lint passes current tree" {
  let findings = try! lint_resource_materialization_repository()
  if findings.length() != 0 {
    fail(resource_materialization_lint_join(findings))
  }
}

///|
test "resource materialization lint flags direct document loads outside helper" {
  let findings : Array[String] = []
  lint_resource_materialization_source(
    "src/reader/text.mbt",
    "fn materialize_bad(file : PdfFile, id : Id) -> Unit {\n" +
    "  let value = load_document_object(file, id)\n" +
    "  ignore(value)\n" +
    "}\n",
    findings,
  )
  assert_true(findings.length() > 0)
  assert_true(findings[0].contains("direct load_document_object"))
}

///|
test "resource materialization lint flags array matches before unwrap" {
  let findings : Array[String] = []
  lint_resource_materialization_source(
    "src/reader/text.mbt",
    "fn materialize_bad(value : @objects.PdfObject?) -> Unit {\n" +
    "  match value {\n" +
    "    Some(@objects.PdfObject::Array(values)) => ignore(values)\n" +
    "    _ => ()\n" +
    "  }\n" +
    "}\n",
    findings,
  )
  assert_true(findings.length() > 0)
  assert_true(findings[0].contains("before a Ref unwrap"))
}

///|
test "resource materialization lint permits array matches after unwrap" {
  let findings : Array[String] = []
  lint_resource_materialization_source(
    "src/reader/text.mbt",
    "fn materialize_good(file : PdfFile, value : @objects.PdfObject) -> Unit {\n" +
    "  let resolved = resolve_indirect(file, value)\n" +
    "  match Some(resolved) {\n" +
    "    Some(@objects.PdfObject::Array(values)) => ignore(values)\n" +
    "    _ => ()\n" +
    "  }\n" +
    "}\n",
    findings,
  )
  assert_eq(findings.length(), 0)
}

///|
fn resource_materialization_lint_join(findings : Array[String]) -> String {
  let builder = StringBuilder::new()
  for index in 0..<findings.length() {
    if index > 0 {
      builder.write_string("\n")
    }
    builder.write_string(findings[index])
  }
  builder.to_string()
}
