# graphics

## API

- **`ColourSpace`** (Enum) — PDF colour space families used by graphics operators for ISO 32000-2 8.6
- **`GraphicsState`** (Struct) — Stored graphics state parameters from ISO 32000-2 section 8.4.
- **`GraphicsProgram`** (Struct) — Complete device-independent graphics description for a PDF content stream.
- **`GraphicsEvent`** (Enum) — Ordered graphics interpretation events for PDF graphics operators.
- **`ExtGStatePatch`** (Struct) — Cumulative graphics state parameter dictionary patch resolved from an
- **`ImageDescriptor`** (Struct) — Validated image dictionary descriptor for image XObjects and inline images.
- **`ReferenceXObjectInfo`** (Struct) — Reference XObject metadata from ISO 32000-2 8.10.4. The required reference
- **`OptionalContentState`** (Struct) — Optional content state derived from OCProperties, OCGs, the default
- **`IccBasedParams`** (Struct) — ICCBased colour space dictionary parameters: required N component count,
- **`AxialShading`** (Struct) — ISO 32000-2 8.7.4.5.3 Type 2 axial shading.
- **`ImageSource`** (Enum) — ISO 32000-2 8.8 and 8.9 image source: an image XObject painted by the
- **`ColourTransformFunction`** (Enum) — Direct scalar function source used by colour conversion policies such as
- **`GraphicsMatrix`** (Struct) — ISO PDF six-number affine transformation matrix `[a b c d e f]`.
- **`PatternDefinition`** (Enum) — Pattern dictionary varieties from ISO 32000-2 8.7.1 General:
- **`initial_value`** (Function) — Returns the initial current colour for a colour space. DeviceGray,
- **`FormXObject`** (Struct) — Type 1 Form XObject descriptor from ISO 32000-2 8.10. A form XObject is a
- **`XObjectResource`** (Enum) — External object resource from ISO 32000-2 8.8.1. A `Do` operator names an
- **`ColourState`** (Struct) — Current colour-space and current colour parameter of the graphics state.
- **`TilingPattern`** (Struct) — ISO 32000-2 8.7.1 and 8.7.2 Type 1 tiling pattern object.
- **`DeviceNAttributes`** (Struct) — DeviceN attributes dictionary from ISO 32000-2 Table 70. Subtype may be
- **`ImageByteStatus`** (Enum) — Availability of image sample data after structural filter handling.
- **`GraphicsInitialState`** (Struct) — Caller-supplied initial page graphics state inputs. The CTM starts the
- **`ImageStructuralMetadata`** (Struct) — Structural entries specific to image dictionaries: rendering Intent,
- **`DeviceColourSpace`** (Enum) — Device colour spaces from ISO 32000-2 8.6.4.1 General.
- **`ExtractedImageData`** (Enum) — Extracted image data. Supported sample-byte filters are expanded into
- **`IccProfileInfo`** (Struct) — ICCBased profile header summary. PDF 2.0 uses ICC.1:2010
- **`ImageSampleLayout`** (Struct) — Image coordinate system and sample representation. Width and height are in
- **`ShadingPattern`** (Struct) — ISO 32000-2 8.7.4.1 Type 2 shading pattern dictionary.
- **`FunctionBasedShading`** (Struct) — ISO 32000-2 8.7.4.5.2 Type 1 function-based shading.
- **`PatternPaintType`** (Enum) — Pattern PaintType values for ISO 32000-2 8.7.3 tiling patterns.
- **`BlackPointCompensation`** (Enum) — UseBlackPtComp policy from ISO 32000-2 8.6.5.9. ON applies black point
- **`DeviceNParams`** (Struct) — DeviceN and NChannel colour space parameters from ISO 32000-2 8.6.6.5.
- **`IccProfileHeader`** (Struct) — Parsed ICC profile header fields used by ICCBased colour spaces. Offsets
- **`ShadingKind`** (Enum) — ISO 32000-2 8.7.4.5.1 shading types selected by ShadingType.
- **`PatternParams`** (Struct) — Parameters for the special ISO 32000-2 Pattern colour space family.
- **`TensorPatchMeshShading`** (Struct) — ISO 32000-2 8.7.4.5.8 Type 7 tensor-product patch mesh shading.
- **`TransparencyGroupContext`** (Enum) — Context in which a transparency group dictionary is interpreted. Form
- **`IndexedParams`** (Struct) — Indexed colour space parameters from ISO 32000-2 8.6.6.3. The lookup colour
- **`FormXObjectGeometry`** (Struct) — Geometry applied when painting a form XObject: its Matrix is concatenated
- **`validate_tiling_pattern_cell`** (Function) — Validates and interprets one tiling pattern cell content stream.
- **`decode_image_sample_values`** (Function) — Decodes PDF image sample bytes into unsigned component values. Bits are
- **`PatternResource`** (Enum) — Named Pattern resource entry used by CS/cs and SCN/scn colour operators.
- **`ImageDecodeRange`** (Struct) — One pair from an image Decode array. Each range maps the pre-decode sample
- **`FormGroupInfo`** (Struct) — Group XObject attributes from ISO 32000-2 8.10.3. The Group dictionary's
- **`has_transparency_group`** (Function) — Reports whether the form's Group attributes identify an ISO transparency
- **`SeparationParams`** (Struct) — Separation colour space parameters from ISO 32000-2 8.6.6.4. A single tint
- **`effective_black_point_compensation`** (Function) — Computes the effective UseBlackPtComp value. If the current render intent
- **`RenderingIntent`** (Enum) — Standard rendering intents from ISO 32000-2 8.6.5.8 Table 69. The ri
- **`ImageMaskInfo`** (Enum) — Masked image model from ISO 32000-2 8.9.6: no mask, stencil ImageMask,
- **`ImageDictionaryValidation`** (Struct) — Validation summary for an image dictionary's sample stream. The expected
- **`AlternateImageInfo`** (Struct) — Alternate image dictionary metadata from ISO 32000-2 8.9.5.4. The Image
- **`OptionalContentDecision`** (Enum) — Visibility result for optional content in ISO 32000-2 8.11. Hidden
- **`evaluate_visibility`** (Function) — Evaluates an optional-content membership policy against visible group names.
- **`expected_data_length`** (Function) — Computes the decoded sample byte count implied by Width, Height,
- **`ColourStateStack`** (Struct) — LIFO stack for the current colour-space and colour-value pair. This mirrors
- **`ImageDeviceRgbRaster`** (Struct) — DeviceRGB pixel output extracted from an image XObject or inline image.
- **`XObjectType`** (Enum) — XObject subtype classification from an XObject stream dictionary. Image and
- **`ColourRange`** (Struct) — Minimum and maximum valid values for one colour component. Component
- **`set_colour_value`** (Function) — Sets the current stroking or nonstroking colour value. SCN/scn Pattern
- **`TransparencyGroup`** (Struct) — Transparency group XObject attributes from ISO 32000-2 8.10.3 and 11.6.6:
- **`CalRGBParams`** (Struct) — CalRGB CIE-based ABC colour space parameters. Gamma and Matrix define the
- **`IccProfileSource`** (Enum) — Source of an ICCBased colour space profile. DirectProfile stores validated
- **`PathSegment`** (Enum) — One immutable path construction segment in a graphics path snapshot.
- **`Shading`** (Struct) — Parsed shading dictionary or stream dictionary. ShadingType selects the
- **`ColourValue`** (Struct) — Current colour value. In a Pattern colour space, the pattern object name is
- **`apply_decode_array`** (Function) — Applies a raw Decode array to interleaved sample values. Each component
- **`is_stencil_mask`** (Function) — Reports whether these parameters describe an ImageMask stencil: a one-bit,
- **`GraphicsInterpretOptions`** (Struct) — Graphics interpretation options, including the optional content group state
- **`OptionalContentMembership`** (Struct) — Lightweight optional content membership policy over named groups. The
- **`is_visible`** (Function) — Resolves this group's visibility against the default optional-content
- **`ImageSoftMaskSource`** (Enum) — Transparent imaging model soft-mask source for image dictionaries: no
- **`from_values`** (Function) — Computes row bit layout for image space: samples are interleaved
- **`unpack_samples`** (Function) — Unpacks interleaved image sample values from decoded bytes. Bits are read
- **`GraphicsPath`** (Struct) — Snapshot of a PDF current path. Paths are device-independent shapes that
- **`ColourDefaults`** (Struct) — DefaultGray, DefaultRGB, and DefaultCMYK resource entries used to remap
- **`PathPaintOperation`** (Enum) — Path-painting operation that terminates a PDF path object: fill a path with
- **`ColourUse`** (Enum) — Selects whether a colour operator applies to stroking or nonstroking
- **`ColourTransfer`** (Enum) — Transfer function bundle for a colour value. A single function applies to
- **`CalGrayParams`** (Struct) — CalGray CIE-based A colour space parameters. WhitePoint and BlackPoint are
- **`is_form`** (Function) — Reports whether this XObject subtype is a form XObject. This mirrors image
- **`is_image`** (Function) — Reports whether this XObject subtype is an image XObject. Unsupported names
- **`LabParams`** (Struct) — Lab CIE-based ABC colour space parameters for CIE 1976 L*a*b*. The L*
- **`OptionalContentGroup`** (Struct) — Lightweight optional content group state for visibility policy checks. A
- **`default`** (Function) — Creates default graphics interpretation options where optional content is
- **`PatchMeshSummary`** (Struct) — Validation summary for Type 6 Coons patch mesh and Type 7 tensor-product
- **`ClipState`** (Struct) — Approximate clipping-path model: initial page clip plus successive path
- **`DeviceCmykColour`** (Struct) — Device CMYK colour components in subtractive form. Values are normalized to
- **`ImageAlphaMaskRaster`** (Struct) — One-byte alpha mask extracted from an ImageMask, explicit Mask image, or
- **`ImageParams`** (Struct) — Lightweight image sample parameters used by requirements checks and callers
- **`ColourStateSnapshot`** (Struct) — Pair of stroking and nonstroking colour states saved independently from
- **`apply_form_xobject_geometry`** (Function) — Applies a form XObject's Matrix and BBox clip to a graphics-state copy,
- **`apply_image_decode_range`** (Function) — Applies one Decode array component range to a raw sample value by linear
- **`DeviceRgbColour`** (Struct) — Device RGB colour components in additive form. Values are normalized to the
- **`paint_stencil_mask_with_colour`** (Function) — Combines a one-byte stencil alpha mask with the current nonstroking paint
- **`ColourSpaceFamily`** (Enum) — High-level ISO 32000-2 8.6 colour-space family classification used by
- **`OptionalContentPolicy`** (Enum) — Optional content membership dictionary policy (`P`) from ISO 32000-2
- **`apply_image_decode_array`** (Function) — Applies an image Decode array to interleaved raw samples, returning
- **`geometry`** (Function) — Computes the form Matrix transform and BBox clipping geometry used by the
- **`SoftMaskInfo`** (Struct) — Parsed SMask and SMaskInData information, including Matte values for
- **`initial`** (Function) — Initial graphics-state colour is DeviceGray with a single black component
- **`validate_stream_length`** (Function) — Verifies Width, Height, component count, BitsPerComponent, and decoded
- **`TilingType`** (Enum) — Pattern TilingType values controlling spacing relative to the device pixel
- **`MeshSummary`** (Struct) — Validation summary for Type 4 and Type 5 Gouraud-shaded triangle mesh
- **`transform_bounds`** (Function) — Transforms the four rectangle corners and returns their axis-aligned bounds
- **`CieXyzColour`** (Struct) — CIE 1931 XYZ tristimulus value with Y normalized to 1.0 at the reference
- **`decode_stencil_mask_to_colour`** (Function) — Decodes an ImageMask stream and paints every unmasked one-bit sample with
- **`ShadingCommon`** (Struct) — Entries common to all shading dictionaries from Table 77: ColorSpace,
- **`GraphicsObjectLevel`** (Enum) — Section 8.2 graphics object context: content stream level, active path
- **`ShadingResource`** (Enum) — Named Shading resource used either by the sh operator or by a Type 2
- **`GraphicsRect`** (Struct) — Page or path rectangle represented by lower-left and upper-right values.
- **`ExtractedImage`** (Struct) — Validated image descriptor paired with extracted byte-level image data.
- **`ClipEntry`** (Struct) — One accumulated clipping intersection derived from a completed path.
- **`GraphicsPoint`** (Struct) — Coordinate pair in PDF user space or a transformed coordinate space.
- **`concat`** (Function) — Returns `transform x current`, the PDF `cm` premultiplication order.
- **`GraphicsStateChange`** (Enum) — Describes a graphics-state mutation emitted during interpretation.
- **`PathSubpath`** (Struct) — Ordered subpath with its starting point and constructed segments.
- **`FillRule`** (Enum) — PDF fill-rule selection for path painting and clipping.
- **`DashPattern`** (Struct) — Current line dash array and normalized phase.
- **`LineJoinStyle`** (Enum) — Line join styles from ISO 32000-2 Table 54.
- **`LineCapStyle`** (Enum) — Line cap styles from ISO 32000-2 Table 53.
- **`membership_all_on`** (Function) — 


