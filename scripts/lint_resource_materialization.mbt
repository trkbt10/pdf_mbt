///|
let resource_materialization_lint_paths = [
  "src/reader/indirect_resolution.mbt", "src/reader/text.mbt", "src/reader/xobjects.mbt",
  "src/reader/patterns.mbt", "src/reader/annotations.mbt", "src/reader/optional_content.mbt",
  "src/reader/structure_common.mbt", "src/reader/structure_tree.mbt", "src/reader/interchange_metadata.mbt",
  "src/reader/interchange_piece_info.mbt",
]

///|
fn lint_resource_materialization_repository() -> Array[String] raise {
  let findings : Array[String] = []
  for path in resource_materialization_lint_paths {
    lint_resource_materialization_source(
      path,
      @fs.read_file_to_bytes(path).to_string(),
      findings,
    )
  }
  findings
}

///|
fn lint_resource_materialization_source(
  path : String,
  source : String,
  findings : Array[String],
) -> Unit {
  let lines : Array[String] = []
  for line in source.split("\n") {
    lines.push(line.to_owned())
  }
  lint_direct_document_loads(path, lines, findings)
  lint_array_match_without_ref_unwrap(path, lines, findings)
}

///|
fn lint_direct_document_loads(
  path : String,
  lines : Array[String],
  findings : Array[String],
) -> Unit {
  let mut allowed_count = 0
  for index in 0..<lines.length() {
    if lines[index].contains("load_document_object(") {
      if path == "src/reader/indirect_resolution.mbt" {
        allowed_count += 1
      } else {
        findings.push(
          path +
          ":" +
          (index + 1).to_string() +
          ": direct load_document_object outside resolve_indirect helper",
        )
      }
    }
  }
  if path == "src/reader/indirect_resolution.mbt" && allowed_count > 2 {
    findings.push(
      path +
      ": load_document_object should appear only in helper definition and call",
    )
  }
}

///|
fn lint_array_match_without_ref_unwrap(
  path : String,
  lines : Array[String],
  findings : Array[String],
) -> Unit {
  let mut function_name = ""
  let mut saw_unwrap = false
  for index in 0..<lines.length() {
    let trimmed = lines[index].trim()
    match lint_function_name(trimmed) {
      Some(name) => {
        function_name = name
        saw_unwrap = false
      }
      None => ()
    }
    if function_name.length() > 0 {
      if lint_line_is_ref_unwrap(lines[index]) {
        saw_unwrap = true
      }
      if lint_function_is_materializer(function_name) &&
        lint_line_matches_optional_array(lines[index]) &&
        !saw_unwrap {
        findings.push(
          path +
          ":" +
          (index + 1).to_string() +
          ": " +
          function_name +
          " matches an Array before a Ref unwrap",
        )
      }
    }
  }
}

///|
fn lint_function_name(trimmed : StringView) -> String? {
  if trimmed.has_prefix("fn ") {
    lint_name_after_fn_keyword(trimmed, 3)
  } else if trimmed.has_prefix("pub fn ") {
    lint_name_after_fn_keyword(trimmed, 7)
  } else {
    None
  }
}

///|
fn lint_name_after_fn_keyword(trimmed : StringView, start : Int) -> String? {
  let chars = trimmed.to_array()
  let mut end = start
  while end < chars.length() &&
        !chars[end].is_ascii_whitespace() &&
        chars[end].to_int() != b'('.to_int() {
    end += 1
  }
  if end <= start {
    None
  } else {
    Some(trimmed.sub(start~, end~).to_owned())
  }
}

///|
fn lint_function_is_materializer(name : String) -> Bool {
  name.contains("materialize") ||
  name == "page_resource_category_dictionary" ||
  name == "page_load_resource_object"
}

///|
fn lint_line_is_ref_unwrap(line : String) -> Bool {
  line.contains("resolve_indirect(") ||
  line.contains("resolve_optional_page_object(") ||
  line.contains("page_load_resource_object(")
}

///|
fn lint_line_matches_optional_array(line : String) -> Bool {
  line.contains("Some(@objects.PdfObject::Array") ||
  line.contains("Some(Array(") ||
  line.contains("Some(Array")
}
