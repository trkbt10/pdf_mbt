///|
fn text_command() -> @argparse.Command {
  @argparse.Command(
    "text",
    about="Extract text from PDF pages.",
    flags=[
      @argparse.FlagArg(
        "layout",
        long="layout",
        about="Reserved for future layout-preserving extraction.",
      ),
    ],
    options=[
      common_first_page_option(),
      common_last_page_option(),
      common_password_option(),
    ],
    positionals=[
      input_pdf_arg(),
      @argparse.PositionArg("output", about="Output text file."),
    ],
  )
}

///|
fn run_text(matches : @argparse.Matches) -> Unit raise {
  let input = required_value(matches, "input")
  let document = open_document(input)
  let range = page_range(matches, document.page_count())
  let output = extract_document_text(document, range)
  match optional_value(matches, "output") {
    Some(path) => @fs.write_string_to_file(path, output)
    None => println(output)
  }
}

///|
fn extract_document_text(
  document : @reader.PdfDocument,
  range : PageRange,
) -> String raise {
  let out = StringBuilder::new()
  if range.first <= range.last {
    for page_index in (range.first - 1)..<range.last {
      if page_index > range.first - 1 {
        out.write_string("\f")
      }
      let page = document.page(page_index)
      let extracted = page.extracted_text(@reader.TextPageOptions::default())
      for span in extracted.spans {
        out.write_string(span.text)
      }
    }
  }
  out.to_string()
}
