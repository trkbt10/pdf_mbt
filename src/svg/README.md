# SVG Helper Index

This package keeps SVG rendering helper logic package-local so future refactors
can reuse one implementation instead of copying small formatting or emission
rules.

## DRY / SSoT Helpers

- `write_svg_clip_wrapper_begin` / `write_svg_clip_wrapper_end`:
  wrap transformed glyph path and high-volume text output in an untransformed
  page-space clip group.
- `format_svg_number_with_precision`: shared decimal formatting body for the
  standard 3-decimal SVG formatter and the 6-decimal precise formatter.
- `cff_write_uint`: parameterized big-endian integer writer for synthetic CFF
  wrapper tables.
- `parse_cff_charset_range_format`: shared CFF charset range parser for
  format 1 and format 2, parameterized by `num_left` byte width.
- `cid_pad5` / `pad_unsigned_decimal`: shared zero-padding for cid.XXXXX glyph
  names used by CFF post table synthesis and SVG CID glyph lookup.
- `push_system_font_directories`: table-driven OS font directory expansion
  backed by `system_font_dir_tables`.
- `std14_*` constants: Standard 14 font name single source of truth for
  system font resolution and SVG fallback family mapping.
