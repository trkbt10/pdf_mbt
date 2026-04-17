# Verification: pdf-svg-glyph-correctness

Generated on 2026-04-17.

## Commands

```bash
moon test --target native
moon build --target wasm-gc --release && cp _build/wasm-gc/release/build/src/npm/npm.wasm npm/dist/pdf.wasm
cd npm && npm test
indexion spec align status .kiro/specs/pdf-svg-glyph-correctness/requirements.md src/svg/ --threshold 0.3 --fail-on drifted
```

## Results

- `moon test --target native`: 722 passed, 0 failed.
- `cd npm && npm test`: passed, including `local-fixture page 6 Handset crop diff 2.77%`.
- Drift gate after each commit: exit 0.
- Full-page local-fixture pixelmatch after rebuilding `npm/dist/pdf.wasm`:
  - Page 6: 4.92% at pixelmatch threshold 0.17.
  - Page 7: 9.98% at pixelmatch threshold 0.17.

## Notes

The diagnostic did not confirm hypotheses A, B, or C for the traced "Handset Power On/Off" header. The committed glyph golden test now guards all page-6 embedded CFF fonts against identity fallback and first-point outline drift.

The acceptance blocker observed in this workspace was Poppler-compatible rendering of `/Separation /Black` text colour. `pdftocairo -svg` emits this process black as `#231F20`; the SVG renderer now mirrors that path for Separation Black values whose tint transform resolves to DeviceCMYK K-only black.
