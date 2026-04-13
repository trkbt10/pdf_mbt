# Requirements Document

## Project Description (Input)
Implement PDF content stream parsing in MoonBit, conforming to ISO 32000-2:2020 (PDF 2.0) §7.8 and Annex A. A content stream is a sequence of PDF operators and their operands that describe the appearance of a page or other graphical entity. This layer tokenizes content stream bytes into operator/operand sequences, resolves the resource dictionary for each content stream, and provides an iteration API for downstream consumers (graphics state machine, text extraction, etc.). This layer builds on all prior phases.

Reference specification: `spec/extracted/7.8-content-streams.spec.txt`, `spec/extracted/annex-a-operators.spec.txt`

Dependencies: `pdf-objects` (Phase 1), `pdf-file-structure` (Phase 2), `pdf-filters` (Phase 3), `pdf-document-structure` (Phase 4).

## Requirements

### Requirement 1: Content Stream Tokenization
The content stream parser shall tokenize decoded content stream bytes into operands and operators per §7.8.2.

#### Acceptance Criteria
- The content stream parser shall recognize PDF objects (numbers, strings, names, arrays, dictionaries, booleans) appearing as operands before an operator
- The content stream parser shall recognize PDF operator keywords as sequences of regular characters that are not valid PDF objects
- The content stream parser shall produce an ordered sequence of (operands, operator) pairs representing each instruction in the content stream
- The content stream parser shall handle inline image data introduced by the `BI`, `ID`, and `EI` operators as a special case, capturing the image dictionary and raw image bytes

### Requirement 2: Operator Recognition
The content stream parser shall recognize all standard PDF content stream operators listed in Annex A.

#### Acceptance Criteria
- The content stream parser shall recognize graphics state operators: `q`, `Q`, `cm`, `w`, `J`, `j`, `M`, `d`, `ri`, `i`, `gs`
- The content stream parser shall recognize path construction operators: `m`, `l`, `c`, `v`, `y`, `h`, `re`
- The content stream parser shall recognize path painting operators: `S`, `s`, `f`, `F`, `f*`, `B`, `B*`, `b`, `b*`, `n`
- The content stream parser shall recognize clipping operators: `W`, `W*`
- The content stream parser shall recognize text operators: `BT`, `ET`, `Tc`, `Tw`, `Tz`, `TL`, `Tf`, `Tr`, `Ts`, `Td`, `TD`, `Tm`, `T*`, `Tj`, `TJ`, `'`, `"`, `d0`, `d1`
- The content stream parser shall recognize color operators: `CS`, `cs`, `SC`, `SCN`, `sc`, `scn`, `G`, `g`, `RG`, `rg`, `K`, `k`
- The content stream parser shall recognize XObject and inline image operators: `Do`, `BI`, `ID`, `EI`
- The content stream parser shall recognize marked content operators: `MP`, `DP`, `BMC`, `BDC`, `EMC`
- The content stream parser shall recognize compatibility operators: `BX`, `EX`
- The content stream parser shall recognize shading operator: `sh`

### Requirement 3: Resource Dictionary Resolution
The content stream parser shall resolve resource dictionaries for content streams per §7.8.3.

#### Acceptance Criteria
- The content stream parser shall obtain the resource dictionary from the page object or its inherited ancestors
- The content stream parser shall support resource categories: `ExtGState`, `ColorSpace`, `Pattern`, `Shading`, `XObject`, `Font`, `Properties`, and `ProcSet`
- The content stream parser shall resolve named resources by looking up the resource name in the appropriate category subdictionary
- When a Form XObject defines its own `Resources` entry, the content stream parser shall use that entry instead of the page-level resources for the scope of that XObject

### Requirement 4: Content Stream Iteration API
The content stream parser shall provide an iteration interface for consuming parsed instructions.

#### Acceptance Criteria
- The content stream parser shall provide a function that accepts decoded content stream bytes and a resource dictionary and yields parsed instructions one at a time
- Each instruction shall contain the operator name and an array of operand values as PdfObject instances
- The iteration shall handle multiple content streams concatenated from a page Contents array (when Contents is an array of stream references, the streams are concatenated with implicit newline separation)
- The iteration shall return a clear error with byte offset when encountering malformed content

### Requirement 5: Inline Image Handling
The content stream parser shall correctly parse inline image data per §8.9.7.

#### Acceptance Criteria
- When the parser encounters the `BI` operator, it shall collect key-value pairs until the `ID` operator
- The parser shall read raw image bytes after `ID` (preceded by a single white-space byte) until the `EI` operator is found
- The parser shall represent the inline image as an instruction containing the image dictionary and raw byte data
- The parser shall handle abbreviated key names (`W` for `Width`, `H` for `Height`, `BPC` for `BitsPerComponent`, `CS` for `ColorSpace`, etc.)

### Requirement 6: Content Stream Integration
The content stream parser shall integrate with the document structure to parse page content.

#### Acceptance Criteria
- The content stream parser shall accept a page reference from the document structure layer and automatically resolve its Contents stream(s) and Resources
- The content stream parser shall decode content streams using the filter pipeline before parsing
- The content stream parser shall handle both single-stream Contents and array-of-streams Contents
