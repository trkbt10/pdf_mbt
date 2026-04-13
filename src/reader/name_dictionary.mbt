///|
pub fn PdfDocument::names_dict(
  self : PdfDocument,
) -> @objects.PdfDictionary? raise PdfDocumentError {
  match self.catalog.names_entry() {
    Some(value) => Some(resolve_names_dictionary_value(self.file, value))
    None => None
  }
}

///|
pub fn PdfDocument::name_tree_root(
  self : PdfDocument,
  category : NameTreeCategory,
) -> @objects.PdfObject? raise PdfDocumentError {
  match self.names_dict() {
    Some(dict) => dict.get(name_tree_category_key(category))
    None => None
  }
}

///|
fn resolve_names_dictionary_value(
  file : PdfFile,
  value : @objects.PdfObject,
) -> @objects.PdfDictionary raise PdfDocumentError {
  match value {
    @objects.PdfObject::Dictionary(dict) => dict
    @objects.PdfObject::Ref(object_id) => {
      let loaded = try file.load_object(object_id) catch {
        error => raise PdfDocumentError::ReaderError(error)
      } noraise {
        value => value
      }
      match loaded {
        @objects.PdfObject::Dictionary(dict) => dict
        @objects.PdfObject::Null =>
          raise PdfDocumentError::InvalidNameTree(
            @objects.PdfName::new(b"Names"),
            "catalog /Names entry must be a dictionary",
          )
        _ =>
          raise PdfDocumentError::InvalidNameTree(
            @objects.PdfName::new(b"Names"),
            "catalog /Names entry must be a dictionary",
          )
      }
    }
    @objects.PdfObject::Null =>
      raise PdfDocumentError::InvalidNameTree(
        @objects.PdfName::new(b"Names"),
        "catalog /Names entry must be a dictionary",
      )
    _ =>
      raise PdfDocumentError::InvalidNameTree(
        @objects.PdfName::new(b"Names"),
        "catalog /Names entry must be a dictionary",
      )
  }
}

///|
fn name_tree_category_key(category : NameTreeCategory) -> @objects.PdfName {
  match category {
    NameTreeCategory::Dests => @objects.PdfName::new(b"Dests")
    NameTreeCategory::AP => @objects.PdfName::new(b"AP")
    NameTreeCategory::JavaScript => @objects.PdfName::new(b"JavaScript")
    NameTreeCategory::Pages => @objects.PdfName::new(b"Pages")
    NameTreeCategory::Templates => @objects.PdfName::new(b"Templates")
    NameTreeCategory::EmbeddedFiles => @objects.PdfName::new(b"EmbeddedFiles")
    NameTreeCategory::AlternatePresentations =>
      @objects.PdfName::new(b"AlternatePresentations")
  }
}
