# Text Extraction

The `src/text/` package interprets text operators from content streams to extract readable text with positioning.

## Pipeline

`interpret_text(content, resources, initial)` returns `TextProgram` containing:
- `events` — ordered `TextEvent` stream (FontSelected, StateChanged, TextObjectBegan/Ended)
- `spans` — extracted `TextSpan` values with Unicode text, position, font name, size
- `final_state` — text state after interpretation

The interpreter (`TextInterpreter`) tracks: text matrix, text line matrix, font/size (Tf), character spacing (Tc), word spacing (Tw), horizontal scaling (Tz), text rise (Ts), rendering mode (Tr, 8 modes per §9.3.6), text knockout, and a graphics state stack for q/Q save/restore.

## CMap System

`CMap` (`src/text/cmap.mbt`) implements ISO 32000-2 §9.10:
- Codespace ranges define valid byte sequences (1-4 bytes per character code)
- CID mappings via `beginbfchar`/`endbfchar` (single) and `beginbfrange`/`endbfrange` (range)
- Predefined Identity-H / Identity-V CMaps resolved by `resolve_predefined_cmap`
- `CMap::decode_next` returns `CMapDecodeResult` with source bytes, CID, consumed count, writing mode
- `ToUnicodeCMap::map_source_code` for Unicode lookup from source codes

`CMapParser` (`cmap_parser.mbt`) parses the PostScript-like CMap program syntax.

## Font Encoding

`encoding.mbt` provides built-in encoding tables: StandardEncoding, MacRomanEncoding, WinAnsiEncoding, MacExpertEncoding. `UnicodeMapping` resolves character codes to Unicode by trying: ToUnicode CMap → encoding differences array → base encoding table → Adobe glyph name mapping.

## See Also

- wiki://content-streams
- wiki://graphics
- wiki://overview