- **`to_xyz`** (Function) — 


- **`is_empty`** (Function) — 


- **`snapshot`** (Function) — 


- **`clear`** (Function) — 


- **`move_to`** (Function) — 


- **`emit_colour_change`** (Function) — 


- **`validate_sc_supported`** (Function) — 


- **`device_colour_space_name`** (Function) — 


- **`line_to`** (Function) — 


- **`curve_to`** (Function) — 


- **`close_path`** (Function) — 


- **`rectangle`** (Function) — 


- **`from_rect`** (Function) — 


- **`copy`** (Function) — 


- **`append_clip`** (Function) — 


- **`append_segment`** (Function) — 


- **`require_current_point`** (Function) — 


- **`copy_optional_path`** (Function) — 


- **`copy_subpaths`** (Function) — 


- **`new`** (Function) — 


- **`remaining_bits`** (Function) — 


- **`read_bits`** (Function) — 


- **`skip_bits`** (Function) — 


- **`align_to_byte`** (Function) — 


- **`MeshCommonParams`** (Struct) — 


- **`validate_coordinate_bits`** (Function) — 


- **`validate_image_sample_layout`** (Function) — 


- **`is_valid_bits_per_component`** (Function) — 


- **`colour_ranges_to_decode_ranges`** (Function) — 


