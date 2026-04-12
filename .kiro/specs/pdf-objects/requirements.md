# Requirements Document

## Project Description (Input)
Implement a PDF low-level syntax parser in MoonBit, conforming to ISO 32000-2:2020 (PDF 2.0) §7.2–§7.3. The parser tokenizes a PDF byte stream according to lexical conventions and parses the 9 basic object types (Boolean, Integer, Real, String, Name, Array, Dictionary, Stream, Null) plus indirect object references. This is the foundational layer upon which file structure parsing and document structure parsing are built.

Reference specification: `spec/extracted/7.2-lexical.md`, `spec/extracted/7.3-objects.md`

## Requirements

### Requirement 1: Character Classification
The lexer shall classify each byte into exactly one of three classes: white-space, delimiter, or regular, per §7.2.3.

#### Acceptance Criteria
1. When the lexer encounters bytes 0x00 (NUL), 0x09 (HT), 0x0A (LF), 0x0C (FF), 0x0D (CR), 0x20 (SP), the lexer shall classify them as `white-space`
2. When the lexer encounters bytes 0x28 `(`, 0x29 `)`, 0x3C `<`, 0x3E `>`, 0x5B `[`, 0x5D `]`, 0x2F `/`, 0x25 `%`, the lexer shall classify them as `delimiter`
3. When the lexer encounters any other byte value (including 0x80–0xFF), the lexer shall classify it as `regular`
4. The lexer shall not apply character classification inside strings, streams, or comments

### Requirement 2: End-of-Line and White-space Handling
The lexer shall normalize EOL markers and collapse consecutive white-space per §7.2.3.

#### Acceptance Criteria
1. When the lexer encounters CR (0x0D) alone, LF (0x0A) alone, or CR immediately followed by LF, the lexer shall treat each as a single EOL marker
2. When the lexer encounters consecutive white-space characters outside strings and streams, the lexer shall treat them as a single separator
3. When the lexer encounters a delimiter character, the lexer shall terminate the preceding token without including the delimiter in it

### Requirement 3: Comment Handling
The lexer shall skip comments starting with `%` per §7.2.4.

#### Acceptance Criteria
1. When the lexer encounters `%` (0x25) outside a string or stream, the lexer shall skip all bytes from `%` up to but not including the EOL marker
2. The lexer shall treat a comment as a single white-space for token separation
3. The lexer shall recognize `%PDF-n.m` and `%%EOF` as special structural markers distinct from ordinary comments

### Requirement 4: Boolean Objects
The parser shall recognize keywords `true` and `false` as Boolean objects per §7.3.2.

#### Acceptance Criteria
1. When the parser encounters token `true`, the parser shall produce a `Boolean(true)` object
2. When the parser encounters token `false`, the parser shall produce a `Boolean(false)` object
3. The parser shall treat keywords as case-sensitive (`True`, `FALSE` are not Boolean objects)

### Requirement 5: Integer Objects
The parser shall parse signed decimal integers per §7.3.3.

#### Acceptance Criteria
1. When the parser encounters one or more decimal digits optionally preceded by `+` or `-`, with no PERIOD, the parser shall produce an `Integer` object
2. The parser shall correctly parse `123`, `+17`, `-98`, `0`, `43445` to their respective integer values
3. The parser shall not accept hexadecimal radix notation (e.g. `16#FFFE`) or exponential notation (e.g. `6.02E23`)

### Requirement 6: Real Objects
The parser shall parse decimal real numbers containing a PERIOD per §7.3.3.

#### Acceptance Criteria
1. When the parser encounters digits with an embedded, leading, or trailing PERIOD (0x2E) and optional sign, the parser shall produce a `Real` object
2. The parser shall correctly parse `34.5`, `-3.62`, `+123.6`, `4.`, `-.002`, `0.0`
3. Where a real number is expected, the parser shall accept an integer as a substitute
4. Where an integer is expected, the parser shall not accept a real number

### Requirement 7: Literal String Objects
The parser shall parse parenthesized literal strings with escape handling per §7.3.4.2.

#### Acceptance Criteria
1. When the parser encounters `(` (0x28), the parser shall read bytes until the matching `)` (0x29) respecting balanced parenthesis nesting
2. The parser shall convert escape sequences: `\n`→LF, `\r`→CR, `\t`→HT, `\b`→BS, `\f`→FF, `\(`→`(`, `\)`→`)`, `\\`→`\`
3. The parser shall convert `\ddd` octal escapes (1–3 digits) to the corresponding byte value, ignoring high-order overflow
4. When the next character after an octal escape is also a digit, the parser shall require 3-digit notation with leading zeros (e.g. `\0053` = Control-E + `3`)
5. When `\` appears at end-of-line, the parser shall treat it as line continuation and discard both `\` and the EOL
6. When an unescaped EOL appears in a literal string, the parser shall normalize it to LF (0x0A) regardless of whether the original was CR, LF, or CR+LF
7. When `\` is followed by a character not in Table 3, the parser shall ignore the `\`
8. The parser shall parse empty string `()` as a zero-length byte sequence

### Requirement 8: Hexadecimal String Objects
The parser shall parse angle-bracket hex strings per §7.3.4.3.

#### Acceptance Criteria
1. When the parser encounters `<` followed by hex digits and `>`, the parser shall decode pairs of hex digits into bytes
2. The parser shall accept both uppercase (A–F) and lowercase (a–f) hex digits
3. The parser shall ignore white-space characters within the hex string
4. When the hex string has an odd number of digits, the parser shall pad the final digit with 0 (e.g. `<901FA>` → 0x90 0x1F 0xA0)
5. The parser shall parse `<>` as a zero-length byte sequence

### Requirement 9: Name Objects
The parser shall parse `/`-prefixed names with `#XX` hex escape expansion per §7.3.5.

