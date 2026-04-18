# Acceptance

## Visual Result

- `<local-fixture>:page_2` baseline changed from `0.0530` to `0.0477`.
- The rendered page 2 right-column crop has visible text pixels:

```text
dark pixels: 8276
non-white pixels: 29410
```

The right column no longer renders blank under `rsvg-convert`.

## Regression Harness

```text
no regression: <local-fixture>:page_6 diff 0.1612 <= 0.1612 + 0.0020
no regression: <local-fixture>:page_7 diff 0.2145 <= 0.2145 + 0.0020
no regression: <local-fixture>:page_4 diff 0.0025 <= 0.0025 + 0.0020
no regression: <local-fixture>:page_5 diff 0.0713 <= 0.0713 + 0.0020
no regression: <local-fixture>:page_6 diff 0.1082 <= 0.1082 + 0.0020
no regression: <local-fixture>:page_2 diff 0.0477 <= 0.0477 + 0.0020
```

## Commands

```bash
moon fmt
moon test --target native
npm test
moon info
```

All commands exited 0. `moon test --target native` reported `732` tests
passed. `npm test` reported the full harness regression checked `6`
baselines.