- **`validate_mask_exclusions`** (Function) — 


- **`validate_decoded_length`** (Function) — 


- **`max_sample_value`** (Function) — 


- **`read_image_param_sample`** (Function) — 


- **`clamp_image_param_sample`** (Function) — 


- **`invalid_image`** (Function) — 


- **`GraphicsObjectContext`** (Struct) — 


- **`SoftMaskTransferFunction`** (Enum) — 


- **`SoftMaskGroupSource`** (Enum) — 


- **`SoftMaskDictionary`** (Struct) — 


- **`SoftMaskSource`** (Enum) — 


- **`EstablishedSoftMask`** (Struct) — 


- **`none`** (Function) — 


- **`RadialShading`** (Struct) — 


- **`current_colour_as_rgb`** (Function) — 


- **`soft_mask_group_component_count`** (Function) — 


- **`FreeFormMeshShading`** (Struct) — 


- **`LatticeMeshShading`** (Struct) — 


- **`apply_ext_gstate`** (Function) — 


- **`apply_ext_gstate_non_colour`** (Function) — 


- **`CoonsPatchMeshShading`** (Struct) — 


- **`validate_component_bits`** (Function) — 


- **`validate_flag_bits`** (Function) — 


- **`validate_decode_pairs`** (Function) — 


- **`mesh_vertex_record_bits`** (Function) — 


