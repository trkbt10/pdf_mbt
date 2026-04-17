# Diagnostic output: local-fixture page 6 glyph trace

Generated on 2026-04-17 with:

```bash
moon test --target native -p trkbt10/pdf/src/svg 2>&1 | grep "diagnostic local-fixture glyph_trace"
pdftocairo -f 6 -l 6 -svg <local-fixture> /tmp/pdfsvg/local-fixture-page6-poppler.svg
```

## Handset trace excerpt

```text
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x48 glyph_id_resolved=24 post_name_at_gid=H outline_first_point=(65,0)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x61 glyph_id_resolved=41 post_name_at_gid=a outline_first_point=(562,0)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x6E glyph_id_resolved=54 post_name_at_gid=n outline_first_point=(56,0)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x64 glyph_id_resolved=44 post_name_at_gid=d outline_first_point=(616,750)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x73 glyph_id_resolved=59 post_name_at_gid=s outline_first_point=(36,13)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x65 glyph_id_resolved=45 post_name_at_gid=e outline_first_point=(573,208)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x74 glyph_id_resolved=60 post_name_at_gid=t outline_first_point=(10,395)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x20 glyph_id_resolved=1 post_name_at_gid=space outline_first_point=<empty>
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x50 glyph_id_resolved=32 post_name_at_gid=P outline_first_point=(55,0)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x6F glyph_id_resolved=55 post_name_at_gid=o outline_first_point=(334,-12)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x77 glyph_id_resolved=63 post_name_at_gid=w outline_first_point=(169,0)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x65 glyph_id_resolved=45 post_name_at_gid=e outline_first_point=(573,208)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x72 glyph_id_resolved=58 post_name_at_gid=r outline_first_point=(437,527)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x20 glyph_id_resolved=1 post_name_at_gid=space outline_first_point=<empty>
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x4F glyph_id_resolved=31 post_name_at_gid=O outline_first_point=(39,349)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x6E glyph_id_resolved=54 post_name_at_gid=n outline_first_point=(56,0)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x2F glyph_id_resolved=9 post_name_at_gid=slash outline_first_point=(-21,-12)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x4F glyph_id_resolved=31 post_name_at_gid=O outline_first_point=(39,349)
diagnostic local-fixture glyph_trace: font=T1_3 char_code=0x66 glyph_id_resolved=46 post_name_at_gid=f outline_first_point=(119,0)
```

## Analysis

- Hypothesis C is false for the traced header: every non-space row resolves to an Adobe glyph name, not a `cidNNNNN` post-name fallback.
- The traced glyph IDs are subset-reordered and differ from raw WinAnsi character codes, so identity fallback is not winning for the header.
- Poppler's `pdftocairo -svg` output uses the same outlines after normalization. Example: Poppler `glyph-4-0` (`H`) starts at `M 0.71875 0`; MoonBit resolves `H` to first point `(65,0)` and renders it through `matrix(0.011 0 0 -0.011 ...)`, giving `0.715` before rounding.
- The remaining measured page-6 pixelmatch at threshold `0.1` is `12.50%`, but the visible header crop differs primarily because Poppler fills text with near-black `#231F20` while the current SVG text paths use `#000000`.

Conclusion: the diagnostic evidence does not confirm A, B, or C for the "Handset Power On/Off" header. The acceptance blocker observed in this workspace is text colour propagation/conversion, not a glyph-id fallback in the traced chain.
