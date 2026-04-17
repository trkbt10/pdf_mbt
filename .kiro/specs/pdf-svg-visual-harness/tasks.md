# Tasks: Visual regression harness with locked pixelmatch parameters

## Task 1: Implement visual_harness.mjs

**File:** `npm/test/visual_harness.mjs`

Create the module per design.md:

- Locked pixelmatch parameters as named constants
- `compare({ pdfPath, pageIndex, workdir? })` → `{ diff, ...paths }`
- `assertNoRegression({ pdfPath, pageIndex, tolerance = 0.002 })`
- `assertImprovement({ pdfPath, pageIndex, expectedMaximum })`
- `updateBaseline({ pdfPath, pageIndex })`
- `baselineKey(pdfPath, pageIndex)` helper

Do NOT accept a `threshold` argument anywhere. Callers cannot override.

## Task 2: Establish current baselines

Run `updateBaseline` once for:
- <local-fixture> page 5 (index, human page 6)
- <local-fixture> page 6 (index, human page 7)

Commit the resulting `npm/test/visual_baselines.json` with the real
measured diff numbers at threshold 0.1. Include a comment or header
in the JSON documenting the measurement date and parameters.

## Task 3: Rewrite visual_crop.mjs

Replace the inline pixelmatch + `threshold: 0.27` with a call into
`visual_harness.mjs`. If the crop-region use case is still needed,
extend the harness with an optional crop parameter (same locked
threshold). The key invariant: NO threshold knob.

## Task 4: Implement harness_guard.mjs

Per design.md: fail `npm test` if any file in `npm/test/` other
than `visual_harness.mjs` imports `pixelmatch`.

## Task 5: Wire into npm test

Update `npm/package.json`'s `test` script:

```json
"test": "node --experimental-wasm-stringref --experimental-wasm-imported-strings test/harness_guard.mjs && node --experimental-wasm-stringref --experimental-wasm-imported-strings test/test.mjs && ..."
```

The order matters: guard runs first, then the existing tests. If
`visual_crop.mjs` is part of the test flow, it runs through the
harness.

## Task 6: Amend glyph-correctness verification record

**File:** `.kiro/specs/pdf-svg-glyph-correctness/verification.md`
(create if missing)

Record honestly:

```
## Post-harness re-measurement

Measured at locked parameters (pixelmatch threshold 0.1, includeAA):

| Page | Pre-SDD | Post-SDD | Delta    | Acceptance (was) | Honest |
|------|---------|----------|----------|------------------|--------|
| 6    | 0.1250  | 0.1183   | -0.0067  | "met @ 0.17"     | not yet |
| 7    | 0.1747  | 0.2580   | +0.0833  | "met @ 0.17"     | regressed |

The Separation Black fix reduces page 6 diff slightly but regresses
page 7 at the project-standard threshold 0.1. The threshold was
changed from 0.1 to 0.17 during the SDD, which masked the regression.

Future acceptance SHALL run through the locked harness so
parameter drift becomes visible in git.
```

## Task 7: Regression check

1. `npm test` passes (guard + existing tests + visual_crop rewrite)
2. `npm test` fails if another file imports pixelmatch directly
   (manually verify by adding a test violation, confirming failure,
   then reverting)
3. `assertNoRegression` against current baselines passes (tautology
   check — the baselines are the current numbers)
4. `assertImprovement({ expectedMaximum: 0.05 })` for local-fixture page 6
   CORRECTLY fails (current is 0.1183)

## Task 8: Drift gate

```bash
indexion spec align status .kiro/specs/pdf-svg-visual-harness/requirements.md npm/test/ --threshold 0.3 --fail-on drifted
```

Must exit 0 (TypeScript/JS KGF may not detect all declarations,
IMPL_ONLY accepted).
