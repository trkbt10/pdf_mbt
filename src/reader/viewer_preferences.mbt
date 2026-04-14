///|
pub fn PdfDocument::viewer_preferences(
  self : PdfDocument,
) -> PdfViewerPreferences raise PdfDocumentError {
  let key = navigation_key(b"ViewerPreferences")
  match self.catalog.entry(key) {
    Some(value) => {
      let dict = require_navigation_dictionary(
        self.file,
        value,
        key,
        "ViewerPreferences",
      )
      parse_viewer_preferences_dictionary(dict)
    }
    None => default_viewer_preferences()
  }
}

///|
fn default_viewer_preferences() -> PdfViewerPreferences {
  let raw_dict : @objects.PdfDictionary = Map::new()
  PdfViewerPreferences::{
    hide_toolbar: false,
    hide_menubar: false,
    hide_window_ui: false,
    fit_window: false,
    center_window: false,
    display_doc_title: false,
    non_full_screen_page_mode: PdfPageMode::UseNone,
    direction: PdfReadingDirection::LeftToRight,
    view_area: PdfPageBoundary::CropBox,
    view_clip: PdfPageBoundary::CropBox,
    print_area: PdfPageBoundary::CropBox,
    print_clip: PdfPageBoundary::CropBox,
    print_scaling: PdfPrintScaling::AppDefault,
    duplex: None,
    pick_tray_by_pdf_size: false,
    print_page_ranges: [],
    num_copies: None,
    enforce: [],
    raw_dict,
  }
}

///|
fn parse_viewer_preferences_dictionary(
  dict : @objects.PdfDictionary,
) -> PdfViewerPreferences raise PdfDocumentError {
  let owner = navigation_key(b"ViewerPreferences")
  PdfViewerPreferences::{
    hide_toolbar: navigation_bool_or_default(
      dict,
      navigation_key(b"HideToolbar"),
      false,
      owner,
    ),
    hide_menubar: navigation_bool_or_default(
      dict,
      navigation_key(b"HideMenubar"),
      false,
      owner,
    ),
    hide_window_ui: navigation_bool_or_default(
      dict,
      navigation_key(b"HideWindowUI"),
      false,
      owner,
    ),
    fit_window: navigation_bool_or_default(
      dict,
      navigation_key(b"FitWindow"),
      false,
      owner,
    ),
    center_window: navigation_bool_or_default(
      dict,
      navigation_key(b"CenterWindow"),
      false,
      owner,
    ),
    display_doc_title: navigation_bool_or_default(
      dict,
      navigation_key(b"DisplayDocTitle"),
      false,
      owner,
    ),
    non_full_screen_page_mode: parse_page_mode(
      dict_get_or(
        dict,
        navigation_key(b"NonFullScreenPageMode"),
        @objects.PdfObject::Name(navigation_key(b"UseNone")),
      ),
      owner,
    ),
    direction: parse_reading_direction(
      dict_get_or(
        dict,
        navigation_key(b"Direction"),
        @objects.PdfObject::Name(navigation_key(b"L2R")),
      ),
      owner,
    ),
    view_area: parse_page_boundary(
      dict_get_or(
        dict,
        navigation_key(b"ViewArea"),
        @objects.PdfObject::Name(navigation_key(b"CropBox")),
      ),
      owner,
    ),
    view_clip: parse_page_boundary(
      dict_get_or(
        dict,
        navigation_key(b"ViewClip"),
        @objects.PdfObject::Name(navigation_key(b"CropBox")),
      ),
      owner,
    ),
    print_area: parse_page_boundary(
      dict_get_or(
        dict,
        navigation_key(b"PrintArea"),
        @objects.PdfObject::Name(navigation_key(b"CropBox")),
      ),
      owner,
    ),
    print_clip: parse_page_boundary(
      dict_get_or(
        dict,
        navigation_key(b"PrintClip"),
        @objects.PdfObject::Name(navigation_key(b"CropBox")),
      ),
      owner,
    ),
    print_scaling: parse_print_scaling(
      dict_get_or(
        dict,
        navigation_key(b"PrintScaling"),
        @objects.PdfObject::Name(navigation_key(b"AppDefault")),
      ),
      owner,
    ),
    duplex: parse_optional_duplex(dict.get(navigation_key(b"Duplex")), owner),
    pick_tray_by_pdf_size: navigation_bool_or_default(
      dict,
      navigation_key(b"PickTrayByPDFSize"),
      false,
      owner,
    ),
    print_page_ranges: parse_page_ranges(
      dict.get(navigation_key(b"PrintPageRange")),
      owner,
    ),
    num_copies: parse_optional_positive_int(
      dict.get(navigation_key(b"NumCopies")),
      owner,
      "NumCopies",
    ),
    enforce: parse_enforce_names(dict.get(navigation_key(b"Enforce")), owner),
    raw_dict: dict,
  }
}

///|
fn dict_get_or(
  dict : @objects.PdfDictionary,
  key : @objects.PdfName,
  default : @objects.PdfObject,
) -> @objects.PdfObject {
  match dict.get(key) {
    Some(value) => value
    None => default
  }
}

