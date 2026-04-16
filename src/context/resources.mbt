///|
pub fn PdfContext::add_font(
  self : PdfContext,
  page_ref : @objects.ObjectId,
  name : @objects.PdfName,
  font_object : @objects.PdfObject,
) -> @objects.ObjectId raise PdfContextError {
  let font_ref = self.resource_object_ref(font_object)
  self.register_page_resource(page_ref, pdf_key(b"Font"), name, font_ref)
  font_ref
}

///|
pub fn PdfContext::add_image(
  self : PdfContext,
  page_ref : @objects.ObjectId,
  name : @objects.PdfName,
  image_stream : @objects.PdfStream,
) -> @objects.ObjectId raise PdfContextError {
  let image_ref = self.allocate_object(@objects.PdfObject::Stream(image_stream))
  self.register_page_resource(page_ref, pdf_key(b"XObject"), name, image_ref)
  image_ref
}

///|
fn PdfContext::resource_object_ref(
  self : PdfContext,
  object : @objects.PdfObject,
) -> @objects.ObjectId {
  match object {
    @objects.PdfObject::Ref(id) => id
    _ => self.allocate_object(object)
  }
}

///|
fn PdfContext::register_page_resource(
  self : PdfContext,
  page_ref : @objects.ObjectId,
  category : @objects.PdfName,
  name : @objects.PdfName,
  resource_ref : @objects.ObjectId,
) -> Unit raise PdfContextError {
  let page = self.require_dictionary(page_ref, "page object")
  require_page_type(page_ref, page)
  let (resources, resources_ref) = self.materialize_page_resources(page)
  let category_dict = materialize_resource_category(resources, category)
  category_dict[name] = @objects.PdfObject::Ref(resource_ref)
  match resources_ref {
    Some(id) => self.mark_dirty(id)
    None => self.mark_dirty(page_ref)
  }
}

///|
fn PdfContext::materialize_page_resources(
  self : PdfContext,
  page : @objects.PdfDictionary,
) -> (@objects.PdfDictionary, @objects.ObjectId?) raise PdfContextError {
  let resources_key = pdf_key(b"Resources")
  match page.get(resources_key) {
    Some(@objects.PdfObject::Dictionary(dict)) => (dict, None)
    Some(@objects.PdfObject::Ref(resources_ref)) => {
      let dict = self.require_dictionary(resources_ref, "page resources")
      (dict, Some(resources_ref))
    }
    _ => {
      let created : @objects.PdfDictionary = Map::new()
      page[resources_key] = @objects.PdfObject::Dictionary(created)
      (created, None)
    }
  }
}

///|
fn materialize_resource_category(
  resources : @objects.PdfDictionary,
  category : @objects.PdfName,
) -> @objects.PdfDictionary {
  match resources.get(category) {
    Some(@objects.PdfObject::Dictionary(dict)) => dict
    _ => {
      let created : @objects.PdfDictionary = Map::new()
      resources[category] = @objects.PdfObject::Dictionary(created)
      created
    }
  }
}