- **`validate_type4_mesh`** (Function) — 


- **`validate_type5_mesh`** (Function) — 


- **`GraphicsInterpreter`** (Struct) — 


- **`invoke_form_xobject`** (Function) — 


- **`OptionalVisibilityStack`** (Struct) — 


- **`validate_patch_mesh`** (Function) — 


- **`lookup_colour_value`** (Function) — 


- **`from_profile_header`** (Function) — 


- **`detected_component_count`** (Function) — 


- **`default_icc_ranges`** (Function) — 


- **`read_u32_be`** (Function) — 


- **`read_signature`** (Function) — 


- **`read_u32_be_or`** (Function) — 


- **`read_signature_or`** (Function) — 


- **`validate_icc_device_class`** (Function) — 


- **`icc_signature_component_count_or_zero`** (Function) — 


- **`icc_signature_component_count`** (Function) — 


- **`icc_rendering_intent_or_default`** (Function) — 


- **`current`** (Function) — 


- **`parse_icc_profile_header`** (Function) — 


- **`icc_rendering_intent`** (Function) — 


- **`push`** (Function) — 


- **`pop`** (Function) — 


- **`BlendModeClass`** (Enum) — 


- **`membership_any_on`** (Function) — 


- **`membership_all_off`** (Function) — 


- **`membership_any_off`** (Function) — 


