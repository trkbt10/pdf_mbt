///|
pub fn PdfPage::materialized_content_resources(
  self : PdfPage,
) -> @content.ContentResources raise PdfDocumentError {
  self.materialized_content_resources_with_xobject_policy(true)
}

///|
fn PdfPage::materialized_content_resources_without_xobjects(
  self : PdfPage,
) -> @content.ContentResources raise PdfDocumentError {
  self.materialized_content_resources_with_xobject_policy(false)
}

///|
fn PdfPage::materialized_content_resources_with_xobject_policy(
  self : PdfPage,
  include_xobjects : Bool,
) -> @content.ContentResources raise PdfDocumentError {
  let object = resolve_optional_page_object(self.file, self.resources())
  match object {
    None => @content.ContentResources::empty()
    Some(@objects.PdfObject::Null) => @content.ContentResources::empty()
    Some(@objects.PdfObject::Dictionary(dict)) =>
      @content.ContentResources::from_dictionary(
        materialize_resource_dictionary(
          self.file,
          dict,
          [],
          self.object_id(),
          include_xobjects,
        ),
      )
    Some(_) =>
      raise PdfDocumentError::ContentError(
        @content.PdfContentError::ResourceFailure(
          0L, "Resources entry for content stream must be a dictionary",
        ),
      )
  }
}

///|
pub fn PdfPage::materialized_content_stream(
  self : PdfPage,
) -> @content.ContentStream raise PdfDocumentError {
  let resources = self.materialized_content_resources()
  let decoded = self.decoded_content_bytes()
  try @content.parse_decoded_content(decoded, resources) catch {
    error => raise PdfDocumentError::ContentError(error)
  } noraise {
    content => content
  }
}

///|
fn PdfPage::materialized_content_stream_without_xobjects(
  self : PdfPage,
) -> @content.ContentStream raise PdfDocumentError {
  let resources = self.materialized_content_resources_without_xobjects()
  let decoded = self.decoded_content_bytes()
  try @content.parse_decoded_content(decoded, resources) catch {
    error => raise PdfDocumentError::ContentError(error)
  } noraise {
    content => content
  }
}

///|
fn materialize_resource_dictionary(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  form_stack : Array[@objects.ObjectId],
  page_id : @objects.ObjectId,
  include_xobjects : Bool,
) -> @objects.PdfDictionary raise PdfDocumentError {
  let output = dict.copy()
  if include_xobjects {
    materialize_named_resource_category(
      file, output, b"XObject", form_stack, page_id,
    )
  }
  materialize_named_resource_category(
    file, output, b"ExtGState", form_stack, page_id,
  )
  materialize_named_resource_category(
    file, output, b"ColorSpace", form_stack, page_id,
  )
  materialize_named_resource_category(
    file, output, b"Pattern", form_stack, page_id,
  )
  materialize_named_resource_category(
    file, output, b"Shading", form_stack, page_id,
  )
  materialize_named_resource_category(
    file, output, b"Properties", form_stack, page_id,
  )
  output
}

///|
fn materialize_named_resource_category(
  file : PdfFile,
  resources : @objects.PdfDictionary,
  category : Bytes,
  form_stack : Array[@objects.ObjectId],
  page_id : @objects.ObjectId,
) -> Unit raise PdfDocumentError {
  let key = @objects.PdfName::new(category)
  match resources.get(key) {
    Some(@objects.PdfObject::Dictionary(dict)) => {
      let materialized : @objects.PdfDictionary = Map::new()
      for resource_name, object in dict {
        materialized[resource_name] = materialize_resource_object(
          file, object, category, form_stack, page_id,
        )
      }
      resources[key] = @objects.PdfObject::Dictionary(materialized)
    }
    Some(@objects.PdfObject::Ref(id)) => {
      let loaded = load_document_object(file, id)
      match loaded {
        @objects.PdfObject::Dictionary(dict) => {
          let materialized : @objects.PdfDictionary = Map::new()
          for resource_name, object in dict {
            materialized[resource_name] = materialize_resource_object(
              file, object, category, form_stack, page_id,
            )
          }
          resources[key] = @objects.PdfObject::Dictionary(materialized)
        }
        _ =>
          raise PdfDocumentError::InvalidPage(
            page_id,
            @objects.PdfName::new(category).to_text() +
            " resource category must resolve to a dictionary",
          )
      }
    }
    _ => ()
  }
}

