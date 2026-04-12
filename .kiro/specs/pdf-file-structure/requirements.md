# Requirements Document

## Project Description (Input)
Implement a PDF file structure reader in MoonBit, conforming to ISO 32000-2:2020 (PDF 2.0) §7.5. The reader parses the four elements of a PDF file — header, body, cross-reference table, and trailer — enabling random access to any indirect object by its object number and generation number. This layer builds on `pdf-objects` (Phase 1) and provides the foundation for document structure parsing (Catalog, Page tree, etc.).

Reference specification: `spec/extracted/7.5-file-structure.spec.txt`, `spec/extracted/annex-h-examples.spec.txt`

Dependency: `pdf-objects` spec (Requirements 1–16) is prerequisite.

## Requirements

### Requirement 1: File Header Parsing
The file reader shall parse the PDF file header to extract version information per §7.5.2.

#### Acceptance Criteria
- When the file reader encounters the byte sequence `%PDF-X.Y` at the start of the file, the file reader shall extract the version number X.Y
- The file reader shall accept versions `1.0` through `1.7` and `2.0` as valid PDF versions
- The file reader shall require an EOL marker (CR, LF, or CR+LF) immediately after the version digits
- When a comment line containing four or more bytes with values 128 or above follows the header, the file reader shall recognize it as a binary file indicator
- The file reader shall use the position of the `%` byte (0x25) as the base for all byte offset calculations

### Requirement 2: Reverse Parsing from File End
The file reader shall locate the cross-reference section by scanning backward from the end of the file per §7.5.5.

#### Acceptance Criteria
- The file reader shall search backward from the end of the file for the `%%EOF` marker
- The file reader shall locate the `startxref` keyword preceding the `%%EOF` marker
- The file reader shall parse the decimal integer after `startxref` as the byte offset of the most recent cross-reference section
- When multiple `%%EOF` markers exist due to incremental updates, the file reader shall use the last `%%EOF` in the file

### Requirement 3: Cross-Reference Table Parsing
The file reader shall parse the traditional cross-reference table format introduced by the `xref` keyword per §7.5.4.

#### Acceptance Criteria
- The file reader shall recognize a cross-reference section starting with the `xref` keyword on its own line
- The file reader shall parse subsection headers as `<first-object-number> <entry-count>` pairs
- The file reader shall parse each cross-reference entry as exactly 20 bytes including EOL
- For in-use entries (type `n`), the file reader shall extract the 10-digit zero-padded byte offset, the 5-digit zero-padded generation number, and the `n` marker
- For free entries (type `f`), the file reader shall extract the 10-digit next-free-object number, the 5-digit generation number, and the `f` marker
- The file reader shall accept SP+CR, SP+LF, or CR+LF as the 2-byte EOL in cross-reference entries
- The file reader shall verify that object 0 is always free with generation number 65535
- The file reader shall correctly parse cross-reference sections containing multiple subsections

### Requirement 4: Trailer Dictionary Parsing
The file reader shall parse the trailer dictionary following the cross-reference table per §7.5.5.

#### Acceptance Criteria
- The file reader shall parse the dictionary following the `trailer` keyword as the trailer dictionary
- The file reader shall validate the required `Size` entry (integer, direct object) representing the total cross-reference entry count (highest object number plus one)
- The file reader shall extract the required `Root` entry (indirect reference) pointing to the Catalog dictionary
- The file reader shall recognize the optional `Prev` entry (integer, direct object) as the byte offset to the previous cross-reference section
- The file reader shall recognize the optional `Encrypt` entry as a reference to the encryption dictionary
- The file reader shall recognize the optional `Info` entry (indirect reference) as a reference to the information dictionary
- The file reader shall recognize the `ID` entry (array of two byte-strings, direct object, required in PDF 2.0) as file identifiers

### Requirement 5: Incremental Update Tracking
The file reader shall follow the `Prev` chain to merge all cross-reference sections per §7.5.6.

