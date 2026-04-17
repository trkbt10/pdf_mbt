///|
let local-fixture_perf_path : String = "<local-fixture>"

///|
let local-fixture_text_bound_ms : UInt64 = 3000UL

///|
test "local-fixture text_program pages stay under performance bound" {
  match open_local-fixture_for_text_perf() {
    Some(document) => {
      for page_index in [4, 5, 7, 8] {
        assert_local-fixture_text_program_bound(document, page_index)
      }
    }
    None => ()
  }
}

///|
fn open_local-fixture_for_text_perf() -> PdfDocument? raise {
  if !@fs.path_exists(local-fixture_perf_path) {
    println(
      "local-fixture text perf skipped: " +
      local-fixture_perf_path +
      " is not present",
    )
    return None
  }
  Some(PdfDocument::open(@fs.read_file_to_bytes(local-fixture_perf_path)))
}

///|
fn assert_local-fixture_text_program_bound(
  document : PdfDocument,
  page_index : Int,
) -> Unit raise {
  let page = document.page(page_index)
  let started = @env.now()
  page.text_program(TextPageOptions::default()) |> ignore
  let elapsed = @env.now() - started
  println(
    "local-fixture page " +
    (page_index + 1).to_string() +
    " text_program: " +
    elapsed.to_string() +
    " ms",
  )
  assert_true(elapsed < local-fixture_text_bound_ms)
}
