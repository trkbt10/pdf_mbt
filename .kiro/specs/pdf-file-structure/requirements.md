# Requirements Document

## Introduction
この機能は、ISO 32000-2:2020 (PDF 2.0) 第7.5節に準拠した PDF ファイル構造パーサーを提供する。PDF ファイルは Header、Body、Cross-reference table、Trailer の4要素で構成される。この仕様は pdf-objects の上位層であり、PDF ファイル全体のバイト列からオブジェクトのランダムアクセスを可能にするクロスリファレンス機構を実現する。後続の文書構造解析（Catalog, Page tree 等）がこの層の上に構築される。

依存: `pdf-objects` spec（Requirement 1-16）が前提。

## Requirements

### Requirement 1: ファイルヘッダの解析
**Objective:** As a PDF パーサー実装者, I want PDF ファイルの先頭バイト列からバージョン情報を抽出したい, so that PDF のバージョン判定とバイナリ判定ができる

#### Acceptance Criteria
1. The PDF File Parser shall ファイル先頭の `%PDF-X.Y` バイト列を認識し、バージョン番号（X.Y）を抽出する
2. The PDF File Parser shall バージョン `1.0` 〜 `1.7` および `2.0` を有効なバージョンとして受理する
3. The PDF File Parser shall `%PDF-` 直後のバージョン数字の後に EOL マーカーを要求する
4. The PDF File Parser shall ヘッダ直後のコメント行（4バイト以上の 0x80 以上のバイト値を含む）をバイナリファイル識別子として認識する
5. The PDF File Parser shall バイトオフセットの計算基点を `%` (0x25) の位置とする

### Requirement 2: ファイル末尾からの逆方向解析
**Objective:** As a PDF パーサー実装者, I want ファイル末尾の `%%EOF` と `startxref` からクロスリファレンスの位置を特定したい, so that 最新のクロスリファレンスセクションに到達できる

#### Acceptance Criteria
1. The PDF File Parser shall ファイル末尾から `%%EOF` マーカーを検索する
2. The PDF File Parser shall `%%EOF` の前にある `startxref` キーワードを検索する
3. The PDF File Parser shall `startxref` の後の10進整数をクロスリファレンスセクションの開始バイトオフセットとして解析する
4. The PDF File Parser shall インクリメンタル更新により複数の `%%EOF` が存在する場合、最後の `%%EOF` を使用する

### Requirement 3: クロスリファレンステーブルの解析
**Objective:** As a PDF パーサー実装者, I want `xref` キーワードで始まるクロスリファレンステーブルを解析したい, so that 各間接オブジェクトのバイトオフセットを取得できる

#### Acceptance Criteria
1. The PDF File Parser shall `xref` キーワードで始まるクロスリファレンスセクションを認識する
2. The PDF File Parser shall サブセクションヘッダ `<開始オブジェクト番号> <エントリ数>` を解析する
3. The PDF File Parser shall 各クロスリファレンスエントリを正確に20バイト（EOL含む）として解析する
4. The PDF File Parser shall in-use エントリ (`n` タイプ) を以下の形式で解析する: `nnnnnnnnnn ggggg n <EOL>` — 10桁のバイトオフセット（ゼロパディング）、5桁の世代番号（ゼロパディング）、`n` マーカー
5. The PDF File Parser shall free エントリ (`f` タイプ) を以下の形式で解析する: `nnnnnnnnnn ggggg f <EOL>` — 10桁の次フリーオブジェクト番号、5桁の世代番号、`f` マーカー
6. The PDF File Parser shall エントリの2バイト EOL として SP+CR (0x20 0x0D)、SP+LF (0x20 0x0A)、CR+LF (0x0D 0x0A) のいずれかを受理する
7. The PDF File Parser shall オブジェクト0が常にフリーで世代番号 65535 であることを検証する
8. The PDF File Parser shall 複数のサブセクションを持つクロスリファレンスセクションを正しく解析する
9. The PDF File Parser shall `xref` と `trailer` の間に PDF コメントが存在しないことを前提とする

