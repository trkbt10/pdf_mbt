///|
priv enum SystemFontCacheEntry {
  Hit(@font.TTFont)
  Miss
}

///|
fn new_system_font_cache() -> Map[String, SystemFontCacheEntry] {
  Map::new()
}

///|
fn system_font_directories() -> Array[String] {
  let dirs : Array[String] = []
  if @fs.path_exists("/System/Library/Fonts/") {
    dirs.push("/System/Library/Fonts/")
    dirs.push("/Library/Fonts/")
    match @env.get_env_var("HOME") {
      Some(home) => dirs.push(home + "/Library/Fonts/")
      None => ()
    }
  } else {
    dirs.push("/usr/share/fonts/")
    dirs.push("/usr/local/share/fonts/")
    match @env.get_env_var("HOME") {
      Some(home) => {
        dirs.push(home + "/.fonts/")
        dirs.push(home + "/.local/share/fonts/")
      }
      None => ()
    }
  }
  dirs
}

///|
fn standard14_base_name(font_name : String) -> String {
  let name = strip_subset_font_tag_text(font_name)
  if name == "Times-Roman" ||
    name == "Times-Bold" ||
    name == "Times-Italic" ||
    name == "Times-BoldItalic" {
    "Times"
  } else {
    match last_hyphen_index(name) {
      Some(index) => string_prefix(name, index)
      None => name
    }
  }
}

///|
fn standard14_candidate_names(base_name : String) -> Array[String] {
  if base_name == "Helvetica" {
    ["Helvetica", "Arial"]
  } else if base_name == "Times" {
    ["Times", "Times New Roman"]
  } else if base_name == "Courier" {
    ["Courier", "Courier New"]
  } else {
    [base_name]
  }
}

///|
fn resolve_system_font(
  font_name : String,
  cache? : Map[String, SystemFontCacheEntry] = new_system_font_cache(),
) -> @font.TTFont? {
  match cache.get(font_name) {
    Some(Hit(ttf)) => Some(ttf)
    Some(Miss) => None
    None => {
      let font = resolve_system_font_uncached(font_name)
      match font {
        Some(ttf) => cache[font_name] = Hit(ttf)
        None => cache[font_name] = Miss
      }
      font
    }
  }
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
