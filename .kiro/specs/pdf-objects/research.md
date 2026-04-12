# Research & Design Decisions

## Summary
- **Feature**: `pdf-objects`
- **Discovery Scope**: New Feature / Full discovery, bounded to local ISO excerpts, project steering, existing MoonBit package layout, and official MoonBit language/core documentation. No external runtime dependency is introduced.
- **Key Findings**:
  - PDF object syntax is byte oriented. Normal lexical classification applies only outside strings, streams, and comments; literal strings, hex strings, names, and stream data require context-specific readers over the same byte cursor.
  - The repository currently has project scaffolding and specification assets but no `src/objects`, `src/lexer`, or `src/parser` implementation. The design can establish clean package boundaries without migration work.
  - MoonBit provides `Bytes`, `Array`, `Map`, and `suberror`, which are sufficient for the object model, parser state, dictionary storage, stream payloads, and typed diagnostics without adding dependencies.

## Research Log

### ISO lexical and object syntax
- **Context**: Requirements target ISO 32000-2:2020 clauses 7.2 and 7.3.
- **Sources Consulted**:
  - `spec/extracted/7.2-lexical.md`
  - `spec/extracted/7.3-objects.md`
  - `spec/extracted/7.2-7.3-syntax-objects.spec.txt`
- **Findings**:
  - White-space bytes are exactly `00`, `09`, `0A`, `0C`, `0D`, and `20`.
  - Requirement 1 intentionally limits delimiter bytes to `(`, `)`, `<`, `>`, `[`, `]`, `/`, and `%`; braces are outside this spec because Type 4 function syntax is not part of object parsing.
  - Comments are separators except `%PDF-n.m` and `%%EOF`, which are structural markers consumed by the file-structure layer.
  - Stream data is not tokenized. It begins after `stream` plus LF or CRLF, is read by exact `Length`, and is followed by optional EOL before `endstream`.
- **Implications**:
  - A single token scanner is insufficient for all input regions. The design uses one byte cursor plus specialized readers for comments, strings, names, and streams.
  - The lexer must expose marker tokens for downstream file-structure parsing while allowing the object parser to ignore ordinary comments.

### Existing repository and package boundaries
- **Context**: Discovery checked whether this feature extends existing parser code or creates the foundational layer.
- **Sources Consulted**:
  - `.kiro/steering/product.md`
  - `.kiro/steering/tech.md`
  - `.kiro/steering/structure.md`
  - `moon.mod.json`
  - `moon.pkg`
  - `cmd/main/main.mbt`
  - `cmd/main/moon.pkg`
  - `.kiro/specs/pdf-file-structure/requirements.md`
- **Findings**:
  - The project target is a MoonBit PDF parser library named `trkbt10/pdf`.
  - Steering defines the dependency direction as `objects <- lexer <- parser <- reader`.
  - The `pdf-file-structure` specification explicitly depends on `pdf-objects` for object parsing, stream objects, indirect references, and nonexistent-reference-to-null semantics.
  - There is no existing `src` implementation to preserve, only a template CLI.
- **Implications**:
  - The design creates new packages under `src/objects`, `src/lexer`, and `src/parser`.
  - Public contracts must be stable enough for `src/reader` to depend on in the next phase.

### MoonBit type and parser conventions
- **Context**: The object model and parser contracts must be idiomatic MoonBit and type-safe.
- **Sources Consulted**:
  - `<local>/.codex/skills/moonbit-agent-guide/SKILL.md`
  - `<local>/.codex/skills/moonbit-lang/reference/fundamentals.md`
  - `<local>/.codex/skills/moonbit-lang/reference/error-handling.md`
  - `<local>/.codex/skills/moonbit-lang/reference/toml-parser-parser.mbt`
  - Official core docs: `https://mooncakes.io/docs/moonbitlang/core/bytes`
  - Official core docs: `https://mooncakes.io/docs/moonbitlang/core/builtin#Map`
