///|
/// Defines the `pdf pages [options] <input.pdf>` subcommand with page range
/// support and `--count` mode for printing only the total page count.
pub fn pages_command() -> @argparse.Command {
  @argparse.Command(
    "pages",
    about="List page geometry.",
    flags=[
      @argparse.FlagArg(
        "count",
        long="count",
        about="Print only the page count.",
      ),
    ],
    options=[
      common_first_page_option(),
      common_last_page_option(),
      common_password_option(),
    ],
    positionals=[input_pdf_arg()],
  )
}

///|
/// Implements page listing by printing one line per selected page with page
/// number, MediaBox width, MediaBox height, and rotation; `--count` prints a
/// single integer page count.
pub fn run_pages(matches : @argparse.Matches) -> Unit raise {
  let input = required_value(matches, "input")
  let document = open_document(input)
  let count = document.page_count()
  if flag_is_set(matches, "count") {
    println(count)
    return
  }
  let range = page_range(matches, count)
  let (first, last) = range
  if first <= last {
    for page_index in (first - 1)..<last {
      let page = document.page(page_index)
      println(
        (page_index + 1).to_string() +
        " " +
        page_media_width(page) +
        " " +
        page_media_height(page) +
        " " +
        page_rotation(page).to_string(),
      )
    }
  }
}