///|
fn materialize_resource_object(
  file : PdfFile,
  object : @objects.PdfObject,
  category : Bytes,
  form_stack : Array[@objects.ObjectId],
  page_id : @objects.ObjectId,
) -> @objects.PdfObject raise PdfDocumentError {
  match object {
    @objects.PdfObject::Ref(id) => {
      let loaded = load_document_object(file, id)
      if category == b"XObject" {
        materialize_xobject_stream(file, loaded, id, form_stack, page_id)
      } else if category == b"ColorSpace" ||
        category == b"Pattern" ||
        category == b"Shading" ||
        category == b"ExtGState" {
        materialize_nested_resource_object(file, loaded, [id], page_id)
      } else {
        loaded
      }
    }
    _ if category == b"ColorSpace" ||
      category == b"Pattern" ||
      category == b"Shading" ||
      category == b"ExtGState" =>
      materialize_nested_resource_object(file, object, [], page_id)
    @objects.PdfObject::Stream(stream) if category == b"XObject" =>
      materialize_direct_xobject_stream(file, stream, form_stack, page_id)
    _ => object
  }
}

///|
fn materialize_xobject_stream(
  file : PdfFile,
  object : @objects.PdfObject,
  id : @objects.ObjectId,
  form_stack : Array[@objects.ObjectId],
  page_id : @objects.ObjectId,
) -> @objects.PdfObject raise PdfDocumentError {
  match object {
    @objects.PdfObject::Stream(stream) =>
      if xobject_subtype_is(stream, b"Form") {
        if contains_object_id(form_stack, id) {
          raise PdfDocumentError::CycleDetected(
            id, "recursive Form XObject reference",
          )
        }
        let next_stack = form_stack.copy()
        next_stack.push(id)
        @objects.PdfObject::Stream(
          materialize_form_stream_resources(file, stream, next_stack, page_id),
        )
      } else if xobject_subtype_is(stream, b"Image") {
        @objects.PdfObject::Stream(
          materialize_image_stream_resources(file, stream, [id]),
        )
      } else {
        object
      }
    @objects.PdfObject::Null =>
      raise PdfDocumentError::InvalidPage(
        page_id, "XObject reference is missing",
      )
    _ =>
      raise PdfDocumentError::InvalidPage(
        page_id, "XObject resource must resolve to a stream",
      )
  }
}

///|
fn materialize_direct_xobject_stream(
  file : PdfFile,
  stream : @objects.PdfStream,
  form_stack : Array[@objects.ObjectId],
  page_id : @objects.ObjectId,
) -> @objects.PdfObject raise PdfDocumentError {
  if xobject_subtype_is(stream, b"Form") {
    @objects.PdfObject::Stream(
      materialize_form_stream_resources(file, stream, form_stack, page_id),
    )
  } else if xobject_subtype_is(stream, b"Image") {
    @objects.PdfObject::Stream(
      materialize_image_stream_resources(file, stream, []),
    )
  } else {
    @objects.PdfObject::Stream(stream)
  }
}

///|
fn materialize_image_stream_resources(
  file : PdfFile,
  stream : @objects.PdfStream,
  object_stack : Array[@objects.ObjectId],
) -> @objects.PdfStream raise PdfDocumentError {
  let dict = stream.dict.copy()
  materialize_image_stream_entry(file, dict, b"ColorSpace", object_stack)
  materialize_image_stream_entry(file, dict, b"Mask", object_stack)
  materialize_image_stream_entry(file, dict, b"SMask", object_stack)
  @objects.PdfStream::{ dict, data: stream.data }
}

///|
fn materialize_image_stream_entry(
  file : PdfFile,
  dict : @objects.PdfDictionary,
  key_bytes : Bytes,
  object_stack : Array[@objects.ObjectId],
) -> Unit raise PdfDocumentError {
  let key = @objects.PdfName::new(key_bytes)
  match dict.get(key) {
    Some(object) =>
      dict[key] = materialize_nested_image_object(file, object, object_stack)
    None => ()
  }
}

