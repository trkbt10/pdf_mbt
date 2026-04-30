///|
/// Validation summary for Type 4 and Type 5 Gouraud-shaded triangle mesh
/// streams after decoding packed vertex records.
pub(all) struct MeshSummary {
  vertex_count : Int
  triangle_count : Int
  decoded_length : Int
} derive(Eq, Debug)

///|
/// Validation summary for Type 6 Coons patch mesh and Type 7 tensor-product
/// patch mesh streams after decoding Table 83 or Table 85 patch records.
pub(all) struct PatchMeshSummary {
  patch_count : Int
  decoded_length : Int
} derive(Eq, Debug)

///|
/// Reports whether decoded mesh data contains at least one triangle.
pub fn MeshSummary::has_renderable_triangles(self : MeshSummary) -> Bool {
  if self.vertex_count < 3 {
    false
  } else if self.triangle_count <= 0 {
    false
  } else {
    self.decoded_length > 0
  }
}

///|
struct MsbBitReader {
  data : Bytes
  mut bit_position : Int
} derive(Eq, Debug)

///|
fn MsbBitReader::new(data : Bytes) -> MsbBitReader {
  MsbBitReader::{ data, bit_position: 0 }
}

///|
fn MsbBitReader::remaining_bits(self : MsbBitReader) -> Int {
  self.data.length() * 8 - self.bit_position
}

///|
fn MsbBitReader::read_bits(
  self : MsbBitReader,
  count : Int,
  offset : Int64,
) -> Int64 raise PdfGraphicsError {
  if count < 0 || count > 62 {
    raise graphics_resource_error(offset, "mesh bit count is out of range")
  }
  if self.remaining_bits() < count {
    raise graphics_resource_error(offset, "truncated mesh shading stream")
  }
  let mut value = 0L
  for _ in 0..<count {
    let byte_index = self.bit_position / 8
    let bit_index = 7 - self.bit_position % 8
    let bit = (self.data[byte_index].to_int() >> bit_index) & 1
    value = (value << 1) | bit.to_int64()
    self.bit_position = self.bit_position + 1
  }
  value
}

///|
fn MsbBitReader::skip_bits(
  self : MsbBitReader,
  count : Int,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  self.read_bits(count, offset) |> ignore
}

///|
fn MsbBitReader::align_to_byte(self : MsbBitReader) -> Unit {
  let rest = self.bit_position % 8
  if rest != 0 {
    self.bit_position = self.bit_position + (8 - rest)
  }
}

///|
fn parse_mesh_shading_kind(
  shading_type : Int64,
  dict : @objects.PdfDictionary,
  stream : @objects.PdfStream,
  space : ColourSpace,
  function : @functions.FunctionSource?,
  offset : Int64,
) -> ShadingKind raise PdfGraphicsError {
  let params = parse_mesh_common(dict, stream, space, function, offset)
  if shading_type == 4L {
    ShadingKind::FreeFormMesh(FreeFormMeshShading::{
      bits_per_coordinate: params.bits_per_coordinate,
      bits_per_component: params.bits_per_component,
      bits_per_flag: params.bits_per_flag,
      decode: params.decode.copy(),
      function,
      summary: validate_type4_mesh(params, offset),
    })
  } else if shading_type == 5L {
    let vertices_per_row = require_positive_mesh_int(
      dict, b"VerticesPerRow", offset, "VerticesPerRow",
    )
    if vertices_per_row < 2 {
      raise graphics_resource_error(offset, "VerticesPerRow must be at least 2")
    }
    ShadingKind::LatticeMesh(LatticeMeshShading::{
      bits_per_coordinate: params.bits_per_coordinate,
      bits_per_component: params.bits_per_component,
      vertices_per_row,
      decode: params.decode.copy(),
      function,
      summary: validate_type5_mesh(params, vertices_per_row, offset),
    })
  } else if shading_type == 6L {
    ShadingKind::CoonsPatchMesh(CoonsPatchMeshShading::{
      bits_per_coordinate: params.bits_per_coordinate,
      bits_per_component: params.bits_per_component,
      bits_per_flag: params.bits_per_flag,
      decode: params.decode.copy(),
      function,
      summary: validate_patch_mesh(params, false, offset),
    })
  } else {
    ShadingKind::TensorPatchMesh(TensorPatchMeshShading::{
      bits_per_coordinate: params.bits_per_coordinate,
      bits_per_component: params.bits_per_component,
      bits_per_flag: params.bits_per_flag,
      decode: params.decode.copy(),
      function,
      summary: validate_patch_mesh(params, true, offset),
    })
  }
}

