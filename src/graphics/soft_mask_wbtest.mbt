///|
test "SoftMask dictionaries accept direct groups and unresolved references" {
  let source = SoftMaskSource::from_pdf_object(
    @objects.PdfObject::Dictionary(
      soft_mask_dictionary(
        @objects.PdfObject::Stream(soft_mask_group_stream()),
        [0.0, 0.0, 0.0],
      ),
    ),
    30L,
  )
  match source {
    AlphaMask(mask) => {
      assert_eq(mask.subtype == SoftMaskSubtype::AlphaSoftMask, true)
      assert_eq(mask.backdrop_colour, [0.0, 0.0, 0.0])
    }
    _ => fail("expected direct alpha mask")
  }
  let unresolved = SoftMaskSource::from_pdf_object(
    @objects.PdfObject::Ref(@objects.ObjectId::{
      object_number: 7,
      generation_number: 0,
    }),
    31L,
  )
  match unresolved {
    UnresolvedSoftMask(id) => assert_eq(id.object_number, 7)
    _ => fail("expected unresolved soft mask")
  }
}

///|
test "SoftMask transfer functions preserve typed direct and unresolved sources" {
  let direct_dict = soft_mask_dictionary(
    @objects.PdfObject::Stream(soft_mask_group_stream()),
    [0.0, 0.0, 0.0],
  )
  direct_dict[pdf_name(b"TR")] = soft_mask_type2_function()
  match
    SoftMaskSource::from_pdf_object(
      @objects.PdfObject::Dictionary(direct_dict),
      12L,
    ) {
    AlphaMask(mask) =>
      match mask.transfer_function {
        DirectTransferFunction(@functions.FunctionSource::DirectFunction(_)) =>
          ()
        _ => fail("expected direct typed soft-mask transfer function")
      }
    _ => fail("expected alpha soft mask")
  }

  let object_id = @objects.ObjectId::{ object_number: 12, generation_number: 0 }
  let unresolved_dict = soft_mask_dictionary(
    @objects.PdfObject::Stream(soft_mask_group_stream()),
    [0.0, 0.0, 0.0],
  )
  unresolved_dict[pdf_name(b"TR")] = @objects.PdfObject::Ref(object_id)
  match
    SoftMaskSource::from_pdf_object(
      @objects.PdfObject::Dictionary(unresolved_dict),
      13L,
    ) {
    AlphaMask(mask) =>
      match mask.transfer_function {
        UnresolvedTransferFunction(found) => assert_eq(found == object_id, true)
        _ => fail("expected unresolved soft-mask transfer function")
      }
    _ => fail("expected alpha soft mask")
  }

  let invalid_dict = soft_mask_dictionary(
    @objects.PdfObject::Stream(soft_mask_group_stream()),
    [0.0, 0.0, 0.0],
  )
  invalid_dict[pdf_name(b"TR")] = @objects.PdfObject::Dictionary(Map::new())
  let invalid : Result[SoftMaskSource, PdfGraphicsError] = try? SoftMaskSource::from_pdf_object(
    @objects.PdfObject::Dictionary(invalid_dict),
    14L,
  )
  match invalid {
    Err(FunctionFailure(_)) => ()
    _ => fail("expected function-domain failure for soft-mask TR")
  }
}

///|
test "SoftMask rejects malformed dictionaries and backdrop component mismatch" {
  let bad : @objects.PdfDictionary = Map::new()
  bad[pdf_name(b"S")] = @objects.PdfObject::Name(pdf_name(b"Luminosity"))
  bad[pdf_name(b"G")] = @objects.PdfObject::Stream(soft_mask_group_stream())
  bad[pdf_name(b"BC")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(0L),
  ])
  let result : Result[SoftMaskSource, PdfGraphicsError] = try? SoftMaskSource::from_pdf_object(
    @objects.PdfObject::Dictionary(bad),
    32L,
  )
  match result {
    Err(InvalidGraphicsState(offset, reason)) => {
      assert_eq(offset, 32L)
      assert_eq(reason.contains("BC"), true)
    }
    _ => fail("expected invalid BC")
  }
}

