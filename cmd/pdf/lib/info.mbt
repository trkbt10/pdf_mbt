///|
/// Defines the `pdf info [options] <input.pdf>` subcommand with `--pages` for
/// page geometry and `--json` for machine-readable pdfinfo-style output.
pub fn info_command() -> @argparse.Command {
  @argparse.Command(
    "info",
    about="Print PDF metadata and structure information.",
    flags=[
      @argparse.FlagArg(
        "pages",
        long="pages",
        about="Include per-page MediaBox and rotation.",
      ),
      @argparse.FlagArg("json", long="json", about="Write JSON output."),
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
/// Implements the pdfinfo-equivalent info subcommand. It prints Title, Author,
/// Subject, Creator, PDF version, page count, encrypted status, file size, and
/// optional per-page MediaBox dimensions and rotation.
pub fn run_info(matches : @argparse.Matches) -> Unit raise {
  let input = required_value(matches, "input")
  let (file, document, bytes) = open_file_and_document(input)
  if flag_is_set(matches, "json") {
    println(
      info_json(file, document, bytes.length(), flag_is_set(matches, "pages")),
    )
  } else {
    print_info_text(
      file,
      document,
      bytes.length(),
      flag_is_set(matches, "pages"),
    )
  }
}

///|
fn print_info_text(
  file : @reader.PdfFile,
  document : @reader.PdfDocument,
  file_size : Int,
  include_pages : Bool,
) -> Unit raise {
  let info = document.document_info()
  let version = file.version()
  let trailer = file.trailer()
  println("Title:          " + document_info_title(info))
  println("Author:         " + document_info_author(info))
  println("Subject:        " + document_info_subject(info))
  println("Creator:        " + document_info_creator(info))
  println(
    "PDF version:    " +
    version.major.to_string() +
    "." +
    version.minor.to_string(),
  )
  println("Pages:          " + document.page_count().to_string())
  println(
    "Encrypted:      " + (if trailer.encrypt is Some(_) { "yes" } else { "no" }),
  )
  println("File size:      " + file_size.to_string() + " bytes")
  if include_pages {
    print_info_pages(document)
  }
}

///|
fn print_info_pages(document : @reader.PdfDocument) -> Unit raise {
  let count = document.page_count()
  for page_index in 0..<count {
    let page = document.page(page_index)
    println(
      "Page " +
      (page_index + 1).to_string() +
      ": " +
      page_media_width(page) +
      " x " +
      page_media_height(page) +
      ", rotate " +
      page_rotation(page).to_string(),
    )
  }
}

///|
fn info_json(
  file : @reader.PdfFile,
  document : @reader.PdfDocument,
  file_size : Int,
  include_pages : Bool,
) -> String raise {
  let info = document.document_info()
  let version = file.version()
  let trailer = file.trailer()
  let entries : Map[String, Json] = {
    "title": Json::string(document_info_title(info)),
    "author": Json::string(document_info_author(info)),
    "subject": Json::string(document_info_subject(info)),
    "creator": Json::string(document_info_creator(info)),
    "pdf_version": Json::string(
      version.major.to_string() + "." + version.minor.to_string(),
    ),
    "page_count": json_number(document.page_count().to_string()),
    "encrypted": json_bool(trailer.encrypt is Some(_)),
    "file_size": json_number(file_size.to_string()),
  }
  if include_pages {
    let pages : Array[Json] = []
    let count = document.page_count()
    for page_index in 0..<count {
      let page = document.page(page_index)
      pages.push(
        Json::object({
          "number": json_number((page_index + 1).to_string()),
          "width": json_number(page_media_width(page)),
          "height": json_number(page_media_height(page)),
          "rotation": json_number(page_rotation(page).to_string()),
        }),
      )
    }
    entries["pages"] = Json::array(pages)
  }
  Json::object(entries).stringify()
}

///|
fn json_number(repr : String) -> Json {
  Json::number(0.0, repr~)
}

///|
fn json_bool(value : Bool) -> Json {
  Json::boolean(value)
}

///|
fn document_info_title(info : @interchange.PdfDocumentInfo?) -> String {
  match info {
    Some(value) => bytes_text(value.title)
    None => ""
  }
}

///|
fn document_info_author(info : @interchange.PdfDocumentInfo?) -> String {
  match info {
    Some(value) => bytes_text(value.author)
    None => ""
  }
}

///|
fn document_info_subject(info : @interchange.PdfDocumentInfo?) -> String {
  match info {
    Some(value) => bytes_text(value.subject)
    None => ""
  }
}

///|
fn document_info_creator(info : @interchange.PdfDocumentInfo?) -> String {
  match info {
    Some(value) => bytes_text(value.creator)
    None => ""
  }
}