///|
struct MeshCommonParams {
  bits_per_coordinate : Int
  bits_per_component : Int
  bits_per_flag : Int
  colour_value_count : Int
  decode : Array[Double]
  decoded : Bytes
} derive(Eq, Debug)

///|
fn parse_mesh_common(
  dict : @objects.PdfDictionary,
  stream : @objects.PdfStream,
  space : ColourSpace,
  function : @functions.FunctionSource?,
  offset : Int64,
) -> MeshCommonParams raise PdfGraphicsError {
  let bpc = require_positive_mesh_int(
    dict, b"BitsPerCoordinate", offset, "BitsPerCoordinate",
  )
  validate_coordinate_bits(bpc, offset)
  let bpcomp = require_positive_mesh_int(
    dict, b"BitsPerComponent", offset, "BitsPerComponent",
  )
  validate_component_bits(bpcomp, offset)
  let bpf = require_positive_mesh_int(
    dict, b"BitsPerFlag", offset, "BitsPerFlag",
  )
  validate_flag_bits(bpf, offset)
  let colour_value_count = match function {
    Some(_) => 1
    None => {
      let count = space.component_count()
      if count <= 0 || count > 32 {
        raise graphics_resource_error(
          offset, "mesh colour component count is out of range",
        )
      }
      count
    }
  }
  let decode = require_number_array_value(
    required_entry(dict, b"Decode", offset),
    4 + colour_value_count * 2,
    offset,
    "Decode",
  )
  validate_decode_pairs(decode, offset)
  let decoded = try @filters.decode_stream(stream) catch {
    error => raise map_filter_error(offset, "shading mesh", error)
  } noraise {
    bytes => bytes
  }
  MeshCommonParams::{
    bits_per_coordinate: bpc,
    bits_per_component: bpcomp,
    bits_per_flag: bpf,
    colour_value_count,
    decode,
    decoded,
  }
}

///|
fn require_positive_mesh_int(
  dict : @objects.PdfDictionary,
  key : Bytes,
  offset : Int64,
  label : String,
) -> Int raise PdfGraphicsError {
  let value = require_integer_value(
    required_entry(dict, key, offset),
    offset,
    label,
  )
  if value <= 0L || value > 2147483647L {
    raise graphics_resource_error(offset, label + " must be a positive integer")
  }
  value.to_int()
}

///|
fn validate_coordinate_bits(
  bits : Int,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if bits != 1 &&
    bits != 2 &&
    bits != 4 &&
    bits != 8 &&
    bits != 12 &&
    bits != 16 &&
    bits != 24 &&
    bits != 32 {
    raise graphics_resource_error(
      offset, "BitsPerCoordinate has an unsupported width",
    )
  }
}

///|
fn validate_component_bits(
  bits : Int,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if bits != 1 &&
    bits != 2 &&
    bits != 4 &&
    bits != 8 &&
    bits != 12 &&
    bits != 16 {
    raise graphics_resource_error(
      offset, "BitsPerComponent has an unsupported width",
    )
  }
}

///|
fn validate_flag_bits(
  bits : Int,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if bits != 2 && bits != 4 && bits != 8 {
    raise graphics_resource_error(
      offset, "BitsPerFlag has an unsupported width",
    )
  }
}

///|
fn validate_decode_pairs(
  decode : Array[Double],
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  if decode.length() > 128 {
    raise graphics_resource_error(offset, "Decode array is unreasonably large")
  }
  for i in 0..<(decode.length() / 2) {
    if decode[i * 2] == decode[i * 2 + 1] {
      raise graphics_resource_error(
        offset, "Decode range endpoints must differ",
      )
    }
  }
}

