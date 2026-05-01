///|
#external
type JSUint8Array

///|
fn uint8array_length(arr : JSUint8Array) -> Int = "pdf" "uint8array_length"

///|
fn uint8array_get(arr : JSUint8Array, index : Int) -> Int = "pdf" "uint8array_get"

///|
fn uint8array_new(length : Int) -> JSUint8Array = "pdf" "uint8array_new"

///|
fn uint8array_set(arr : JSUint8Array, index : Int, value : Int) -> Unit = "pdf" "uint8array_set"

///|
let documents : Map[Int, @pdfapi.PdfDocument] = Map::new()

///|
let contexts : Map[Int, @context.PdfContext] = Map::new()

///|
/// Pending SVG render results for the accessor bridge, keyed by
/// "handle:page" and populated by each pdf_page_to_svg_deferred call.
/// This is per-call pending state, not a cache; the viewer layer avoids
/// duplicate deferred-render invocations with its own application-lifetime
/// cache.
let deferred_svg_pages : Map[String, @svg.SvgDeferredResult] = Map::new()

///|
/// Page-scoped deferred SVG image cache. The intended accessor contract is one
/// graphics event walk per (handle, page), not one walk per image accessor; the
/// first data/info/mime access fills this ordered array for the whole page.
let deferred_svg_image_page_cache : Map[String, Array[@svg.SvgImageEntry]] = Map::new()

///|
let graphics_walk_counter : Ref[Int] = { val: 0 }

///|
priv struct HandleCounter {
  mut value : Int
}

///|
let document_counter : HandleCounter = { value: 1 }

///|
let context_counter : HandleCounter = { value: 1 }

///|
priv struct PageImageEntry {
  name : @objects.PdfName?
  stream : @objects.PdfStream
  resources : @objects.PdfDictionary?
}

///|
pub fn pdf_open(data : JSUint8Array) -> Int {
  let bytes = uint8array_to_bytes(data)
  let result : Result[@pdfapi.PdfDocument, @reader.PdfDocumentError] = try? @pdfapi.open(
    bytes,
  )
  match result {
    Ok(document) => {
      let handle = next_document_handle()
      documents[handle] = document
      handle
    }
    Err(_) => -1
  }
}

///|
pub fn pdf_page_count(handle : Int) -> Int {
  match documents.get(handle) {
    Some(document) => {
      let result : Result[Int, @reader.PdfDocumentError] = try? document.page_count()
      match result {
        Ok(count) => count
        Err(_) => -1
      }
    }
    None => -1
  }
}

///|
pub fn pdf_extract_text(handle : Int, page : Int) -> String {
  match get_page(handle, page) {
    Some(pdf_page) => pdf_page.extract_text()
    None => ""
  }
}

///|
pub fn pdf_extract_text_layout(handle : Int, page : Int) -> String {
  match get_page(handle, page) {
    Some(pdf_page) => pdf_page.extract_text_layout()
    None => ""
  }
}

///|
pub fn pdf_page_geometry_json(handle : Int, page : Int) -> String {
  match get_page(handle, page) {
    Some(pdf_page) => page_geometry_json(pdf_page)
    None => "{\"error\":\"invalid page handle\"}"
  }
}

///|
pub fn pdf_page_text_positions_json(handle : Int, page : Int) -> String {
  match get_page(handle, page) {
    Some(pdf_page) => page_text_positions_json(pdf_page)
    None => "{\"error\":\"invalid page handle\"}"
  }
}

///|
pub fn pdf_page_to_svg(handle : Int, page : Int) -> String {
  match get_page(handle, page) {
    Some(pdf_page) => @svg.render_page_svg(pdf_page.reader_page())
    None => ""
  }
}

///|
pub fn pdf_page_to_svg_deferred(handle : Int, page : Int) -> String {
  match get_page(handle, page) {
    Some(pdf_page) => {
      remove_deferred_images_for_page(handle, page)
      let result = @svg.render_page_svg_deferred(pdf_page.reader_page())
      let svg = result.svg
      deferred_svg_pages[deferred_page_key(handle, page)] = result
      svg
    }
    None => ""
  }
}

///|
pub fn pdf_page_svg_image_count(handle : Int, page : Int) -> Int {
  match deferred_svg_pages.get(deferred_page_key(handle, page)) {
    Some(result) => result.images.length()
    None => 0
  }
}

///|
pub fn pdf_page_svg_image_data(
  handle : Int,
  page : Int,
  index : Int,
) -> JSUint8Array {
  match get_deferred_svg_image_entry(handle, page, index) {
    Some(image) => bytes_to_uint8array(image.data)
    None => bytes_to_uint8array(b"")
  }
}

///|
/// wasm API surface for deferred SVG image metadata. Raw RGBA image/x-rgba8
/// entries report width/height for browser canvas decoding; PNG/JPEG/JP2
/// entries keep 0 dimensions because their encoded bytes are self-describing.
pub fn pdf_page_svg_image_info(handle : Int, page : Int, index : Int) -> String {
  match get_deferred_svg_image_entry(handle, page, index) {
    Some(image) => svg_image_info_json(image)
    None => ""
  }
}

///|
pub fn pdf_page_svg_image_mime(handle : Int, page : Int, index : Int) -> String {
  match get_deferred_svg_image_entry(handle, page, index) {
    Some(image) => image.mime_type
    None => ""
  }
}

///|
pub fn pdf_page_image_count(handle : Int, page : Int) -> Int {
  match get_page(handle, page) {
    Some(pdf_page) => page_image_entries(pdf_page).length()
    None => -1
  }
}

