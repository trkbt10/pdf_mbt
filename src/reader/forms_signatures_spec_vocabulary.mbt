///|
/// ISO 32000-2:2020 12.7.1 General forms vocabulary. Interactive forms
/// collect information from a user, may be submitted, reset, imported, or
/// exported, and may be represented by AcroForm fields, FDF payloads, widgets,
/// non-interactive PrintField markers, XFA legacy data, and caller-owned
/// effects. This reader keeps form behavior structural and side-effect free.
pub fn pdf_forms_signatures_requirement_0_1_general_vocabulary() -> String {
  "12.7.1 General PDF document may contain both interactive and non-Interactive forms. " +
  "An interactive form PDF 1.2 sometimes referred to as an AcroForm is a collection of fields for gathering information interactively from the user. " +
  "A PDF document may contain any number of fields appearing on any combination of pages all of which make up a single global interactive form spanning the entire document. " +
  "Arbitrary subsets of these fields can be imported or exported from the document. Interactive forms are not form XObjects 8.10. " +
  "A non-interactive form PDF 1.7 is a static representation of form fields including text fields and radio buttons converted into non-interactive PDF files or designed to be printed out and filled in manually."
}

///|
/// ISO 32000-2:2020 12.7.2 Interactive Forms vocabulary. A document-wide
/// AcroForm dictionary owns the interactive form field tree, widgets may be
/// separate annotations or merged with field dictionaries, terminal and
/// non-terminal fields inherit attributes, and page annotations keep their
/// existing enumeration semantics.
pub fn pdf_forms_signatures_requirement_0_2_interactive_forms_vocabulary() -> String {
  "12.7.2 Interactive Forms Each field in a document form shall be defined by a field dictionary. " +
  "Fields can be organised hierarchically and can inherit attributes from ancestors in the field hierarchy. " +
  "A field children in the hierarchy may include widget annotations 12.5.6.19 that define its appearance on the page. " +
  "A field that has children that are fields is called a non-terminal field; a field that does not have children that are fields is called a terminal field. " +
  "When a field has only a single associated widget annotation the contents of the field dictionary and annotation dictionary 12.5.2 may be merged into a single dictionary containing entries that pertain to both a field and an annotation. " +
  "If such an object defines an appearance stream the appearance shall be consistent with the object current value as a field. Section 4."
}

///|
/// ISO 32000-2:2020 12.7.4.1 field dictionary general vocabulary. Each
/// field in an interactive form is an indirect field dictionary, field
/// dictionaries may be organised hierarchically, inheritable attributes flow
/// from parent fields, and Tables 226 and 227 define common entries and field
/// flags common to all field types.
pub fn pdf_forms_signatures_requirement_0_4_field_dictionary_general_vocabulary() -> String {
  "12.7.4.1 General Each field in a document interactive form shall be defined by a field dictionary which shall be an indirect object. " +
  "Field dictionaries may be organised hierarchically into one or more tree structures. Many field attributes are inheritable; if not explicitly specified for a field their values are taken from the parent in the field hierarchy. " +
  "Table 226 Entries common to all field dictionaries includes FT Parent Kids T TU TM Ff V DV AA. Table 227 Field flags common to all field types includes ReadOnly Required NoExport. " +
  "An interactive PDF processor shall not limit the range of inheritance for field dictionaries."
}

///|
/// ISO 32000-2:2020 12.7.4.2 Field names vocabulary. Partial field names T
/// combine with PERIOD 2Eh separators into fully qualified names, alternate
/// names TU and mapping names TM remain structural metadata, duplicate fully
/// qualified names require consistent field data, and invalid partial names
/// are diagnosed as InvalidForm.
pub fn pdf_forms_signatures_requirement_0_5_field_names_vocabulary() -> String {
  "12.7.4.2 Field names The T entry in the field dictionary holds a text string defining the field partial field name. " +
  "The fully qualified field name shall be constructed from the partial field names of the field and all ancestors. " +
  "For a field with no parent the partial and fully qualified names are the same. For a child field the fully qualified name is formed by appending the child partial name to the parent fully qualified name separated by a PERIOD 2Eh. " +
  "A partial name shall not contain a PERIOD character. A field dictionary without a partial field name T entry shall not be considered a field but simply a Widget annotation. " +
  "Actual field dictionaries with the same fully qualified field name shall have the same field type FT value V and default value DV."
}

