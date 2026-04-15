# lexer

## API

- **`is_white_space`** (Function) — Returns true for the ISO 32000-2 section 7.2.3 white-space bytes:
- **`skip_separators`** (Function) — Skips ISO 32000-2 section 7.2.3 separators: consecutive white-space,
- **`read_name`** (Function) — Reads an ISO 32000-2 section 7.3.5 Name object. The SOLIDUS prefix is
- **`read_hex_string`** (Function) — Reads an ISO 32000-2 section 7.3.4.3 hexadecimal string. Pairs of
- **`read_regular_token`** (Function) — Reads a sequence of regular characters until white-space or delimiter.
- **`read_literal_string`** (Function) — Reads an ISO 32000-2 section 7.3.4.2 literal string, including escape
- **`read_literal_escape`** (Function) — Decodes a literal string escape sequence from ISO 32000-2 section 7.3.4.2,
- **`CharClass`** (Enum) — PDF character class from ISO 32000-2 section 7.2.3.
- **`is_delimiter`** (Function) — Returns true for ISO 32000-2 section 7.2.3 delimiter bytes. A delimiter
- **`require_stream_eol`** (Function) — Requires the ISO 32000-2 section 7.3.8 stream keyword to be followed by
- **`skip_comment`** (Function) — Skips an ISO 32000-2 section 7.2.4 comment up to but not including the
- **`PdfToken`** (Enum) — Token categories emitted by ISO 32000-2 section 7.2 lexical scanning.
- **`read_eol`** (Function) — Consumes one ISO 32000-2 section 7.2.3 EOL marker. CR, LF, and CR
- **`classify_byte`** (Function) — Classifies one byte as white-space, delimiter, or regular according to
- **`is_pdf_string_space`** (Function) — ISO 32000-2 section 7.3.4.3 white-space ignored inside a hexadecimal
- **`read_bytes`** (Function) — Reads an exact raw byte count, used for stream data after the Length entry.
- **`require_opening`** (Function) — Requires the opening delimiter for a literal string or hexadecimal string.
- **`require_name_opening`** (Function) — Requires the SOLIDUS prefix for an ISO 32000-2 section 7.3.5 Name object.
- **`push_back`** (Function) — Pushes a token back so numeric lookahead can preserve fallback parsing.
- **`read_next_token`** (Function) — Reads the next ordinary token or delimiter outside strings and streams.
- **`read_octal_escape`** (Function) — Reads a one-, two-, or three-digit octal escape for a literal string.
- **`consume_white_space`** (Function) — Consumes one white-space separator, normalizing an EOL marker first.
- **`Lexer`** (Struct) — Lexer state for ISO 32000-2 section 7.2 ordinary lexical scanning.
- **`read_byte`** (Function) — Reads one raw byte, preserving stream and string byte semantics.
- **`new`** (Function) — Creates a cursor over PDF bytes while preserving byte offsets.
- **`has_pushed_tokens`** (Function) — Reports whether the parser has a token saved from lookahead.
- **`peek_token`** (Function) — Reads and then restores the next token for parser lookahead.
- **`ByteCursor`** (Struct) — Byte cursor for ISO 32000-2 section 7.2.3 lexical scanning.
- **`is_name_hex_digit`** (Function) — Returns true for one hexadecimal digit in a #XX hex escape.
- **`has_name_hex_escape`** (Function) — Detects the #XX hex escape form used inside a Name object.
- **`hex_value`** (Function) — Converts one hexadecimal string digit to its nibble value.
- **`next_token`** (Function) — Returns the next PDF token after collapsing separators.
- **`name_hex_value`** (Function) — Converts a #XX hex escape digit to its nibble value.
- **`offset`** (Function) — Current byte offset used in parser diagnostics.
- **`peek`** (Function) — Peeks at the current byte without consuming it.
- **`peek_n`** (Function) — Peeks ahead by n bytes without consuming input.
- **`octal_value`** (Function) — Converts an octal escape digit to its value.
- **`is_octal_digit`** (Function) — Returns true for an octal escape digit.
- **`read_header_marker`** (Function) — 


- **`is_header_marker`** (Function) — 


- **`byte_to_text`** (Function) — 


- **`consume_bytes`** (Function) — 


- **`is_digit_at`** (Function) — 


- **`matches_bytes`** (Function) — 


- **`read_eof_marker`** (Function) — 


- **`name_byte_to_text`** (Function) — 


- **`is_eof_marker`** (Function) —
