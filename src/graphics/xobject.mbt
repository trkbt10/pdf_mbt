///|
pub(all) enum XObjectResource {
  ImageResource(ImageDescriptor)
  FormResource(FormXObject)
  UnresolvedXObject(@objects.PdfName, @objects.ObjectId)
} derive(Eq, Debug)

///|
pub fn resolve_xobject_resource(
  resources : @content.ContentResources,
  name : @objects.PdfName,
  offset : Int64,
) -> XObjectResource raise PdfGraphicsError {
  let object = try
    resources.lookup_resource(@content.ResourceCategory::XObject, name)
  catch {
    error => raise PdfGraphicsError::ContentFailure(error)
  } noraise {
    value => value
  }
  match object {
    None =>
      raise PdfGraphicsError::InvalidXObject(
        offset,
        "missing XObject resource " + name.to_text(),
      )
    Some(value) => parse_xobject_resource(name, value, offset)
  }
}

///|
pub fn parse_xobject_resource(
  name : @objects.PdfName,
  object : @objects.PdfObject,
  offset : Int64,
) -> XObjectResource raise PdfGraphicsError {
  match object {
    @objects.PdfObject::Ref(id) => XObjectResource::UnresolvedXObject(name, id)
    @objects.PdfObject::Stream(stream) => {
      require_type_marker(stream.dict, b"XObject", offset, "XObject")
      let subtype = require_name_value(
        required_entry(stream.dict, b"Subtype", offset),
        offset,
        "XObject Subtype",
      )
      if subtype == pdf_name(b"Image") {
        XObjectResource::ImageResource(
          validate_image_stream(Some(name), stream, offset),
        )
      } else if subtype == pdf_name(b"Form") {
        XObjectResource::FormResource(
          validate_form_xobject(Some(name), stream, offset),
        )
      } else {
        raise PdfGraphicsError::InvalidXObject(
          offset,
          "unsupported XObject Subtype " + subtype.to_text(),
        )
      }
    }
    @objects.PdfObject::Null =>
      raise PdfGraphicsError::InvalidXObject(
        offset,
        "XObject resource " + name.to_text() + " resolves to null",
      )
    _ =>
      raise PdfGraphicsError::InvalidXObject(
        offset,
        "XObject resource " + name.to_text() + " must be a stream or reference",
      )
  }
}
