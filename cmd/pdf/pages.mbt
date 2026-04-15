///|
fn pages_command() -> @argparse.Command {
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
fn run_pages(matches : @argparse.Matches) -> Unit raise {
  let input = required_value(matches, "input")
  let document = open_document(input)
  let count = document.page_count()
  if flag_is_set(matches, "count") {
    println(count)
    return
  }
  let range = page_range(matches, count)
  if range.first <= range.last {
    for page_index in (range.first - 1)..<range.last {
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
