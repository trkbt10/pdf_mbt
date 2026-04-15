# File Reading Pipeline

The reading pipeline transforms raw PDF bytes into a traversable document structure, spanning four packages.

## Stage 1: Lexical Analysis (`src/lexer/`)

`ByteCursor` provides zero-copy byte access with offset tracking. `Lexer` emits `PdfToken` variants: Regular (keywords, numbers), Delimiter, DictStart/DictEnd, HeaderMarker (`%PDF-M.m`), EofMarker (`%%EOF`). Specialized readers handle Name objects (with `#XX` escapes), literal strings (nested parentheses, escape sequences), and hex strings. Supports push-back for 3-token indirect reference lookahead.

## Stage 2: Object Parsing (`src/parser/`)

`ObjectParser` performs recursive descent: dispatches on first byte (`(` for literal strings, `<` for hex/dict, `/` for names, `[` for arrays). Handles the §7.3.10 indirect reference ambiguity with bounded lookahead (`N G R` pattern via `parse_integer_or_reference`). Public API: `parse_object`, `parse_all_objects`.

## Stage 3: File Structure (`src/reader/`)

`PdfFile::open(bytes)` implements §7.5.5 reverse parsing: find last `%%EOF`, locate `startxref`, parse xref section chain following `Prev` links for incremental updates, merge table-based (§7.5.4) and stream-based (§7.5.8) xref formats. Returns `PdfFile` with header, trailer (`TrailerInfo` with Root reference), merged xref index, and lazy object cache with object stream decompression. `PdfCatalog` provides typed accessors for Catalog entries (names, AcroForm, permissions, DSS, requirements per §§12.7-12.11).

## Stage 4: Stream Decoding (`src/filters/`)

`decode_stream` chains Filter entries with DecodeParms: FlateDecode (RFC 1951 DEFLATE with zlib wrapper, PNG/TIFF predictors via `Columns`/`Colors`/`BitsPerComponent`), LZWDecode (variable-width codes with `EarlyChange`), ASCIIHexDecode, ASCII85Decode (with `~>` EOD marker), RunLengthDecode (repeat/literal runs, byte 128 EOD), DCTDecode. All implemented in pure MoonBit.

## See Also

- wiki://overview
- wiki://object-model
- wiki://content-streams
- wiki://cryptography
