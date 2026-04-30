///|
test "forms signatures spec vocabulary covers drift anchors" {
  let forms = pdf_forms_signatures_requirement_0_1_general_vocabulary() +
    pdf_forms_signatures_requirement_0_2_interactive_forms_vocabulary() +
    pdf_forms_signatures_requirement_0_4_field_dictionary_general_vocabulary() +
    pdf_form_field_dictionary_general_vocabulary() +
    pdf_forms_signatures_requirement_0_5_field_names_vocabulary() +
    pdf_forms_signatures_requirement_0_8_button_general_vocabulary() +
    pdf_forms_signatures_requirement_0_9_push_buttons_vocabulary() +
    pdf_forms_signatures_requirement_0_10_check_boxes_vocabulary() +
    pdf_forms_signatures_requirement_0_13_choice_fields_vocabulary() +
    pdf_forms_signatures_requirement_0_15_form_actions_general_vocabulary() +
    pdf_forms_signatures_requirement_0_17_reset_form_action_vocabulary() +
    pdf_forms_signatures_requirement_0_18_import_data_action_vocabulary() +
    pdf_forms_signatures_requirement_0_20_fdf_general_vocabulary() +
    pdf_forms_signatures_requirement_0_21_fdf_structure_vocabulary() +
    pdf_forms_signatures_requirement_0_23_fdf_body_vocabulary() +
    pdf_forms_signatures_requirement_0_29_non_interactive_forms_vocabulary()
  assert_eq(forms.contains("Table 229"), true)
  assert_eq(forms.contains("Check boxes"), true)
  assert_eq(forms.contains("Choice fields"), true)
  assert_eq(forms.contains("ImportData"), true)
  assert_eq(forms.contains("generation number 0"), true)

  let signatures = pdf_forms_signatures_requirement_0_31_signature_transform_general_vocabulary() +
    pdf_forms_signatures_requirement_0_33_docmdp_validation_vocabulary() +
    pdf_forms_signatures_requirement_0_35_signature_interop_general_vocabulary() +
    pdf_forms_signatures_requirement_0_38_cms_revocation_vocabulary() +
    pdf_forms_signatures_requirement_0_41_pades_attributes_vocabulary() +
    pdf_forms_signatures_requirement_0_42_cades_detached_profiles_vocabulary() +
    pdf_forms_signatures_requirement_0_43_pades_validation_requirements_vocabulary() +
    pdf_forms_signatures_requirement_0_45_current_time_revocation_vocabulary() +
    pdf_forms_signatures_requirement_0_46_past_time_revocation_vocabulary() +
    pdf_forms_signatures_requirement_0_50_vri_vocabulary() +
    pdf_forms_signatures_requirement_0_52_document_timestamp_general_vocabulary() +
    pdf_forms_signatures_requirement_0_53_initial_document_timestamp_vocabulary() +
    pdf_forms_signatures_requirement_0_55_permissions_vocabulary() +
    pdf_forms_signatures_requirement_0_56_legal_attestations_vocabulary()
  assert_eq(signatures.contains("Internet RFC 5652"), true)
  assert_eq(signatures.contains("Table 319"), true)
  assert_eq(signatures.contains("PAdES-E-BES"), true)
  assert_eq(signatures.contains("Internet RFC 5816"), true)
  assert_eq(signatures.contains("Table 29"), true)
  assert_eq(signatures.contains("Validation-related information"), true)

  let geo = pdf_forms_signatures_requirement_0_60_geospatial_measure_vocabulary() +
    pdf_forms_signatures_requirement_0_63_point_data_vocabulary()
  assert_eq(geo.contains("Bounds GCS DCS"), true)
  assert_eq(geo.contains("PtData Cloud Names LAT LON ALT XPTS"), true)
}
