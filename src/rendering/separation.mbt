///|
pub(all) struct SeparationPlane {
  colourant : @objects.PdfName
  surface : RasterSurface
} derive(Eq, Debug)

///|
pub(all) struct SeparationTarget {
  simulated_device : RasterDevice
  actual_device : RasterDevice
  planes : Array[SeparationPlane]
} derive(Eq, Debug)

///|
pub(all) struct SeparationPaintPolicy {
  overprint : Bool
  preserve_spots : Bool
} derive(Eq, Debug)

///|
pub fn SeparationPaintPolicy::default() -> SeparationPaintPolicy {
  SeparationPaintPolicy::{ overprint: false, preserve_spots: true }
}

///|
pub fn SeparationTarget::allocate(
  simulated_device : RasterDevice,
  actual_device : RasterDevice,
) -> SeparationTarget raise PdfRenderingError {
  simulated_device.validate()
  actual_device.validate()
  let planes : Array[SeparationPlane] = []
  for name in simulated_device.process_colourants {
    planes.push(SeparationPlane::{
      colourant: name,
      surface: single_plane_surface(simulated_device),
    })
  }
  for name in simulated_device.spot_colourants {
    planes.push(SeparationPlane::{
      colourant: name,
      surface: single_plane_surface(simulated_device),
    })
  }
  SeparationTarget::{ simulated_device, actual_device, planes }
}

///|
pub fn SeparationTarget::plane_count(self : SeparationTarget) -> Int {
  self.planes.length()
}

///|
pub fn SeparationTarget::plane_index(
  self : SeparationTarget,
  colourant : @objects.PdfName,
) -> Int? {
  for index in 0..<self.planes.length() {
    if self.planes[index].colourant == colourant {
      return Some(index)
    }
  }
  None
}

///|
pub fn SeparationTarget::paint_colourant(
  self : SeparationTarget,
  colourant : @objects.PdfName,
  x : Int,
  y : Int,
  value : Double,
) -> Unit raise PdfRenderingError {
  match self.plane_index(colourant) {
    Some(index) =>
      self.planes[index].surface.write_component_byte(
        x,
        y,
        0,
        0,
        component_to_separation_byte(value),
      )
    None =>
      raise PdfRenderingError::UnsupportedCapability(
        "separation colourant " + colourant.to_text() + " is not available",
      )
  }
}

///|
pub fn simulate_separations(
  target : SeparationTarget,
) -> RasterSurface raise PdfRenderingError {
  let output = RasterSurface::allocate(target.actual_device)
  for y in 0..<output.height {
    for x in 0..<output.width {
      let mut multiplied = 1.0
      for plane in target.planes {
        let ink = plane.surface
          .read_component_byte(x, y, 0, 0)
          .to_int()
          .to_double() /
          255.0
        multiplied = multiplied * (1.0 - ink)
      }
      let byte = component_to_separation_byte(multiplied)
      for component in 0..<output.pixel_format.component_count {
        output.write_component_byte(x, y, component, 0, byte)
      }
    }
  }
  output
}

///|
fn single_plane_surface(
  device : RasterDevice,
) -> RasterSurface raise PdfRenderingError {
  RasterSurface::allocate(
    RasterDevice::gray(device.width, device.height).with_limits(device.limits),
  )
}

///|
fn component_to_separation_byte(value : Double) -> Byte {
  clamp_int(@math.round(colour_component(value) * 255.0).to_int(), 0, 255).to_byte()
}
