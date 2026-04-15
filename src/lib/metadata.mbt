///|
/// Returns the document Info dictionary Title entry when present.
pub fn document_title(doc : PdfDocument) -> String? {
  document_info_string(doc, b"Title")
}

///|
/// Returns the document Info dictionary Author entry when present.
pub fn document_author(doc : PdfDocument) -> String? {
  document_info_string(doc, b"Author")
}

///|
/// Implements Requirement 4.1 document metadata:
/// `PdfDocument::subject() -> String?` SHALL return the Info dictionary
/// Subject entry when present.
pub fn document_subject(doc : PdfDocument) -> String? {
  document_info_string(doc, b"Subject")
}

///|
/// Returns the document Info dictionary Creator entry when present.
pub fn document_creator(doc : PdfDocument) -> String? {
  document_info_string(doc, b"Creator")
}

///|
/// Method form of `document_title`, returning the Info dictionary Title.
pub fn PdfDocument::title(self : PdfDocument) -> String? {
  document_title(self)
}

///|
/// Method form of `document_author`, returning the Info dictionary Author.
pub fn PdfDocument::author(self : PdfDocument) -> String? {
  document_author(self)
}

///|
/// Method form of `document_subject`, returning the Info dictionary Subject.
pub fn PdfDocument::subject(self : PdfDocument) -> String? {
  document_subject(self)
}

///|
/// Method form of `document_creator`, returning the Info dictionary Creator.
pub fn PdfDocument::creator(self : PdfDocument) -> String? {
  document_creator(self)
}

///|
/// Implements Requirement 4.3 page geometry:
/// `PdfPage::width() -> Double` SHALL return the effective page width after
/// rotation, using the MediaBox dimensions.
pub fn page_width(page : PdfPage) -> Double {
  let (width, height) = page_dimensions(page)
  if page_is_rotated_sideways(page) {
    height
  } else {
    width
  }
}

///|
/// Implements Requirement 4.3 page geometry:
/// `PdfPage::height() -> Double` SHALL return the effective page height after
/// rotation, using the MediaBox dimensions.
pub fn page_height(page : PdfPage) -> Double {
  let (width, height) = page_dimensions(page)
  if page_is_rotated_sideways(page) {
    width
  } else {
    height
  }
}

///|
/// Method form of `page_width`, returning effective page width.
pub fn PdfPage::width(self : PdfPage) -> Double {
  page_width(self)
}

///|
/// Method form of `page_height`, returning effective page height.
pub fn PdfPage::height(self : PdfPage) -> Double {
  page_height(self)
}

///|
fn document_info_string(doc : PdfDocument, key : Bytes) -> String? {
  let result : Result[@interchange.PdfDocumentInfo?, @reader.PdfDocumentError] = try? doc.inner.document_info()
  match result {
    Ok(Some(info)) =>
      match key {
        b"Title" => info.title.map(bytes_to_text)
        b"Author" => info.author.map(bytes_to_text)
        b"Subject" => info.subject.map(bytes_to_text)
        b"Creator" => info.creator.map(bytes_to_text)
        _ => None
      }
    _ => None
  }
}

///|
fn page_dimensions(page : PdfPage) -> (Double, Double) {
  let result : Result[@reader.PdfRectangle?, @reader.PdfDocumentError] = try? page.inner.media_box()
  match result {
    Ok(Some(box)) =>
      (abs_double(box.right - box.left), abs_double(box.top - box.bottom))
    _ => (0.0, 0.0)
  }
}

///|
fn page_is_rotated_sideways(page : PdfPage) -> Bool {
  let result : Result[Int?, @reader.PdfDocumentError] = try? page.inner.rotate()
  match result {
    Ok(Some(value)) => {
      let normalized = positive_mod(value, 360)
      normalized == 90 || normalized == 270
    }
    _ => false
  }
}

///|
fn positive_mod(value : Int, base : Int) -> Int {
  let result = value % base
  if result < 0 {
    result + base
  } else {
    result
  }
}

///|
fn abs_double(value : Double) -> Double {
  if value < 0.0 {
    0.0 - value
  } else {
    value
  }
}

///|
fn bytes_to_text(bytes : Bytes) -> String {
  let chars : Array[Char] = []
  for byte in bytes {
    chars.push(byte.to_char())
  }
  String::from_array(chars)
}
