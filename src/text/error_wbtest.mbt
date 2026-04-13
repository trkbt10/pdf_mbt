///|
test "text failures preserve offset and resource context" {
  let context = TextErrorContext::with_resource(42L, "Font/F1/ToUnicode")
  let result : Result[Unit, PdfTextError] = try? raise_invalid_cmap(context)
  match result {
    Err(InvalidCMap(found, reason)) => {
      assert_eq(found.offset, 42L)
      assert_eq(found.resource, Some("Font/F1/ToUnicode"))
      assert_eq(reason.contains("codespace"), true)
    }
    _ => fail("expected InvalidCMap")
  }
}

///|
fn raise_invalid_cmap(context : TextErrorContext) -> Unit raise PdfTextError {
  raise PdfTextError::InvalidCMap(context, "bad codespace")
}