///|
pub fn pdf_page_image_info_json(
  handle : Int,
  page : Int,
  index : Int,
) -> String {
  match get_page_image_entry(handle, page, index) {
    Some(entry) => page_image_info_json(entry)
    None => "{\"error\":\"invalid image handle\"}"
  }
}

///|
pub fn pdf_page_image_rgba(
  handle : Int,
  page : Int,
  index : Int,
) -> JSUint8Array {
  match get_page_image_entry(handle, page, index) {
    Some(entry) => bytes_to_uint8array(page_image_rgba(entry))
    None => bytes_to_uint8array(b"")
  }
}

///|
pub fn pdf_info_json(handle : Int) -> String {
  match documents.get(handle) {
    Some(document) => document_info_json(document)
    None => "{\"error\":\"invalid document handle\"}"
  }
}

///|
pub fn pdf_check_json(handle : Int) -> String {
  match documents.get(handle) {
    Some(document) => {
      let result : Result[@pdfapi.PdfCapabilityReport, @reader.PdfDocumentError] = try? document.check()
      match result {
        Ok(report) => capability_report_json(report)
        Err(_) => "{\"error\":\"failed to build capability report\"}"
      }
    }
    None => "{\"error\":\"invalid document handle\"}"
  }
}

///|
pub fn pdf_close(handle : Int) -> Unit {
  documents.remove(handle)
  remove_deferred_pages_for_handle(handle)
  remove_deferred_image_pages_for_handle(handle)
}

///|
/// test-only
pub fn test_reset_graphics_walk_counter() -> Unit {
  graphics_walk_counter.val = 0
}

///|
/// test-only
pub fn test_graphics_walk_counter() -> Int {
  graphics_walk_counter.val
}

///|
pub fn ctx_new() -> Int {
  let handle = next_context_handle()
  contexts[handle] = @context.PdfContext::new()
  handle
}

///|
pub fn ctx_from_document(handle : Int) -> Int {
  match documents.get(handle) {
    Some(document) => {
      let result : Result[@context.PdfContext, @context.PdfContextError] = try? @context.PdfContext::from_document(
        document.reader_document(),
      )
      match result {
        Ok(context) => {
          let context_handle = next_context_handle()
          contexts[context_handle] = context
          context_handle
        }
        Err(_) => -1
      }
    }
    None => -1
  }
}

///|
pub fn ctx_add_page(ctx : Int, width : Double, height : Double) -> Int {
  match contexts.get(ctx) {
    Some(context) => context.add_page(width, height).object_number
    None => -1
  }
}

///|
pub fn ctx_set_title(ctx : Int, title : String) -> Unit {
  match contexts.get(ctx) {
    Some(context) => context.set_title(@utf8.encode(title))
    None => ()
  }
}

///|
pub fn ctx_to_bytes(ctx : Int) -> JSUint8Array {
  match contexts.get(ctx) {
    Some(context) => bytes_to_uint8array(context.to_bytes())
    None => bytes_to_uint8array(b"")
  }
}

///|
pub fn ctx_close(ctx : Int) -> Unit {
  contexts.remove(ctx)
}

///|
fn next_document_handle() -> Int {
  let handle = document_counter.value
  document_counter.value = document_counter.value + 1
  handle
}

///|
fn next_context_handle() -> Int {
  let handle = context_counter.value
  context_counter.value = context_counter.value + 1
  handle
}

///|
fn uint8array_to_bytes(data : JSUint8Array) -> Bytes {
  let length = uint8array_length(data)
  Bytes::makei(length, fn(i) { uint8array_get(data, i).to_byte() })
}

///|
fn bytes_to_uint8array(bytes : Bytes) -> JSUint8Array {
  let out = uint8array_new(bytes.length())
  for i in 0..<bytes.length() {
    uint8array_set(out, i, bytes[i].to_int())
  }
  out
}

///|
fn get_page(handle : Int, page : Int) -> @pdfapi.PdfPage? {
  match documents.get(handle) {
    Some(document) => {
      let result : Result[@pdfapi.PdfPage, @reader.PdfDocumentError] = try? document.page(
        page,
      )
      match result {
        Ok(pdf_page) => Some(pdf_page)
        Err(_) => None
      }
    }
    None => None
  }
}

