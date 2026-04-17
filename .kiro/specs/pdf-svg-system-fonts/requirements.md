# SDD Draft: System Font Resolution for SVG Glyph Path Rendering

## Problem

Standard 14 PDF fonts (Helvetica, Times-Roman, Courier, etc.) have no
embedded font program. The current SVG renderer falls back to `<text>`
elements with CSS font-family, producing visual differences because
the SVG viewer's font glyphs differ from what pdftoppm renders.

The OS has the actual font files (e.g., `/System/Library/Fonts/Helvetica.ttc`
on macOS). These should be loaded and used to render glyphs as SVG `<path>`
elements, identical to the embedded font path.

## Requirements

### Requirement 1: System font directory discovery

#### 1.1: OS-specific font directories
The font resolver SHALL search the following directories for font files:
- macOS: `/System/Library/Fonts/`, `/Library/Fonts/`, `~/Library/Fonts/`
- Linux: `/usr/share/fonts/`, `/usr/local/share/fonts/`, `~/.fonts/`,
  `~/.local/share/fonts/`

The directory list SHALL use `@config.resolve_os_dir` or similar
OS-detection logic (SoT for OS-specific paths).

#### 1.2: Font file formats
The resolver SHALL support `.ttf` (TrueType), `.ttc` (TrueType Collection),
and `.otf` (OpenType with TrueType outlines) files.

### Requirement 2: Standard 14 font name resolution

#### 2.1: BaseFont to file name mapping
The resolver SHALL map PDF Standard 14 BaseFont names to candidate
file names for lookup:

| BaseFont | Candidate file names |
|----------|---------------------|
| Helvetica | Helvetica, Arial |
| Helvetica-Bold | Helvetica, Arial |
| Helvetica-Oblique | Helvetica, Arial |
| Helvetica-BoldOblique | Helvetica, Arial |
| Times-Roman | Times, Times New Roman |
| Times-Bold | Times, Times New Roman |
| Times-Italic | Times, Times New Roman |
| Times-BoldItalic | Times, Times New Roman |
| Courier | Courier, Courier New |
| Courier-Bold | Courier, Courier New |
| Courier-Oblique | Courier, Courier New |
| Courier-BoldOblique | Courier, Courier New |
| Symbol | Symbol |
| ZapfDingbats | ZapfDingbats |

#### 2.2: File search strategy
For each candidate name, try extensions in order: `.ttc`, `.ttf`, `.otf`.
Search each font directory. Return the first match found.

#### 2.3: TTC font index selection
When loading a `.ttc` file via `@font.parse_font_collection()`, select
the font whose name table best matches the requested BaseFont. For
simple cases (Helvetica Regular), the first font in the collection
is typically correct.

### Requirement 3: Font caching

#### 3.1: Per-render font cache
System fonts SHALL be cached for the duration of a page render to
avoid re-reading and re-parsing the same font file for every text span.

#### 3.2: Cache key
The cache key SHALL be the BaseFont name (PdfName).

### Requirement 4: Integration with glyph path rendering

#### 4.1: System font as TTFont
When a system font is resolved, it SHALL be used as a TTFont in the
same glyph path rendering pipeline as embedded fonts (from the
pdf-svg-glyph-paths spec).

#### 4.2: Fallback chain
Font resolution priority:
1. Embedded font (FontFile2/FontFile3 in FontDescriptor)
2. System font (resolved from BaseFont name)
3. `<text>` element with CSS font-family (last resort)

### Requirement 5: Native-only feature

#### 5.1: Target-conditional compilation
System font file access uses `@fs.read_file_to_bytes` which is only
available on the native target. The wasm-gc target SHALL skip system
font resolution and fall back to `<text>` elements.

This can be achieved via conditional compilation or by catching the
file I/O error gracefully.
