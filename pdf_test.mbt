///|
test "root package opens PDF through high-level API" {
  let document = @pdf.open(
    @fs.read_file_to_bytes("spec/pdf20examples/Simple PDF 2.0 file.pdf"),
  )
  assert_eq(document.page_count(), 1)
  assert_eq(@pdf.extract_all_text(document), "HelloWorld")
}