///|
fn get_page_image_entry(
  handle : Int,
  page : Int,
  index : Int,
) -> PageImageEntry? {
  match get_page(handle, page) {
    Some(pdf_page) => {
      let entries = page_image_entries(pdf_page)
      if index >= 0 && index < entries.length() {
        Some(entries[index])
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn deferred_page_key(handle : Int, page : Int) -> String {
  handle.to_string() + ":" + page.to_string()
}

///|
fn get_deferred_svg_image(
  handle : Int,
  page : Int,
  index : Int,
) -> @svg.SvgImageEntry? {
  match deferred_svg_pages.get(deferred_page_key(handle, page)) {
    Some(result) =>
      if index >= 0 && index < result.images.length() {
        Some(result.images[index])
      } else {
        None
      }
    None => None
  }
}

///|
fn get_deferred_svg_image_entry(
  handle : Int,
  page : Int,
  index : Int,
) -> @svg.SvgImageEntry? {
  if get_deferred_svg_image(handle, page, index) is None {
    return None
  }
  let key = deferred_page_key(handle, page)
  let entries = match deferred_svg_image_page_cache.get(key) {
    Some(entries) => entries
    None =>
      match build_deferred_svg_image_page(handle, page) {
        Some(entries) => {
          deferred_svg_image_page_cache[key] = entries
          entries
        }
        None => return None
      }
  }
  if index >= 0 && index < entries.length() {
    Some(entries[index])
  } else {
    None
  }
}

///|
fn build_deferred_svg_image_page(
  handle : Int,
  page : Int,
) -> Array[@svg.SvgImageEntry]? {
  match get_page(handle, page) {
    Some(pdf_page) => {
      graphics_walk_counter.val += 1
      let result : Result[
        Array[@graphics.GraphicsEvent],
        @reader.PdfDocumentError,
      ] = try? pdf_page
        .reader_page()
        .graphics_events(
          @reader.GraphicsPageOptions::with_materialized_xobjects(None),
        )
      match result {
        Ok(events) => {
          let page_entries = page_image_entries(pdf_page)
          let extracted_cache : Map[@objects.PdfName, @graphics.ExtractedImage] = Map::new()
          let passthrough_cache : PassthroughCache = Map::new()
          let entries : Array[@svg.SvgImageEntry] = []
          for event in events {
            match event {
              @graphics.GraphicsEvent::ImagePainted(_, descriptor, state) =>
                match descriptor.source {
                  @graphics.ImageSource::XObjectImage(Some(name)) =>
                    match
                      page_image_entry_by_name_from_entries(page_entries, name) {
                      Some(entry) =>
                        match
                          deferred_svg_image_entry_data_cached(
                            entry,
                            state,
                            extracted_cache,
                            passthrough_cache,
                          ) {
                          Some(image) => entries.push(image)
                          None => ()
                        }
                      None => ()
                    }
                  _ => ()
                }
              _ => ()
            }
          }
          Some(entries)
        }
        Err(_) => None
      }
    }
    None => None
  }
}

///|
fn page_image_entry_by_name_from_entries(
  entries : Array[PageImageEntry],
  name : @objects.PdfName,
) -> PageImageEntry? {
  for entry in entries {
    match entry.name {
      Some(entry_name) if entry_name == name => return Some(entry)
      _ => ()
    }
  }
  None
}

///|
/// Per-page cache for the SvgImageEntry produced by the browser-passthrough
/// fast path. Keyed by PdfName so multiple paint events for the same XObject
/// share one extracted entry without re-running the dictionary checks.
typealias Map[@objects.PdfName, @svg.SvgImageEntry] as PassthroughCache

///|
fn deferred_svg_image_entry_data_cached(
  entry : PageImageEntry,
  state : @graphics.GraphicsState,
  extracted_cache : Map[@objects.PdfName, @graphics.ExtractedImage],
  passthrough_cache : PassthroughCache,
) -> @svg.SvgImageEntry? {
  match entry.name {
    Some(name) => {
      // Browser-passthrough fast path: when the source image is a baseline
      // JPEG (DCTDecode) with a browser-compatible colour space and no
      // alpha mask / Decode override, hand the original encoded bytes to
      // the browser instead of decoding to RGBA inside wasm. The wasm-gc
      // JPEG decoder is several seconds per megapixel; the browser's
      // native decoder is sub-frame, and the bytes-out volume drops
      // ~30x because we skip the decoded RGBA buffer entirely.
      match passthrough_cache.get(name) {
        Some(image) => return Some(image)
        None => ()
      }
      match try_browser_passthrough_svg_image(entry) {
        Some(image) => {
          passthrough_cache[name] = image
          return Some(image)
        }
        None => ()
      }
      match extracted_cache.get(name) {
        Some(extracted) => svg_image_entry_from_extracted(extracted, state)
        None =>
          match extract_deferred_svg_image(entry) {
            Some(extracted) => {
              extracted_cache[name] = extracted
              svg_image_entry_from_extracted(extracted, state)
            }
            None => None
          }
      }
    }
    None => deferred_svg_image_entry_data(entry, state)
  }
}

///|
fn deferred_svg_image_entry_data(
  entry : PageImageEntry,
  state : @graphics.GraphicsState,
) -> @svg.SvgImageEntry? {
  match try_browser_passthrough_svg_image(entry) {
    Some(image) => return Some(image)
    None => ()
  }
  match extract_deferred_svg_image(entry) {
    Some(extracted) => svg_image_entry_from_extracted(extracted, state)
    None => None
  }
}

///|
/// Returns Some(entry) when the image XObject can be served to the browser
/// without wasm-side decoding. The check is intentionally conservative: it
/// only accepts a single DCTDecode (browser native JPEG) or FlateDecode
/// (browser native zlib via DecompressionStream) filter with DeviceRGB /
/// DeviceGray (or the calibrated equivalents) colour space, no alpha mask,
/// no predictor, and a default Decode array. Anything more exotic falls
/// through to the full extract_image_xobject pipeline so colour fidelity is
/// preserved.
fn try_browser_passthrough_svg_image(
  entry : PageImageEntry,
) -> @svg.SvgImageEntry? {
  let prepared = prepare_render_image_stream(entry.stream, entry.resources)
  let dict = prepared.dict
  match dict.get(@objects.PdfName::new(b"Mask")) {
    Some(@objects.PdfObject::Null) | None => ()
    Some(_) => return None
  }
  match dict.get(@objects.PdfName::new(b"ImageMask")) {
    Some(@objects.PdfObject::Boolean(true)) => return None
    _ => ()
  }
  let filter = match single_filter_name(dict) {
    Some(name) => name
    None => return None
  }
  if !is_browser_compatible_color_space(dict) {
    return None
  }
  let component_count = if has_grayscale_color_space(dict) { 1 } else { 3 }
  if !is_default_image_decode(dict, component_count) {
    return None
  }
  let smask_passthrough = read_browser_smask_passthrough(dict)
  // Bail if SMask is set but cannot be passed through to the browser — falling
  // through to the WASM decoder is the only way to preserve the alpha mask.
  if dict.get(@objects.PdfName::new(b"SMask")) is Some(_) &&
    smask_passthrough is None {
    return None
  }
  if filter == @objects.PdfName::new(b"DCTDecode") {
    let width = dict_integer_or_zero(dict, b"Width")
    let height = dict_integer_or_zero(dict, b"Height")
    if width <= 0 || height <= 0 {
      return None
    }
    return Some(jpeg_passthrough_entry(prepared.data, width, height, smask_passthrough))
  }
  if filter == @objects.PdfName::new(b"FlateDecode") {
    if !is_default_or_no_predictor(dict) {
      return None
    }
    if dict_integer_or_zero(dict, b"BitsPerComponent") != 8 {
      return None
    }
    let width = dict_integer_or_zero(dict, b"Width")
    let height = dict_integer_or_zero(dict, b"Height")
    if width <= 0 || height <= 0 {
      return None
    }
    if smask_passthrough is Some(_) {
      // SMask compositing for FlateDecode passthrough is not yet implemented
      // on the JS side; bail to the wasm decoder so alpha stays correct.
      return None
    }
    let mime = if component_count == 1 {
      @svg.pdf_flate_gray_image_mime
    } else {
      @svg.pdf_flate_rgb_image_mime
    }
    return Some(@svg.SvgImageEntry::{
      mime_type: mime,
      data: prepared.data,
      width: Some(width),
      height: Some(height),
    })
  }
  None
}

///|
priv struct BrowserSMaskPassthrough {
  width : Int
  height : Int
  flate_data : Bytes
}

///|
/// Resolves a soft-mask reference embedded in an image XObject dictionary into
/// the framed payload we pass to the browser. Only the narrow case used by
/// presentation-style PDFs is accepted here:
/// - SMask is an inline Stream (not a Ref — those carry no resolution context
///   inside this module)
/// - Single FlateDecode filter, BitsPerComponent 8, DeviceGray colour space
///   (or no ColorSpace, since SMask is implicitly DeviceGray)
/// - No nested SMask, no Mask, no Predictor, no ImageMask
/// Anything else returns None so the caller falls through to the wasm decoder.
fn read_browser_smask_passthrough(
  dict : @objects.PdfDictionary,
) -> BrowserSMaskPassthrough? {
  let smask_object = match dict.get(@objects.PdfName::new(b"SMask")) {
    Some(value) => value
    None => return None
  }
  let smask_stream = match smask_object {
    @objects.PdfObject::Stream(stream) => stream
    _ => return None
  }
  let mask_dict = smask_stream.dict
  if mask_dict.get(@objects.PdfName::new(b"SMask")) is Some(_) {
    return None
  }
  if mask_dict.get(@objects.PdfName::new(b"Mask")) is Some(_) {
    return None
  }
  match mask_dict.get(@objects.PdfName::new(b"ImageMask")) {
    Some(@objects.PdfObject::Boolean(true)) => return None
    _ => ()
  }
  let filter = match single_filter_name(mask_dict) {
    Some(name) => name
    None => return None
  }
  if filter != @objects.PdfName::new(b"FlateDecode") {
    return None
  }
  if !is_default_or_no_predictor(mask_dict) {
    return None
  }
  if dict_integer_or_zero(mask_dict, b"BitsPerComponent") != 8 {
    return None
  }
  // SMasks are conventionally DeviceGray. Accept "absent" as well so we cover
  // PDFs that lean on the implicit default.
  match mask_dict.get(@objects.PdfName::new(b"ColorSpace")) {
    None => ()
    Some(@objects.PdfObject::Name(name)) =>
      if name != @objects.PdfName::new(b"DeviceGray") &&
        name != @objects.PdfName::new(b"G") {
        return None
      }
    _ => return None
  }
  if !is_default_image_decode(mask_dict, 1) {
    return None
  }
  let width = dict_integer_or_zero(mask_dict, b"Width")
  let height = dict_integer_or_zero(mask_dict, b"Height")
  if width <= 0 || height <= 0 {
    return None
  }
  Some(BrowserSMaskPassthrough::{
    width,
    height,
    flate_data: smask_stream.data,
  })
}

///|
/// Builds the JPEG SvgImageEntry, framing the JPEG together with the SMask
/// passthrough payload (if any) so the JS layer can composite the alpha mask.
/// Frame layout for the smask case:
///   magic 'PSMK' (4) | width (4 BE) | height (4 BE) |
///   smask_w (4 BE) | smask_h (4 BE) | smask_len (4 BE) | smask_zlib_bytes |
///   jpeg_len (4 BE) | jpeg_bytes
/// For the non-smask case we just hand the JPEG bytes through with the
/// canonical image/jpeg MIME so existing Blob URL paths apply.
fn jpeg_passthrough_entry(
  jpeg : Bytes,
  width : Int,
  height : Int,
  smask : BrowserSMaskPassthrough?,
) -> @svg.SvgImageEntry {
  match smask {
    None =>
      @svg.SvgImageEntry::{
        mime_type: "image/jpeg",
        data: jpeg,
        width: Some(width),
        height: Some(height),
      }
    Some(mask) => {
      let buf : Array[Byte] = []
      append_bytes_to_array(buf, b"PSMK")
      append_be_u32(buf, width)
      append_be_u32(buf, height)
      append_be_u32(buf, mask.width)
      append_be_u32(buf, mask.height)
      append_be_u32(buf, mask.flate_data.length())
      append_bytes_to_array(buf, mask.flate_data)
      append_be_u32(buf, jpeg.length())
      append_bytes_to_array(buf, jpeg)
      @svg.SvgImageEntry::{
        mime_type: @svg.pdf_jpeg_with_smask_image_mime,
        data: Bytes::from_array(buf[:]),
        width: Some(width),
        height: Some(height),
      }
    }
  }
}

///|
fn append_be_u32(buf : Array[Byte], value : Int) -> Unit {
  buf.push(((value >> 24) & 0xff).to_byte())
  buf.push(((value >> 16) & 0xff).to_byte())
  buf.push(((value >> 8) & 0xff).to_byte())
  buf.push((value & 0xff).to_byte())
}

///|
fn append_bytes_to_array(buf : Array[Byte], bytes : Bytes) -> Unit {
  for byte in bytes {
    buf.push(byte)
  }
}

///|
/// Detects FlateDecode predictor settings that match "no predictor" — i.e.
/// the inflated stream is the literal sample sequence with no per-row filter
/// byte and no inter-row prediction. We only fast-path this case because
/// applying TIFF/PNG predictors in JavaScript would erode the speedup.
fn is_default_or_no_predictor(dict : @objects.PdfDictionary) -> Bool {
  match dict.get(@objects.PdfName::new(b"DecodeParms")) {
    None => true
    Some(@objects.PdfObject::Null) => true
    Some(@objects.PdfObject::Dictionary(params)) =>
      match params.get(@objects.PdfName::new(b"Predictor")) {
        None => true
        Some(@objects.PdfObject::Null) => true
        Some(@objects.PdfObject::Integer(value)) => value == 1L
        _ => false
      }
    _ => false
  }
}

///|
fn single_filter_name(
  dict : @objects.PdfDictionary,
) -> @objects.PdfName? {
  match dict.get(@objects.PdfName::new(b"Filter")) {
    Some(@objects.PdfObject::Name(name)) => Some(name)
    Some(@objects.PdfObject::Array(values)) =>
      if values.length() == 1 {
        match values[0] {
          @objects.PdfObject::Name(name) => Some(name)
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn is_browser_compatible_color_space(
  dict : @objects.PdfDictionary,
) -> Bool {
  // After prepare_render_image_stream the ColorSpace field is materialized
  // (a name reference into Resources is replaced by the resolved object),
  // so we only have to recognise the inline forms here. We accept the
  // device colour spaces and their CIE-calibrated counterparts because
  // browsers handle them as untagged sRGB / grayscale, which is exactly
  // what the existing canvas-decoded path produced.
  match dict.get(@objects.PdfName::new(b"ColorSpace")) {
    None => false
    Some(@objects.PdfObject::Name(name)) =>
      name == @objects.PdfName::new(b"DeviceRGB") ||
      name == @objects.PdfName::new(b"DeviceGray") ||
      name == @objects.PdfName::new(b"RGB") ||
      name == @objects.PdfName::new(b"G")
    Some(@objects.PdfObject::Array(values)) =>
      if values.length() >= 1 {
        match values[0] {
          @objects.PdfObject::Name(name) =>
            name == @objects.PdfName::new(b"CalRGB") ||
            name == @objects.PdfName::new(b"CalGray") ||
            name == @objects.PdfName::new(b"DeviceRGB") ||
            name == @objects.PdfName::new(b"DeviceGray")
          _ => false
        }
      } else {
        false
      }
    _ => false
  }
}

///|
fn has_grayscale_color_space(dict : @objects.PdfDictionary) -> Bool {
  match dict.get(@objects.PdfName::new(b"ColorSpace")) {
    Some(@objects.PdfObject::Name(name)) =>
      name == @objects.PdfName::new(b"DeviceGray") ||
      name == @objects.PdfName::new(b"G")
    Some(@objects.PdfObject::Array(values)) =>
      if values.length() >= 1 {
        match values[0] {
          @objects.PdfObject::Name(name) =>
            name == @objects.PdfName::new(b"CalGray") ||
            name == @objects.PdfName::new(b"DeviceGray")
          _ => false
        }
      } else {
        false
      }
    _ => false
  }
}

///|
fn is_default_image_decode(
  dict : @objects.PdfDictionary,
  component_count : Int,
) -> Bool {
  match dict.get(@objects.PdfName::new(b"Decode")) {
    None => true
    Some(@objects.PdfObject::Array(values)) => {
      if values.length() != component_count * 2 {
        return false
      }
      let mut index = 0
      while index < values.length() {
        let lo = number_value(values[index])
        let hi = number_value(values[index + 1])
        match (lo, hi) {
          (Some(lo_value), Some(hi_value)) =>
            if lo_value != 0.0 || hi_value != 1.0 {
              return false
            }
          _ => return false
        }
        index = index + 2
      }
      true
    }
    _ => false
  }
}

///|
fn number_value(value : @objects.PdfObject) -> Double? {
  match value {
    @objects.PdfObject::Integer(n) => Some(n.to_double())
    @objects.PdfObject::Real(n) => Some(n)
    _ => None
  }
}

///|
fn dict_integer_or_zero(dict : @objects.PdfDictionary, key : Bytes) -> Int {
  match dict.get(@objects.PdfName::new(key)) {
    Some(@objects.PdfObject::Integer(value)) => value.to_int()
    Some(@objects.PdfObject::Real(value)) => value.to_int()
    _ => 0
  }
}

///|
fn extract_deferred_svg_image(
  entry : PageImageEntry,
) -> @graphics.ExtractedImage? {
  let result : Result[@graphics.ExtractedImage, @graphics.PdfGraphicsError] = try? @graphics.extract_image_xobject(
    entry.name,
    prepare_render_image_stream(entry.stream, entry.resources),
    0L,
  )
  match result {
    Ok(extracted) => Some(extracted)
    Err(_) => None
  }
}

///|
fn svg_image_entry_from_extracted(
  extracted : @graphics.ExtractedImage,
  state : @graphics.GraphicsState,
) -> @svg.SvgImageEntry? {
  match extracted.data {
    @graphics.ExtractedImageData::DeviceRgbRaster(raster) =>
      raw_rgba_svg_image_entry(raster.width, raster.height, raster.rgba)
    @graphics.ExtractedImageData::StencilMaskRaster(mask) => {
      let paint_result : Result[
        @graphics.DeviceRgbColour,
        @graphics.PdfGraphicsError,
      ] = try? state.current_colour_as_rgb(@graphics.ColourUse::Nonstroking)
      let paint = match paint_result {
        Ok(rgb) => rgb
        Err(_) => @graphics.DeviceRgbColour::{ red: 0.0, green: 0.0, blue: 0.0 }
      }
      let raster = @graphics.paint_stencil_mask_with_colour(mask, paint)
      raw_rgba_svg_image_entry(raster.width, raster.height, raster.rgba)
    }
    @graphics.ExtractedImageData::EncodedImageData(data, filters) =>
      browser_encoded_svg_image_entry(data, filters)
  }
}

///|
fn raw_rgba_svg_image_entry(
  width : Int,
  height : Int,
  rgba : Bytes,
) -> @svg.SvgImageEntry? {
  if width <= 0 || height <= 0 || rgba.length() != width * height * 4 {
    None
  } else {
    Some(@svg.SvgImageEntry::{
      mime_type: @svg.raw_rgba_image_mime,
      data: rgba,
      width: Some(width),
      height: Some(height),
    })
  }
}

///|
fn browser_encoded_svg_image_entry(
  data : Bytes,
  filters : Array[@objects.PdfName],
) -> @svg.SvgImageEntry? {
  if filters.length() != 1 {
    return None
  }
  let filter = filters[0]
  if filter == @objects.PdfName::new(b"DCTDecode") {
    Some(@svg.SvgImageEntry::{
      mime_type: "image/jpeg",
      data,
      width: None,
      height: None,
    })
  } else if filter == @objects.PdfName::new(b"JPXDecode") {
    Some(@svg.SvgImageEntry::{
      mime_type: "image/jp2",
      data,
      width: None,
      height: None,
    })
  } else {
    None
  }
}

///|
fn svg_image_info_json(image : @svg.SvgImageEntry) -> String {
  "{\"mime\":\"" +
  image.mime_type +
  "\",\"width\":" +
  svg_image_optional_dimension(image.width).to_string() +
  ",\"height\":" +
  svg_image_optional_dimension(image.height).to_string() +
  "}"
}

///|
fn svg_image_optional_dimension(value : Int?) -> Int {
  match value {
    Some(size) => size
    None => 0
  }
}

///|
fn remove_deferred_pages_for_handle(handle : Int) -> Unit {
  let prefix = handle.to_string() + ":"
  deferred_svg_pages.retain(fn(key, _value) { !key.has_prefix(prefix) })
}

///|
fn remove_deferred_image_pages_for_handle(handle : Int) -> Unit {
  let prefix = handle.to_string() + ":"
  deferred_svg_image_page_cache.retain(fn(key, _value) {
    !key.has_prefix(prefix)
  })
}

///|
fn remove_deferred_images_for_page(handle : Int, page : Int) -> Unit {
  deferred_svg_image_page_cache.remove(deferred_page_key(handle, page))
}

///|
fn document_info_json(document : @pdfapi.PdfDocument) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{")
  builder.write_string("\"pageCount\":")
  builder.write_string(pdf_page_count_for_json(document).to_string())
  builder.write_string(",\"title\":")
  builder.write_string(json_string_option(document.title()))
  builder.write_string(",\"author\":")
  builder.write_string(json_string_option(document.author()))
  builder.write_string(",\"subject\":")
  builder.write_string(json_string_option(document.subject()))
  builder.write_string(",\"creator\":")
  builder.write_string(json_string_option(document.creator()))
  builder.write_string("}")
  builder.to_string()
}

///|
fn pdf_page_count_for_json(document : @pdfapi.PdfDocument) -> Int {
  let result : Result[Int, @reader.PdfDocumentError] = try? document.page_count()
  match result {
    Ok(count) => count
    Err(_) => -1
  }
}

///|
fn page_geometry_json(page : @pdfapi.PdfPage) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{\"width\":")
  builder.write_string(page.width().to_string())
  builder.write_string(",\"height\":")
  builder.write_string(page.height().to_string())
  builder.write_string(",\"rotation\":")
  builder.write_string(page_rotation(page).to_string())
  builder.write_string("}")
  builder.to_string()
}

///|
fn page_rotation(page : @pdfapi.PdfPage) -> Int {
  let result : Result[Int?, @reader.PdfDocumentError] = try? page
    .reader_page()
    .rotate()
  match result {
    Ok(Some(value)) => positive_mod(value, 360)
    _ => 0
  }
}

///|
fn page_text_positions_json(page : @pdfapi.PdfPage) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{\"texts\":[")
  page_render_texts_json(builder, page)
  builder.write_string("]}")
  builder.to_string()
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
fn page_render_texts_json(
  builder : StringBuilder,
  page : @pdfapi.PdfPage,
) -> Unit {
  let result : Result[@text.TextProgram, @reader.PdfDocumentError] = try? page
    .reader_page()
    .text_program(@reader.TextPageOptions::default())
  match result {
    Ok(program) => {
      let mut written = 0
      for index in 0..<program.spans.length() {
        let span = program.spans[index]
        if span.text.length() > 0 {
          if written > 0 {
            builder.write_string(",")
          }
          page_render_text_json(builder, span)
          written += 1
        }
      }
    }
    Err(_) => ()
  }
}

///|
fn page_render_text_json(
  builder : StringBuilder,
  span : @text.TextSpan,
) -> Unit {
  builder.write_string("{\"text\":")
  builder.write_string(json_string(span.text))
  builder.write_string(",\"x\":")
  builder.write_string(span.text_matrix.e.to_string())
  builder.write_string(",\"y\":")
  builder.write_string(span.text_matrix.f.to_string())
  builder.write_string(",\"fontSize\":")
  builder.write_string(span.font_size.to_string())
  builder.write_string(",\"fontName\":")
  builder.write_string(
    json_string_option(span.font_name.map(fn(name) { name.to_text() })),
  )
  builder.write_string("}")
}

///|
fn page_image_entries(page : @pdfapi.PdfPage) -> Array[PageImageEntry] {
  let resources_result : Result[
    @content.ContentResources,
    @reader.PdfDocumentError,
  ] = try? page.reader_page().materialized_content_resources()
  match resources_result {
    Ok(resources) => page_image_entries_from_resources(resources)
    Err(_) => []
  }
}

///|
fn page_image_entries_from_resources(
  resources : @content.ContentResources,
) -> Array[PageImageEntry] {
  let entries : Array[PageImageEntry] = []
  let result : Result[@objects.PdfObject?, @content.PdfContentError] = try? resources.category_object(
    @content.ResourceCategory::XObject,
  )
  match result {
    Ok(Some(@objects.PdfObject::Dictionary(xobjects))) =>
      collect_xobject_image_entries(xobjects, resources.dictionary, entries)
    _ => ()
  }
  entries
}

///|
fn collect_xobject_image_entries(
  xobjects : @objects.PdfDictionary,
  resources : @objects.PdfDictionary?,
  entries : Array[PageImageEntry],
) -> Unit {
  for name, object in xobjects {
    match object {
      @objects.PdfObject::Stream(stream) if stream_subtype_is(stream, b"Image") =>
        entries.push(PageImageEntry::{ name: Some(name), stream, resources })
      @objects.PdfObject::Stream(stream) if stream_subtype_is(stream, b"Form") =>
        collect_form_image_entries(stream, resources, entries)
      _ => ()
    }
  }
}

///|
fn collect_form_image_entries(
  stream : @objects.PdfStream,
  parent_resources : @objects.PdfDictionary?,
  entries : Array[PageImageEntry],
) -> Unit {
  let resources = match stream.dict.get(@objects.PdfName::new(b"Resources")) {
    Some(@objects.PdfObject::Dictionary(form_resources)) => Some(form_resources)
    _ => parent_resources
  }
  match resources {
    Some(resource_dict) =>
      match resource_dict.get(@objects.PdfName::new(b"XObject")) {
        Some(@objects.PdfObject::Dictionary(xobjects)) =>
          collect_xobject_image_entries(xobjects, resources, entries)
        _ => ()
      }
    None => ()
  }
}

///|
fn page_image_info_json(entry : PageImageEntry) -> String {
  match page_image_descriptor(entry) {
    Some(descriptor) => image_descriptor_json(descriptor)
    None => "{\"error\":\"failed to read image metadata\"}"
  }
}

///|
fn image_descriptor_json(descriptor : @graphics.ImageDescriptor) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{\"width\":")
  builder.write_string(descriptor.width.to_string())
  builder.write_string(",\"height\":")
  builder.write_string(descriptor.height.to_string())
  builder.write_string(",\"colorSpace\":")
  builder.write_string(
    json_string_option(descriptor.color_space.map(colour_space_label)),
  )
  builder.write_string("}")
  builder.to_string()
}

///|
fn page_image_descriptor(entry : PageImageEntry) -> @graphics.ImageDescriptor? {
  let result : Result[@graphics.ImageDescriptor, @graphics.PdfGraphicsError] = try? @graphics.validate_image_stream(
    entry.name,
    prepare_render_image_stream(entry.stream, entry.resources),
    0L,
  )
  match result {
    Ok(descriptor) => Some(descriptor)
    Err(_) => None
  }
}

///|
fn page_image_rgba(entry : PageImageEntry) -> Bytes {
  let result : Result[@graphics.ExtractedImage, @graphics.PdfGraphicsError] = try? @graphics.extract_image_xobject(
    entry.name,
    prepare_render_image_stream(entry.stream, entry.resources),
    0L,
  )
  match result {
    Ok(extracted) => extracted_image_rgba(extracted.data)
    Err(_) => b""
  }
}

///|
fn colour_space_label(space : @graphics.ColourSpace) -> String {
  match space {
    Device(device) =>
      match device {
        DeviceGray => "DeviceGray"
        DeviceRGB => "DeviceRGB"
        DeviceCMYK => "DeviceCMYK"
      }
    CalGray(_) => "CalGray"
    CalRGB(_) => "CalRGB"
    Lab(_) => "Lab"
    ICCBased(_) => "ICCBased"
    Pattern(_) => "Pattern"
    Indexed(_) => "Indexed"
    Separation(_) => "Separation"
    DeviceN(_) => "DeviceN"
  }
}

///|
fn prepare_render_image_stream(
  stream : @objects.PdfStream,
  resources : @objects.PdfDictionary?,
) -> @objects.PdfStream {
  let dict = stream.dict.copy()
  materialize_render_resource_entry(dict, resources, b"ColorSpace")
  @objects.PdfStream::{ dict, data: stream.data }
}

///|
fn materialize_render_resource_entry(
  dict : @objects.PdfDictionary,
  resources : @objects.PdfDictionary?,
  key_bytes : Bytes,
) -> Unit {
  let key = @objects.PdfName::new(key_bytes)
  match (dict.get(key), resources) {
    (Some(@objects.PdfObject::Name(name)), Some(resource_dict)) =>
      match resource_dict.get(key) {
        Some(@objects.PdfObject::Dictionary(named_resources)) =>
          match named_resources.get(name) {
            Some(value) => dict[key] = value
            None => ()
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn stream_subtype_is(stream : @objects.PdfStream, expected : Bytes) -> Bool {
  match stream.dict.get(@objects.PdfName::new(b"Subtype")) {
    Some(@objects.PdfObject::Name(name)) =>
      name == @objects.PdfName::new(expected)
    _ => false
  }
}

///|
fn extracted_image_rgba(data : @graphics.ExtractedImageData) -> Bytes {
  match data {
    DeviceRgbRaster(raster) => raster.rgba
    StencilMaskRaster(mask) => stencil_mask_to_rgba(mask)
    EncodedImageData(data, _) =>
      match decode_external_image_bytes(data) {
        Some(image) => image.data
        None => b""
      }
  }
}

///|
fn stencil_mask_to_rgba(mask : @graphics.ImageAlphaMaskRaster) -> Bytes {
  let rgba : Array[Byte] = []
  for alpha in mask.alpha {
    rgba.push(0x00)
    rgba.push(0x00)
    rgba.push(0x00)
    rgba.push(alpha)
  }
  Bytes::from_array(rgba)
}

///|
fn decode_external_image_bytes(data : Bytes) -> @image.ImageData? {
  match decode_png_image_bytes(data) {
    Some(image) => Some(image)
    None =>
      match decode_bmp_image_bytes(data) {
        Some(image) => Some(image)
        None => decode_jpeg_image_bytes(data)
      }
  }
}

///|
fn decode_png_image_bytes(data : Bytes) -> @image.ImageData? {
  let result : Result[@image.ImageData, @image.DecodeError] = try? @image.decode_png(
    data,
  )
  match result {
    Ok(image) => Some(image)
    Err(_) => None
  }
}

///|
fn decode_bmp_image_bytes(data : Bytes) -> @image.ImageData? {
  let result : Result[@image.ImageData, @image.DecodeError] = try? @image.decode_bmp(
    data,
  )
  match result {
    Ok(image) => Some(image)
    Err(_) => None
  }
}

///|
fn decode_jpeg_image_bytes(data : Bytes) -> @image.ImageData? {
  let result : Result[@image.ImageData, @image.DecodeError] = try? @image.decode_jpeg(
    data,
  )
  match result {
    Ok(image) => Some(image)
    Err(_) => None
  }
}

///|
fn capability_report_json(report : @pdfapi.PdfCapabilityReport) -> String {
  let builder = StringBuilder::new()
  builder.write_string("{\"entries\":[")
  for index in 0..<report.entries.length() {
    if index > 0 {
      builder.write_string(",")
    }
    capability_entry_json(builder, report.entries[index])
  }
  builder.write_string("]}")
  builder.to_string()
}

///|
fn capability_entry_json(
  builder : StringBuilder,
  entry : @pdfapi.PdfCapabilityEntry,
) -> Unit {
  builder.write_string("{\"featureName\":")
  builder.write_string(json_string(entry.feature_name))
  builder.write_string(",\"category\":")
  builder.write_string(json_string(entry.category))
  builder.write_string(",\"status\":")
  builder.write_string(json_string(capability_status_text(entry.status)))
  builder.write_string(",\"description\":")
  builder.write_string(json_string(entry.description))
  builder.write_string("}")
}

///|
fn capability_status_text(status : @pdfapi.PdfCapabilityStatus) -> String {
  match status {
    Supported => "supported"
    Partial => "partial"
    Unsupported => "unsupported"
    Unused => "unused"
  }
}

///|
fn json_string_option(value : String?) -> String {
  match value {
    Some(text) => json_string(text)
    None => "null"
  }
}

///|
fn json_string(value : String) -> String {
  let builder = StringBuilder::new()
  builder.write_char('"')
  for char in value {
    match char {
      '"' => builder.write_string("\\\"")
      '\\' => builder.write_string("\\\\")
      '\n' => builder.write_string("\\n")
      '\r' => builder.write_string("\\r")
      '\t' => builder.write_string("\\t")
      _ => builder.write_char(char)
    }
  }
  builder.write_char('"')
  builder.to_string()
}

///|
fn keep_requested_imports_alive() -> Unit {
  let spans : Array[@text.TextSpan] = []
  @layout.layout_text_spans(spans) |> ignore
  let colour_space : @graphics.ColourSpace? = None
  colour_space |> ignore
  let object_id : @objects.ObjectId? = None
  object_id |> ignore
}

///|
fn main {
  keep_requested_imports_alive()
}
