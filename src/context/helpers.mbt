///|
fn pdf_key(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}

///|
fn object_ref(object_number : Int) -> @objects.ObjectId {
  @objects.ObjectId::{ object_number, generation_number: 0 }
}

///|
fn PdfContext::generation_for(self : PdfContext, object_number : Int) -> Int {
  match self.generations.get(object_number) {
    Some(value) => value
    None => 0
  }
}

///|
fn PdfContext::mark_dirty(self : PdfContext, id : @objects.ObjectId) -> Unit {
  self.dirty_objects[id.object_number] = true
}

///|
fn PdfContext::store_object(
  self : PdfContext,
  id : @objects.ObjectId,
  value : @objects.PdfObject,
  dirty~ : Bool,
) -> Unit {
  self.objects[id.object_number] = value
  self.generations[id.object_number] = id.generation_number
  if id.object_number >= self.next_object_number {
    self.next_object_number = id.object_number + 1
  }
  if dirty {
    self.mark_dirty(id)
  }
}

///|
fn PdfContext::allocate_object(
  self : PdfContext,
  value : @objects.PdfObject,
) -> @objects.ObjectId {
  let id = @objects.ObjectId::{
    object_number: self.next_object_number,
    generation_number: 0,
  }
  self.store_object(id, value, dirty=true)
  id
}

///|
pub fn PdfContext::object(
  self : PdfContext,
  id : @objects.ObjectId,
) -> @objects.PdfObject? {
  self.objects.get(id.object_number)
}

///|
/// Enables optional stream compression for serialization to valid PDF bytes.
/// When true, unfiltered stream data is emitted with FlateDecode.
pub fn PdfContext::set_stream_compression(
  self : PdfContext,
  enabled : Bool,
) -> Unit {
  // Serialization builder stream compression option.
  self.compress_streams = enabled
}

///|
pub fn PdfContext::set_object(
  self : PdfContext,
  id : @objects.ObjectId,
  value : @objects.PdfObject,
) -> Unit {
  self.store_object(id, value, dirty=true)
}

///|
fn PdfContext::require_dictionary(
  self : PdfContext,
  id : @objects.ObjectId,
  context : String,
) -> @objects.PdfDictionary raise PdfContextError {
  match self.objects.get(id.object_number) {
    Some(@objects.PdfObject::Dictionary(dict)) => dict
    Some(_) =>
      raise PdfContextError::InvalidObject(
        id,
        "\{context} must be a dictionary",
      )
    None => raise PdfContextError::MissingObject(id)
  }
}

///|
fn clone_dictionary(source : @objects.PdfDictionary) -> @objects.PdfDictionary {
  let copy : @objects.PdfDictionary = Map::new()
  for entry in source.to_array() {
    let (key, value) = entry
    copy[key] = clone_object(value)
  }
  copy
}

///|
fn clone_array(source : Array[@objects.PdfObject]) -> Array[@objects.PdfObject] {
  let copy : Array[@objects.PdfObject] = []
  for value in source {
    copy.push(clone_object(value))
  }
  copy
}

///|
fn clone_object(object : @objects.PdfObject) -> @objects.PdfObject {
  match object {
    @objects.PdfObject::Array(values) =>
      @objects.PdfObject::Array(clone_array(values))
    @objects.PdfObject::Dictionary(dict) =>
      @objects.PdfObject::Dictionary(clone_dictionary(dict))
    @objects.PdfObject::Stream(stream) =>
      @objects.PdfObject::Stream(@objects.PdfStream::{
        dict: clone_dictionary(stream.dict),
        data: stream.data,
      })
    _ => object
  }
}

///|
fn copy_object_ids(
  source : Array[@objects.ObjectId],
) -> Array[@objects.ObjectId] {
  let copy : Array[@objects.ObjectId] = []
  for id in source {
    copy.push(id)
  }
  copy
}