///|
fn mesh_vertex_record_bits(
  params : MeshCommonParams,
  include_flag : Bool,
) -> Int {
  let mut bits = params.bits_per_coordinate * 2 +
    params.bits_per_component * params.colour_value_count
  if include_flag {
    bits = bits + params.bits_per_flag
  }
  bits
}

///|
fn validate_type4_mesh(
  params : MeshCommonParams,
  offset : Int64,
) -> MeshSummary raise PdfGraphicsError {
  let reader = MsbBitReader::new(params.decoded)
  let payload_bits = params.bits_per_coordinate * 2 +
    params.bits_per_component * params.colour_value_count
  let flags : Array[Int] = []
  while reader.remaining_bits() > 0 {
    let flag = reader.read_bits(params.bits_per_flag, offset).to_int()
    reader.skip_bits(payload_bits, offset)
    reader.align_to_byte()
    if flag < 0 || flag > 2 {
      raise graphics_resource_error(
        offset, "Type 4 mesh edge flag must be 0, 1, or 2",
      )
    }
    flags.push(flag)
  }
  if flags.length() < 3 {
    raise graphics_resource_error(
      offset, "Type 4 mesh requires at least one complete triangle",
    )
  }
  if flags[0] != 0 {
    raise graphics_resource_error(
      offset, "Type 4 first triangle must start with edge flag 0",
    )
  }
  let mut index = 0
  let mut triangles = 0
  while index < flags.length() {
    if flags[index] == 0 {
      if index + 2 >= flags.length() {
        raise graphics_resource_error(
          offset, "Type 4 mesh has an incomplete independent triangle",
        )
      }
      triangles = triangles + 1
      index = index + 3
    } else {
      triangles = triangles + 1
      index = index + 1
    }
  }
  MeshSummary::{
    vertex_count: flags.length(),
    triangle_count: triangles,
    decoded_length: params.decoded.length(),
  }
}

///|
fn validate_type5_mesh(
  params : MeshCommonParams,
  vertices_per_row : Int,
  offset : Int64,
) -> MeshSummary raise PdfGraphicsError {
  let record_bits = mesh_vertex_record_bits(params, false)
  let reader = MsbBitReader::new(params.decoded)
  let mut vertex_count = 0
  while reader.remaining_bits() > 0 {
    reader.skip_bits(record_bits, offset)
    reader.align_to_byte()
    vertex_count = vertex_count + 1
  }
  if vertex_count < vertices_per_row * 2 || vertex_count % vertices_per_row != 0 {
    raise graphics_resource_error(offset, "Type 5 mesh requires complete rows")
  }
  let rows = vertex_count / vertices_per_row
  MeshSummary::{
    vertex_count,
    triangle_count: (rows - 1) * (vertices_per_row - 1) * 2,
    decoded_length: params.decoded.length(),
  }
}

///|
fn validate_patch_mesh(
  params : MeshCommonParams,
  tensor : Bool,
  offset : Int64,
) -> PatchMeshSummary raise PdfGraphicsError {
  let reader = MsbBitReader::new(params.decoded)
  let mut patch_count = 0
  while reader.remaining_bits() > 0 {
    let flag = reader.read_bits(params.bits_per_flag, offset).to_int()
    if flag < 0 || flag > 3 {
      raise graphics_resource_error(
        offset, "patch mesh flag must be in range 0..3",
      )
    }
    if patch_count == 0 && flag != 0 {
      raise graphics_resource_error(
        offset, "first patch mesh record must use flag 0",
      )
    }
    let control_points = if tensor {
      if flag == 0 {
        16
      } else {
        12
      }
    } else if flag == 0 {
      12
    } else {
      8
    }
    let bits = control_points * 2 * params.bits_per_coordinate +
      4 * params.colour_value_count * params.bits_per_component
    reader.skip_bits(bits, offset)
    reader.align_to_byte()
    patch_count = patch_count + 1
  }
  if patch_count == 0 {
    raise graphics_resource_error(
      offset, "patch mesh requires at least one patch",
    )
  }
  PatchMeshSummary::{ patch_count, decoded_length: params.decoded.length() }
}