///|
/// ISO 32000-2:2020 12.7.5.2.1 General button field vocabulary. Table 229
/// defines button field flags including NoToggleToOff, Radio, Pushbutton, and
/// RadiosInUnison. Push-buttons do not retain permanent V or DV values while
/// check boxes and radio buttons use appearance state names such as Off.
pub fn pdf_forms_signatures_requirement_0_8_button_general_vocabulary() -> String {
  "12.7.5.2.1 General A button field field type Btn represents an interactive control on the screen that the user can manipulate with the mouse. " +
  "There are three types of button fields: push-button, check box toggles between two states on and off, and radio button fields contain a set of related buttons. " +
  "For button fields bits 15 16 17 and 26 shall indicate intended behaviour as defined in Table 229 Field flags specific to button fields. " +
  "NoToggleToOff Radio Pushbutton RadiosInUnison HTML radio buttons mutually exclusive same value for the on state."
}

///|
/// ISO 32000-2:2020 12.7.5.2.2 Push-buttons vocabulary. Table 229
/// Pushbutton fields activate actions and do not preserve a permanent value;
/// malformed combinations with radio button state are retained as structural
/// constraints for caller-owned UI behavior.
pub fn pdf_forms_signatures_requirement_0_9_push_buttons_vocabulary() -> String {
  "12.7.5.2.2 Push-buttons A push-button field shall have a field type of Btn and the Pushbutton flag Table 229 set to one. " +
  "Because this type retains no permanent value it shall not use the V and DV entries in the field dictionary Table 226 Entries common to all field dictionaries."
}

///|
/// ISO 32000-2:2020 12.7.5.2.3 Check boxes vocabulary. Check box fields use
/// button appearance state names, Off for the unselected state, and export
/// values from the selected normal appearance name without mutating form data.
pub fn pdf_forms_signatures_requirement_0_10_check_boxes_vocabulary() -> String {
  "12.7.5.2.3 Check boxes A check box field represents one or more check boxes that toggle between two states on and off when manipulated by the user with mouse or keyboard. " +
  "Its field type shall be Btn and its Pushbutton and Radio flags Table 229 shall both be clear. " +
  "Each state can have a separate appearance defined by an appearance stream in the appearance dictionary of the field widget annotation 12.5.5. " +
  "The appearance for the off state is optional but if present shall be stored under the name Off. " +
  "The V entry holds a name object representing the check box appearance state and the value of V shall also be the value of AS; if not equal AS is used instead of V."
}

///|
/// ISO 32000-2:2020 12.7.5.4 Choice fields vocabulary. Choice fields Ch use
/// Opt arrays, combo boxes, editable combo boxes, sort metadata, multi-select
/// arrays, TI top index, I selected indices, and CommitOnSelChange, while
/// caller-owned import/export effects remain outside the reader.
pub fn pdf_forms_signatures_requirement_0_13_choice_fields_vocabulary() -> String {
  "12.7.5.4 Choice fields A choice field shall have a field type of Ch that contains several text items one or more selected as the field value. " +
  "The items may be presented as a scrollable list box or a combo box drop-down list with optional editable text box controlled by the Edit bit. " +
  "Table 233 Field flags specific to choice fields: Combo Edit Sort MultiSelect DoNotSpellCheck CommitOnSelChange. " +
  "Table 234 Additional entries specific to a choice field includes Opt options, TI top index, I selected indices, and V value."
}

///|
/// ISO 32000-2:2020 12.7.6.1 General form action vocabulary. Submit-form,
/// reset-form, and import-data actions preserve F file specifications, Fields
/// arrays, Include and Exclude plans, flags, character set, raw dictionaries,
/// and side-effect-free selection metadata.
pub fn pdf_forms_signatures_requirement_0_15_form_actions_general_vocabulary() -> String {
  "12.7.6.1 General Interactive forms also support special types of actions in addition to those described in 12.6.4 Action types: submit-form action, reset-form action, and import-data action. " +
  "The reader represents SubmitForm ResetForm ImportData as action structures preserving F file specification, Fields arrays, Flags, Include Exclude plans, and side-effect free structural data."
}

