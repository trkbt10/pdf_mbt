///|
pub(all) struct PixelFormat {
  native_colour_space : NativeColourSpace
  process_colourants : Array[@objects.PdfName]
  spot_colourants : Array[@objects.PdfName]
  bits_per_component : Int
  bytes_per_component : Int
  component_count : Int
} derive(Eq, Debug)

///|
pub(all) struct PixelAddress {
  x : Int
  y : Int
  component : Int
  byte_index : Int
  buffer_offset : Int
} derive(Eq, Debug)

///|
pub(all) struct RasterSurface {
  width : Int
  height : Int
  pixel_format : PixelFormat
  component_buffers : Array[Array[Byte]]
} derive(Eq, Debug)

///|
pub fn PixelFormat::from_device(device : RasterDevice) -> PixelFormat {
  PixelFormat::{
    native_colour_space: device.native_colour_space,
    process_colourants: device.process_colourants.copy(),
    spot_colourants: device.spot_colourants.copy(),
    bits_per_component: device.bits_per_component,
    bytes_per_component: device.bytes_per_component(),
    component_count: device.component_count(),
  }
}

///|
pub fn RasterSurface::allocate(
  device : RasterDevice,
) -> RasterSurface raise PdfRenderingError {
  device.validate()
  let pixel_format = PixelFormat::from_device(device)
  let pixel_count = device.width * device.height
  let buffer_length = pixel_count * pixel_format.bytes_per_component
  let buffers : Array[Array[Byte]] = []
  for _component in 0..<pixel_format.component_count {
    buffers.push(zero_buffer(buffer_length))
  }
  RasterSurface::{
    width: device.width,
    height: device.height,
    pixel_format,
    component_buffers: buffers,
  }
}

///|
pub fn RasterSurface::pixel_address(
  self : RasterSurface,
  x : Int,
  y : Int,
  component : Int,
  byte_index : Int,
) -> PixelAddress raise PdfRenderingError {
  if x < 0 || x >= self.width || y < 0 || y >= self.height {
    raise PdfRenderingError::PixelOutOfBounds(x, y)
  }
  if component < 0 || component >= self.pixel_format.component_count {
    raise PdfRenderingError::InvalidResource(
      "surface component index out of bounds",
    )
  }
  if byte_index < 0 || byte_index >= self.pixel_format.bytes_per_component {
    raise PdfRenderingError::InvalidResource(
      "surface component byte index out of bounds",
    )
  }
  PixelAddress::{
    x,
    y,
    component,
    byte_index,
    buffer_offset: (y * self.width + x) * self.pixel_format.bytes_per_component +
    byte_index,
  }
}

///|
pub fn RasterSurface::write_component_byte(
  self : RasterSurface,
  x : Int,
  y : Int,
  component : Int,
  byte_index : Int,
  value : Byte,
) -> Unit raise PdfRenderingError {
  let address = self.pixel_address(x, y, component, byte_index)
  let buffer = self.component_buffers[component]
  buffer[address.buffer_offset] = value
}

///|
pub fn RasterSurface::read_component_byte(
  self : RasterSurface,
  x : Int,
  y : Int,
  component : Int,
  byte_index : Int,
) -> Byte raise PdfRenderingError {
  let address = self.pixel_address(x, y, component, byte_index)
  self.component_buffers[component][address.buffer_offset]
}

///|
pub fn RasterSurface::component_buffer_length(self : RasterSurface) -> Int {
  if self.component_buffers.length() == 0 {
    0
  } else {
    self.component_buffers[0].length()
  }
}

///|
fn zero_buffer(length : Int) -> Array[Byte] {
  let buffer : Array[Byte] = []
  for _index in 0..<length {
    buffer.push(b'\x00')
  }
  buffer
}