- **`contains_visible_group_name`** (Function) — 


- **`classify`** (Function) — 


- **`is_separable`** (Function) — 


- **`decode_sample_bytes_to_rgb`** (Function) — 


- **`decode_stencil_alpha_mask`** (Function) — 


- **`alpha_for_image_descriptor`** (Function) — 


- **`decode_gray_alpha_mask`** (Function) — 


- **`alpha_from_single_component_samples`** (Function) — 


- **`colour_key_alpha`** (Function) — 


- **`require_alpha_dimensions`** (Function) — 


- **`alpha_byte_at`** (Function) — 


- **`unpack_image_samples`** (Function) — 


- **`validate_sample_value`** (Function) — 


- **`read_msb_bits`** (Function) — 


- **`pixel_to_device_rgb`** (Function) — 


- **`indexed_pixel_to_device_rgb`** (Function) — 


- **`decode_sample_value`** (Function) — 


- **`components_to_device_rgb`** (Function) — 


- **`rgb_colour_tuple`** (Function) — 


- **`unit_to_byte`** (Function) — 


- **`is_non_separable`** (Function) — 


- **`colour_space_repeat_decode`** (Function) — 


- **`is_white_preserving`** (Function) — 


- **`repeat_double`** (Function) — 


- **`identity`** (Function) — 


- **`from_six`** (Function) — 


- **`translation`** (Function) — 


- **`scale`** (Function) — 


- **`rotation`** (Function) — 


- **`skew`** (Function) — 


- **`clamp_ab`** (Function) — 


- **`transform_point`** (Function) — 


- **`determinant`** (Function) — 


- **`inverse`** (Function) — 


- **`graphics_resource_error`** (Function) — 


- **`missing_required`** (Function) — 


- **`validate_transparency_group_colour_space`** (Function) — 


- **`invalid_xobject`** (Function) — 


- **`is_restricted`** (Function) — 


- **`validate_pattern_selection`** (Function) — 


- **`colour_space_repeat_components`** (Function) — 


- **`validate_tiling_pattern_selection`** (Function) — 


- **`validate_coloured_pattern_selection`** (Function) — 


