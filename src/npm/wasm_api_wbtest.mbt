///|
let diagnostic_local-fixture_path : String = "<local-fixture>"

///|
fn open_local-fixture_handle_for_test() -> Int? {
  if !@fs.path_exists(diagnostic_local-fixture_path) {
    println("diagnostic skipped: " + diagnostic_local-fixture_path + " is not present")
    return None
  }
  let bytes_result : Result[Bytes, @fs.IOError] = try? @fs.read_file_to_bytes(
    diagnostic_local-fixture_path,
  )
  let bytes = match bytes_result {
    Ok(bytes) => bytes
    Err(_) => {
      println("diagnostic skipped: failed to read " + diagnostic_local-fixture_path)
      return None
    }
  }
  let result : Result[@pdfapi.PdfDocument, @reader.PdfDocumentError] = try? @pdfapi.open(
    bytes,
  )
  match result {
    Ok(document) => {
      let handle = next_document_handle()
      documents[handle] = document
      Some(handle)
    }
    Err(_) => {
      println("diagnostic skipped: failed to open " + diagnostic_local-fixture_path)
      None
    }
  }
}

///|
fn prepare_local-fixture_page_7_for_test(handle : Int) -> Int {
  pdf_page_to_svg_deferred(handle, 6) |> ignore
  pdf_page_svg_image_count(handle, 6)
}

///|
fn elapsed_page_7_image_data_ms(handle : Int, count : Int) -> UInt64 {
  let start = @env.now()
  for i in 0..<count {
    pdf_page_svg_image_data(handle, 6, i) |> ignore
  }
  @env.now() - start
}

///|
test "local-fixture page 7 image data stays under performance bound with one graphics walk" {
  match open_local-fixture_handle_for_test() {
    Some(handle) => {
      test_reset_graphics_walk_counter()
      let count = prepare_local-fixture_page_7_for_test(handle)
      assert_true(count > 0)
      let first_ms = elapsed_page_7_image_data_ms(handle, count)
      assert_true(first_ms < 3000UL)
      assert_eq(test_graphics_walk_counter(), 1)
      pdf_close(handle)
    }
    None => ()
  }
}

///|
test "local-fixture page 7 image accessors reuse cache on second pass" {
  match open_local-fixture_handle_for_test() {
    Some(handle) => {
      let count = prepare_local-fixture_page_7_for_test(handle)
      assert_true(count > 0)
      let first_ms = elapsed_page_7_image_data_ms(handle, count)
      let second_ms = elapsed_page_7_image_data_ms(handle, count)
      assert_true(second_ms * 10UL < first_ms || second_ms <= 1UL)
      pdf_close(handle)
    }
    None => ()
  }
}

///|
test "local-fixture page 7 one graphics walk across N accessor calls" {
  match open_local-fixture_handle_for_test() {
    Some(handle) => {
      test_reset_graphics_walk_counter()
      let count = prepare_local-fixture_page_7_for_test(handle)
      assert_true(count > 0)
      for i in 0..<count {
        pdf_page_svg_image_info(handle, 6, i) |> ignore
        pdf_page_svg_image_mime(handle, 6, i) |> ignore
      }
      assert_eq(test_graphics_walk_counter(), 1)
      pdf_close(handle)
    }
    None => ()
  }
}