///|
test "Image soft masks expose explicit and embedded mask sources" {
  let dict = base_image_dict()
  dict[pdf_name(b"SMask")] = @objects.PdfObject::Stream(
    soft_mask_image_stream(),
  )
  let descriptor = validate_image_dictionary(
    ImageSource::XObjectImage(Some(pdf_name(b"Im"))),
    dict,
    Bytes::from_array([b'\x00', b'\x00', b'\x00']),
    false,
    33L,
  )
  match descriptor.soft_mask.source {
    ExplicitImageSoftMask(_) => ()
    _ => fail("expected explicit image soft mask")
  }
  assert_eq(descriptor.soft_mask.matte, [0.0, 0.0, 0.0])

  let embedded = base_image_dict()
  embedded[pdf_name(b"SMaskInData")] = @objects.PdfObject::Integer(1L)
  let embedded_descriptor = validate_image_dictionary(
    ImageSource::XObjectImage(Some(pdf_name(b"Im"))),
    embedded,
    Bytes::from_array([b'\x00', b'\x00', b'\x00']),
    false,
    34L,
  )
  assert_eq(
    embedded_descriptor.soft_mask.source ==
    ImageSoftMaskSource::EmbeddedImageSoftMask(1),
    true,
  )
}

///|
test "Image soft masks reject nested masks and ImageMask conflicts" {
  let nested_stream = soft_mask_image_stream()
  nested_stream.dict[pdf_name(b"SMaskInData")] = @objects.PdfObject::Integer(1L)
  let dict = base_image_dict()
  dict[pdf_name(b"SMask")] = @objects.PdfObject::Stream(nested_stream)
  let nested : Result[ImageDescriptor, PdfGraphicsError] = try? validate_image_dictionary(
    ImageSource::XObjectImage(Some(pdf_name(b"Im"))),
    dict,
    Bytes::from_array([b'\x00', b'\x00', b'\x00']),
    false,
    35L,
  )
  match nested {
    Err(InvalidImage(offset, reason)) => {
      assert_eq(offset, 35L)
      assert_eq(reason.contains("nested"), true)
    }
    _ => fail("expected nested soft mask image rejection")
  }

  let image_mask = base_image_mask_dict()
  image_mask[pdf_name(b"SMask")] = @objects.PdfObject::Ref(@objects.ObjectId::{
    object_number: 8,
    generation_number: 0,
  })
  let conflict : Result[ImageDescriptor, PdfGraphicsError] = try? validate_image_dictionary(
    ImageSource::XObjectImage(Some(pdf_name(b"Mask"))),
    image_mask,
    Bytes::from_array([b'\x00']),
    false,
    36L,
  )
  match conflict {
    Err(InvalidImage(offset, reason)) => {
      assert_eq(offset, 36L)
      assert_eq(reason.contains("ImageMask"), true)
    }
    _ => fail("expected ImageMask SMask conflict")
  }
}

///|
fn soft_mask_dictionary(
  group : @objects.PdfObject,
  backdrop : Array[Double],
) -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_name(b"S")] = @objects.PdfObject::Name(pdf_name(b"Alpha"))
  dict[pdf_name(b"G")] = group
  let bc : Array[@objects.PdfObject] = []
  for value in backdrop {
    bc.push(@objects.PdfObject::Real(value))
  }
  dict[pdf_name(b"BC")] = @objects.PdfObject::Array(bc)
  dict[pdf_name(b"TR")] = @objects.PdfObject::Name(pdf_name(b"Identity"))
  dict
}

