///|
pub(all) enum NativeColourSpace {
  NativeGray
  NativeRGB
  NativeCMYK
} derive(Eq, Debug)

///|
pub(all) enum OutputProfileRef {
  DirectOutputProfile(@objects.PdfObject)
  IndirectOutputProfile(@objects.ObjectId)
} derive(Eq, Debug)

///|
pub(all) enum TransferFunctionRef {
  IdentityTransfer
  DirectTransfer(@functions.FunctionSource)
  IndirectTransfer(@objects.ObjectId)
} derive(Eq, Debug)

///|
pub(all) enum HalftoneRef {
  DefaultHalftone
  DirectHalftone(@objects.PdfObject)
  IndirectHalftone(@objects.ObjectId)
} derive(Eq, Debug)

///|
/// Guard rails that keep rendering allocation and provider work bounded.
pub(all) struct RenderLimits {
  max_width : Int
  max_height : Int
  max_surface_bytes : Int
  max_process_colourants : Int
  max_spot_colourants : Int
  max_bits_per_component : Int
  max_threshold_bytes : Int
  max_path_segments : Int
  max_halftone_cell_pixels : Int
  max_provider_cache_entries : Int
} derive(Eq, Debug)

///|
pub(all) struct RasterDevice {
  width : Int
  height : Int
  resolution_x : Double
  resolution_y : Double
  native_colour_space : NativeColourSpace
  process_colourants : Array[@objects.PdfName]
  spot_colourants : Array[@objects.PdfName]
  continuous_tone : Bool
  bits_per_component : Int
  output_profile : OutputProfileRef?
  default_transfer : TransferFunctionRef?
  default_halftone : HalftoneRef?
  limits : RenderLimits
} derive(Eq, Debug)

///|
pub fn RenderLimits::default() -> RenderLimits {
  RenderLimits::{
    max_width: 10000,
    max_height: 10000,
    max_surface_bytes: 268435456,
    max_process_colourants: 4,
    max_spot_colourants: 32,
    max_bits_per_component: 16,
    max_threshold_bytes: 16777216,
    max_path_segments: 1000000,
    max_halftone_cell_pixels: 1048576,
    max_provider_cache_entries: 4096,
  }
}

///|
pub fn NativeColourSpace::component_count(self : NativeColourSpace) -> Int {
  match self {
    NativeGray => 1
    NativeRGB => 3
    NativeCMYK => 4
  }
}

///|
pub fn NativeColourSpace::default_process_colourants(
  self : NativeColourSpace,
) -> Array[@objects.PdfName] {
  match self {
    NativeGray => [pdf_name(b"Gray")]
    NativeRGB => [pdf_name(b"Red"), pdf_name(b"Green"), pdf_name(b"Blue")]
    NativeCMYK =>
      [
        pdf_name(b"Cyan"),
        pdf_name(b"Magenta"),
        pdf_name(b"Yellow"),
        pdf_name(b"Black"),
      ]
  }
}

///|
pub fn RasterDevice::new(
  width : Int,
  height : Int,
  native_colour_space : NativeColourSpace,
) -> RasterDevice {
  RasterDevice::{
    width,
    height,
    resolution_x: 72.0,
    resolution_y: 72.0,
    native_colour_space,
    process_colourants: native_colour_space.default_process_colourants(),
    spot_colourants: [],
    continuous_tone: true,
    bits_per_component: 8,
    output_profile: None,
    default_transfer: Some(TransferFunctionRef::IdentityTransfer),
    default_halftone: None,
    limits: RenderLimits::default(),
  }
}

///|
pub fn RasterDevice::gray(width : Int, height : Int) -> RasterDevice {
  RasterDevice::new(width, height, NativeColourSpace::NativeGray)
}

///|
pub fn RasterDevice::rgb(width : Int, height : Int) -> RasterDevice {
  RasterDevice::new(width, height, NativeColourSpace::NativeRGB)
}

///|
pub fn RasterDevice::cmyk(width : Int, height : Int) -> RasterDevice {
  RasterDevice::new(width, height, NativeColourSpace::NativeCMYK)
}