///|
fn materialize_nested_image_object(
  file : PdfFile,
  object : @objects.PdfObject,
  object_stack : Array[@objects.ObjectId],
) -> @objects.PdfObject raise PdfDocumentError {
  match object {
    @objects.PdfObject::Ref(id) => {
      if contains_object_id(object_stack, id) {
        raise PdfDocumentError::CycleDetected(
          id, "recursive image transparency resource reference",
        )
      }
      let next_stack = object_stack.copy()
      next_stack.push(id)
      materialize_nested_image_object(
        file,
        load_document_object(file, id),
        next_stack,
      )
    }
    @objects.PdfObject::Array(values) => {
      let materialized : Array[@objects.PdfObject] = []
      for value in values {
        materialized.push(
          materialize_nested_image_object(file, value, object_stack),
        )
      }
      @objects.PdfObject::Array(materialized)
    }
    @objects.PdfObject::Dictionary(dict) => {
      let materialized : @objects.PdfDictionary = Map::new()
      for key, value in dict {
        materialized[key] = materialize_nested_image_object(
          file, value, object_stack,
        )
      }
      @objects.PdfObject::Dictionary(materialized)
    }
    @objects.PdfObject::Stream(stream) =>
      @objects.PdfObject::Stream(
        materialize_image_stream_resources(file, stream, object_stack),
      )
    _ => object
  }
}

///|
fn materialize_nested_resource_object(
  file : PdfFile,
  object : @objects.PdfObject,
  object_stack : Array[@objects.ObjectId],
  page_id : @objects.ObjectId,
) -> @objects.PdfObject raise PdfDocumentError {
  match object {
    @objects.PdfObject::Ref(id) => {
      if contains_object_id(object_stack, id) {
        raise PdfDocumentError::CycleDetected(
          id, "recursive resource reference",
        )
      }
      let next_stack = object_stack.copy()
      next_stack.push(id)
      materialize_nested_resource_object(
        file,
        load_document_object(file, id),
        next_stack,
        page_id,
      )
    }
    @objects.PdfObject::Array(values) => {
      let materialized : Array[@objects.PdfObject] = []
      for value in values {
        materialized.push(
          materialize_nested_resource_object(file, value, object_stack, page_id),
        )
      }
      @objects.PdfObject::Array(materialized)
    }
    @objects.PdfObject::Dictionary(dict) => {
      let materialized : @objects.PdfDictionary = Map::new()
      for key, value in dict {
        materialized[key] = materialize_nested_resource_object(
          file, value, object_stack, page_id,
        )
      }
      @objects.PdfObject::Dictionary(materialized)
    }
    @objects.PdfObject::Stream(stream) => {
      let dict : @objects.PdfDictionary = Map::new()
      for key, value in stream.dict {
        dict[key] = materialize_nested_resource_object(
          file, value, object_stack, page_id,
        )
      }
      @objects.PdfObject::Stream(@objects.PdfStream::{ dict, data: stream.data })
    }
    _ => object
  }
}

///|
fn materialize_form_stream_resources(
  file : PdfFile,
  stream : @objects.PdfStream,
  form_stack : Array[@objects.ObjectId],
  page_id : @objects.ObjectId,
) -> @objects.PdfStream raise PdfDocumentError {
  match stream.dict.get(@objects.PdfName::new(b"Resources")) {
    Some(@objects.PdfObject::Dictionary(resources)) => {
      let dict = stream.dict.copy()
      dict[@objects.PdfName::new(b"Resources")] = @objects.PdfObject::Dictionary(
        materialize_resource_dictionary(
          file, resources, form_stack, page_id, true,
        ),
      )
      @objects.PdfStream::{ dict, data: stream.data }
    }
    Some(@objects.PdfObject::Ref(id)) => {
      let loaded = load_document_object(file, id)
      match loaded {
        @objects.PdfObject::Dictionary(resources) => {
          let dict = stream.dict.copy()
          dict[@objects.PdfName::new(b"Resources")] = @objects.PdfObject::Dictionary(
            materialize_resource_dictionary(
              file, resources, form_stack, page_id, true,
            ),
          )
          @objects.PdfStream::{ dict, data: stream.data }
        }
        _ =>
          raise PdfDocumentError::InvalidPage(
            page_id, "Form XObject Resources reference must resolve to a dictionary",
          )
      }
    }
    _ => stream
  }
}

///|
fn xobject_subtype_is(stream : @objects.PdfStream, expected : Bytes) -> Bool {
  match stream.dict.get(@objects.PdfName::new(b"Subtype")) {
    Some(@objects.PdfObject::Name(name)) =>
      name == @objects.PdfName::new(expected)
    _ => false
  }
}

///|
fn load_document_object(
  file : PdfFile,
  id : @objects.ObjectId,
) -> @objects.PdfObject raise PdfDocumentError {
  try file.load_object(id) catch {
    error => raise PdfDocumentError::ReaderError(error)
  } noraise {
    object => object
  }
}

///|
fn contains_object_id(
  values : Array[@objects.ObjectId],
  id : @objects.ObjectId,
) -> Bool {
  for value in values {
    if value == id {
      return true
    }
  }
  false
}
