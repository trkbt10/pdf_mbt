# Structure Steering

## Directory Layout
```
pdf/
├── .kiro/
│   ├── specs/           - SDD specifications
│   │   ├── pdf-objects/       - Phase 1: PDF低レベル構文
│   │   ├── pdf-file-structure/ - Phase 2: ファイル構造
│   │   ├── pdf-filters/       - Phase 3: ストリームフィルタ
│   │   └── ...
│   └── steering/        - Project-wide guidance
├── spec/
│   ├── pdf/             - ISO PDF仕様書 (PDF files)
│   ├── pdf20examples/   - PDF 2.0 サンプルファイル
│   └── extracted/       - 仕様書テキスト抽出 (Markdown)
├── src/
│   ├── objects/         - PdfObject enum, PdfError suberror
│   ├── lexer/           - Byte-level lexer
│   ├── parser/          - Object parser
│   └── reader/          - File structure reader (Phase 2)
├── cmd/
│   └── main/            - CLI entry point
├── moon.mod.json        - Module definition
└── moon.pkg             - Root package
```

## Naming Conventions
- パッケージ名: snake_case (`pdf_objects` ではなく `objects`)
- 型名: PascalCase (`PdfObject`, `Lexer`)
- 関数名: snake_case (`read_literal_string`)
- テストファイル: `*_test.mbt` (blackbox), `*_wbtest.mbt` (whitebox)

## Dependencies
- 外部依存: なし（標準ライブラリのみ）
- パッケージ間依存: objects ← lexer ← parser ← reader