///|
pub fn RasterDevice::with_resolution(
  self : RasterDevice,
  resolution_x : Double,
  resolution_y : Double,
) -> RasterDevice {
  RasterDevice::{
    width: self.width,
    height: self.height,
    resolution_x,
    resolution_y,
    native_colour_space: self.native_colour_space,
    process_colourants: self.process_colourants.copy(),
    spot_colourants: self.spot_colourants.copy(),
    continuous_tone: self.continuous_tone,
    bits_per_component: self.bits_per_component,
    output_profile: self.output_profile,
    default_transfer: self.default_transfer,
    default_halftone: self.default_halftone,
    limits: self.limits,
  }
}

///|
pub fn RasterDevice::with_bits_per_component(
  self : RasterDevice,
  bits_per_component : Int,
) -> RasterDevice {
  RasterDevice::{
    width: self.width,
    height: self.height,
    resolution_x: self.resolution_x,
    resolution_y: self.resolution_y,
    native_colour_space: self.native_colour_space,
    process_colourants: self.process_colourants.copy(),
    spot_colourants: self.spot_colourants.copy(),
    continuous_tone: self.continuous_tone,
    bits_per_component,
    output_profile: self.output_profile,
    default_transfer: self.default_transfer,
    default_halftone: self.default_halftone,
    limits: self.limits,
  }
}

///|
pub fn RasterDevice::with_spot_colourants(
  self : RasterDevice,
  spot_colourants : Array[@objects.PdfName],
) -> RasterDevice {
  RasterDevice::{
    width: self.width,
    height: self.height,
    resolution_x: self.resolution_x,
    resolution_y: self.resolution_y,
    native_colour_space: self.native_colour_space,
    process_colourants: self.process_colourants.copy(),
    spot_colourants: spot_colourants.copy(),
    continuous_tone: self.continuous_tone,
    bits_per_component: self.bits_per_component,
    output_profile: self.output_profile,
    default_transfer: self.default_transfer,
    default_halftone: self.default_halftone,
    limits: self.limits,
  }
}

///|
pub fn RasterDevice::with_process_colourants(
  self : RasterDevice,
  process_colourants : Array[@objects.PdfName],
) -> RasterDevice {
  RasterDevice::{
    width: self.width,
    height: self.height,
    resolution_x: self.resolution_x,
    resolution_y: self.resolution_y,
    native_colour_space: self.native_colour_space,
    process_colourants: process_colourants.copy(),
    spot_colourants: self.spot_colourants.copy(),
    continuous_tone: self.continuous_tone,
    bits_per_component: self.bits_per_component,
    output_profile: self.output_profile,
    default_transfer: self.default_transfer,
    default_halftone: self.default_halftone,
    limits: self.limits,
  }
}

///|
pub fn RasterDevice::with_limits(
  self : RasterDevice,
  limits : RenderLimits,
) -> RasterDevice {
  RasterDevice::{
    width: self.width,
    height: self.height,
    resolution_x: self.resolution_x,
    resolution_y: self.resolution_y,
    native_colour_space: self.native_colour_space,
    process_colourants: self.process_colourants.copy(),
    spot_colourants: self.spot_colourants.copy(),
    continuous_tone: self.continuous_tone,
    bits_per_component: self.bits_per_component,
    output_profile: self.output_profile,
    default_transfer: self.default_transfer,
    default_halftone: self.default_halftone,
    limits,
  }
}

///|
pub fn RasterDevice::component_count(self : RasterDevice) -> Int {
  self.process_colourants.length() + self.spot_colourants.length()
}

///|
pub fn RasterDevice::bytes_per_component(self : RasterDevice) -> Int {
  bytes_for_bits(self.bits_per_component)
}

