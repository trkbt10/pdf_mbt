///|
/// Group XObject attributes from ISO 32000-2 8.10.3. The Group dictionary's
/// subtype (`S`) distinguishes transparency group XObjects from other group
/// attributes, and the raw dictionary is retained for deferred rendering.
pub(all) struct FormGroupInfo {
  subtype : @objects.PdfName?
  transparency : TransparencyGroup?
  raw : @objects.PdfDictionary
} derive(Eq, Debug)

///|
/// Reference XObject metadata from ISO 32000-2 8.10.4. The required reference
/// dictionary entries `F` and `Page` identify the target document and page;
/// `ID` helps find or warn about changed target files. Printing may use the
/// imported content or this proxy form, while annotation appearance and logical
/// structure caveats are preserved for higher layers.
pub(all) struct ReferenceXObjectInfo {
  file_spec : @objects.PdfObject?
  page : @objects.PdfObject?
  id : @objects.PdfObject?
} derive(Eq, Debug)

///|
/// Type 1 Form XObject descriptor from ISO 32000-2 8.10. A form XObject is a
/// reusable content stream painted by `Do`; it has form space, BBox clipping,
/// a Matrix mapping form space to user space, optional Resources, Group,
/// reference proxy metadata, OC optional content, and associated files.
pub(all) struct FormXObject {
  name : @objects.PdfName?
  form_type : Int
  bbox : GraphicsRect
  matrix : GraphicsMatrix
  resources : @objects.PdfDictionary?
  group : FormGroupInfo?
  reference : ReferenceXObjectInfo?
  struct_parent : Int?
  struct_parents : Int?
  metadata : @objects.PdfObject?
  piece_info : @interchange.PdfPagePieceDictionary?
  associated_files : @objects.PdfObject?
  oc : @objects.PdfObject?
  stream : @objects.PdfStream
} derive(Eq, Debug)

///|
/// Geometry applied when painting a form XObject: its Matrix is concatenated
/// with the caller CTM, its BBox becomes a clipping path in form space, and
/// transformed_bbox records the Matrix-mapped BBox bounds for layout analysis.
pub(all) struct FormXObjectGeometry {
  matrix : GraphicsMatrix
  bbox : GraphicsRect
  transformed_bbox : GraphicsRect
  clip_path : GraphicsPath
} derive(Eq, Debug)

///|
/// Validates a form XObject stream dictionary: `/Type /XObject`,
/// `/Subtype /Form`, Type 1 FormType, required BBox, default Matrix,
/// optional Resources, Group, Ref, Metadata, StructParent/StructParents
/// exclusivity, OC optional content, and PDF 2.0 associated files.
pub fn validate_form_xobject(
  name : @objects.PdfName?,
  stream : @objects.PdfStream,
  offset : Int64,
) -> FormXObject raise PdfGraphicsError {
  require_type_marker(stream.dict, b"XObject", offset, "Form XObject")
  require_name_entry_value(
    stream.dict,
    b"Subtype",
    b"Form",
    offset,
    "Form Subtype",
  )
  let form_type = match optional_entry(stream.dict, b"FormType") {
    Some(value) => {
      let n = require_integer_value(value, offset, "FormType")
      if n != 1L {
        raise invalid_xobject(offset, "FormType must be 1")
      }
      1
    }
    None => 1
  }
  let struct_parent = image_optional_int(
    stream.dict,
    b"StructParent",
    offset,
    "StructParent",
  )
  let struct_parents = image_optional_int(
    stream.dict,
    b"StructParents",
    offset,
    "StructParents",
  )
  if struct_parent is Some(_) && struct_parents is Some(_) {
    raise invalid_xobject(
      offset, "Form XObject cannot contain both StructParent and StructParents",
    )
  }
  FormXObject::{
    name,
    form_type,
    bbox: required_graphics_rect(stream.dict, b"BBox", offset, "BBox"),
    matrix: optional_graphics_matrix(stream.dict, offset, "Form Matrix"),
    resources: optional_form_resources(stream.dict, offset),
    group: optional_group(stream.dict, offset),
    reference: optional_reference(stream.dict, offset),
    struct_parent,
    struct_parents,
    metadata: optional_entry(stream.dict, b"Metadata"),
    piece_info: optional_form_piece_info(stream.dict),
    associated_files: optional_entry(stream.dict, b"AF"),
    oc: optional_entry(stream.dict, b"OC"),
    stream,
  }
}