- **`parse_tiling_type`** (Function) — 


- **`establish`** (Function) — 


- **`parse_pattern_paint_type`** (Function) — 


- **`device_gray_to_rgb`** (Function) — 


- **`device_cmyk_to_rgb`** (Function) — 


- **`to_srgb`** (Function) — 


- **`lab_d50_to_srgb`** (Function) — 


- **`cie_xyz_d65_to_srgb`** (Function) — 


- **`GraphicsStateStack`** (Struct) — 


- **`lookup_device_rgb`** (Function) — 


- **`alternate_colour_value`** (Function) — 


- **`apply_transfer_function`** (Function) — 


- **`apply_transfer_functions`** (Function) — 


- **`selected_pattern`** (Function) — 


- **`icc_based_to_device_rgb`** (Function) — 


- **`apply_scalar`** (Function) — 


- **`apply`** (Function) — 


- **`min3`** (Function) — 


- **`colour_component`** (Function) — 


- **`lab_g`** (Function) — 


- **`srgb_encode`** (Function) — 


- **`d50_white_point`** (Function) — 


- **`d65_white_point`** (Function) — 


- **`adapt_xyz_to_d65`** (Function) — 


- **`adapt_xyz_between_whites`** (Function) — 


- **`bradford_to_lms`** (Function) — 


- **`bradford_from_lms`** (Function) — 


- **`clip`** (Function) — 


- **`infer_type2_output_count`** (Function) — 


- **`finite_double`** (Function) — 


- **`default_decode_array`** (Function) — 


- **`empty`** (Function) — 


- **`defaulted_device_space`** (Function) — 


- **`validate_default_space`** (Function) — 


- **`validate_alternate_colour_space`** (Function) — 


- **`component_count`** (Function) — 


- **`is_device_space`** (Function) — 


- **`to_device_family`** (Function) — 


- **`resolve_default_space`** (Function) — 


- **`component_ranges`** (Function) — 


- **`MsbBitReader`** (Struct) — 


- **`initial_from_ranges`** (Function) — 


- **`repeat_range`** (Function) — 


- **`validate_range_pairs`** (Function) — 


- **`colour_state`** (Function) — 


- **`solid`** (Function) — 


- **`from_clip`** (Function) — 


- **`reset_transparency_parameters`** (Function) — 


- **`concat_ctm`** (Function) — 


- **`set_line_width`** (Function) — 


- **`from_int`** (Function) — 


- **`set_miter_limit`** (Function) — 


- **`set_flatness`** (Function) — 


- **`save`** (Function) — 


- **`restore`** (Function) — 


- **`CurrentPath`** (Struct) — 


- **`normalize_colour_components`** (Function) — 


- **`current_colour_space`** (Function) — 


- **`with_stroke_colour`** (Function) — 


- **`default_colour_value`** (Function) — 


- **`with_fill_colour`** (Function) — 


- **`current_colour_value`** (Function) — 


- **`set_colour_space`** (Function) — 


- **`components_to_rgb`** (Function) — 


- **`replace_colour_state`** (Function) — 


- **`validate_colour_value_for_space`** (Function) — 


- **`numeric_colour_value`** (Function) — 


- **`convert_to_rgb`** (Function) — 


- **`clamp_indexed_component`** (Function) — 


- **`clamp_double`** (Function) — 


- **`is_valid_device_default`** (Function) — 


- **`resolve_device_space`** (Function) — 


- **`normalized_for_space`** (Function) — 


- **`normalized`** (Function) — 


- **`from_graphics_state`** (Function) — 


- **`apply_to_graphics_state`** (Function) — 


- **`depth`** (Function) — 


- **`push_graphics_state`** (Function) — 


- **`pop_into_graphics_state`** (Function) — 


- **`pdf_name`** (Function) — 
- **`ColourRestriction`** (Enum) — 
- **`BlendMode`** (Enum) — 
- **`SoftMaskSubtype`** (Enum) —
