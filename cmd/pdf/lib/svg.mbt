///|
/// Defines the `pdf svg [options] <input.pdf> <output-prefix>` subcommand.
/// It writes one SVG file per selected page using `<prefix>-<page>.svg`.
pub fn svg_command() -> @argparse.Command {
  @argparse.Command(
    "svg",
    about="Render PDF pages as SVG files.",
    options=[
      common_first_page_option(),
      common_last_page_option(),
      common_password_option(),
    ],
    positionals=[
      input_pdf_arg(),
      @argparse.PositionArg(
        "prefix",
        about="Output file prefix.",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
  )
}

///|
/// Implements `pdf svg` by rendering each selected page to shared SVG markup
/// and writing `<prefix>-<page>.svg`.
pub fn run_svg(matches : @argparse.Matches) -> Unit raise {
  let input = required_value(matches, "input")
  let prefix = required_value(matches, "prefix")
  ensure_prefix_parent_directory(prefix)
  let document = open_document(input)
  let range = page_range(matches, document.page_count())
  let (first, last) = range
  if first <= last {
    for page_index in (first - 1)..<last {
      let page_number = page_index + 1
      let path = prefix + "-" + page_number.to_string() + ".svg"
      @fs.write_string_to_file(
        path,
        @svg.render_page_svg(document.page(page_index)),
      )
    }
  }
}

///|
fn ensure_prefix_parent_directory(prefix : String) -> Unit {
  match parent_directory(prefix) {
    Some(path) => {
      let exists = try @fs.is_dir(path) catch {
        _ => false
      } noraise {
        value => value
      }
      if !exists {
        @fs.create_dir(path) catch {
          _ => ()
        }
      }
    }
    None => ()
  }
}

///|
fn parent_directory(path : String) -> String? {
  match path.to_string_view().rev_split_once("/".to_string_view()) {
    Some((parent, _)) if !parent.is_empty() => Some(parent.to_string())
    _ => None
  }
}
