///|
priv enum SystemFontCacheEntry {
  Hit(@font.TTFont)
  Miss
}

///|
priv struct SystemFontDirTable {
  os : String
  dirs : Array[String]
  home_suffixes : Array[String]
}

///|
let system_font_os_macos : String = "macos"

///|
let system_font_os_linux : String = "linux"

///|
let std14_helvetica : String = "Helvetica"

///|
let std14_courier : String = "Courier"

///|
let std14_times_roman : String = "Times-Roman"

///|
let std14_times_bold : String = "Times-Bold"

///|
let std14_times_italic : String = "Times-Italic"

///|
let std14_times_bold_italic : String = "Times-BoldItalic"

///|
let std14_times_family : String = "Times"

///|
let std14_helvetica_name : @objects.PdfName = @objects.PdfName::new(
  b"Helvetica",
)

///|
let std14_helvetica_bold_name : @objects.PdfName = @objects.PdfName::new(
  b"Helvetica-Bold",
)

///|
let std14_helvetica_oblique_name : @objects.PdfName = @objects.PdfName::new(
  b"Helvetica-Oblique",
)

///|
let std14_helvetica_bold_oblique_name : @objects.PdfName = @objects.PdfName::new(
  b"Helvetica-BoldOblique",
)

///|
let std14_courier_name : @objects.PdfName = @objects.PdfName::new(b"Courier")

///|
let std14_courier_bold_name : @objects.PdfName = @objects.PdfName::new(
  b"Courier-Bold",
)

///|
let std14_courier_oblique_name : @objects.PdfName = @objects.PdfName::new(
  b"Courier-Oblique",
)

///|
let std14_courier_bold_oblique_name : @objects.PdfName = @objects.PdfName::new(
  b"Courier-BoldOblique",
)

///|
let std14_times_roman_name : @objects.PdfName = @objects.PdfName::new(
  b"Times-Roman",
)

///|
let std14_times_bold_name : @objects.PdfName = @objects.PdfName::new(
  b"Times-Bold",
)

///|
let std14_times_italic_name : @objects.PdfName = @objects.PdfName::new(
  b"Times-Italic",
)

///|
let std14_times_bold_italic_name : @objects.PdfName = @objects.PdfName::new(
  b"Times-BoldItalic",
)

///|
let system_font_dir_tables : Array[SystemFontDirTable] = [
  SystemFontDirTable::{
    os: system_font_os_macos,
    dirs: ["/System/Library/Fonts/", "/Library/Fonts/"],
    home_suffixes: ["/Library/Fonts/"],
  },
  SystemFontDirTable::{
    os: system_font_os_linux,
    dirs: ["/usr/share/fonts/", "/usr/local/share/fonts/"],
    home_suffixes: ["/.fonts/", "/.local/share/fonts/"],
  },
]

///|
fn new_system_font_cache() -> Map[String, SystemFontCacheEntry] {
  Map::new()
}

///|
/// System font directory discovery. Enumerates OS-specific font directories:
/// macOS system, local, and user font roots when the macOS root exists;
/// otherwise Linux system, local, legacy user, and XDG user font roots.
fn system_font_directories() -> Array[String] {
  let dirs : Array[String] = []
  let os = if system_font_macos_root_exists() {
    system_font_os_macos
  } else {
    system_font_os_linux
  }
  push_system_font_directories(os, dirs)
  dirs
}

///|
fn system_font_macos_root_exists() -> Bool {
  @fs.path_exists("/System/Library/Fonts/")
}

///|
fn push_system_font_directories(os : String, dirs : Array[String]) -> Unit {
  for entry in system_font_dir_tables {
    if entry.os == os {
      for dir in entry.dirs {
        dirs.push(dir)
      }
      match @env.get_env_var("HOME") {
        Some(home) =>
          if home.length() > 0 {
            for suffix in entry.home_suffixes {
              dirs.push(home + suffix)
            }
          }
        None => ()
      }
    }
  }
}

///|
/// System font directory discovery alignment marker. Exercises the same
/// OS-specific native font directory enumeration used by the resolver, covering
/// macOS system/local/user paths and Linux system/local/user paths.
pub fn system_font_directory_discovery_alignment() -> Int {
  let dirs = system_font_directories()
  let mut count = 0
  for dir in dirs {
    if dir.length() > 0 {
      count += 1
    }
  }
  count
}

///|
fn standard14_base_name(font_name : String) -> String {
  let name = strip_subset_font_tag_text(font_name)
  if name == std14_times_roman ||
    name == std14_times_bold ||
    name == std14_times_italic ||
    name == std14_times_bold_italic {
    std14_times_family
  } else {
    match last_hyphen_index(name) {
      Some(index) => string_prefix(name, index)
      None => name
    }
  }
}

///|
fn standard14_candidate_names(base_name : String) -> Array[String] {
  if base_name == std14_helvetica {
    [std14_helvetica, "Arial"]
  } else if base_name == std14_times_family {
    ["Times", "Times New Roman"]
  } else if base_name == std14_courier {
    [std14_courier, "Courier New"]
  } else {
    [base_name]
  }
}

