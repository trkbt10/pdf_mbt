///|
pub fn PdfContext::set_title(self : PdfContext, title : Bytes) -> Unit {
  self.set_info_string(pdf_key(b"Title"), title)
}

///|
pub fn PdfContext::set_author(self : PdfContext, author : Bytes) -> Unit {
  self.set_info_string(pdf_key(b"Author"), author)
}

///|
fn PdfContext::set_info_string(
  self : PdfContext,
  key : @objects.PdfName,
  value : Bytes,
) -> Unit {
  let info_ref = self.ensure_info_ref()
  let dict = match self.objects.get(info_ref.object_number) {
    Some(@objects.PdfObject::Dictionary(existing)) => existing
    _ => {
      let created : @objects.PdfDictionary = Map::new()
      self.objects[info_ref.object_number] = @objects.PdfObject::Dictionary(
        created,
      )
      created
    }
  }
  dict[key] = @objects.PdfObject::String(value)
  self.mark_dirty(info_ref)
}

///|
fn PdfContext::ensure_info_ref(self : PdfContext) -> @objects.ObjectId {
  match self.info_ref {
    Some(id) => id
    None => {
      let id = self.allocate_object(@objects.PdfObject::Dictionary(Map::new()))
      self.info_ref = Some(id)
      id
    }
  }
}