- **Findings**:
  - `Bytes` is the correct storage type for PDF string values, name bytes, and raw stream data.
  - `Array[T]` fits heterogeneous PDF arrays only through the recursive `PdfObject` enum.
  - `Map[PdfName, PdfObject]` matches dictionary requirements and preserves insertion order, while equality for names remains byte based.
  - `suberror` supports typed parse errors that can carry offsets and error kinds.
  - The local parser style reference favors a parser object with a token view, `update_view`, and centralized error construction.
- **Implications**:
  - `PdfName` is a value object wrapping `Bytes`, with text conversion as an explicit helper rather than equality semantics.
  - `PdfParseError` is a public `suberror` with byte offsets.
  - Parser tasks should keep parsing methods small and package-local, using black-box tests for public APIs and white-box tests for cursor edge cases.

### External dependencies
- **Context**: Full discovery checks whether an existing library should be adopted.
- **Sources Consulted**:
  - Project steering dependency policy.
  - MoonBit standard library capabilities above.
- **Findings**:
  - Steering requires no external dependencies for this phase.
  - The feature is low-level syntax parsing with ISO-specific byte rules; external parser generators or PDF libraries would either violate the dependency policy or obscure compliance-critical behavior.
- **Implications**:
  - Build in MoonBit using the standard library only.
  - Avoid a parser generator and keep lexical decisions auditable against requirement IDs.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Layered byte parser | `objects` defines types, `lexer` reads byte-level tokens and special regions, `parser` assembles objects. | Matches steering direction, isolates byte rules, easy to test by layer. | Requires careful cursor ownership for stream data. | Selected. |
| Parser generator | Define grammar and generate parser code. | Declarative grammar, potential speed for conventional token streams. | PDF streams and context-sensitive strings do not fit a pure token grammar; adds dependency and generated code review cost. | Rejected. |
| Monolithic parser | One package performs byte scanning and object construction. | Fast to start and fewer files. | Blurs responsibility boundaries, harder for file-structure layer to reuse lexical markers. | Rejected. |
| Adopt external PDF parser | Wrap an existing parser library. | Could cover many PDF edge cases. | Conflicts with no-dependency steering and MoonBit target; weak traceability to ISO clauses. | Rejected. |

## Design Decisions

### Decision: Use a shared byte cursor with context-specific readers
- **Context**: Character classification does not apply inside strings, streams, or comments, yet all readers need consistent offsets.
- **Alternatives Considered**:
  1. Tokenize the entire file first.
  2. Parse directly from raw bytes in every parser method.
  3. Use a cursor plus specialized readers.
- **Selected Approach**: `ByteCursor` owns position and EOL recognition. `Lexer` handles ordinary tokens and comments. Literal string, hex string, name, and stream readers use the same cursor when the parser enters those contexts.
- **Rationale**: This preserves precise offsets while preventing normal token rules from leaking into raw byte regions.
- **Trade-offs**: The parser and lexer share cursor state, so implementation tasks must define ownership clearly.
- **Follow-up**: White-box tests must verify cursor position after every special reader.

### Decision: Keep `PdfName` byte-first
- **Context**: PDF names may be displayed as UTF-8 text, but equality is exact byte sequence equality.
- **Alternatives Considered**:
  1. Store names as `String`.
  2. Store names as `Bytes` only.
  3. Store a `PdfName` value object with bytes and helper methods.
- **Selected Approach**: `PdfName` wraps decoded name bytes. Equality, hashing, and dictionary keys use bytes. UTF-8 text rendering is an explicit fallible view.
- **Rationale**: This satisfies name equality and avoids corrupting non-text byte sequences.
- **Trade-offs**: Callers must explicitly request text conversion.
- **Follow-up**: Tests must include invalid or non-ASCII name bytes and confirm equality remains byte based.