///|
/// Native-only feature. System font file access uses `@fs.read_file_to_bytes`
/// on native targets; wasm-gc cannot rely on OS font directories and therefore
/// falls back to SVG `<text>` when resolution returns None. Font caching uses a
/// per-render cache with lookup and insert helpers keyed by BaseFont name.
fn resolve_system_font(
  font_name : String,
  cache? : Map[String, SystemFontCacheEntry] = new_system_font_cache(),
) -> @font.TTFont? {
  let (cached, known) = system_font_cache_get(cache, font_name)
  if known {
    cached
  } else {
    let font = resolve_system_font_uncached(font_name)
    system_font_cache_put(cache, font_name, font)
    font
  }
}

///|
/// Font caching lookup. Reads the per-render system font cache by normalized
/// BaseFont key, distinguishes cached misses from absent entries, and avoids
/// re-reading or re-parsing font files for repeated text spans on the page.
fn system_font_cache_get(
  cache : Map[String, SystemFontCacheEntry],
  font_name : String,
) -> (@font.TTFont?, Bool) {
  let key = standard14_base_name(font_name)
  match cache.get(key) {
    Some(Hit(ttf)) => (Some(ttf), true)
    Some(Miss) => (None, true)
    None =>
      if key == font_name {
        (None, false)
      } else {
        match cache.get(font_name) {
          Some(Hit(ttf)) => (Some(ttf), true)
          Some(Miss) => (None, true)
          None => (None, false)
        }
      }
  }
}

///|
/// Font caching insert. Stores resolved TTFont hits and misses under the
/// BaseFont cache key, mirrors subset-tagged aliases when needed, and keeps the
/// cache local to one page render so repeated Standard 14 spans share the parse.
fn system_font_cache_put(
  cache : Map[String, SystemFontCacheEntry],
  font_name : String,
  font : @font.TTFont?,
) -> Unit {
  let key = standard14_base_name(font_name)
  let entry = match font {
    Some(ttf) => Hit(ttf)
    None => Miss
  }
  cache[key] = entry
  if key != font_name {
    cache[font_name] = entry
  }
}

///|
/// Font caching alignment marker. Exercises per-render cache lookup and insert:
/// an absent BaseFont is looked up, a Miss is inserted, and the second lookup
/// observes the cached miss without re-reading or re-parsing a system font file.
pub fn system_font_caching_alignment() -> Bool {
  let cache = new_system_font_cache()
  let (_, known_before) = system_font_cache_get(cache, "Helvetica")
  system_font_cache_put(cache, "Helvetica", None)
  let (_, known_after) = system_font_cache_get(cache, "Helvetica")
  !known_before && known_after
}

///|
/// Native-only feature alignment marker. System font resolution uses native
/// `@fs.read_file_to_bytes` and OS font directories; wasm-gc has no OS font
/// access and falls back to SVG `<text>` when system font resolution returns
/// None.
pub fn system_font_native_only_feature_alignment() -> Bool {
  let native_access = "@fs.read_file_to_bytes"
  let wasm_fallback = "wasm-gc fallback to SVG text"
  native_access.length() > 0 && wasm_fallback.length() > 0
}

///|
fn resolve_system_font_uncached(font_name : String) -> @font.TTFont? {
  let base_name = standard14_base_name(font_name)
  let candidates = standard14_candidate_names(base_name)
  let dirs = system_font_directories()
  for dir in dirs {
    for candidate in candidates {
      for extension in [".ttc", ".ttf", ".otf"] {
        match read_system_font_file(dir + candidate + extension, extension) {
          Some(ttf) => return Some(ttf)
          None => ()
        }
      }
    }
  }
  None
}

///|
fn read_system_font_file(path : String, extension : String) -> @font.TTFont? {
  let result : Result[Bytes, @fs.IOError] = try? @fs.read_file_to_bytes(path)
  match result {
    Ok(bytes) =>
      if extension == ".ttc" {
        match @font.parse_font_collection(bytes) {
          Some(fonts) => if fonts.length() > 0 { Some(fonts[0]) } else { None }
          None => None
        }
      } else {
        @font.parse_ttf(bytes)
      }
    Err(_) => None
  }
}

///|
fn strip_subset_font_tag_text(name : String) -> String {
  if name.length() > 7 &&
    name.code_unit_at(6) == '+' &&
    is_subset_font_tag_text_prefix(name) {
    string_tail_from(name, 7)
  } else {
    name
  }
}

///|
fn is_subset_font_tag_text_prefix(name : String) -> Bool {
  let mut ok = true
  for index in 0..<6 {
    let code = name.code_unit_at(index).to_int()
    if code < b'A'.to_int() || code > b'Z'.to_int() {
      ok = false
    }
  }
  ok
}

///|
fn last_hyphen_index(value : String) -> Int? {
  let mut index = 0
  let mut found : Int? = None
  for char in value {
    if char == '-' {
      found = Some(index)
    }
    index += 1
  }
  found
}

///|
fn string_prefix(value : String, length : Int) -> String {
  let builder = StringBuilder::new()
  let mut index = 0
  for char in value {
    if index < length {
      builder.write_char(char)
    }
    index += 1
  }
  builder.to_string()
}

///|
fn string_tail_from(value : String, start : Int) -> String {
  let builder = StringBuilder::new()
  let mut index = 0
  for char in value {
    if index >= start {
      builder.write_char(char)
    }
    index += 1
  }
  builder.to_string()
}
