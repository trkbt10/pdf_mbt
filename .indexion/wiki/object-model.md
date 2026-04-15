# Object Model

The `src/objects/` package defines the ISO 32000-2 §7.3 object hierarchy as a type-safe enum.

## PdfObject

Ten variants covering all PDF object types:

| Variant | ISO Section | MoonBit Type |
|---------|-------------|--------------|
| Boolean | §7.3.2 | `Bool` |
| Integer | §7.3.3 | `Int64` |
| Real | §7.3.3 | `Double` |
| String | §7.3.4 | `Bytes` (literal or hex) |
| Name | §7.3.5 | `PdfName` (decoded byte sequence) |
| Array | §7.3.6 | `Array[PdfObject]` |
| Dictionary | §7.3.7 | `Map[PdfName, PdfObject]` |
| Stream | §7.3.8 | `PdfStream` (dict + raw bytes) |
| Null | §7.3.9 | unit |
| Ref | §7.3.10 | `ObjectId` (object number + generation) |

## PdfName Equality

`PdfName` stores the decoded byte sequence after SOLIDUS prefix and `#XX` hex escape expansion. Equality is **byte-sequence comparison**, not string comparison. This correctly handles non-UTF-8 names in legacy files.

## Accessors

Type-safe extraction methods (`as_integer`, `as_number`, `as_name`, `as_dictionary`, `as_ref`, `as_stream`) raise `PdfParseError` on type mismatch. `dictionary_get_or_null` returns Null for missing keys.

## See Also

- wiki://overview
- wiki://file-reading