#### Acceptance Criteria
1. When the parser encounters `/` (0x2F), the parser shall read subsequent regular characters as a name
2. The parser shall expand `#XX` sequences where XX is a 2-digit hexadecimal code to the corresponding byte
3. The parser shall parse `/` followed by no regular characters as the empty name
4. The parser shall not allow NUL (0x00) within a name
5. The parser shall correctly parse: `/Name1`→`Name1`, `/A#42`→`AB`, `/Lime#20Green`→`Lime Green`, `/paired#28#29parentheses`→`paired()parentheses`, `/The_Key_of_F#23_Minor`→`The_Key_of_F#_Minor`
6. The parser shall interpret name bytes as UTF-8 for text representation, but determine name equality by exact byte-sequence comparison

### Requirement 10: Array Objects
The parser shall parse bracket-delimited heterogeneous arrays per §7.3.6.

#### Acceptance Criteria
1. When the parser encounters `[` (0x5B), the parser shall read objects until `]` (0x5D) and produce an `Array` object
2. The parser shall accept any object type as array elements, including nested arrays
3. The parser shall parse `[]` as a zero-element array
4. The parser shall correctly parse `[549 3.14 false (Ralph) /SomeName]` as a 5-element array

### Requirement 11: Dictionary Objects
The parser shall parse `<<`...`>>` delimited key-value pair collections per §7.3.7.

#### Acceptance Criteria
1. When the parser encounters `<<` (0x3C 0x3C), the parser shall read key-value pairs until `>>` (0x3E 0x3E) and produce a `Dictionary` object
2. The parser shall require all dictionary keys to be Name objects (direct objects only)
3. The parser shall treat a dictionary entry with value `null` as equivalent to the entry not existing
4. The parser shall not allow duplicate keys in the same dictionary
5. The parser shall parse `<<>>` as a zero-entry dictionary
6. The parser shall correctly distinguish `<<` (dictionary start) from `<` (hex string start)

### Requirement 12: Stream Objects
The parser shall parse dictionary + `stream`...`endstream` byte sequences per §7.3.8.

#### Acceptance Criteria
1. When a dictionary is immediately followed by the keyword `stream`, the parser shall treat it as a Stream object
2. The parser shall require the `stream` keyword to be followed by an EOL: CR+LF or LF only (not CR alone)
3. The parser shall use the `Length` entry from the stream dictionary to determine the exact byte count of stream data
4. The parser shall not include the optional EOL before `endstream` in the stream data
5. The parser shall recognize stream dictionary entries: `Length` (required integer), `Filter` (optional name or array), `DecodeParms` (optional), `DL` (optional hint integer)

### Requirement 13: Null Object
The parser shall recognize keyword `null` as the Null object per §7.3.9.

#### Acceptance Criteria
1. When the parser encounters token `null`, the parser shall produce a `Null` object
2. An indirect reference to a nonexistent object shall be treated as `Null`

### Requirement 14: Indirect Objects and References
The parser shall parse `N G obj ... endobj` definitions and `N G R` references per §7.3.10.

#### Acceptance Criteria
1. When the parser encounters `<positive-integer> <non-negative-integer> obj`, the parser shall read the enclosed object value until `endobj` and produce an indirect object definition
2. When the parser encounters `<positive-integer> <non-negative-integer> R`, the parser shall produce an indirect reference (`Ref`)
3. The parser shall uniquely identify objects by the pair (object number, generation number)
4. The parser shall correctly parse `12 0 obj (Brillig) endobj` as indirect string object #12 gen 0

### Requirement 15: Ambiguity Resolution for Numbers vs References
The parser shall disambiguate `N G R` / `N G obj` from standalone integers using lookahead per §7.3.10.

#### Acceptance Criteria
1. When two consecutive integer tokens are followed by `R`, the parser shall produce an indirect reference
2. When two consecutive integer tokens are followed by `obj`, the parser shall begin an indirect object definition
3. When two consecutive integer tokens are followed by neither `R` nor `obj`, the parser shall yield the first integer as a standalone `Integer` object and re-parse from the second
4. The parser shall use at most 2-token lookahead for this disambiguation

### Requirement 16: Type-Safe Object Model
The parsed result shall be represented as a type-safe MoonBit algebraic data type.

#### Acceptance Criteria
1. The object model shall represent all 9 PDF object types as variants of a single `PdfObject` enum: `Boolean`, `Integer`, `Real`, `String`, `Name`, `Array`, `Dictionary`, `Stream`, `Null`
2. The object model shall represent indirect references as `Ref(Int, Int)` carrying object number and generation number
3. The object model shall represent `Dictionary` as a `Name` → `PdfObject` map
4. The object model shall represent `Stream` as a `Dictionary` + `Bytes` pair
5. Parse errors shall be represented using MoonBit's `suberror` mechanism with error kind and byte offset for diagnostics