///|
/// ISO 32000-2:2020 12.7.6.3 Reset-form action vocabulary. ResetForm uses
/// the Fields array and Include or Exclude rule to select fields whose current
/// values would be reset to default values by caller-owned behavior.
pub fn pdf_forms_signatures_requirement_0_17_reset_form_action_vocabulary() -> String {
  "12.7.6.3 Reset-form action Upon invocation an interactive PDF processor shall reset selected interactive form fields to default values by setting V to DV. " +
  "If no default value is defined V shall be removed. For fields that can have no value such as push-buttons the action has no effect. " +
  "Table 241 Additional entries specific to a reset-form action: S shall be ResetForm, Fields array identifies fields to reset or exclude, and Flags integer. " +
  "Table 242 Flag for reset-form actions defines Include/Exclude bit position 1; descendants of specified fields are reset as well."
}

///|
/// ISO 32000-2:2020 12.7.6.4 Import-data action vocabulary. ImportData points
/// at an FDF file specification and imports field values, flag plans,
/// annotation payloads, differences, and JavaScript descriptors only as
/// structural data for caller-owned workflows.
pub fn pdf_forms_signatures_requirement_0_18_import_data_action_vocabulary() -> String {
  "12.7.6.4 Import-data action Upon invocation a PDF processor shall import data from Forms Data Format FDF, XFDF XML-based Forms Data Format ISO 19444-1, or any other supported data format into the document interactive form from a specified file. " +
  "Table 243 Additional entries specific to an import-data action: S name shall be ImportData and F file specification is the FDF XFDF or other data format file from which to import the data."
}

///|
/// ISO 32000-2:2020 12.7.8.1 General FDF vocabulary. Forms Data Format
/// application/vnd.fdf represents stand-alone form data, annotations, pages,
/// templates, embedded FDF streams, differences, JavaScript, and source or
/// target PDF file descriptors separate from normal PDF document opening.
pub fn pdf_forms_signatures_requirement_0_20_fdf_general_vocabulary() -> String {
  "12.7.8.1 General This subclause describes Forms Data Format FDF the file format used for interactive form data PDF 1.2. " +
  "FDF can be used when submitting form data to a server, receiving the response, and incorporating it into the interactive form. " +
  "It can also be used to export form data to stand-alone files that can be stored transmitted electronically and imported back into the corresponding PDF interactive form. " +
  "Beginning in PDF 1.3 FDF can be used to define a container for annotations separate from the PDF document to which they apply. " +
  "FDF is based on PDF; it uses the same syntax and has essentially the same file structure 7.5 File structure. " +
  "The cross-reference table 7.5.4 is optional. FDF files shall not be updated 7.5.6 Incremental updates. Objects shall only be of generation 0 generation number 0 and no two objects within an FDF file shall have the same object number. " +
  "The document structure is much simpler than PDF since the body of an FDF document consists of only one required object. The length of a stream shall not be specified by an indirect object. " +
  "FDF shall use the MIME media type application/vnd.fdf. On Microsoft Windows and UNIX platforms FDF files shall have extension .fdf; on Mac OS file type FDF."
}

///|
/// ISO 32000-2:2020 12.7.8.2.1 FDF file structure vocabulary. An FDF file
/// has a header, body, optional cross-reference table, trailer Root catalog,
/// generation-zero indirect objects, duplicate object-number rejection, and a
/// final EOF marker independent of PDF incremental updates.
pub fn pdf_forms_signatures_requirement_0_21_fdf_structure_vocabulary() -> String {
  "12.7.8.2.1 General An FDF file shall be structured in essentially the same way as a PDF file but contains only elements required for export and import of interactive form and annotation data. " +
  "It consists of three required elements and one optional element Figure 85 FDF file structure: one-line header identifying version number, body containing objects that make up content, optional cross-reference table containing information about indirect objects, optional trailer giving location of cross-reference table and special objects within the body."
}

///|
/// ISO 32000-2:2020 12.7.8.2.3 FDF body vocabulary. The body contains
/// indirect objects using generation number 0, including the catalog and any
/// referenced field, annotation, page, template, or embedded descriptors.
pub fn pdf_forms_signatures_requirement_0_23_fdf_body_vocabulary() -> String {
  "12.7.8.2.3 FDF body The body of an FDF file shall consist of a sequence of indirect objects representing the file catalog dictionary and any additional objects that the catalog dictionary references. " +
  "The objects are of the same basic types described in 7.5 File structure other than the PDF-n.m and EOF comments; just as in PDF, objects in FDF can be direct or indirect."
}

///|
/// ISO 32000-2:2020 12.7.9 Non-interactive forms vocabulary. PrintField
/// marked-content and page-content markers are not interactive AcroForm
/// fields; the reader preserves them as raw parser metadata separate from
/// widget-backed field records.
pub fn pdf_forms_signatures_requirement_0_29_non_interactive_forms_vocabulary() -> String {
  "12.7.9 Non-interactive forms PrintField marked content page content metadata separate from AcroForm widget fields"
}

