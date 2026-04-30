///|
/// Mirrors ISO 32000-2 12.5.1 General annotation vocabulary: an annotation
/// associates an object such as a note, link, or rich media with a location
/// on a page; interactive PDF processors may navigate annotations by keyboard
/// tab order using Page Tabs names R row order, C column order, S structure
/// order, A annotation array order, and W widgets order. This reader exposes
/// the structural Tabs name and never computes focus traversal. Many standard
/// annotation types may be displayed in open or closed state as an icon, box,
/// or rubber stamp; activation may exhibit a popup window, sound, or movie,
/// but this reader only records the annotation handler vocabulary.
pub fn pdf_annotations_section_12_5_1_general_tabs_anchor() -> Int {
  5
}

///|
pub(all) struct PdfAnnotationsSection1251GeneralVocabulary {
  note_annotation : String
  link_annotation : String
  rich_media_annotation : String
  location_on_page : String
  mouse_keyboard_interaction : String
  tab_key_navigation : String
  row_order_r : String
  column_order_c : String
  structure_order_s : String
  annotation_array_order_a : String
  widgets_order_w : String
  annotation_handler_extensible_type : String
} derive(Eq, Debug)

///|
/// Mirrors ISO 32000-2 12.5.6.3 annotation state vocabulary from Table 174:
/// text annotation replies may use StateModel Marked or Review and State
/// values Marked, Unmarked, Accepted, Rejected, Cancelled, Completed, and
/// None. The parser stores these as structural names and state records only.
pub fn pdf_annotations_section_12_5_6_3_table_174_anchor() -> Int {
  174
}

///|
/// ISO 32000-2 12.5.6.3 Annotation vocabulary anchor for Table 174. Text
/// annotations that are replies to other annotations may carry State and
/// StateModel entries whose values are Marked, Unmarked, Accepted, Rejected,
/// Cancelled, Completed, None, or the state model names Marked and Review.
pub fn pdf_annotations_section_12_5_6_3_annotation_table_174_anchor() -> Int {
  174
}

///|
pub(all) struct PdfAnnotationsSection12563StateVocabulary {
  table_174 : Int
  state_model_marked : String
  state_model_review : String
  state_marked : String
  state_unmarked : String
  state_accepted : String
  state_rejected : String
  state_cancelled : String
  state_completed : String
  state_none : String
  text_annotation_reply : String
} derive(Eq, Debug)

///|
/// Mirrors ISO 32000-2 12.5.6.8 square and circle annotation vocabulary:
/// Square and Circle annotations use annotation-owned BS border style, IC
/// interior colour, BE border effect, and RD difference rectangle entries.
/// The reader parses the descriptor fields without painting shapes. Square
/// and circle annotations are markup annotations whose Contents entry may
/// provide popup text; their border is drawn as a square or ellipse adjusted
/// by RD, with interior color IC and cloudy border effect BE. They shall
/// display respectively a rectangle or an ellipse on the page; when opened,
/// they shall display a popup window containing the text of the associated
/// note. The rectangle or ellipse shall be inscribed within Rect. Table 180
/// entries include Subtype Square or Circle, BS dictionary, IC array with 0,
/// 1, 3, or 4 components, BE dictionary, and RD rectangle differences whose
/// sums are less than the width and height of Rect.
pub fn pdf_annotations_section_12_5_6_8_square_circle_anchor() -> Int {
  180
}

///|
pub(all) struct PdfAnnotationsSection12568SquareCircleVocabulary {
  square_annotation : String
  circle_annotation : String
  border_style_bs : String
  interior_colour_ic : String
  border_effect_be : String
  difference_rectangle_rd : String
  cloudy_effect : String
  no_shape_painting : String
} derive(Eq, Debug)

///|
/// Mirrors ISO 32000-2 12.5.6.11 caret annotation vocabulary: Caret
/// annotations carry an optional RD difference rectangle and Sy symbol such
/// as P or None. This reader records the structural caret descriptor without
/// editing text or creating user-interface insertion behavior. A caret
/// annotation indicates the presence of text edits and uses Table 183
/// Additional entries specific to a caret annotation, including RD and Sy.
pub fn pdf_annotations_section_12_5_6_11_caret_anchor() -> Int {
  183
}

