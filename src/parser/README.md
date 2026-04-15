# parser

## API

- **`parse_regular_object`** (Function) — Parses ISO 32000-2 section 7.3.2 Boolean object keywords true and false,
- **`parse_integer_or_reference`** (Function) — Uses bounded lookahead for ISO 32000-2 section 7.3.10 disambiguation:
- **`parse_object`** (Function) — Parses one ISO 32000-2 section 7.3 object, dispatching literal string,
- **`parse_dictionary`** (Function) — Parses an ISO 32000-2 section 7.3.7 Dictionary object as key-value pairs
- **`parse_indirect_object`** (Function) — Parses an ISO 32000-2 section 7.3.10 indirect object definition in the
- **`parse_ordinary_object`** (Function) — Parses regular tokens into Boolean object true/false, Null object,
- **`build_ref_object`** (Function) — Builds an ISO 32000-2 section 7.3.10 indirect reference after validating
- **`sign_prefix_length`** (Function) — Returns the optional sign prefix length for signed decimal integer and
- **`matches_keyword`** (Function) — Matches a keyword only when the following byte is white-space, delimiter,
- **`parse_double_lexeme`** (Function) — Converts a decimal number containing a PERIOD decimal point into a Real
- **`is_numeric_like`** (Function) — Recognizes malformed numeric-looking lexemes for ISO 32000-2 section 7.3.3
- **`next_token_can_be_regular`** (Function) — Checks whether the next input can begin the regular token needed by
- **`is_real_lexeme`** (Function) — Recognizes a Real object token containing exactly one PERIOD as the
- **`parse_array`** (Function) — Parses an ISO 32000-2 section 7.3.6 Array object until the closing
- **`read_indirect_generation_number`** (Function) — Reads and validates the non-negative generation number in an indirect
- **`parse_int64_lexeme`** (Function) — Converts a signed decimal integer token into an Integer object payload.
- **`require_indirect_keyword`** (Function) — Requires the obj keyword when parsing N G obj indirect object syntax.
- **`read_indirect_object_number`** (Function) — Reads and validates the positive object number in an indirect object.
- **`consume_dictionary_start`** (Function) — Consumes the ISO 32000-2 section 7.3.7 Dictionary object opening <<.
- **`consume_dictionary_end`** (Function) — Consumes the ISO 32000-2 section 7.3.7 Dictionary object closing >>.
- **`ObjectParser`** (Struct) — Recursive object parser for ISO 32000-2 sections 7.2 and 7.3.
- **`require_endstream`** (Function) — Requires the ISO 32000-2 section 7.3.8 endstream keyword.
- **`is_integer_lexeme`** (Function) — Recognizes a signed decimal integer token with no PERIOD.
- **`all_digits_from`** (Function) — Checks that all bytes from start are decimal digits.
- **`parse_all_objects`** (Function) — Parses all adjacent direct objects in a byte slice.
- **`is_at_dictionary_end`** (Function) — Detects the Dictionary object closing delimiter >>.
- **`new`** (Function) — Creates an object parser over PDF bytes.
- **`is_digit`** (Function) — Returns true for one decimal digit.
- **`bytes_to_text`** (Function) — 


- **`consume_bytes`** (Function) —
