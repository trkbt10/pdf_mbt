# SDD Draft: PDF CLI Tool

Modeled after poppler-utils (pdftotext, pdfinfo, pdfimages) — the most
widely-used PDF command-line tool suite.

## Requirements

### Requirement 1: Subcommand architecture
The CLI SHALL use a subcommand-based architecture:
`pdf <subcommand> [options] <input.pdf> [output]`

Subcommands: `text`, `info`, `images`, `pages`.

#### 1.1: Global options
All subcommands SHALL accept:
- `-f <int>` / `--first-page <int>` — first page (1-based, default 1)
- `-l <int>` / `--last-page <int>` — last page (default: last)
- `--password <string>` — document password (for encrypted PDFs)
- `-h` / `--help` — show subcommand help
- `-v` / `--version` — show version

### Requirement 2: text subcommand (pdftotext equivalent)
`pdf text [options] <input.pdf> [output.txt]`

SHALL extract text from PDF pages and write to stdout or a file.

#### 2.1: Basic text extraction
For each page in the specified range, the CLI SHALL extract Unicode text
using `PdfPage::extracted_text` and output it. Pages SHALL be separated
by form-feed characters (`\f`) matching pdftotext behaviour.

#### 2.2: Output destination
When `output.txt` is provided, write to that file. When omitted, write
to stdout.

#### 2.3: Page range
`-f` and `-l` SHALL restrict extraction to the specified page range.
Page numbers are 1-based. Out-of-range values SHALL be clamped silently.

#### 2.4: Layout mode (future)
`--layout` flag (reserved for future use). When absent, text is extracted
in content stream order without spatial layout reconstruction.

### Requirement 3: info subcommand (pdfinfo equivalent)
`pdf info [options] <input.pdf>`

SHALL display document metadata and structure information to stdout.

#### 3.1: Basic metadata
The output SHALL include:
- Title, Author, Subject, Creator (from Info dictionary)
- PDF version
- Page count
- Encrypted: yes/no
- File size in bytes

#### 3.2: Page geometry
When `--pages` flag is set, the output SHALL additionally list each page's
MediaBox dimensions and rotation.

#### 3.3: Output format
Default output is human-readable key-value pairs (matching pdfinfo format).
`--json` flag SHALL output JSON instead.

### Requirement 4: images subcommand (pdfimages equivalent)
`pdf images [options] <input.pdf> <output-prefix>`

SHALL extract images from PDF pages and write them as individual files.

#### 4.1: Image enumeration and extraction
For each page in the range, enumerate Image XObjects. For each image,
decode to RGBA pixels and write to a file named
`<output-prefix>-<page>-<index>.ppm` (PPM P6 format for simplicity).

#### 4.2: Raw JPEG passthrough
When `--raw` flag is set and the image uses DCTDecode, write the raw
JPEG bytes directly as `.jpg` files without decoding and re-encoding.

#### 4.3: List mode
`--list` flag SHALL list image metadata (page, index, width, height,
colour space, bits per component) without extracting.

### Requirement 5: pages subcommand
`pdf pages [options] <input.pdf>`

SHALL list page-level information.

#### 5.1: Page listing
Output one line per page: page number, MediaBox dimensions, rotation.

#### 5.2: Page count mode
`--count` flag SHALL output only the total page count as a single integer.

### Requirement 6: Diagnostic and capability reporting
The CLI SHALL report what it can and cannot do for a given PDF, surfacing
unimplemented features rather than silently skipping them.

#### 6.1: check subcommand
`pdf check [options] <input.pdf>`

SHALL analyze a PDF file and report which features are used and whether
the library can handle them. Output a table of features with status:
- **supported**: feature is used and fully handled
- **partial**: feature is used but only partially handled (e.g., text
  extraction works but layout positioning is approximate)
- **unsupported**: feature is used but not implemented (e.g., JBIG2Decode
  filter, JavaScript actions, XFA forms)
- **unused**: feature is not present in this PDF

Categories to check:
- Filters: which stream filters are referenced (FlateDecode, DCTDecode,
  JBIG2Decode, JPXDecode, CCITTFaxDecode, Crypt, etc.)
- Fonts: which font types are used (Type1, TrueType, Type0/CID, Type3)
  and whether encoding/ToUnicode is available
- Images: colour spaces used, bits per component, mask types
- Encryption: whether the file is encrypted and which algorithm
- Interactive features: forms, JavaScript, embedded files, multimedia
- Structure: tagged PDF, bookmarks, article threads

#### 6.2: Error context in all subcommands
When any subcommand encounters an unsupported feature, the error message
SHALL include the feature name and the ISO 32000-2 section reference
where possible, so the user knows exactly what is missing.
For example:
```
Warning: page 3: image uses JPXDecode filter (ISO 32000-2 §7.4.9) — not supported, skipping
Warning: page 5: font /F2 uses Type3 glyph programs (ISO 32000-2 §9.6.4) — text may be incomplete
```

#### 6.3: Summary statistics
At the end of `text`, `images`, and `check` subcommands, print a summary
line to stderr:
```
Pages: 42  Text: 38/42 ok  Images: 12/15 decoded  Warnings: 5
```