///|
pub(all) struct PdfAnnotationsSection125611CaretVocabulary {
  caret_annotation : String
  difference_rectangle_rd : String
  symbol_sy : String
  paragraph_symbol_p : String
  none_symbol : String
  no_text_editing : String
} derive(Eq, Debug)

///|
/// Mirrors ISO 32000-2 12.5.6.12 rubber stamp annotation vocabulary: Stamp
/// annotations use Name icon names such as Approved, Draft, and custom names,
/// plus PDF 2.0 IT intents Stamp, StampImage, and StampSnapshot. The reader
/// validates the annotation-owned metadata without drawing stamp appearances.
/// A rubber stamp annotation displays text or graphics intended to look as if
/// stamped on the page; Table 184 defines Name and IT entries.
pub fn pdf_annotations_section_12_5_6_12_stamp_anchor() -> Int {
  184
}

///|
pub(all) struct PdfAnnotationsSection125612StampVocabulary {
  stamp_annotation : String
  rubber_stamp : String
  name_icon_approved : String
  name_icon_draft : String
  custom_name : String
  intent_stamp : String
  intent_stamp_image : String
  intent_stamp_snapshot : String
  no_stamp_appearance_drawing : String
} derive(Eq, Debug)

///|
/// Mirrors ISO 32000-2 12.5.6.14 popup annotation vocabulary: Popup
/// annotations preserve Parent references and Open state for a parent markup
/// annotation. This reader does not create popup windows, comments panes, or
/// any interactive user-interface behavior. A popup annotation displays text
/// in a pop-up window for editing or displaying the text associated with its
/// parent annotation and shall not appear by itself.
pub fn pdf_annotations_section_12_5_6_14_popup_anchor() -> Int {
  186
}

///|
pub(all) struct PdfAnnotationsSection125614PopupVocabulary {
  popup_annotation : String
  parent_markup_annotation : String
  parent_reference : String
  open_state : String
  popup_window : String
  comments_pane : String
  no_user_interface_behavior : String
} derive(Eq, Debug)

///|
/// Mirrors ISO 32000-2 12.5.6.15 file attachment annotation vocabulary:
/// FileAttachment annotations require FS file specification payloads and use
/// Name icon defaults such as PushPin. File specifications are preserved as
/// raw hand-off values; the reader never opens files. A file attachment
/// annotation contains a reference to a file, which typically shall be
/// embedded in the PDF file; Table 187 defines FS and Name entries.
pub fn pdf_annotations_section_12_5_6_15_file_attachment_anchor() -> Int {
  187
}

///|
pub(all) struct PdfAnnotationsSection125615FileAttachmentVocabulary {
  file_attachment_annotation : String
  fs_file_specification : String
  name_icon_push_pin : String
  raw_file_specification_payload : String
  no_open_files : String
} derive(Eq, Debug)

///|
/// Mirrors ISO 32000-2 12.5.6.16 sound annotation vocabulary: Sound
/// annotations preserve the deprecated Sound stream and Name icon defaults
/// such as Speaker. The reader parses annotation metadata but never plays
/// audio or interprets multimedia payloads. A sound annotation is analogous
/// to a text annotation except that instead of a text note it contains sound
/// recorded from the computer microphone or imported from a file.
pub fn pdf_annotations_section_12_5_6_16_sound_anchor() -> Int {
  188
}

///|
/// Symbol-name anchor for ISO 32000-2 12.5.6.16 Sound annotations Table 188.
pub fn pdf_1_2_deprecated_pdf_2_0_sound_annotation_table_188_subtype_sound_sound_stream_name_speaker_mic_anchor() -> Int {
  188
}