///|
/// ISO 32000-2:2020 12.8.2.1 General transform vocabulary. Signature
/// reference dictionaries define TransformMethod, TransformParams,
/// DigestMethod, and direct-object requirements for DocMDP, UR, and FieldMDP
/// constraints without performing object-diff validation.
pub fn pdf_forms_signatures_requirement_0_31_signature_transform_general_vocabulary() -> String {
  "12.8.2.1 General Transform methods along with transform parameters shall determine which objects are included and excluded in revision comparison. " +
  "Signature reference dictionaries carry TransformMethod, TransformParams, DigestMethod, DocMDP, UR, FieldMDP, direct object requirements, and structural constraints without performing object diff validation."
}

///|
/// ISO 32000-2:2020 12.8.2.2.2 DocMDP validation vocabulary. DocMDP transform
/// parameters expose modification permissions P, version V, digest method,
/// signed revision inputs, and document modification constraints as external
/// validation work items.
pub fn pdf_forms_signatures_requirement_0_33_docmdp_validation_vocabulary() -> String {
  "12.8.2.2.2 Validating signatures that use the DocMDP transform method. A PDF processor first shall verify the byte range digest and then verify that modifications made to the document are permitted by transform parameters. " +
  "The ByteRange entry in the signature dictionary Table 255 identifies the signed state of the document at signing. " +
  "Table 257 Entries in the DocMDP transform parameters dictionary: Type TransformParams, P permissions values 1 2 3, V name value 1.2. " +
  "Incremental updates that include only DSS 12.8.4.3 Document Security Store and/or document timestamps 12.8.5 are not considered document changes for DocMDP."
}

///|
/// ISO 32000-2:2020 12.8.3.1 General signature interoperability vocabulary.
/// Signature handlers process Filter and SubFilter values, Contents bytes,
/// ByteRange slices, PKCS 1, PKCS 7, CMS, CAdES, PAdES, certificates,
/// timestamps, revocation data, and policy checks outside the reader.
pub fn pdf_forms_signatures_requirement_0_35_signature_interop_general_vocabulary() -> String {
  "12.8.3.1 General PDF processors allow interoperability between signature handlers. PDF 2.0 defines new signature formats for PAdES signatures PDF Advanced Electronic Signatures as defined by ETSI EN 319 142-1 and ETSI EN 319 142-2. " +
  "SubFilter specifies encoding of signature value and key information while Filter specifies preferred handler. " +
  "SubFilter values are based on RSA Security standards, IETF PKIX, ETSI, and ECDSA Internet RFC 5480. " +
  "Table 260 SubFilter value algorithm support includes adbe.pkcs7.detached, adbe.pkcs7.sha1, adbe.x509.rsa_sha1, ETSI.CAdES.detached, ETSI.RFC3161, SHA1, SHA256, SHA384, SHA512, RIPEMD160, RSA, DSA, ECDSA."
}

///|
/// ISO 32000-2:2020 12.8.3.3.2 CMS revocation vocabulary. CMS-based
/// signatures may include certificate path information, revocation evidence,
/// OCSP responses, CRL data, timestamps, and validation data that are routed
/// to external handlers without trust assertions.
pub fn pdf_forms_signatures_requirement_0_38_cms_revocation_vocabulary() -> String {
  "12.8.3.3.2 Revocation of CMS-based signatures certificate path OCSP CRL timestamp validation data external handler"
}

///|
/// ISO 32000-2:2020 12.8.3.4.3 PAdES attributes vocabulary. PAdES signatures
/// use CMS attributes from Internet RFC 5652, ETSI CAdES attributes, Table
/// 319 profile data, signing certificate references, revocation values, and
/// timestamp or policy attributes as handler-owned validation inputs.
pub fn pdf_forms_signatures_requirement_0_41_pades_attributes_vocabulary() -> String {
  "12.8.3.4.3 Attributes for PAdES signatures Internet RFC 5652 Table 319 CMS CAdES signing certificate revocation timestamp policy"
}

