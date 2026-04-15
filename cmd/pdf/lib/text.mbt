///|
/// Defines the `pdf text [options] <input.pdf> [output.txt]` subcommand,
/// including global page range options `-f` / `--first-page`, `-l` /
/// `--last-page`, `--password`, and the reserved `--layout` flag.
pub fn text_command() -> @argparse.Command {
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
/// Implements the pdftotext-equivalent text subcommand. It extracts Unicode
/// text with `PdfPage::extracted_text`, applies 1-based clamped page ranges,
/// separates pages with form-feed characters (`\f`), and writes to stdout or
/// an optional output text file.
pub fn run_text(matches : @argparse.Matches) -> Unit raise {
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
  range : (Int, Int),
) -> String raise {
  let out = StringBuilder::new()
  let (first, last) = range
  if first <= last {
    for page_index in (first - 1)..<last {
      if page_index > first - 1 {
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