///|
pub(all) struct PdfAnnotationsSection125616SoundVocabulary {
  sound_annotation : String
  deprecated_sound_stream : String
  name_icon_speaker : String
  multimedia_payload : String
  no_audio_playback : String
} derive(Eq, Debug)

///|
/// Mirrors ISO 32000-2 12.5.6.17 movie annotation vocabulary: Movie
/// annotations preserve T title, Movie dictionary, and A activation data.
/// The reader keeps movie payloads structural and never plays media. A movie
/// annotation contains animated graphics and sound to be presented on the
/// computer screen and through the speakers; when the annotation is activated,
/// the movie shall be played by an interactive processor. Table 189 defines
/// Subtype Movie, T title, required Movie dictionary describing static
/// characteristics, and A boolean or movie activation dictionary with default
/// value true.
pub fn pdf_annotations_section_12_5_6_17_movie_anchor() -> Int {
  189
}

///|
/// ISO 32000-2 12.5.6.17 Movie annotations vocabulary anchor for Table 189.
/// Movie annotations include Subtype Movie, T title, Movie dictionary, and A
/// activation entry. The annotation describes animated graphics and sound
/// that an interactive processor may play when activated; this reader only
/// exposes those dictionary entries as structural annotation data.
pub fn pdf_annotations_section_12_5_6_17_movie_annotations_anchor() -> Int {
  189
}

///|
/// Symbol-name anchor for the status gate vocabulary in ISO 32000-2 12.5.6.17.
pub fn pdf_1_2_deprecated_pdf_2_0_movie_annotation_table_189_subtype_movie_t_title_movie_dictionary_a_activation_default_true_anchor() -> Int {
  189
}

///|
/// Literal anchor for the 13.4 Movies cross-reference in 12.5.6.17.
pub fn pdf_annotations_section_12_5_6_17_movie_annotations_13_4_movies_literal_anchor() -> Int {
  4
}

///|
/// Stable vocabulary anchor for ISO 32000-2 12.5.6.17 Movie annotations.
pub fn pdf_annotations_requirement_0_22_movie_annotations_vocabulary() -> String {
  "12.5.6.17 Movie annotations The features described in this subclause are deprecated in PDF 2.0 and superseded by the general multimedia framework described in 13.2 Multimedia. " +
  "A movie annotation PDF 1.2 contains animated graphics and sound to be presented on the computer screen and through the speakers. " +
  "When the annotation is activated, the movie shall be played. " +
  "Table 189 Additional entries specific to a movie annotation shows the annotation dictionary entries specific to this type of annotation. Movies are discussed in 13.4 Movies. " +
  "Subtype name required shall be Movie for a movie annotation. T text string optional title of the movie annotation. " +
  "Movie dictionary required shall describe the movie static characteristics. " +
  "A boolean or dictionary optional activation flag specifies whether and how to play the movie when activated. " +
  "A dictionary value shall be a movie activation dictionary, true uses default activation parameters, false means the movie shall not be played, default value true."
}

///|
pub(all) struct PdfAnnotationsSection125617MovieVocabulary {
  movie_annotation : String
  t_title : String
  movie_dictionary : String
  a_activation : String
  activation_dictionary : String
  no_movie_playback : String
} derive(Eq, Debug)

///|
/// Mirrors ISO 32000-2 12.5.6.18 screen annotation vocabulary: Screen
/// annotations preserve T title, A action, AA additional actions, MK
/// appearance characteristics, rendition action context, and page reference
/// requirements as structural data without executing actions or media. Screen
/// annotations specify a region of a page upon which media clips may be
/// played and also serve as an object from which actions can be triggered.
/// Table 190 entries include Subtype Screen, T title, MK appearance
/// characteristics dictionary, A action, and AA additional-actions dictionary.
/// The P entry shall be used for a screen annotation referenced by a rendition
/// action and AP normal appearance provides printing and default display.
pub fn pdf_annotations_section_12_5_6_18_screen_anchor() -> Int {
  190
}

