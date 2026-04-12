# Product Steering

## Project Overview
MoonBit で ISO 32000-2:2020 (PDF 2.0) 準拠の PDF パーサーライブラリを実装する。

## Goals
- PDF ファイルの読み取り（パース）を主目的とする
- 仕様準拠を最優先とし、ISO 32000-2:2020 の規範的要件に忠実に従う
- 段階的に積み上げ可能な構造: Objects → File Structure → Document Structure → Content Streams → ...

## Non-Goals (Phase 1)
- PDF の生成（ライティング）は対象外
- 暗号化・復号は後続フェーズ
- フォント処理・レンダリングは後続フェーズ
- コンテンツストリームの解釈は後続フェーズ

## Target Users
- MoonBit でPDFを扱うライブラリ作者・アプリケーション開発者
- indexion プロジェクト（PDF をソースとして処理するため）