///|
/// Computes the form Matrix transform and BBox clipping geometry used by the
/// Do operator before interpreting the form content stream.
pub fn FormXObject::geometry(self : FormXObject) -> FormXObjectGeometry {
  FormXObjectGeometry::{
    matrix: self.matrix,
    bbox: self.bbox,
    transformed_bbox: self.bbox.transform_bounds(self.matrix),
    clip_path: GraphicsPath::from_rect(self.bbox),
  }
}

///|
/// Applies the form Matrix to the BBox corners and returns the axis-aligned
/// transformed bounds as `(left, bottom, right, top)` coordinates.
pub fn FormXObject::transformed_bbox(
  self : FormXObject,
) -> (Double, Double, Double, Double) {
  let transformed = self.bbox.transform_bounds(self.matrix)
  let left = transformed.left
  let bottom = transformed.bottom
  let right = transformed.right
  let top = transformed.top
  (left, bottom, right, top)
}

///|
/// Reports whether the form's Group attributes identify an ISO transparency
/// group. Parsed transparency metadata is authoritative, while the subtype
/// name keeps the predicate true for equivalent preserved group metadata.
pub fn FormXObject::has_transparency_group(self : FormXObject) -> Bool {
  match self.group {
    Some(group) =>
      match group.transparency {
        Some(_) => true
        None => group.subtype == Some(pdf_name(b"Transparency"))
      }
    None => false
  }
}

///|
/// Applies a form XObject's Matrix and BBox clip to a graphics-state copy,
/// producing the scoped state in which the form content is interpreted.
pub fn apply_form_xobject_geometry(
  form : FormXObject,
  parent_state : GraphicsState,
) -> GraphicsState {
  let state = parent_state.copy()
  let geometry = form.geometry()
  state.concat_ctm(geometry.matrix)
  state.clipping_path = state.clipping_path.append_clip(
    geometry.clip_path.transformed(state.ctm),
    FillRule::NonZero,
  )
  state
}

///|
fn optional_form_piece_info(
  dict : @objects.PdfDictionary,
) -> @interchange.PdfPagePieceDictionary? raise PdfGraphicsError {
  try @interchange.validate_optional_page_piece_entry(dict) catch {
    error => raise PdfGraphicsError::InterchangeFailure(error)
  } noraise {
    value => value
  }
}

///|
fn optional_form_resources(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> @objects.PdfDictionary? raise PdfGraphicsError {
  match optional_entry(dict, b"Resources") {
    Some(value) => Some(require_dictionary_value(value, offset, "Resources"))
    None => None
  }
}

///|
fn optional_group(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> FormGroupInfo? raise PdfGraphicsError {
  match optional_entry(dict, b"Group") {
    Some(value) => {
      let group = require_dictionary_value(value, offset, "Group")
      match optional_entry(group, b"Type") {
        Some(type_value) => {
          let type_name = require_name_value(type_value, offset, "Group Type")
          if type_name != pdf_name(b"Group") {
            raise invalid_xobject(offset, "Group Type must be Group")
          }
        }
        None => ()
      }
      let subtype = image_optional_name(group, b"S", offset, "Group subtype")
      Some(FormGroupInfo::{
        subtype,
        transparency: if subtype == Some(pdf_name(b"Transparency")) {
          Some(
            parse_transparency_group_dictionary(
              group,
              TransparencyGroupContext::FormTransparencyGroup,
              offset,
            ),
          )
        } else {
          None
        },
        raw: group,
      })
    }
    None => None
  }
}

///|
fn optional_reference(
  dict : @objects.PdfDictionary,
  offset : Int64,
) -> ReferenceXObjectInfo? raise PdfGraphicsError {
  match optional_entry(dict, b"Ref") {
    Some(value) => {
      let ref_dict = require_dictionary_value(value, offset, "Ref")
      let file_spec = required_entry(ref_dict, b"F", offset)
      let page = required_entry(ref_dict, b"Page", offset)
      Some(ReferenceXObjectInfo::{
        file_spec: Some(file_spec),
        page: Some(page),
        id: optional_entry(ref_dict, b"ID"),
      })
    }
    None => None
  }
}

///|
fn invalid_xobject(offset : Int64, reason : String) -> PdfGraphicsError {
  PdfGraphicsError::InvalidXObject(offset, reason)
}
