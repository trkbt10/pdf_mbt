#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"

cd "$ROOT_DIR"
moon build --target wasm-gc --release
mkdir -p npm/dist
cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm
