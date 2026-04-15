///|
fn info_command() -> @argparse.Command {
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
fn run_info(matches : @argparse.Matches) -> Unit raise {
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
  let out = StringBuilder::new()
  out.write_string("{")
  out.write_string("\"title\":" + json_string(document_info_title(info)) + ",")
  out.write_string(
    "\"author\":" + json_string(document_info_author(info)) + ",",
  )
  out.write_string(
    "\"subject\":" + json_string(document_info_subject(info)) + ",",
  )
  out.write_string(
    "\"creator\":" + json_string(document_info_creator(info)) + ",",
  )
  out.write_string(
    "\"pdf_version\":" +
    json_string(version.major.to_string() + "." + version.minor.to_string()) +
    ",",
  )
  out.write_string("\"page_count\":" + document.page_count().to_string() + ",")
  out.write_string(
    "\"encrypted\":" +
    (if trailer.encrypt is Some(_) { "true" } else { "false" }) +
    ",",
  )
  out.write_string("\"file_size\":" + file_size.to_string())
  if include_pages {
    out.write_string(",\"pages\":[")
    let count = document.page_count()
    for page_index in 0..<count {
      if page_index > 0 {
        out.write_string(",")
      }
      let page = document.page(page_index)
      out.write_string("{")
      out.write_string("\"number\":" + (page_index + 1).to_string() + ",")
      out.write_string("\"width\":" + page_media_width(page) + ",")
      out.write_string("\"height\":" + page_media_height(page) + ",")
      out.write_string("\"rotation\":" + page_rotation(page).to_string())
      out.write_string("}")
    }
    out.write_string("]")
  }
  out.write_string("}")
  out.to_string()
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
