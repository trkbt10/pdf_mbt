# Technical Steering

## Language & Tooling
- **Language**: MoonBit (moonbitlang.com)
- **Build**: `moon build`, `moon test`, `moon fmt`, `moon info`
- **Module**: `trkbt10/pdf` (moon.mod.json)
- **Target**: native (primary), wasm (secondary)

## MoonBit Conventions
- ブロックスタイル: 各ブロックは `///|` で区切る
- パッケージ: 各ディレクトリに `moon.pkg` ファイル
- テスト: `*_test.mbt` (blackbox), `*_wbtest.mbt` (whitebox)
- エラー処理: `suberror` + `raise` + `Result` パターン
- 可視性: `pub(all) enum` (外部パターンマッチ用), `pub struct` (外部読み取り用)

## Architecture Principles
- バイト列ベースのパーサー（PDF はバイトストリーム）
- 遅延評価: 間接参照はアクセス時に解決
- ゼロコピー志向: 可能な限りバッファのコピーを避ける
- 各レイヤーは独立してテスト可能

## Package Structure
```
src/
  objects/   - PdfObject 型定義、エラー型
  lexer/     - バイト→トークン変換（文字分類、文字列/名前パース）
  parser/    - トークン→PdfObject 変換
  reader/    - ファイル構造（xref, trailer）パース（Phase 2）
```

## Specification Reference
- 仕様書: `spec/pdf/<local-fixture>` (1020ページ)
- テキスト抽出済み: `spec/extracted/7.*.md`
- サンプルPDF: `spec/pdf20examples/`
