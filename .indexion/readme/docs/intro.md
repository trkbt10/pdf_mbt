# trkbt10/pdf

A pure [MoonBit](https://www.moonbitlang.com/) implementation of the **ISO 32000-2 (PDF 2.0)** specification — a complete read-side pipeline from raw bytes to structured document access, graphics interpretation, and text extraction.

## Features

- **Spec-faithful object model** — `PdfObject`, `PdfName`, `PdfStream`, `PdfDictionary` directly mirror ISO 32000-2 §7.3. Every type and function cites its spec clause.
- **Full file structure parsing** — Header, cross-reference tables (both table and stream formats), trailer chains, incremental updates, and object streams.
- **Zero native dependencies** — All decompression filters (DEFLATE, LZW, ASCII85, ASCIIHex, RunLength) and cryptographic primitives (AES-128/CBC, RC4, MD5, SHA-256/384/512) are implemented in pure MoonBit — no C FFI.
- **Content stream interpretation** — All ~70 PDF content stream operators with BX/EX compatibility section tracking.
- **Graphics state machine** — Full clause 8-11 coverage: coordinate transforms, colour spaces (Device, CIE, ICC, Pattern, Separation, DeviceN), paths, clipping, XObjects, optional content layers.
- **Text extraction** — CMap parsing, font encoding tables (Standard, MacRoman, WinAnsi), Unicode mapping, text span extraction with positions.
- **Document structure** — Catalog, page tree, annotations, actions, outlines, tagged PDF structure trees, interactive forms, digital signatures, multimedia, and more.

## Architecture

```
┌─────────────────────────────────────────────┐
│                  rendering                   │  Halftone, surface, colour output
├─────────────────────────────────────────────┤
│            graphics  │   text                │  State machine interpreters
├─────────────────────────────────────────────┤
│                  content                     │  Content stream operators
├─────────────────────────────────────────────┤
│                  reader                      │  Document structure, xref, catalog
├─────────────────────────────────────────────┤
│                  parser                      │  Object parser (dict, array, stream)
├─────────────────────────────────────────────┤
│                  lexer                       │  Byte cursor, tokenizer
├─────────────────────────────────────────────┤
│   objects  │ common_data │ filters │ crypto  │  Foundation types and algorithms
└─────────────────────────────────────────────┘
```

Each layer depends only on the layers below it.

## Usage

```moonbit
// Open and parse a PDF file
let file = @reader.PdfFile::open(bytes)
let doc = @reader.PdfDocument::from_file(file)

// Extract text from a page
let content = @reader.content_stream(file, page)
let program = @text.interpret_text(content, resources, initial)
for span in program.spans {
  println(span.text)
}
```

## Getting Started

Add to your `moon.mod.json`:

```json
{
  "deps": {
    "trkbt10/pdf": ""
  }
}
```

```sh
moon build
moon test
```
