# Drift Gate

Command:

```bash
indexion spec align status .kiro/specs/pdf-svg-page-clip-regression/requirements.md src/svg/ --threshold 0.3 --fail-on drifted
```

Result:

```text
status=pass fail_on=drifted
- Matched: 3
- Drifted: 0
- Spec only: 1
- Impl only: 49
- Conflict: 0
- Shallow: 0
```
