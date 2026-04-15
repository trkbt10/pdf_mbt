# SDD Draft: Form Field Value Extraction

Reference: ISO 32000-2 §12.7

## Requirements

### Requirement 1: AcroForm field value reading
The reader SHALL extract current values from interactive form fields.

#### 1.1: Text field values
For text fields (/FT /Tx), the reader SHALL extract the /V entry as a
text string representing the field's current value.

#### 1.2: Choice field values
For choice fields (/FT /Ch — combo boxes, list boxes), the reader SHALL
extract the /V entry as the selected option value(s). For multi-select
fields, /V may be an array of strings.

#### 1.3: Button field states
For button fields (/FT /Btn — checkboxes, radio buttons), the reader
SHALL extract the /V or /AS entry to determine the selected state.
The value `/Off` indicates unchecked; any other name indicates checked
with that appearance state.

#### 1.4: Signature field detection
For signature fields (/FT /Sig), the reader SHALL detect whether a
signature value (/V) is present, indicating the field is signed.

### Requirement 2: Field hierarchy traversal
The reader SHALL traverse the AcroForm field tree from the catalog's
/AcroForm /Fields array, resolving parent-child relationships and
inheriting properties (/FT, /Ff, /T) from parent nodes.

### Requirement 3: Flat form data export
The reader SHALL provide a function that returns all form field
name-value pairs as a flat map (field fully-qualified name → value string),
suitable for programmatic form data extraction.