#### Acceptance Criteria
- The file reader shall follow the `Prev` entry from the most recent trailer to locate previous cross-reference sections
- For the same object number, the file reader shall prefer the entry from the most recent cross-reference section
- The file reader shall treat free entries (type `f`) as indicating the object has been deleted and shall exclude it from the resolved object map
- The file reader shall produce a single merged mapping from object number to byte offset (or object stream location) covering all cross-reference sections

### Requirement 6: Object Streams
The file reader shall parse object streams (type `/ObjStm`) to access compressed indirect objects per §7.5.7.

#### Acceptance Criteria
- The file reader shall recognize a stream with `/Type /ObjStm` in its dictionary as an object stream
- The file reader shall use the required `N` entry (integer) as the count of objects in the stream and the required `First` entry (integer) as the byte offset of the first object within the decoded stream
- The file reader shall parse the header portion of the decoded stream as N pairs of integers (object number, relative byte offset)
- The file reader shall read each object starting at its specified byte offset within the decoded stream, without `obj` or `endobj` keywords
- The file reader shall assume generation number 0 for all objects within an object stream
- The file reader shall reject stream objects stored inside an object stream

### Requirement 7: Cross-Reference Streams
The file reader shall parse cross-reference streams (type `/XRef`) as an alternative to cross-reference tables per §7.5.8.

#### Acceptance Criteria
- The file reader shall recognize a stream with `/Type /XRef` in its dictionary as a cross-reference stream
- The file reader shall parse the required stream dictionary entries: `Type` (name, direct), `Size` (integer, direct), `W` (array of three integers, direct), and optional `Index` (array, direct, defaults to `[0 Size]`)
- The file reader shall use the `W` array to determine field widths in bytes for each entry (e.g. `[1 2 2]` means 1-byte type, 2-byte field2, 2-byte field3)
- The file reader shall read multi-byte fields in big-endian order (most significant byte first)
- The file reader shall decode Type 0 entries as free objects (field2 = next free object number, field3 = generation number), Type 1 entries as uncompressed in-use objects (field2 = byte offset from file start, field3 = generation number), and Type 2 entries as compressed objects (field2 = object stream number, field3 = index within the object stream)
- When `W[0]` is 0, the file reader shall default the type field to 1 (in-use uncompressed)
- The file reader shall not decrypt cross-reference streams

### Requirement 8: Hybrid-Reference Files
The file reader shall handle files containing both cross-reference tables and cross-reference streams per §7.5.8.4.

#### Acceptance Criteria
- When the trailer dictionary contains an `XRefStm` entry (integer byte offset), the file reader shall recognize the file as a hybrid-reference file
- The file reader shall resolve objects in this priority order: current cross-reference table first, then the `XRefStm`-referenced cross-reference stream, then `Prev`-referenced sections

### Requirement 9: Random-Access Object Loading
The file reader shall load any indirect object by its object number and generation number on demand.

#### Acceptance Criteria
- The file reader shall resolve an object number and generation number to its byte offset (or object stream location) using the merged cross-reference data
- For Type 1 entries (uncompressed), the file reader shall seek to the byte offset and parse `N G obj ... endobj` using the pdf-objects parser
- For Type 2 entries (compressed in object stream), the file reader shall decode the object stream and extract the object at the specified index
- The file reader shall support lazy loading so that objects are parsed only when first accessed
- The file reader shall return `PdfObject::Null` for references to nonexistent objects

### Requirement 10: Sample File Validation
The file reader shall correctly parse ISO 32000-2 Annex H samples and the bundled PDF 2.0 example files.

#### Acceptance Criteria
- The file reader shall parse the Annex H.2 minimal PDF (Catalog, Pages, Page, Content stream, Metadata) and access all objects
- The file reader shall parse the Annex H.3 simple text string example (font resources, content stream with text operators) and access all objects
- The file reader shall parse `spec/pdf20examples/Simple PDF 2.0 file.pdf` and successfully load all indirect objects
- The file reader shall parse `spec/pdf20examples/PDF 2.0 via incremental save.pdf` with its incremental updates and resolve objects to their most recent versions
