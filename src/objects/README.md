# objects

## API

- **`PdfObject`** (Enum) — Type-safe ISO 32000-2 section 7.3 object model:
- **`PdfStream`** (Struct) — ISO 32000-2 section 7.3.8 Stream object, pairing the stream dictionary
- **`PdfName`** (Struct) — ISO 32000-2 section 7.3.5 Name object value. PdfName stores the decoded
- **`ObjectId`** (Struct) — Identifier for an ISO 32000-2 section 7.3.10 indirect object or indirect
- **`PdfDictionary`** (Type) — ISO 32000-2 section 7.3.7 Dictionary object map from Name object keys to
- **`as_number`** (Function) — Requires a numeric object where ISO 32000-2 section 7.3.3 allows either an
- **`to_text`** (Function) — Decodes Name object bytes as UTF-8 for display only; equality remains
- **`as_integer`** (Function) — Requires an Integer object where ISO 32000-2 section 7.3.3 allows only a
- **`IndirectObject`** (Struct) — Parsed ISO 32000-2 section 7.3.10 indirect object definition in the
- **`dictionary_get_or_null`** (Function) — Looks up a Dictionary object entry, returning the Null object when the
- **`expect_token_error`** (Function) — Builds a typed object expectation error at the current byte offset.
- **`kind_name`** (Function) — Internal kind name for ISO 32000-2 section 7.3 object diagnostics.
- **`as_dictionary`** (Function) — Requires a Dictionary object from ISO 32000-2 section 7.3.7.
- **`is_null`** (Function) — Returns true for the ISO 32000-2 section 7.3.9 Null object.
- **`as_ref`** (Function) — Requires an ISO 32000-2 section 7.3.10 indirect reference.
- **`new`** (Function) — Creates a Name object payload with byte-sequence equality.
- **`as_stream`** (Function) — Requires a Stream object from ISO 32000-2 section 7.3.8.
- **`as_name`** (Function) — Requires a Name object from ISO 32000-2 section 7.3.5.