///|
/// ISO 32000-2:2020 12.8.3.4.4 Profiles of ETSI.CAdES.detached vocabulary.
/// The ETSI.CAdES.detached SubFilter may follow PAdES-E-BES and
/// PAdES-E-EPES profiles compatible with ETSI EN 319 122-2 and ETSI EN
/// 319 142-2, preserving commitment-type-indication, Reason,
/// signature-policy-identifier, seed values, CAdES-T timestamps, document
/// timestamp DTS dictionaries, and signed-attribute validation as external
/// handler work.
pub fn pdf_forms_signatures_requirement_0_42_cades_detached_profiles_vocabulary() -> String {
  "12.8.3.4.4 Profiles of ETSI.CAdES.detached The signatures using the SubFilter value ETSI.CAdES.detached may follow one of two profiles denoted as PAdES-E-BES Basic Electronic Signature and PAdES-E-EPES Explicit Policy Electronic Signature. " +
  "These are compatible with ETSI EN 319 122-2 CAdES-E-BES and CAdES-E-EPES and also denoted in ETSI EN 319 142-2. " +
  "If discrepancies exist between this document and ETSI this document shall prevail. " +
  "CMS SignedData attributes may include commitment-type-indication; if present a Reason entry shall not be used, if absent Reason may be used. " +
  "For PAdES-E-EPES a signature-policy-identifier shall be present as a signed attribute and CAdES clause 5.2.9 rules apply. Signature policy parameters take precedence over seed values in 12.7.5.5 Signature fields. " +
  "Further CAdES-T compatible capabilities may be provided by timestamp attribute or document timestamp DTS dictionary 12.8.5. All signed attributes shall be checked for proper values by signature validation software."
}

///|
/// ISO 32000-2:2020 12.8.3.4.5 PAdES validation requirements vocabulary.
/// Validation plans gather subfilter, byte ranges, contents, transform
/// constraints, certificate path inputs, revocation references, timestamps,
/// and signature-policy work items while never marking a signature valid.
pub fn pdf_forms_signatures_requirement_0_43_pades_validation_requirements_vocabulary() -> String {
  "12.8.3.4.5 Requirements for validation of PAdES signatures byte ranges contents certificate path revocation timestamps signature policy"
}

///|
/// ISO 32000-2:2020 12.8.3.4.7 current-time PAdES revocation vocabulary.
/// External handlers check revocation at the current time using VRI-specific
/// evidence, DSS global arrays, embedded signature evidence, OCSP, CRL, and
/// timestamp-related validation data.
pub fn pdf_forms_signatures_requirement_0_45_current_time_revocation_vocabulary() -> String {
  "12.8.3.4.7 Revocation checking PAdES signatures current time VRI DSS embedded signature OCSP CRL timestamp evidence"
}

///|
/// ISO 32000-2:2020 12.8.3.4.8 past-time PAdES revocation vocabulary.
/// External handlers check revocation at a time in the past by using signed
/// timestamps, DSS and VRI evidence, initial and subsequent document
/// timestamp chains, and policy constraints.
pub fn pdf_forms_signatures_requirement_0_46_past_time_revocation_vocabulary() -> String {
  "12.8.3.4.8 Revocation checking PAdES signatures time in the past signed timestamp DSS VRI document timestamp chain policy"
}

///|
/// ISO 32000-2:2020 12.8.4.4 Validation-related information vocabulary. VRI
/// dictionaries use uppercase signature hash keys and may provide Cert, CRL,
/// OCSP, TU, and TS entries for long-term validation evidence without logging
/// sensitive certificate or revocation bytes.
pub fn pdf_forms_signatures_requirement_0_50_vri_vocabulary() -> String {
  "12.8.4.4 Validation-related information VRI A signature VRI dictionary shall contain validation-related information for one signature used to successfully validate the given signature. " +
  "It references certificates Cert from Certs in the DSS dictionary, CRLs from the CRL list, and OCSP responses from the OCSP response list. Empty Cert CRL or OCSP arrays are omitted. " +
  "The VRI dictionary may also contain the time data was created and a timestamp token with UTC time. It shall not record an unsuccessful validation attempt. " +
  "Table 262 Entries in the signature validation-related information VRI dictionary: Type VRI, Cert DER-encoded X.509 certificate Internet RFC 5280, CRL, OCSP, TU date, TS DER-encoded timestamp Internet RFC 3161 updated by Internet RFC 5816."
}

