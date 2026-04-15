///|
/// Defines the `pdf images [options] <input.pdf> <output-prefix>` subcommand
/// with page range options, `--raw` JPEG passthrough, and `--list` metadata
/// mode for image width, height, colour space, bits per component, and filters.
pub fn images_command() -> @argparse.Command {
  @argparse.Command(
    "images",
    about="Extract image XObjects.",
    flags=[
      @argparse.FlagArg(
        "raw",
        long="raw",
        about="Write raw JPEG bytes for DCTDecode images.",
      ),
      @argparse.FlagArg(
        "list",
        long="list",
        about="List image metadata without extracting files.",
      ),
    ],
    options=[
      common_first_page_option(),
      common_last_page_option(),
      common_password_option(),
    ],
    positionals=[
      input_pdf_arg(),
      @argparse.PositionArg(
        "prefix",
        about="Output file prefix.",
        num_args=@argparse.ValueRange::single(),
      ),
    ],
  )
}

///|
/// Implements the pdfimages-equivalent images subcommand. It enumerates image
/// XObjects, writes decoded PPM P6 files named `<prefix>-<page>-<index>.ppm`,
/// optionally writes raw DCTDecode JPEG bytes as `.jpg`, or lists image
/// metadata without extraction.
pub fn run_images(matches : @argparse.Matches) -> Unit raise {
  let input = required_value(matches, "input")
  let prefix = required_value(matches, "prefix")
  let (file, document, _) = open_file_and_document(input)
  let range = page_range(matches, document.page_count())
  if flag_is_set(matches, "list") {
    println("page index name width height color bpc filters")
  }
  let (first, last) = range
  if first <= last {
    for page_index in (first - 1)..<last {
      extract_page_images(
        file,
        document.page(page_index),
        page_index + 1,
        prefix,
        raw=flag_is_set(matches, "raw"),
        list=flag_is_set(matches, "list"),
      )
    }
  }
}

///|
fn extract_page_images(
  file : @reader.PdfFile,
  page : @reader.PdfPage,
  page_number : Int,
  prefix : String,
  raw~ : Bool,
  list~ : Bool,
) -> Unit raise {
  match resolve_optional_pdf_object(file, page.resources()) {
    Some(@objects.PdfObject::Dictionary(resources)) =>
      match resources.get(@objects.PdfName::new(b"XObject")) {
        Some(object) =>
          match resolve_pdf_object(file, object) {
            @objects.PdfObject::Dictionary(xobjects) => {
              let mut index = 1
              for name, value in xobjects {
                match resolve_pdf_object(file, value) {
                  @objects.PdfObject::Stream(stream) if stream_is_image_xobject(
                      stream,
                    ) => {
                    let materialized = materialize_image_stream(file, stream)
                    let extracted = @graphics.extract_image_xobject(
                      Some(name),
                      materialized,
                      0L,
                    )
                    if list {
                      print_image_row(page_number, index, name, extracted)
                    } else {
                      write_image(
                        prefix,
                        page_number,
                        index,
                        materialized,
                        extracted,
                        raw~,
                      )
                    }
                    index += 1
                  }
                  _ => ()
                }
              }
            }
            @objects.PdfObject::Null => ()
            _ =>
              raise CliError::Message("XObject resources must be a dictionary")
          }
        None => ()
      }
    Some(@objects.PdfObject::Null) | None => ()
    Some(_) => raise CliError::Message("page Resources must be a dictionary")
  }
}

///|
fn print_image_row(
  page_number : Int,
  index : Int,
  name : @objects.PdfName,
  image : @graphics.ExtractedImage,
) -> Unit {
  println(
    page_number.to_string() +
    " " +
    index.to_string() +
    " " +
    name.to_text() +
    " " +
    image.descriptor.width.to_string() +
    " " +
    image.descriptor.height.to_string() +
    " " +
    colour_space_text(image.descriptor.color_space) +
    " " +
    bits_per_component_text(image.descriptor.bits_per_component) +
    " " +
    filter_list_text(image.descriptor.filters),
  )
}

///|
fn write_image(
  prefix : String,
  page_number : Int,
  index : Int,
  stream : @objects.PdfStream,
  image : @graphics.ExtractedImage,
  raw~ : Bool,
) -> Unit raise {
  let base = prefix + "-" + page_number.to_string() + "-" + index.to_string()
  if raw && has_filter(image.descriptor.filters, b"DCTDecode") {
    let bytes = match image.data {
      EncodedImageData(data, _) => data
      _ => stream.data
    }
    @fs.write_bytes_to_file(base + ".jpg", bytes)
    return
  }
  match image.data {
    DeviceRgbRaster(raster) =>
      @fs.write_bytes_to_file(base + ".ppm", ppm_from_rgba(raster))
    StencilMaskRaster(raster) =>
      @fs.write_bytes_to_file(base + ".ppm", ppm_from_alpha(raster))
    EncodedImageData(_, filters) =>
      raise CliError::Message(
        "image " +
        base +
        " has unsupported encoded filters: " +
        filter_list_text(filters),
      )
  }
}

