///|
/// Creates a minimal valid PDF document with Catalog and an empty root Pages
/// tree. Object 1 is Catalog and object 2 is Pages, matching the existing
/// writer refactor path: PdfContext::new() -> add pages -> to_bytes().
pub fn PdfContext::new() -> PdfContext {
  // Refactor existing writer: create_pdf(content_bytes) now maps to
  // PdfContext::new() -> add pages -> to_bytes().
  let catalog_ref = object_ref(1)
  let pages_ref = object_ref(2)
  let context = PdfContext::{
    objects: Map::new(),
    generations: Map::new(),
    dirty_objects: Map::new(),
    catalog_ref,
    pages_ref,
    page_tree_refs: [pages_ref],
    info_ref: None,
    version: @reader.PdfVersion::{ major: 2, minor: 0 },
    next_object_number: 3,
    compress_streams: false,
    file_id: Some(default_context_file_id()),
  }
  context.store_object(
    catalog_ref,
    @objects.PdfObject::Dictionary(catalog_dictionary(pages_ref)),
    dirty=true,
  )
  context.store_object(
    pages_ref,
    @objects.PdfObject::Dictionary(empty_pages_dictionary()),
    dirty=true,
  )
  context
}

///|
pub fn PdfContext::set_version(
  self : PdfContext,
  major : Int,
  minor : Int,
) -> Unit {
  // Metadata manipulation: set_version updates the document PDF version.
  self.version = @reader.PdfVersion::{ major, minor }
}

///|
/// Page manipulation: PdfContext SHALL support page-level operations by
/// appending a new blank Page with the given MediaBox.
pub fn PdfContext::add_page(
  self : PdfContext,
  width : Double,
  height : Double,
) -> @objects.ObjectId {
  let page_ref = @objects.ObjectId::{
    object_number: self.next_object_number,
    generation_number: 0,
  }
  let page = page_dictionary(self.pages_ref, width, height)
  self.store_object(page_ref, @objects.PdfObject::Dictionary(page), dirty=true)
  append_page_to_root(self, page_ref)
  page_ref
}

///|
/// Page manipulation: PdfContext SHALL support page-level operations by
/// removing the page at the zero-based page tree index.
pub fn PdfContext::remove_page(
  self : PdfContext,
  index : Int,
) -> Unit raise PdfContextError {
  let pages = self.page_locations()
  let count = pages.length()
  if index < 0 || index >= count {
    raise PdfContextError::PageIndexOutOfRange(index, count)
  }
  let location = pages[index]
  remove_page_from_parent(self, location.parent_ref, location.page_ref)
  remove_page_contents(self, location.page_ref)
  self.objects.remove(location.page_ref.object_number)
  self.generations.remove(location.page_ref.object_number)
  self.dirty_objects.remove(location.page_ref.object_number)
  decrement_page_counts(self, location.parent_ref)
}

///|
/// Page manipulation: sets or replaces a page Contents stream.
pub fn PdfContext::set_page_content(
  self : PdfContext,
  page_ref : @objects.ObjectId,
  content_bytes : Bytes,
) -> @objects.ObjectId raise PdfContextError {
  let page = self.require_dictionary(page_ref, "page object")
  require_page_type(page_ref, page)
  let stream = @objects.PdfStream::{ dict: Map::new(), data: content_bytes }
  let contents_key = pdf_key(b"Contents")
  let content_ref = match page.get(contents_key) {
    Some(@objects.PdfObject::Ref(existing_ref)) =>
      match self.objects.get(existing_ref.object_number) {
        Some(@objects.PdfObject::Stream(_)) => existing_ref
        _ => self.allocate_object(@objects.PdfObject::Stream(stream))
      }
    _ => self.allocate_object(@objects.PdfObject::Stream(stream))
  }
  self.objects[content_ref.object_number] = @objects.PdfObject::Stream(stream)
  self.mark_dirty(content_ref)
  page[contents_key] = @objects.PdfObject::Ref(content_ref)
  self.mark_dirty(page_ref)
  content_ref
}