///|
/// ISO 32000-2:2020 12.8.5.1 document timestamp vocabulary. A document
/// timestamp dictionary establishes the exact contents of the complete PDF
/// file at the time indicated in the timestamp token; ordering uses signed
/// revision boundaries and complete-file byte range expectations.
pub fn pdf_forms_signatures_requirement_0_52_document_timestamp_general_vocabulary() -> String {
  "12.8.5.1 General A document timestamp dictionary establishes the exact contents of the complete PDF file at the time indicated in the timestamp token. " +
  "Document timestamp DTS dictionaries are represented structurally with timestamp token, signed revision boundary, ByteRange, complete PDF file contents, and ordering inputs for external validation handlers."
}

///|
/// ISO 32000-2:2020 12.8.5.2 initial document timestamp vocabulary. Initial
/// document timestamp dictionaries use SubFilter ETSI.RFC3161 with Internet
/// RFC 3161 timestamp tokens as updated by Internet RFC 5816 and require a
/// complete-file byte range expectation for ordering.
pub fn pdf_forms_signatures_requirement_0_53_initial_document_timestamp_vocabulary() -> String {
  "12.8.5.2 Initial document timestamp dictionary ETSI.RFC3161 Internet RFC 3161 Internet RFC 5816 complete file ByteRange ordering"
}

///|
/// ISO 32000-2:2020 12.8.6 Permissions vocabulary. Catalog Permissions from
/// Table 29 may contain DocMDP and deprecated UR3 signature dictionaries,
/// permission handlers, usage-rights metadata, and security-handler policy
/// inputs, all preserved without enforcement.
pub fn pdf_forms_signatures_requirement_0_55_permissions_vocabulary() -> String {
  "12.8.6 Permissions The Perms entry in the document catalog dictionary Table 29 shall specify a permissions dictionary PDF 1.5. " +
  "Each entry Table 263 Entries in a permissions dictionary specifies the name of a permission handler controlling access permissions for the document, similar to security handlers Table 22 but not requiring encryption. " +
  "DocMDP is an indirect reference to a signature dictionary Table 255 containing a Reference entry with DocMDP transform method and transform parameters. " +
  "UR3 deprecated in PDF 2.0 is a signature dictionary for usage rights granted for the document through a UR transform method."
}

///|
/// ISO 32000-2:2020 12.8.7 legal content attestations vocabulary. Catalog
/// Legal entries from Table 29 record JavaScriptActions, LaunchActions,
/// URIActions, MovieActions, SoundActions, HideAnnotationActions,
/// GoToRemoteActions, annotations, OptionalContent, and Attestation text
/// without making legal trust decisions.
pub fn pdf_forms_signatures_requirement_0_56_legal_attestations_vocabulary() -> String {
  "12.8.7 Legal content attestations Catalog Table 29 JavaScriptActions LaunchActions URIActions MovieActions SoundActions HideAnnotationActions GoToRemoteActions annotations OptionalContent Attestation"
}

///|
/// ISO 32000-2:2020 12.10.2 geospatial measure vocabulary. GEO dictionaries
/// expose Bounds, GCS, DCS, PDU, GPTS, LPTS, PCSM, default neatline values,
/// point cardinality, unit names, and PCSM priority metadata without EPSG
/// lookup, WKT parsing, or coordinate conversion.
pub fn pdf_forms_signatures_requirement_0_60_geospatial_measure_vocabulary() -> String {
  "12.10.2 Geospatial measure GEO Bounds GCS DCS PDU GPTS LPTS PCSM default neatline point cardinality unit names priority"
}

///|
/// ISO 32000-2:2020 12.10.5 point data vocabulary. PtData dictionaries with
/// Cloud subtype use Names columns such as LAT, LON, ALT and XPTS tuples; each
/// tuple must match the Names arity and malformed tuple shapes raise
/// InvalidMeasure.
pub fn pdf_forms_signatures_requirement_0_63_point_data_vocabulary() -> String {
  "12.10.5 Point data dictionary Any 2D object Viewport image XObject or form XObject that contains a measure dictionary Table 266 of subtype GEO can optionally include a PtData entry. " +
  "PtData is a point data dictionary or array of point data dictionaries of extended data associated with points in 2D space. " +
  "Table 272 Entries in a point data dictionary: Type shall be PtData, Subtype shall be Cloud, PtData Cloud Names LAT LON ALT XPTS, Names array identifies internal data elements, predefined names LAT latitude, LON longitude, ALT altitude, XPTS array of arrays whose interior member count corresponds to the size of the Names array. " +
  "The XPTS array is a collection of tuples without guaranteed ordering or relationship from point to point."
}