///|
fn ppm_from_rgba(raster : @graphics.ImageDeviceRgbRaster) -> Bytes {
  let pixels = raster.width * raster.height
  let buffer = @buffer.new(size_hint=32 + pixels * 3)
  buffer.write_bytes(
    @utf8.encode(
      "P6\n" +
      raster.width.to_string() +
      " " +
      raster.height.to_string() +
      "\n255\n",
    ),
  )
  for pixel in 0..<pixels {
    let offset = pixel * 4
    buffer.write_byte(raster.rgba[offset])
    buffer.write_byte(raster.rgba[offset + 1])
    buffer.write_byte(raster.rgba[offset + 2])
  }
  buffer.to_bytes()
}

///|
fn ppm_from_alpha(raster : @graphics.ImageAlphaMaskRaster) -> Bytes {
  let pixels = raster.width * raster.height
  let buffer = @buffer.new(size_hint=32 + pixels * 3)
  buffer.write_bytes(
    @utf8.encode(
      "P6\n" +
      raster.width.to_string() +
      " " +
      raster.height.to_string() +
      "\n255\n",
    ),
  )
  for pixel in 0..<pixels {
    let value = raster.alpha[pixel]
    buffer.write_byte(value)
    buffer.write_byte(value)
    buffer.write_byte(value)
  }
  buffer.to_bytes()
}

///|
fn resolve_optional_pdf_object(
  file : @reader.PdfFile,
  object : @objects.PdfObject?,
) -> @objects.PdfObject? raise {
  match object {
    Some(value) => Some(resolve_pdf_object(file, value))
    None => None
  }
}

///|
fn resolve_pdf_object(
  file : @reader.PdfFile,
  object : @objects.PdfObject,
) -> @objects.PdfObject raise {
  match object {
    @objects.PdfObject::Ref(id) =>
      try file.load_object(id) catch {
        _ => raise CliError::Message("failed to load PDF object")
      } noraise {
        value => value
      }
    _ => object
  }
}

///|
fn resolve_nested_pdf_object(
  file : @reader.PdfFile,
  object : @objects.PdfObject,
) -> @objects.PdfObject raise {
  match object {
    @objects.PdfObject::Ref(id) =>
      resolve_nested_pdf_object(
        file,
        resolve_pdf_object(file, @objects.PdfObject::Ref(id)),
      )
    @objects.PdfObject::Array(values) => {
      let resolved : Array[@objects.PdfObject] = []
      for value in values {
        resolved.push(resolve_nested_pdf_object(file, value))
      }
      @objects.PdfObject::Array(resolved)
    }
    @objects.PdfObject::Dictionary(dict) => {
      let resolved : @objects.PdfDictionary = Map::new()
      for key, value in dict {
        resolved[key] = resolve_nested_pdf_object(file, value)
      }
      @objects.PdfObject::Dictionary(resolved)
    }
    @objects.PdfObject::Stream(stream) =>
      @objects.PdfObject::Stream(materialize_image_stream(file, stream))
    _ => object
  }
}

///|
fn materialize_image_stream(
  file : @reader.PdfFile,
  stream : @objects.PdfStream,
) -> @objects.PdfStream raise {
  let dict = stream.dict.copy()
  materialize_image_entry(file, dict, b"ColorSpace")
  materialize_image_entry(file, dict, b"Mask")
  materialize_image_entry(file, dict, b"SMask")
  @objects.PdfStream::{ dict, data: stream.data }
}

///|
fn materialize_image_entry(
  file : @reader.PdfFile,
  dict : @objects.PdfDictionary,
  key_bytes : Bytes,
) -> Unit raise {
  let key = @objects.PdfName::new(key_bytes)
  match dict.get(key) {
    Some(value) => dict[key] = resolve_nested_pdf_object(file, value)
    None => ()
  }
}

///|
fn stream_is_image_xobject(stream : @objects.PdfStream) -> Bool {
  match stream.dict.get(@objects.PdfName::new(b"Subtype")) {
    Some(@objects.PdfObject::Name(name)) =>
      name == @objects.PdfName::new(b"Image")
    _ => false
  }
}

///|
fn has_filter(filters : Array[@objects.PdfName], expected : Bytes) -> Bool {
  let expected_name = @objects.PdfName::new(expected)
  for filter in filters {
    if filter == expected_name {
      return true
    }
  }
  false
}

///|
fn filter_list_text(filters : Array[@objects.PdfName]) -> String {
  if filters.length() == 0 {
    return "-"
  }
  let out = StringBuilder::new()
  for index, filter in filters.iter2() {
    if index > 0 {
      out.write_string(",")
    }
    out.write_string(filter.to_text())
  }
  out.to_string()
}

///|
fn bits_per_component_text(value : Int?) -> String {
  match value {
    Some(bits) => bits.to_string()
    None => "-"
  }
}

///|
fn colour_space_text(value : @graphics.ColourSpace?) -> String {
  match value {
    Some(Device(DeviceGray)) => "DeviceGray"
    Some(Device(DeviceRGB)) => "DeviceRGB"
    Some(Device(DeviceCMYK)) => "DeviceCMYK"
    Some(CalGray(_)) => "CalGray"
    Some(CalRGB(_)) => "CalRGB"
    Some(Lab(_)) => "Lab"
    Some(ICCBased(_)) => "ICCBased"
    Some(Pattern(_)) => "Pattern"
    Some(Indexed(_)) => "Indexed"
    Some(Separation(_)) => "Separation"
    Some(DeviceN(_)) => "DeviceN"
    None => "-"
  }
}