### Requirement 4: トレーラ辞書の解析
**Objective:** As a PDF パーサー実装者, I want `trailer` キーワードの後の辞書からルートオブジェクト参照等を取得したい, so that 文書のエントリポイントに到達できる

#### Acceptance Criteria
1. The PDF File Parser shall `trailer` キーワードに続く Dictionary オブジェクトをトレーラ辞書として解析する
2. The PDF File Parser shall トレーラ辞書の必須エントリ `Size` (integer, 直接オブジェクト) を検証する — クロスリファレンステーブルの総エントリ数（= 最大オブジェクト番号 + 1）
3. The PDF File Parser shall トレーラ辞書の必須エントリ `Root` (間接参照) を取得する — Catalog 辞書への参照
4. The PDF File Parser shall 任意エントリ `Prev` (integer, 直接オブジェクト) を認識する — 前のクロスリファレンスセクションへのバイトオフセット（インクリメンタル更新時）
5. The PDF File Parser shall 任意エントリ `Encrypt` を認識する — 暗号化辞書への参照
6. The PDF File Parser shall 任意エントリ `Info` (間接参照) を認識する — 情報辞書（PDF 2.0 では非推奨）
7. The PDF File Parser shall 必須エントリ `ID` (2要素の byte-string 配列, 直接オブジェクト, PDF 2.0 で必須) を認識する

### Requirement 5: インクリメンタル更新の追跡
**Objective:** As a PDF パーサー実装者, I want `Prev` エントリを辿って全てのクロスリファレンスセクションを結合したい, so that 最新のオブジェクト状態を取得できる

#### Acceptance Criteria
1. The PDF File Parser shall 最新のトレーラから `Prev` エントリを辿り、過去のクロスリファレンスセクションを順次読み込む
2. The PDF File Parser shall 同一オブジェクト番号について、最新のクロスリファレンスエントリを優先する
3. The PDF File Parser shall フリーマーカー (`f`) のエントリはオブジェクトが削除されたことを示すものとして、対応するオブジェクトを無効化する
4. The PDF File Parser shall 最終的に全セクションを結合した単一のオブジェクト番号→バイトオフセットのマッピングを構築する

### Requirement 6: オブジェクトストリーム (PDF 1.5+)
**Objective:** As a PDF パーサー実装者, I want `/Type /ObjStm` のストリームオブジェクト内に格納された間接オブジェクト群を解析したい, so that 圧縮されたオブジェクトにアクセスできる

#### Acceptance Criteria
1. The PDF File Parser shall ストリーム辞書に `/Type /ObjStm` を持つストリームをオブジェクトストリームとして認識する
2. The PDF File Parser shall オブジェクトストリーム辞書の必須エントリ `N` (integer) — ストリーム内のオブジェクト数、`First` (integer) — デコード済みストリーム内の最初のオブジェクトのバイトオフセットを使用する
3. The PDF File Parser shall デコード済みストリームの先頭部分を N 個の整数ペア（オブジェクト番号, バイトオフセット）として解析する
4. The PDF File Parser shall 各オブジェクトを指定されたバイトオフセットから読み取る（`obj`/`endobj` キーワードなし）
5. The PDF File Parser shall オブジェクトストリーム内のオブジェクトの世代番号が全て0であることを前提とする
6. The PDF File Parser shall ストリームオブジェクト自体はオブジェクトストリーム内に格納できないという制約を認識する

### Requirement 7: クロスリファレンスストリーム (PDF 1.5+)
**Objective:** As a PDF パーサー実装者, I want `/Type /XRef` のストリームオブジェクトをクロスリファレンス情報源として解析したい, so that テーブル形式とストリーム形式の両方のクロスリファレンスに対応できる

#### Acceptance Criteria
1. The PDF File Parser shall ストリーム辞書に `/Type /XRef` を持つストリームをクロスリファレンスストリームとして認識する
2. The PDF File Parser shall クロスリファレンスストリーム辞書の必須エントリを解析する:
   - `Type` (name, 直接): `/XRef`
   - `Size` (integer, 直接): 最大オブジェクト番号 + 1
   - `W` (array, 直接): 3つの整数 — 各フィールドのバイト幅
   - `Index` (array, 直接, 任意): サブセクション定義。省略時は `[0 Size]`