///|
fn parse_page_mode(
  value : @objects.PdfObject,
  owner : @objects.PdfName,
) -> PdfPageMode raise PdfDocumentError {
  let name = navigation_name(value, owner, "page mode")
  if name == navigation_key(b"UseNone") {
    PdfPageMode::UseNone
  } else if name == navigation_key(b"UseOutlines") {
    PdfPageMode::UseOutlines
  } else if name == navigation_key(b"UseThumbs") {
    PdfPageMode::UseThumbs
  } else if name == navigation_key(b"FullScreen") {
    PdfPageMode::FullScreen
  } else if name == navigation_key(b"UseOC") {
    PdfPageMode::UseOC
  } else if name == navigation_key(b"UseAttachments") {
    PdfPageMode::UseAttachments
  } else {
    PdfPageMode::Unknown(name)
  }
}

///|
fn parse_reading_direction(
  value : @objects.PdfObject,
  owner : @objects.PdfName,
) -> PdfReadingDirection raise PdfDocumentError {
  let name = navigation_name(value, owner, "Direction")
  if name == navigation_key(b"L2R") {
    PdfReadingDirection::LeftToRight
  } else if name == navigation_key(b"R2L") {
    PdfReadingDirection::RightToLeft
  } else {
    raise navigation_error(owner, "Direction must be /L2R or /R2L")
  }
}

///|
fn parse_page_boundary(
  value : @objects.PdfObject,
  owner : @objects.PdfName,
) -> PdfPageBoundary raise PdfDocumentError {
  let name = navigation_name(value, owner, "page boundary")
  if name == navigation_key(b"MediaBox") {
    PdfPageBoundary::MediaBox
  } else if name == navigation_key(b"CropBox") {
    PdfPageBoundary::CropBox
  } else if name == navigation_key(b"BleedBox") {
    PdfPageBoundary::BleedBox
  } else if name == navigation_key(b"TrimBox") {
    PdfPageBoundary::TrimBox
  } else if name == navigation_key(b"ArtBox") {
    PdfPageBoundary::ArtBox
  } else {
    PdfPageBoundary::Unknown(name)
  }
}

///|
fn parse_print_scaling(
  value : @objects.PdfObject,
  owner : @objects.PdfName,
) -> PdfPrintScaling raise PdfDocumentError {
  let name = navigation_name(value, owner, "PrintScaling")
  if name == navigation_key(b"None") {
    PdfPrintScaling::None
  } else {
    PdfPrintScaling::AppDefault
  }
}

///|
fn parse_optional_duplex(
  value : @objects.PdfObject?,
  owner : @objects.PdfName,
) -> PdfDuplex? raise PdfDocumentError {
  match value {
    Some(object) => {
      let name = navigation_name(object, owner, "Duplex")
      if name == navigation_key(b"Simplex") {
        Some(PdfDuplex::Simplex)
      } else if name == navigation_key(b"DuplexFlipShortEdge") {
        Some(PdfDuplex::DuplexFlipShortEdge)
      } else if name == navigation_key(b"DuplexFlipLongEdge") {
        Some(PdfDuplex::DuplexFlipLongEdge)
      } else {
        raise navigation_error(owner, "Duplex has an unsupported value")
      }
    }
    None => None
  }
}

///|
fn parse_page_ranges(
  value : @objects.PdfObject?,
  owner : @objects.PdfName,
) -> Array[PdfPageRange] raise PdfDocumentError {
  match value {
    Some(object) => {
      let values = navigation_array(object, owner, "PrintPageRange")
      if values.length() % 2 != 0 {
        raise navigation_error(owner, "PrintPageRange must contain pairs")
      }
      let ranges : Array[PdfPageRange] = []
      let mut index = 0
      while index < values.length() {
        let first = navigation_int(values[index], owner, "PrintPageRange first")
        let last = navigation_int(
          values[index + 1],
          owner,
          "PrintPageRange last",
        )
        if first < 0 || last < first {
          raise navigation_error(owner, "PrintPageRange values are invalid")
        }
        ranges.push(PdfPageRange::{ first, last })
        index += 2
      }
      ranges
    }
    None => []
  }
}

///|
fn parse_optional_positive_int(
  value : @objects.PdfObject?,
  owner : @objects.PdfName,
  label : String,
) -> Int? raise PdfDocumentError {
  match value {
    Some(object) => {
      let count = navigation_int(object, owner, label)
      if count <= 0 {
        raise navigation_error(owner, label + " must be positive")
      }
      Some(count)
    }
    None => None
  }
}

///|
fn parse_enforce_names(
  value : @objects.PdfObject?,
  owner : @objects.PdfName,
) -> Array[PdfViewerPreferenceEnforceName] raise PdfDocumentError {
  match value {
    Some(object) => {
      let values = navigation_array(object, owner, "Enforce")
      let out : Array[PdfViewerPreferenceEnforceName] = []
      for item in values {
        let name = navigation_name(item, owner, "Enforce entry")
        if name == navigation_key(b"PrintScaling") {
          out.push(PdfViewerPreferenceEnforceName::PrintScaling)
        } else if name == navigation_key(b"Duplex") {
          out.push(PdfViewerPreferenceEnforceName::Duplex)
        } else if name == navigation_key(b"PickTrayByPDFSize") {
          out.push(PdfViewerPreferenceEnforceName::PickTrayByPDFSize)
        } else if name == navigation_key(b"PrintPageRange") {
          out.push(PdfViewerPreferenceEnforceName::PrintPageRange)
        } else if name == navigation_key(b"NumCopies") {
          out.push(PdfViewerPreferenceEnforceName::NumCopies)
        } else {
          raise navigation_error(owner, "Enforce contains an unsupported name")
        }
      }
      out
    }
    None => []
  }
}
