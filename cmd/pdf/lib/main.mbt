///|
let cli_version : String = "0.1.0"

///|
/// CLI error used by the public dispatcher for subcommand validation, input
/// file access, unsupported feature diagnostics, and capability reporting.
pub(all) suberror CliError {
  Message(String)
}

///|
#borrow(message)
extern "c" fn stderr_write_ffi(message : Bytes) -> Unit = "trkbt10_pdf_cli_stderr_write"

///|
fn print_stderr(message : String) -> Unit {
  stderr_write_ffi(@utf8.encode(message))
}

///|
/// Runs the `pdf` command-line interface. It parses the subcommand-based
/// architecture `pdf <subcommand> [options] <input.pdf> [output]`, handles
/// global `--help` and `--version` support from argparse, dispatches to text,
/// info, images, pages, or check, and writes diagnostic errors to stderr.
pub fn run_cli() -> Unit {
  try {
    let matches = pdf_command().parse()
    dispatch(matches)
  } catch {
    CliError::Message(message) => {
      print_stderr("pdf: " + message)
      @sys.exit(1)
    }
    err => {
      print_stderr("pdf: " + err.to_string())
      @sys.exit(1)
    }
  }
}

///|
/// Builds the root `pdf` argparse command with global `-v` / `--version` and
/// subcommands `text`, `info`, `images`, `pages`, `svg`, and `check`.
pub fn pdf_command() -> @argparse.Command {
  @argparse.Command(
    "pdf",
    about="Inspect and extract content from PDF files.",
    version=cli_version,
    disable_version_flag=true,
    flags=[
      @argparse.FlagArg(
        "version",
        short='v',
        long="version",
        about="Show version information.",
        action=Version,
        global=true,
      ),
    ],
    subcommand_required=true,
    subcommands=[
      text_command(),
      info_command(),
      images_command(),
      pages_command(),
      svg_command(),
      check_command(),
    ],
  )
}

///|
/// Dispatches parsed subcommands to the public CLI implementations.
pub fn dispatch(matches : @argparse.Matches) -> Unit raise {
  match matches.subcommand {
    Some(("text", subcommand)) => run_text(subcommand)
    Some(("info", subcommand)) => run_info(subcommand)
    Some(("images", subcommand)) => run_images(subcommand)
    Some(("pages", subcommand)) => run_pages(subcommand)
    Some(("svg", subcommand)) => run_svg(subcommand)
    Some(("check", subcommand)) => run_check(subcommand)
    Some((name, _)) => raise CliError::Message("unknown subcommand " + name)
    None => raise CliError::Message("missing subcommand")
  }
}

///|
fn common_first_page_option() -> @argparse.OptionArg {
  @argparse.OptionArg(
    "first-page",
    short='f',
    long="first-page",
    about="First page to process, 1-based.",
    default_values=["1"],
  )
}

///|
fn common_last_page_option() -> @argparse.OptionArg {
  @argparse.OptionArg(
    "last-page",
    short='l',
    long="last-page",
    about="Last page to process, 1-based.",
  )
}

///|
fn common_password_option() -> @argparse.OptionArg {
  @argparse.OptionArg(
    "password",
    long="password",
    about="Document password for encrypted PDFs.",
  )
}

///|
fn input_pdf_arg() -> @argparse.PositionArg {
  @argparse.PositionArg(
    "input",
    about="Input PDF file.",
    num_args=@argparse.ValueRange::single(),
  )
}

///|
fn required_value(
  matches : @argparse.Matches,
  name : String,
) -> String raise CliError {
  match matches.values.get(name) {
    Some(values) if values.length() > 0 => values[0]
    _ => raise CliError::Message("missing required argument " + name)
  }
}

///|
fn optional_value(matches : @argparse.Matches, name : String) -> String? {
  match matches.values.get(name) {
    Some(values) if values.length() > 0 => Some(values[0])
    _ => None
  }
}

///|
fn flag_is_set(matches : @argparse.Matches, name : String) -> Bool {
  match matches.flags.get(name) {
    Some(value) => value
    None => false
  }
}

///|
fn parse_positive_int(value : String, label : String) -> Int raise CliError {
  let parsed = try @string.parse_int(value.to_string_view()) catch {
    _ => raise CliError::Message(label + " must be an integer")
  } noraise {
    number => number
  }
  if parsed < 1 {
    raise CliError::Message(label + " must be at least 1")
  }
  parsed
}

///|
fn page_range(
  matches : @argparse.Matches,
  page_count : Int,
) -> (Int, Int) raise {
  if page_count <= 0 {
    return (1, 0)
  }
  let first_raw = required_value(matches, "first-page")
  let first = parse_positive_int(first_raw, "--first-page").clamp(
    min=1,
    max=page_count,
  )
  let last = match optional_value(matches, "last-page") {
    Some(raw) =>
      parse_positive_int(raw, "--last-page").clamp(min=1, max=page_count)
    None => page_count
  }
  (first, last)
}

///|
fn open_document(path : String) -> @reader.PdfDocument raise {
  let bytes = @fs.read_file_to_bytes(path)
  @reader.PdfDocument::open(bytes)
}

///|
fn open_file_and_document(
  path : String,
) -> (@reader.PdfFile, @reader.PdfDocument, Bytes) raise {
  let bytes = @fs.read_file_to_bytes(path)
  let file = @reader.PdfFile::open(bytes)
  let document = file.document()
  (file, document, bytes)
}

///|
fn rectangle_width(rect : @reader.PdfRectangle) -> Double {
  rect.right - rect.left
}

///|
fn rectangle_height(rect : @reader.PdfRectangle) -> Double {
  rect.top - rect.bottom
}

///|
fn number_text(value : Double) -> String {
  let rounded = value.round()
  if value == rounded {
    rounded.to_int().to_string()
  } else {
    value.to_string()
  }
}

///|
fn page_media_width(page : @reader.PdfPage) -> String raise {
  match page.media_box() {
    Some(rect) => number_text(rectangle_width(rect))
    None => "0"
  }
}

///|
fn page_media_height(page : @reader.PdfPage) -> String raise {
  match page.media_box() {
    Some(rect) => number_text(rectangle_height(rect))
    None => "0"
  }
}

///|
fn page_rotation(page : @reader.PdfPage) -> Int raise {
  match page.rotate() {
    Some(value) => value
    None => 0
  }
}

///|
fn bytes_text(bytes : Bytes?) -> String {
  match bytes {
    Some(value) =>
      @common_data.parse_text_string(value).text catch {
        _ => @utf8.decode_lossy(value)
      }
    None => ""
  }
}