///|
fn soft_mask_type2_function() -> @objects.PdfObject {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_name(b"FunctionType")] = @objects.PdfObject::Integer(2L)
  dict[pdf_name(b"Domain")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(1L),
  ])
  dict[pdf_name(b"C0")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(0L),
  ])
  dict[pdf_name(b"C1")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(1L),
  ])
  dict[pdf_name(b"N")] = @objects.PdfObject::Integer(1L)
  @objects.PdfObject::Dictionary(dict)
}

///|
fn soft_mask_group_stream() -> @objects.PdfStream {
  transparent_form_stream(b"")
}

///|
fn transparent_form_stream(data : Bytes) -> @objects.PdfStream {
  let group : @objects.PdfDictionary = Map::new()
  group[pdf_name(b"Type")] = @objects.PdfObject::Name(pdf_name(b"Group"))
  group[pdf_name(b"S")] = @objects.PdfObject::Name(pdf_name(b"Transparency"))
  group[pdf_name(b"CS")] = @objects.PdfObject::Name(pdf_name(b"DeviceRGB"))
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_name(b"Type")] = @objects.PdfObject::Name(pdf_name(b"XObject"))
  dict[pdf_name(b"Subtype")] = @objects.PdfObject::Name(pdf_name(b"Form"))
  dict[pdf_name(b"BBox")] = @objects.PdfObject::Array([
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(0L),
    @objects.PdfObject::Integer(10L),
    @objects.PdfObject::Integer(10L),
  ])
  dict[pdf_name(b"Group")] = @objects.PdfObject::Dictionary(group)
  @objects.PdfStream::{ dict, data }
}

///|
fn base_image_dict() -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_name(b"Type")] = @objects.PdfObject::Name(pdf_name(b"XObject"))
  dict[pdf_name(b"Subtype")] = @objects.PdfObject::Name(pdf_name(b"Image"))
  dict[pdf_name(b"Width")] = @objects.PdfObject::Integer(1L)
  dict[pdf_name(b"Height")] = @objects.PdfObject::Integer(1L)
  dict[pdf_name(b"ColorSpace")] = @objects.PdfObject::Name(
    pdf_name(b"DeviceRGB"),
  )
  dict[pdf_name(b"BitsPerComponent")] = @objects.PdfObject::Integer(8L)
  dict
}

///|
fn base_image_mask_dict() -> @objects.PdfDictionary {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_name(b"Type")] = @objects.PdfObject::Name(pdf_name(b"XObject"))
  dict[pdf_name(b"Subtype")] = @objects.PdfObject::Name(pdf_name(b"Image"))
  dict[pdf_name(b"Width")] = @objects.PdfObject::Integer(1L)
  dict[pdf_name(b"Height")] = @objects.PdfObject::Integer(1L)
  dict[pdf_name(b"ImageMask")] = @objects.PdfObject::Boolean(true)
  dict[pdf_name(b"BitsPerComponent")] = @objects.PdfObject::Integer(1L)
  dict
}

///|
fn soft_mask_image_stream() -> @objects.PdfStream {
  let dict : @objects.PdfDictionary = Map::new()
  dict[pdf_name(b"Type")] = @objects.PdfObject::Name(pdf_name(b"XObject"))
  dict[pdf_name(b"Subtype")] = @objects.PdfObject::Name(pdf_name(b"Image"))
  dict[pdf_name(b"Width")] = @objects.PdfObject::Integer(1L)
  dict[pdf_name(b"Height")] = @objects.PdfObject::Integer(1L)
  dict[pdf_name(b"ColorSpace")] = @objects.PdfObject::Name(
    pdf_name(b"DeviceGray"),
  )
  dict[pdf_name(b"BitsPerComponent")] = @objects.PdfObject::Integer(8L)
  dict[pdf_name(b"Matte")] = @objects.PdfObject::Array([
    @objects.PdfObject::Real(0.0),
    @objects.PdfObject::Real(0.0),
    @objects.PdfObject::Real(0.0),
  ])
  @objects.PdfStream::{ dict, data: Bytes::from_array([b'\x00']) }
}
