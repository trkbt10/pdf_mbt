///|
test "ImageParams computes row-padded decoded byte length" {
  let params = ImageParams::{
    width: 3,
    height: 2,
    bits_per_component: 1,
    component_count: 1,
    image_mask: false,
  }

  assert_eq(params.expected_data_length(), 2)
}

///|
test "ImageParams unpacks row-aligned low-bit samples" {
  let params = ImageParams::{
    width: 3,
    height: 2,
    bits_per_component: 1,
    component_count: 1,
    image_mask: false,
  }
  let samples = params.unpack_samples(
    Bytes::from_array([0b10100000, 0b01000000]),
  )

  assert_eq(samples, [1, 0, 1, 0, 1, 0])
}

///|
test "ImageParams applies Decode pairs by component" {
  let params = ImageParams::{
    width: 2,
    height: 1,
    bits_per_component: 8,
    component_count: 2,
    image_mask: false,
  }
  let decoded = params.apply_decode_array([0, 255, 255, 0], [0.0, 1.0, 1.0, 0.0])

  assert_eq(decoded, [0.0, 0.0, 1.0, 1.0])
}

///|
test "ImageParams identifies stencil masks" {
  let stencil = ImageParams::{
    width: 2,
    height: 2,
    bits_per_component: 1,
    component_count: 1,
    image_mask: true,
  }
  let colour_image = ImageParams::{
    width: 2,
    height: 2,
    bits_per_component: 8,
    component_count: 3,
    image_mask: false,
  }

  assert_eq(stencil.is_stencil_mask(), true)
  assert_eq(colour_image.is_stencil_mask(), false)
}
