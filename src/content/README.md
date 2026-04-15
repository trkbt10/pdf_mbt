# content

## API

- **`PdfInlineImage`** (Struct) — Parsed inline image instruction data per ISO 32000-2 §8.9.7 from a `BI`
- **`parse`** (Function) — Parses one inline image value, expanding abbreviated image dictionary keys
- **`ContentResources`** (Struct) — Resource context for content stream parsing. It preserves the raw page or
- **`parse_next`** (Function) — Reads the next content stream instruction one at a time from decoded bytes.
- **`category_object`** (Function) — Returns the raw resource category object for graphics state, ColorSpace,
- **`ContentInstruction`** (Enum) — Public content stream instruction model. Normal operators carry an ordered
- **`InlineImageReader`** (Struct) — Reads inline image dictionaries and raw image data without tokenizing image
- **`parse_next_operation`** (Function) — Reads the next normal content operation for callers that are not consuming
- **`ContentStream`** (Struct) — Parsed decoded content stream aggregate preserving source order for every
- **`parse_decoded_content`** (Function) — Parses already-decoded content stream bytes with an explicit resource
- **`ResourceCategory`** (Enum) — Public resource dictionary category model for content streams per §7.8.3:
- **`ContentOperation`** (Struct) — A parsed normal content stream instruction containing the recognized
- **`ContentStreamParser`** (Struct) — Iterates decoded content stream bytes, collecting PDF object operands until
- **`CompatibilityTracker`** (Struct) — Tracks balanced compatibility operators `BX` and `EX` while the content
- **`recognize_operator`** (Function) — Recognizes exact Annex A operator keywords and leaves unknown keywords as
- **`ContentInput`** (Struct) — Cursor wrapper for decoded content bytes. The parser layer keeps the same
- **`read_next`** (Function) — Reads the next direct operand or operator candidate from the content
- **`with_resources`** (Function) — Creates a content stream parser over already-decoded bytes with an explicit
- **`is_active`** (Function) — Reports whether unknown operators shall be ignored because the parser is
- **`empty`** (Function) — Creates an empty content resource context for pages or streams with no
- **`ContentOperandReader`** (Struct) — Reads direct operands from decoded content bytes without performing
- **`compatibility_depth`** (Function) — Returns the current compatibility section depth maintained from `BX` and
- **`end`** (Function) — Leaves one `EX` compatibility section and rejects unbalanced `EX` markers.
- **`parse_all`** (Function) — Parses all decoded content bytes into an ordered content stream aggregate.
- **`new`** (Function) — Creates a compatibility section tracker with zero active `BX` depth.
- **`peek_n`** (Function) — Peeks ahead within the decoded content input without consuming it.
- **`require_stream_eol`** (Function) — Requires the stream EOL convention used by lower parsing layers.
- **`peek`** (Function) — Peeks at the current decoded content byte without consuming it.
- **`read_eol`** (Function) — Reads a logical EOL marker from the decoded content input.
- **`offset`** (Function) — Current byte offset within the decoded content input.
- **`read_bytes`** (Function) — Reads a raw byte span from the decoded content input.
- **`StandardContentOperator`** (Enum) — Standard Annex A content-stream operator vocabulary.
- **`OperandReadResult`** (Enum) — Result of reading the next decoded content token.
- **`begin`** (Function) — Enters one `BX` compatibility section.
- **`read_dictionary`** (Function) — 


- **`is_real_lexeme`** (Function) — 


- **`sign_prefix_length`** (Function) — 


- **`all_digits_from`** (Function) — 


- **`is_digit`** (Function) — 


- **`parse_int64_lexeme`** (Function) — 


- **`parse_double_lexeme`** (Function) — 


- **`byte_to_text`** (Function) — 


- **`bytes_to_text`** (Function) — 


- **`take_operands`** (Function) — 


- **`is_integer_lexeme`** (Function) — 


- **`read_direct_operand`** (Function) — 


- **`read_value`** (Function) — 


- **`classify_regular_token`** (Function) — 


- **`read_array`** (Function) — 


- **`is_stream_like_keyword`** (Function) — 


- **`read_dictionary_body`** (Function) — 


- **`handle_operator`** (Function) — 


- **`consume_array_start`** (Function) — 


- **`consume_dictionary_start`** (Function) — 


- **`label`** (Function) — 


- **`label_bytes`** (Function) — 


- **`consume_dictionary_end`** (Function) — 


- **`skip_separators`** (Function) — 


- **`next_token`** (Function) — 


- **`read_dictionary_until_id`** (Function) — 


- **`consume_required_data_space`** (Function) — 


- **`read_data_until_ei`** (Function) — 


- **`inline_image_end_delta_after_space`** (Function) — 


- **`is_valid_inline_image_end_follow`** (Function) — 


- **`consume_inline_image_end_marker`** (Function) — 


- **`read_raw_byte`** (Function) — 


- **`read_byte`** (Function) — 


- **`is_numeric_like`** (Function) —