///|
/// Parses a rendering transfer function reference into a typed function source
/// when the object is already direct, while preserving indirect references for
/// reader-owned materialization. Rendering evaluates only typed direct transfer
/// functions at the raster boundary and does not resolve document objects.
pub fn TransferFunctionRef::from_object(
  object : @objects.PdfObject,
  limits? : @functions.FunctionLimits = @functions.FunctionLimits::default(),
  offset? : Int64 = 0L,
) -> TransferFunctionRef raise PdfRenderingError {
  match object {
    @objects.PdfObject::Name(name) =>
      if name == pdf_name(b"Identity") {
        IdentityTransfer
      } else {
        raise PdfRenderingError::UnsupportedCapability(
          "unsupported named transfer function",
        )
      }
    @objects.PdfObject::Ref(object_id) => IndirectTransfer(object_id)
    _ =>
      DirectTransfer(
        try @functions.parse_function_object(object, limits, offset) catch {
          _ =>
            raise PdfRenderingError::ProviderFailure(
              "transfer function", "typed direct transfer function could not be parsed",
            )
        } noraise {
          source => source
        },
      )
  }
}

///|
/// Applies a rendering transfer function to one component. Indirect transfer
/// references must be materialized before rendering, keeping object loading out
/// of the raster policy layer.
pub fn TransferFunctionRef::apply_component(
  self : TransferFunctionRef,
  component : Double,
  limits? : @functions.FunctionLimits = @functions.FunctionLimits::default(),
) -> Double raise PdfRenderingError {
  match self {
    IdentityTransfer => colour_component(component)
    DirectTransfer(source) => {
      let output = try
        @functions.evaluate_function_source(
          source,
          [colour_component(component)],
          limits,
        )
      catch {
        _ =>
          raise PdfRenderingError::ProviderFailure(
            "transfer function", "typed direct transfer function could not be evaluated",
          )
      } noraise {
        value => value
      }
      if output.length() != 1 {
        raise PdfRenderingError::ProviderFailure(
          "transfer function", "typed direct transfer function must return one component",
        )
      }
      colour_component(output[0])
    }
    IndirectTransfer(_) =>
      raise PdfRenderingError::ProviderFailure(
        "transfer function", "indirect transfer function must be materialized before rendering",
      )
  }
}

///|
pub fn RasterDevice::apply_default_transfer(
  self : RasterDevice,
  component : Double,
) -> Double raise PdfRenderingError {
  match self.default_transfer {
    Some(transfer) => transfer.apply_component(component)
    None => colour_component(component)
  }
}

///|
pub fn RasterDevice::surface_byte_count(self : RasterDevice) -> Int {
  self.width * self.height * self.component_count() * self.bytes_per_component()
}

///|
pub fn RasterDevice::validate(
  self : RasterDevice,
) -> Unit raise PdfRenderingError {
  validate_limits(self.limits)
  if self.width <= 0 {
    raise PdfRenderingError::InvalidDevice("raster width must be positive")
  }
  if self.height <= 0 {
    raise PdfRenderingError::InvalidDevice("raster height must be positive")
  }
  if self.width > self.limits.max_width {
    raise PdfRenderingError::LimitExceeded(
      "width",
      self.width,
      self.limits.max_width,
    )
  }
  if self.height > self.limits.max_height {
    raise PdfRenderingError::LimitExceeded(
      "height",
      self.height,
      self.limits.max_height,
    )
  }
  if !valid_positive_double(self.resolution_x) {
    raise PdfRenderingError::InvalidDevice("x resolution must be positive")
  }
  if !valid_positive_double(self.resolution_y) {
    raise PdfRenderingError::InvalidDevice("y resolution must be positive")
  }
  validate_bits_per_component(self.bits_per_component, self.limits)
  let expected = self.native_colour_space.component_count()
  if self.process_colourants.length() != expected {
    raise PdfRenderingError::InvalidDevice(
      "process colourant count must match native colour space",
    )
  }
  if self.process_colourants.length() > self.limits.max_process_colourants {
    raise PdfRenderingError::LimitExceeded(
      "process colourants",
      self.process_colourants.length(),
      self.limits.max_process_colourants,
    )
  }
  if self.spot_colourants.length() > self.limits.max_spot_colourants {
    raise PdfRenderingError::LimitExceeded(
      "spot colourants",
      self.spot_colourants.length(),
      self.limits.max_spot_colourants,
    )
  }
  validate_no_duplicate_colourants(
    self.process_colourants,
    self.spot_colourants,
  )
  let byte_count = self.surface_byte_count()
  if byte_count > self.limits.max_surface_bytes {
    raise PdfRenderingError::LimitExceeded(
      "surface bytes",
      byte_count,
      self.limits.max_surface_bytes,
    )
  }
}

