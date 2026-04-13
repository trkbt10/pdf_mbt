///|
pub fn PdfPage::pattern_resource(
  self : PdfPage,
  name : @objects.PdfName,
) -> @graphics.PatternResource raise PdfDocumentError {
  let resources = page_direct_resource_dictionary(self)
  let value = page_named_resource_value(
    self,
    resources,
    @content.ResourceCategory::Pattern,
    name,
  )
  let loaded = page_load_resource_object(self, value)
  let defaults = page_colour_defaults(resources)
  try @graphics.parse_pattern_object(name, loaded, defaults, 0L) catch {
    error => raise PdfDocumentError::GraphicsError(error)
  } noraise {
    resource => resource
  }
}

///|
pub fn PdfPage::shading_resource(
  self : PdfPage,
  name : @objects.PdfName,
) -> @graphics.ShadingResource raise PdfDocumentError {
  let resources = page_direct_resource_dictionary(self)
  let value = page_named_resource_value(
    self,
    resources,
    @content.ResourceCategory::Shading,
    name,
  )
  let loaded = page_load_resource_object(self, value)
  let defaults = page_colour_defaults(resources)
  try @graphics.parse_shading_object(Some(name), loaded, defaults, 0L) catch {
    error => raise PdfDocumentError::GraphicsError(error)
  } noraise {
    resource => resource
  }
}

///|
pub fn PdfPage::pattern_resources(
  self : PdfPage,
) -> Array[@graphics.PatternResource] raise PdfDocumentError {
  let resources = page_direct_resource_dictionary(self)
  let category = page_resource_category_dictionary(
    self,
    resources,
    @content.ResourceCategory::Pattern,
    false,
  )
  let patterns : Array[@graphics.PatternResource] = []
  match category {
    None => patterns
    Some(dict) => {
      let defaults = page_colour_defaults(resources)
      for entry in dict.to_array() {
        let (name, value) = entry
        let loaded = page_load_resource_object(self, value)
        let pattern = try
          @graphics.parse_pattern_object(name, loaded, defaults, 0L)
        catch {
          error => raise PdfDocumentError::GraphicsError(error)
        } noraise {
          parsed => parsed
        }
        patterns.push(pattern)
      }
      patterns
    }
  }
}

///|
fn page_direct_resource_dictionary(
  page : PdfPage,
) -> @objects.PdfDictionary raise PdfDocumentError {
  let object = resolve_optional_page_object(page.file, page.resources())
  match object {
    None => Map::new()
    Some(@objects.PdfObject::Null) => Map::new()
    Some(@objects.PdfObject::Dictionary(dict)) => dict
    Some(_) =>
      raise PdfDocumentError::InvalidPage(
        page.object_id(),
        "Resources entry must resolve to a dictionary",
      )
  }
}

///|
fn page_named_resource_value(
  page : PdfPage,
  resources : @objects.PdfDictionary,
  category : @content.ResourceCategory,
  name : @objects.PdfName,
) -> @objects.PdfObject raise PdfDocumentError {
  let category_dict = match
    page_resource_category_dictionary(page, resources, category, true) {
    Some(dict) => dict
    None =>
      raise PdfDocumentError::InvalidPage(
        page.object_id(),
        "missing resource category",
      )
  }
  match category_dict.get(name) {
    Some(value) => value
    None =>
      raise PdfDocumentError::GraphicsError(
        @graphics.PdfGraphicsError::ResourceFailure(
          0L,
          "missing resource " + name.to_text(),
        ),
      )
  }
}

///|
fn page_resource_category_dictionary(
  page : PdfPage,
  resources : @objects.PdfDictionary,
  category : @content.ResourceCategory,
  required : Bool,
) -> @objects.PdfDictionary? raise PdfDocumentError {
  match resources.get(category.name()) {
    None =>
      if required {
        raise PdfDocumentError::GraphicsError(
          @graphics.PdfGraphicsError::ResourceFailure(
            0L,
            "missing resource category " + category.name().to_text(),
          ),
        )
      } else {
        None
      }
    Some(value) => {
      let loaded = page_load_resource_object(page, value)
      match loaded {
        @objects.PdfObject::Dictionary(dict) => Some(dict)
        _ =>
          raise PdfDocumentError::InvalidPage(
            page.object_id(),
            "resource category " +
            category.name().to_text() +
            " must resolve to a dictionary",
          )
      }
    }
  }
}

///|
fn page_load_resource_object(
  page : PdfPage,
  value : @objects.PdfObject,
) -> @objects.PdfObject raise PdfDocumentError {
  match value {
    @objects.PdfObject::Ref(object_id) =>
      try page.file.load_object(object_id) catch {
        error => raise PdfDocumentError::ReaderError(error)
      } noraise {
        object => object
      }
    _ => value
  }
}

///|
fn page_colour_defaults(
  resources : @objects.PdfDictionary,
) -> @graphics.ColourDefaults raise PdfDocumentError {
  let content_resources = @content.ContentResources::from_dictionary(resources)
  try @graphics.ColourDefaults::from_resources(content_resources, 0L) catch {
    error => raise PdfDocumentError::GraphicsError(error)
  } noraise {
    defaults => defaults
  }
}