3. The PDF File Parser shall `W` 配列の3つの整数を使用して各エントリのフィールドサイズを決定する（例: `[1 2 2]` = Type 1バイト + Offset/StreamNum 2バイト + Gen/Index 2バイト）
4. The PDF File Parser shall マルチバイトフィールドをビッグエンディアン（上位バイトが先）で読み取る
5. The PDF File Parser shall Type 0 (フリー)、Type 1 (非圧縮 in-use)、Type 2 (オブジェクトストリーム内) の3種のエントリタイプを解析する:
   - Type 0: Field2 = 次フリーオブジェクト番号、Field3 = 世代番号
   - Type 1: Field2 = ファイル先頭からのバイトオフセット、Field3 = 世代番号
   - Type 2: Field2 = オブジェクトストリームのオブジェクト番号、Field3 = ストリーム内インデックス
6. The PDF File Parser shall `W[0]` が 0 の場合、Type フィールドを省略しデフォルト値 1 (Type 1) として扱う
7. The PDF File Parser shall クロスリファレンスストリーム自体は暗号化されないことを前提とする

### Requirement 8: ハイブリッドリファレンスファイル
**Objective:** As a PDF パーサー実装者, I want テーブル形式とストリーム形式が混在するハイブリッドファイルを正しく解析したい, so that PDF 1.5 前後の互換性を持つファイルに対応できる

#### Acceptance Criteria
1. The PDF File Parser shall トレーラ辞書に `XRefStm` エントリ（integer — クロスリファレンスストリームへのバイトオフセット）が存在する場合、ハイブリッドファイルとして認識する
2. The PDF File Parser shall オブジェクト検索時に以下の優先順で参照する: (1) 現セクションのクロスリファレンステーブル、(2) `XRefStm` が指すクロスリファレンスストリーム、(3) `Prev` が指す前セクション

### Requirement 9: オブジェクトのランダムアクセス読み込み
**Objective:** As a PDF パーサー実装者, I want オブジェクト番号を指定して任意の間接オブジェクトを読み込みたい, so that 必要なオブジェクトだけをオンデマンドで解析できる

#### Acceptance Criteria
1. The PDF File Parser shall オブジェクト番号と世代番号を指定して、クロスリファレンス情報から対象オブジェクトのバイトオフセットを解決する
2. The PDF File Parser shall Type 1 エントリの場合、ファイル内の指定オフセットにシークし、`N G obj ... endobj` を解析する
3. The PDF File Parser shall Type 2 エントリの場合、オブジェクトストリームをデコードし、指定インデックスのオブジェクトを取得する
4. The PDF File Parser shall 間接参照の解決を遅延実行可能にする（参照されたときに初めて読み込む）
5. The PDF File Parser shall 存在しないオブジェクトへの参照を Null として返す

### Requirement 10: サンプルファイルによる検証
**Objective:** As a PDF パーサー実装者, I want ISO 32000-2 Annex H のサンプルおよび `spec/pdf20examples/` の実ファイルで解析結果を検証したい, so that 仕様準拠を実ファイルで確認できる

#### Acceptance Criteria
1. The PDF File Parser shall Annex H.2 の Minimal PDF（5オブジェクト: Catalog, Pages, Page, Content stream, Metadata）を正しく解析する
2. The PDF File Parser shall Annex H.3 の Simple Text String Example（7オブジェクト、フォントリソース）を正しく解析する
3. The PDF File Parser shall `spec/pdf20examples/Simple PDF 2.0 file.pdf` を正しく解析し、全オブジェクトにアクセスできる
4. The PDF File Parser shall `spec/pdf20examples/PDF 2.0 with offset start.pdf`（先頭にオフセットがあるファイル）を正しく解析する
5. The PDF File Parser shall `spec/pdf20examples/PDF 2.0 via incremental save.pdf`（インクリメンタル更新を含むファイル）を正しく解析する
