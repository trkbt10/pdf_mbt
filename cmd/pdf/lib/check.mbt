///|
/// Defines the `pdf check [options] <input.pdf>` diagnostic subcommand. It
/// reports capability support for filters, fonts, images, encryption,
/// interactive features, and structure categories such as bookmarks.
pub fn check_command() -> @argparse.Command {
  @argparse.Command(
    "check",
    about="Report PDF feature support and diagnostics.",
    options=[
      common_first_page_option(),
      common_last_page_option(),
      common_password_option(),
    ],
    positionals=[input_pdf_arg()],
  )
}

///|
/// Implements capability reporting for `pdf check`. It analyzes the input PDF,
/// prints a feature/status table, includes unsupported feature diagnostics, and
/// emits summary statistics to stderr.
pub fn run_check(matches : @argparse.Matches) -> Unit raise {
  let input = required_value(matches, "input")
  let document = @pdfapi.open(@fs.read_file_to_bytes(input))
  let report = document.check()
  println("category feature status description")
  let mut warnings = 0
  for entry in report.entries {
    if entry.status == @pdfapi.PdfCapabilityStatus::Unsupported {
      warnings += 1
    }
    println(
      entry.category +
      " " +
      entry.feature_name +
      " " +
      capability_status_text(entry.status) +
      " " +
      entry.description,
    )
  }
  print_stderr(
    "Pages: " +
    document.page_count().to_string() +
    "  Text: capability report  Images: capability report  Warnings: " +
    warnings.to_string(),
  )
}

///|
fn capability_status_text(status : @pdfapi.PdfCapabilityStatus) -> String {
  match status {
    Supported => "supported"
    Partial => "partial"
    Unsupported => "unsupported"
    Unused => "unused"
  }
}