///|
/// Page manipulation view used by roundtrip fidelity tests and bridge edits.
/// Resource management callers use these page references to manage page resources.
/// The parser -> context -> builder pipeline preserves document structure by
/// keeping page references addressable across roundtrip edits.
pub fn PdfContext::page_refs(
  self : PdfContext,
) -> Array[@objects.ObjectId] raise PdfContextError {
  let locations = self.page_locations()
  let refs : Array[@objects.ObjectId] = []
  for location in locations {
    refs.push(location.page_ref)
  }
  refs
}

///|
/// Resource management: registers a Font resource on a page.
pub fn PdfContext::add_font(
  self : PdfContext,
  page_ref : @objects.ObjectId,
  name : @objects.PdfName,
  font_object : @objects.PdfObject,
) -> @objects.ObjectId raise PdfContextError {
  // Resource management: add_font registers a page Font resource.
  let font_ref = self.resource_object_ref(font_object)
  self.register_page_resource(page_ref, pdf_key(b"Font"), name, font_ref)
  font_ref
}

///|
/// Resource management: registers an image XObject resource on a page.
pub fn PdfContext::add_image(
  self : PdfContext,
  page_ref : @objects.ObjectId,
  name : @objects.PdfName,
  image_stream : @objects.PdfStream,
) -> @objects.ObjectId raise PdfContextError {
  // Resource management: add_image registers a page image XObject resource.
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

///|
fn append_page_to_root(
  context : PdfContext,
  page_ref : @objects.ObjectId,
) -> Unit {
  let pages = match context.objects.get(context.pages_ref.object_number) {
    Some(@objects.PdfObject::Dictionary(dict)) => dict
    _ => {
      let created = empty_pages_dictionary()
      context.objects[context.pages_ref.object_number] = @objects.PdfObject::Dictionary(
        created,
      )
      created
    }
  }
  let kids_key = pdf_key(b"Kids")
  let kids = match pages.get(kids_key) {
    Some(@objects.PdfObject::Array(values)) => values
    _ => {
      let values : Array[@objects.PdfObject] = []
      pages[kids_key] = @objects.PdfObject::Array(values)
      values
    }
  }
  kids.push(@objects.PdfObject::Ref(page_ref))
  pages[pdf_key(b"Count")] = @objects.PdfObject::Integer(
    kids.length().to_int64(),
  )
  context.mark_dirty(context.pages_ref)
}

///|
fn remove_page_from_parent(
  context : PdfContext,
  parent_ref : @objects.ObjectId,
  page_ref : @objects.ObjectId,
) -> Unit raise PdfContextError {
  let parent = context.require_dictionary(parent_ref, "page parent")
  let kids_key = pdf_key(b"Kids")
  let kids = match parent.get(kids_key) {
    Some(@objects.PdfObject::Array(values)) => values
    _ =>
      raise PdfContextError::InvalidObject(
        parent_ref, "page parent /Kids must be an array",
      )
  }
  let replacement : Array[@objects.PdfObject] = []
  for kid in kids {
    match kid {
      @objects.PdfObject::Ref(id) if id == page_ref => ()
      _ => replacement.push(kid)
    }
  }
  parent[kids_key] = @objects.PdfObject::Array(replacement)
  context.mark_dirty(parent_ref)
}

///|
fn remove_page_contents(
  context : PdfContext,
  page_ref : @objects.ObjectId,
) -> Unit raise PdfContextError {
  let page = context.require_dictionary(page_ref, "page object")
  match page.get(pdf_key(b"Contents")) {
    Some(@objects.PdfObject::Ref(content_ref)) => {
      context.objects.remove(content_ref.object_number)
      context.generations.remove(content_ref.object_number)
      context.dirty_objects.remove(content_ref.object_number)
    }
    _ => ()
  }
}

///|
fn decrement_page_counts(
  context : PdfContext,
  start_ref : @objects.ObjectId,
) -> Unit raise PdfContextError {
  let mut current : @objects.ObjectId? = Some(start_ref)
  while current is Some(node_ref) {
    let dict = context.require_dictionary(node_ref, "page tree node")
    match dict.get(pdf_key(b"Count")) {
      Some(@objects.PdfObject::Integer(count)) =>
        dict[pdf_key(b"Count")] = @objects.PdfObject::Integer(count - 1L)
      _ => ()
    }
    context.mark_dirty(node_ref)
    current = match dict.get(pdf_key(b"Parent")) {
      Some(@objects.PdfObject::Ref(parent_ref)) => Some(parent_ref)
      _ => None
    }
  }
}

///|
fn PdfContext::page_locations(
  self : PdfContext,
) -> Array[ContextPageLocation] raise PdfContextError {
  let locations : Array[ContextPageLocation] = []
  let path : Array[@objects.ObjectId] = []
  traverse_page_node(self, self.pages_ref, None, path, locations)
  locations
}

///|
fn traverse_page_node(
  context : PdfContext,
  node_ref : @objects.ObjectId,
  parent_ref : @objects.ObjectId?,
  path : Array[@objects.ObjectId],
  locations : Array[ContextPageLocation],
) -> Unit raise PdfContextError {
  if path_contains(path, node_ref) {
    raise PdfContextError::InvalidObject(node_ref, "page tree cycle detected")
  }
  let dict = context.require_dictionary(node_ref, "page tree object")
  let type_name = match dict.get(pdf_key(b"Type")) {
    Some(@objects.PdfObject::Name(name)) => Some(name)
    _ => None
  }
  if type_name == Some(pdf_key(b"Page")) {
    let actual_parent = match parent_ref {
      Some(value) => value
      None => context.pages_ref
    }
    locations.push(ContextPageLocation::{
      page_ref: node_ref,
      parent_ref: actual_parent,
    })
  } else {
    let kids = match dict.get(pdf_key(b"Kids")) {
      Some(@objects.PdfObject::Array(values)) => values
      _ => []
    }
    let next_path = copy_object_ids(path)
    next_path.push(node_ref)
    for kid in kids {
      match kid {
        @objects.PdfObject::Ref(kid_ref) =>
          traverse_page_node(
            context,
            kid_ref,
            Some(node_ref),
            next_path,
            locations,
          )
        _ => ()
      }
    }
  }
}

///|
fn path_contains(
  path : Array[@objects.ObjectId],
  id : @objects.ObjectId,
) -> Bool {
  for current in path {
    if current == id {
      return true
    }
  }
  false
}

///|
fn require_page_type(
  page_ref : @objects.ObjectId,
  page : @objects.PdfDictionary,
) -> Unit raise PdfContextError {
  match page.get(pdf_key(b"Type")) {
    Some(@objects.PdfObject::Name(name)) if name == pdf_key(b"Page") => ()
    _ =>
      raise PdfContextError::InvalidPageReference(
        page_ref, "object is not a /Page dictionary",
      )
  }
}

///|
fn catalog_dictionary(pages_ref : @objects.ObjectId) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_key(b"Type")] = @objects.PdfObject::Name(pdf_key(b"Catalog"))
  dict[pdf_key(b"Pages")] = @objects.PdfObject::Ref(pages_ref)
  dict
}

///|
fn empty_pages_dictionary() -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_key(b"Type")] = @objects.PdfObject::Name(pdf_key(b"Pages"))
  dict[pdf_key(b"Kids")] = @objects.PdfObject::Array([])
  dict[pdf_key(b"Count")] = @objects.PdfObject::Integer(0L)
  dict
}

///|
fn page_dictionary(
  parent_ref : @objects.ObjectId,
  width : Double,
  height : Double,
) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_key(b"Type")] = @objects.PdfObject::Name(pdf_key(b"Page"))
  dict[pdf_key(b"Parent")] = @objects.PdfObject::Ref(parent_ref)
  dict[pdf_key(b"MediaBox")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Real(width),
    @objects.PdfObject::Real(height),
  ])
  dict[pdf_key(b"Resources")] = @objects.PdfObject::Dictionary(Map::new())
  dict
}

///|
fn default_context_file_id() -> PdfContextFileId {
  PdfContextFileId::{
    first: b"moonbit-pdf-context-id-000000001",
    second: b"moonbit-pdf-context-id-000000001",
  }
}
