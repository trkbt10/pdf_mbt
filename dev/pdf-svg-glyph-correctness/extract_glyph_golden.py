#!/usr/bin/env python3
"""Generate local-fixture page-6 glyph golden cases for render_wbtest.mbt.

This is a dev-only helper. It writes a temporary MoonBit whitebox test into
src/svg, runs the SVG package tests for the local local-fixture fixture, parses the
sample glyph rows, prints Page6GlyphOutlineGolden entries, and removes the
temporary file. The generated entries are embedded in render_wbtest.mbt so CI
does not need Python at test runtime.

The fallback generator is intentionally based on the committed diagnostic path
because fontTools/pikepdf were not available in the implementation workspace on
2026-04-17.
"""

from __future__ import annotations

import pathlib
import re
import subprocess


ROOT = pathlib.Path(__file__).resolve().parents[2]
TMP_TEST = ROOT / "src/svg/tmp_glyph_samples_wbtest.mbt"

TMP_SOURCE = r'''///|
test "tmp local-fixture page 6 glyph samples" {
  let path = "<local-fixture>"
  if !@fs.path_exists(path) {
    return
  }
  let document = @reader.PdfDocument::open(@fs.read_file_to_bytes(path))
  let page = document.page(5)
  let result : Result[@text.TextProgram, @reader.PdfDocumentError] = try? page.text_program(
    @reader.TextPageOptions::default(),
  )
  match result {
    Ok(program) => {
      let glyph_groups = text_program_span_glyphs(program)
      let embedded_fonts = page_svg_embedded_fonts(page)
      let seen : Map[@objects.PdfName, Bool] = Map::new()
      for index in 0..<program.spans.length() {
        let span = program.spans[index]
        match span.font_name {
          Some(font_name) =>
            if seen.get(font_name) != Some(true) {
              match embedded_fonts.get(font_name) {
                Some(ttf) => {
                  let glyphs = span_glyphs(glyph_groups, index)
                  for glyph in glyphs {
                    let gid = svg_resolve_glyph_id(ttf, glyph)
                    if gid >= 0 &&
                      gid < ttf.num_glyphs &&
                      ttf.glyph_outline(gid).length() > 0 {
                      println(
                        "tmp glyph_sample font=" +
                        font_name.to_text() +
                        " code=" +
                        glyph.glyph.source_code.to_string() +
                        " gid=" +
                        gid.to_string() +
                        " first=" +
                        diagnostic_outline_first_point(ttf, gid),
                      )
                      seen[font_name] = true
                      break
                    }
                  }
                }
                None => ()
              }
            }
          None => ()
        }
      }
    }
    Err(_) => ()
  }
}
'''

ROW = re.compile(
    r"tmp glyph_sample font=(?P<font>\S+) code=(?P<code>\d+) "
    r"gid=(?P<gid>-?\d+) first=\((?P<x>-?\d+(?:\.\d+)?),(?P<y>-?\d+(?:\.\d+)?)\)"
)


def main() -> None:
    TMP_TEST.write_text(TMP_SOURCE, encoding="utf-8")
    try:
        result = subprocess.run(
            ["moon", "test", "--target", "native", "-p", "trkbt10/pdf/src/svg"],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=True,
        )
    finally:
        TMP_TEST.unlink(missing_ok=True)

    rows = []
    for line in result.stdout.splitlines():
        match = ROW.search(line)
        if match:
            rows.append(match.groupdict())

    wanted = {"T1_0", "T1_1", "T1_2", "T1_3", "T1_4", "T1_5", "C0_0", "C0_1"}
    for row in rows:
        if row["font"] not in wanted:
            continue
        print("Page6GlyphOutlineGolden::{")
        print(f'  font_name: @objects.PdfName::new(b"{row["font"]}"),')
        print(f'  source_code: {row["code"]},')
        print(f'  expected_gid: {row["gid"]},')
        print(f'  expected_x: {float(row["x"]):.1f},')
        print(f'  expected_y: {float(row["y"]):.1f},')
        print("  require_non_identity: true,")
        print("},")


if __name__ == "__main__":
    main()