///|
fn validate_limits(limits : RenderLimits) -> Unit raise PdfRenderingError {
  if limits.max_width <= 0 {
    raise PdfRenderingError::InvalidDevice("max_width limit must be positive")
  }
  if limits.max_height <= 0 {
    raise PdfRenderingError::InvalidDevice("max_height limit must be positive")
  }
  if limits.max_surface_bytes <= 0 {
    raise PdfRenderingError::InvalidDevice(
      "max_surface_bytes limit must be positive",
    )
  }
  if limits.max_process_colourants <= 0 {
    raise PdfRenderingError::InvalidDevice(
      "max_process_colourants limit must be positive",
    )
  }
  if limits.max_spot_colourants < 0 {
    raise PdfRenderingError::InvalidDevice(
      "max_spot_colourants limit must be nonnegative",
    )
  }
  if limits.max_bits_per_component <= 0 {
    raise PdfRenderingError::InvalidDevice(
      "max_bits_per_component limit must be positive",
    )
  }
  if limits.max_threshold_bytes <= 0 {
    raise PdfRenderingError::InvalidDevice(
      "max_threshold_bytes limit must be positive",
    )
  }
  if limits.max_path_segments <= 0 {
    raise PdfRenderingError::InvalidDevice(
      "max_path_segments limit must be positive",
    )
  }
  if limits.max_halftone_cell_pixels <= 0 {
    raise PdfRenderingError::InvalidDevice(
      "max_halftone_cell_pixels limit must be positive",
    )
  }
  if limits.max_provider_cache_entries <= 0 {
    raise PdfRenderingError::InvalidDevice(
      "max_provider_cache_entries limit must be positive",
    )
  }
}

///|
fn validate_bits_per_component(
  bits_per_component : Int,
  limits : RenderLimits,
) -> Unit raise PdfRenderingError {
  if bits_per_component <= 0 {
    raise PdfRenderingError::InvalidDevice(
      "bits per component must be positive",
    )
  }
  if bits_per_component > limits.max_bits_per_component {
    raise PdfRenderingError::LimitExceeded(
      "bits per component",
      bits_per_component,
      limits.max_bits_per_component,
    )
  }
  if !(bits_per_component == 1 ||
    bits_per_component == 2 ||
    bits_per_component == 4 ||
    bits_per_component == 8 ||
    bits_per_component == 16) {
    raise PdfRenderingError::InvalidDevice(
      "bits per component must be one of 1, 2, 4, 8, or 16",
    )
  }
}

///|
fn validate_no_duplicate_colourants(
  process_colourants : Array[@objects.PdfName],
  spot_colourants : Array[@objects.PdfName],
) -> Unit raise PdfRenderingError {
  validate_unique_names(process_colourants, "process colourants")
  validate_unique_names(spot_colourants, "spot colourants")
  for process in process_colourants {
    for spot in spot_colourants {
      if process == spot {
        raise PdfRenderingError::InvalidDevice(
          "spot colourant duplicates a process colourant",
        )
      }
    }
  }
}

///|
fn validate_unique_names(
  names : Array[@objects.PdfName],
  label : String,
) -> Unit raise PdfRenderingError {
  for i in 0..<names.length() {
    for j in (i + 1)..<names.length() {
      if names[i] == names[j] {
        raise PdfRenderingError::InvalidDevice(label + " must be unique")
      }
    }
  }
}

///|
fn bytes_for_bits(bits : Int) -> Int {
  if bits <= 8 {
    1
  } else {
    2
  }
}

///|
fn valid_positive_double(value : Double) -> Bool {
  value > 0.0 && value == value
}

///|
fn pdf_name(bytes : Bytes) -> @objects.PdfName {
  @objects.PdfName::new(bytes)
}
