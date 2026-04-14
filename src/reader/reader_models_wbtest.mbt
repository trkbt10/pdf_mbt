///|
test "forms signatures fdf measurement and requirement models are constructible" {
  let dict : @objects.PdfDictionary = Map::new()
  let field = PdfFormField::{
    object_id: Some(oid(10)),
    partial_name: Some(b"Name"),
    fully_qualified_name: Some(b"Root.Name"),
    field_type: PdfFormFieldType::Text,
    flags: PdfFormFieldFlags::{ bits: 1 },
    value: PdfFormFieldValue::String(b"Alice"),
    default_value: PdfFormFieldValue::Absent,
    parent: None,
    kids: [],
    widgets: [],
    variable_text: Some(PdfVariableTextDescriptor::{
      default_appearance: Some(b"/Helv 10 Tf 0 g"),
      quadding: Some(0),
      default_style: None,
      rich_text: None,
      default_resources: None,
      raw_dict: dict,
    }),
    raw_dict: dict,
  }
  let form = PdfAcroForm::{
    root_fields: [field],
    need_appearances: Some(false),
    signature_flags: None,
    calculation_order: [],
    default_resources: None,
    default_appearance: None,
    quadding: None,
    xfa: None,
    raw_dict: dict,
  }
  assert_eq(form.root_fields.length(), 1)
  assert_eq(
    form.root_fields[0].fully_qualified_name == Some(b"Root.Name"),
    true,
  )

  let fdf = PdfFDFDocument::{
    catalog: PdfFDFCatalog::{
      version: Some(structural_key(b"1.7")),
      fdf: Some(PdfFDFDictionary::{
        file: None,
        fields: [],
        status: Some(b"ok"),
        pages: [],
        encoding: None,
        annotations: [],
        differences: None,
        target: None,
        embedded_fdf: None,
        javascript: None,
        raw_dict: dict,
      }),
      raw_dict: dict,
    },
    objects: [],
    trailer: None,
  }
  assert_eq(fdf.catalog.version == Some(structural_key(b"1.7")), true)

  let signature = PdfSignatureDictionary::{
    object_id: Some(oid(11)),
    filter: Some(structural_key(b"Adobe.PPKLite")),
    subfilter: PdfSignatureSubFilter::AdbePkcs7Detached,
    contents: Some(b"signature-bytes"),
    cert: None,
    byte_range: [PdfSignatureByteRange::{ offset: 0L, length: 100L }],
    references: [],
    signer_name: Some(b"Alice"),
    signing_time: None,
    location: None,
    reason: None,
    contact_info: None,
    changes: [],
    raw_dict: dict,
  }
  let plan = PdfSignatureValidationPlan::{
    signature,
    byte_ranges: signature.byte_range,
    raw_contents: signature.contents,
    transform_constraints: [],
    evidence_sources: [],
  }
  assert_eq(plan.byte_ranges[0].length, 100L)

  let measure = PdfMeasure::{
    kind: PdfMeasureKind::Rectilinear,
    subtype: Some(structural_key(b"RL")),
    scale_ratio: Some(b"1 in = 1 ft"),
    number_formats: [
      PdfNumberFormatDescriptor::{
        labels: [b"ft"],
        conversion_factor: 12.0,
        precision: Some(2),
        fraction_denominator: None,
        decimal_separator: Some(b"."),
        thousands_separator: Some(b","),
        label_position: Some(structural_key(b"S")),
        raw_dict: dict,
      },
    ],
    raw_dict: dict,
  }
  let viewport = PdfViewport::{
    bbox: Some(PdfRectangle::{ left: 0.0, bottom: 0.0, right: 10.0, top: 10.0 }),
    name: Some(b"vp"),
    measure: Some(measure),
    point_data: None,
    raw_dict: dict,
  }
  assert_eq(viewport.name == Some(b"vp"), true)

  let geo = PdfGeospatialMeasure::{
    bounds: [0.0, 0.0, 1.0, 1.0],
    geographic_coordinate_system: Some(PdfCoordinateSystem::{
      kind: PdfCoordinateSystemKind::Geographic,
      descriptor: PdfCoordinateSystemDescriptor::EPSG(4326),
      raw_dict: dict,
    }),
    display_coordinate_system: None,
    preferred_display_units: [],
    gpts: [],
    lpts: [],
    pcsm: None,
    raw_dict: dict,
  }
  assert_eq(geo.bounds.length(), 4)

  let requirement = PdfCatalogRequirement::{
    requirement_type: Some(structural_key(b"EnableJavaScripts")),
    minimum_version: Some(PdfVersion::{ major: 2, minor: 0 }),
    handlers: [
      PdfRequirementHandler::{
        handler_type: Some(structural_key(b"Script")),
        version: None,
        raw_dict: dict,
      },
    ],
    penalty: None,
    support_status: PdfRequirementSupportStatus::Unsupported,
    raw_payload: None,
    raw_dict: dict,
  }
  assert_eq(requirement.handlers.length(), 1)
}