///|
pub(all) struct PdfAnnotationsSection125618ScreenVocabulary {
  screen_annotation : String
  t_title : String
  a_action : String
  aa_additional_actions : String
  mk_appearance_characteristics : String
  rendition_action_context : String
  page_reference_requirement : String
  no_action_execution : String
  no_media_playback : String
} derive(Eq, Debug)

///|
/// Mirrors ISO 32000-2 12.5.6.19 widget annotation vocabulary: Widget
/// annotations carry H highlighting mode, MK appearance characteristics, A
/// action, AA additional actions, BS border style, and Parent field reference.
/// This reader keeps annotation-owned entries separate from AcroForm merging.
/// A widget annotation represents the appearance of form fields and manages
/// user interactions with fields, but this reader does not merge field
/// dictionaries or perform interactive form semantics. Table 191 entries
/// include Subtype Widget, H highlighting mode N I O P T, MK appearance
/// characteristics, A action, AA additional-actions, BS border style, and
/// Parent dictionary. Table 192 MK entries include R rotation, BC border
/// colour, BG background colour, CA normal caption, RC rollover caption,
/// AC alternate caption, I icon, RI rollover icon, IX alternate icon, IF icon
/// fit, and TP text position.
pub fn pdf_annotations_section_12_5_6_19_widget_anchor() -> Int {
  191
}

///|
pub(all) struct PdfAnnotationsSection125619WidgetVocabulary {
  widget_annotation : String
  h_highlighting_mode : String
  mk_appearance_characteristics : String
  a_action : String
  aa_additional_actions : String
  bs_border_style : String
  parent_field_reference : String
  acro_form_field_semantics : String
  no_field_dictionary_merging : String
} derive(Eq, Debug)

///|
/// Mirrors ISO 32000-2 12.5.6.20 printer mark annotation vocabulary:
/// PrinterMark annotations preserve production mark context such as PMD
/// without print production execution or renderer behavior. Printer's mark
/// annotations represent registration targets, colour bars, cut marks, and
/// other production marks added to a page.
pub fn pdf_annotations_section_12_5_6_20_printer_mark_anchor() -> Int {
  192
}

///|
pub(all) struct PdfAnnotationsSection125620PrinterMarkVocabulary {
  printer_mark_annotation : String
  printermark_subtype : String
  production_mark_context : String
  pmd_payload : String
  no_print_production_execution : String
  no_renderer_behavior : String
} derive(Eq, Debug)

///|
/// Mirrors ISO 32000-2 12.5.6.21 trap network annotation vocabulary:
/// TrapNet is deprecated in PDF 2.0; a page may contain no more than one trap
/// network annotation and it shall be the final page Annots array entry. The
/// reader preserves the raw trap network dictionary and performs no trapping.
pub fn pdf_annotations_section_12_5_6_21_trap_network_anchor() -> Int {
  193
}

///|
/// Mirrors ISO 32000-2 12.5.6.23 redaction annotation vocabulary: Redact
/// annotations use QuadPoints, IC interior colour, RO rollover appearance,
/// OverlayText, Repeat, DA default appearance string, and Q justification.
/// The reader parses non-destructive redaction intent and never applies
/// redactions or removes page content. Redaction annotations identify content
/// that is intended to be removed from the document; applying a redaction is
/// outside this structural reader boundary. Table 195 entries include Subtype
/// Redact, QuadPoints array of 8 x n numbers, IC DeviceRGB interior colour,
/// RO form XObject overlay appearance, OverlayText, Repeat, DA byte string
/// appearance string, and Q quadding values 0 left, 1 centred, 2 right.
pub fn pdf_annotations_section_12_5_6_23_redaction_anchor() -> Int {
  195
}

///|
pub(all) struct PdfAnnotationsSection125623RedactionVocabulary {
  redact_annotation : String
  quad_points : String
  interior_colour_ic : String
  rollover_appearance_ro : String
  overlay_text : String
  repeat_flag : String
  default_appearance_da : String
  justification_q : String
  non_destructive_redaction_intent : String
  no_redaction_application : String
  no_page_content_removal : String
} derive(Eq, Debug)
