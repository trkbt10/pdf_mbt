# SDD Draft: PDF Writing

Reference: ISO 32000-2 §7.5 (file structure)

## Requirements

### Requirement 1: Incremental save
The writer SHALL append new or modified objects to the end of an existing
PDF file (incremental update), preserving the original file content.

#### 1.1: New cross-reference section
The writer SHALL write a new xref table (or xref stream) and trailer
that points to the previous xref section via /Prev.

#### 1.2: Modified object serialization
Modified indirect objects SHALL be serialized in standard PDF syntax
(number generation `obj` ... `endobj`) with updated byte offsets in
the new xref.

### Requirement 2: Object serialization
The writer SHALL serialize all PDF object types to valid PDF syntax:
booleans, integers, real numbers, strings (literal and hex), names,
arrays, dictionaries, streams, and indirect references.

### Requirement 3: New PDF creation
The writer SHALL create a valid PDF file from scratch with:
- PDF header (%PDF-2.0)
- Catalog with /Pages reference
- Page tree with at least one page
- Cross-reference table and trailer

### Requirement 4: Page content writing
The writer SHALL generate content streams from a structured API:
- Text operators (BT/ET, Tf, Td, Tj)
- Basic graphics (path operators, colour operators)
- Font resource references

### Requirement 5: Stream compression
The writer SHALL optionally compress stream data using FlateDecode
before writing, to produce compact output files.