### Decision: Normalize dictionaries during parse
- **Context**: Dictionary keys must be names, null-valued entries are equivalent to missing entries, and duplicate keys are not allowed.
- **Alternatives Considered**:
  1. Preserve all entries and validate later.
  2. Insert entries directly into `Map`, overwriting duplicates.
  3. Track syntactic keys while building a normalized dictionary.
- **Selected Approach**: `DictionaryBuilder` records every syntactic key in a seen set, rejects repeats, inserts only non-null values, and omits null-valued entries from the final map.
- **Rationale**: This enforces duplicate-key errors without exposing null entries as present dictionary values.
- **Trade-offs**: The original entry order for null entries is not preserved in the normalized dictionary.
- **Follow-up**: Tests must cover duplicate non-null keys, duplicate keys where one value is null, and null omission.

### Decision: Treat streams as dictionary plus exact raw bytes
- **Context**: Stream data can contain arbitrary bytes and is delimited by dictionary `Length`, not token scanning.
- **Alternatives Considered**:
  1. Scan for `endstream`.
  2. Decode filters during object parsing.
  3. Read exact raw bytes from `Length` and leave filters undecoded.
- **Selected Approach**: `StreamReader` reads the encoded stream data by exact `Length`, validates LF or CRLF after `stream`, excludes the optional EOL before `endstream`, and records filter-related dictionary entries without decoding them.
- **Rationale**: This implements clause 7.3.8 syntax and keeps filter decoding for a later spec.
- **Trade-offs**: If a malformed file has incorrect `Length`, the object parser fails rather than heuristically searching.
- **Follow-up**: Integration tests must cover LF, CRLF, CR-alone rejection, zero-length streams, and optional EOL before `endstream`.

### Decision: Use bounded lookahead for indirect syntax
- **Context**: Two integers may be standalone values, a reference, or an indirect object header.
- **Alternatives Considered**:
  1. Parse greedily and backtrack.
  2. Use unbounded token lookahead.
  3. Maintain a two-token lookahead buffer after the first integer.
- **Selected Approach**: `ObjectParser` peeks at most two tokens beyond the first integer. `N G R` yields `Ref`; `N G obj` enters indirect-object mode; other sequences emit the first integer and retain the second token.
- **Rationale**: This exactly matches the ambiguity-resolution requirement and keeps parser state deterministic.
- **Trade-offs**: The token buffer must support pushback for the second integer.
- **Follow-up**: Tests must prove the second integer is not lost in `1 2 true`.

## Risks & Mitigations
- Incorrect offsets in errors or stream reads - Centralize all byte movement in `ByteCursor` and assert offsets in tests.
- Normal lexical classification leaking into strings or streams - Use context-specific readers and test delimiter bytes inside strings and streams.
- Dictionary duplicate behavior conflicting with null omission - Track syntactic keys separately from the final map.
- Numeric overflow or unsupported integer ranges - Parse into the selected integer representation with explicit overflow errors.
- Downstream file-structure needs broader marker handling - Expose `%PDF-n.m` and `%%EOF` marker tokens without making this spec parse file structure.

## References
- `spec/extracted/7.2-lexical.md` - ISO lexical conventions used by lexer design.
- `spec/extracted/7.3-objects.md` - ISO object syntax used by parser and data model design.
- `.kiro/steering/product.md` - Project goals and non-goals.
- `.kiro/steering/tech.md` - MoonBit tooling, error handling, and architecture principles.
- `.kiro/steering/structure.md` - Package layout and dependency direction.
- `<local>/.codex/skills/moonbit-agent-guide/SKILL.md` - MoonBit package and test workflow guidance.
- `<local>/.codex/skills/moonbit-lang/reference/error-handling.md` - `suberror` and `raise` guidance.
- `https://mooncakes.io/docs/moonbitlang/core/bytes` - Official `Bytes` API reference.
- `https://mooncakes.io/docs/moonbitlang/core/builtin#Map` - Official `Map` API reference.
