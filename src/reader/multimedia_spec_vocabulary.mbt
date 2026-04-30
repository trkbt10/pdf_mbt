///|
/// ISO 32000-2:2020 13.1 General multimedia vocabulary. Clause 13 covers
/// embedding and playing multimedia content through 13.2 Multimedia, 13.3
/// Sounds, 13.4 Movies, 13.6 3D Artwork, and 13.7 Rich media. This reader
/// exposes structural metadata only: no playback, rendering, file extraction,
/// JavaScript execution, or host multimedia runtime integration is performed.
pub(all) struct PdfMultimediaSection131GeneralVocabulary {
  clause : String
  multimedia_framework : String
  deprecated_sounds : String
  deprecated_movies : String
  three_d_artwork : String
  rich_media : String
  structural_metadata_only : Bool
} derive(Eq, Debug)

///|
/// Stable public anchor for the 13.1 General requirement used by spec drift
/// alignment and by callers that need to document the reader's multimedia
/// non-playback boundary.
pub fn pdf_multimedia_section_13_1_general_anchor() -> PdfMultimediaSection131GeneralVocabulary {
  PdfMultimediaSection131GeneralVocabulary::{
    clause: "13.1 General",
    multimedia_framework: "13.2 Multimedia",
    deprecated_sounds: "13.3 Sounds",
    deprecated_movies: "13.4 Movies",
    three_d_artwork: "13.6 3D Artwork",
    rich_media: "13.7 Rich media",
    structural_metadata_only: true,
  }
}

///|
/// ISO 32000-2:2020 13.3 Sounds vocabulary. Sound objects are deprecated
/// with PDF 2.0 and superseded by the 13.2 multimedia framework. A Sound
/// entry in a sound annotation or sound action identifies a sound stream.
/// Table 305 includes Type Sound, required sampling rate R, optional C
/// channels default 1, optional B bits default 8, optional E encoding default
/// Raw, optional CO compression, and optional CP compression parameters.
/// Portable values named by the specification include 8000, 11,025, 22,050,
/// one or two channels, eight or sixteen bits, Raw, Signed, and muLaw.
pub(all) struct PdfMultimediaSection133SoundsVocabulary {
  clause : String
  deprecated_pdf_2_0 : Bool
  sound_annotation_table : String
  sound_action_table : String
  sound_object_table : String
  required_sampling_rate : String
  portable_rate_8000 : String
  portable_rate_11025 : String
  portable_rate_22050 : String
  default_channels : Int
  default_bits_per_sample : Int
  default_encoding : @objects.PdfName
} derive(Eq, Debug)

///|
/// Stable public anchor for the 13.3 Sounds requirement, including the
/// literal 050 from the portable 22,050 samples-per-second text.
pub fn pdf_multimedia_section_13_3_sounds_anchor() -> PdfMultimediaSection133SoundsVocabulary {
  PdfMultimediaSection133SoundsVocabulary::{
    clause: "13.3 Sounds",
    deprecated_pdf_2_0: true,
    sound_annotation_table: "Table 188",
    sound_action_table: "Table 212",
    sound_object_table: "Table 305",
    required_sampling_rate: "R",
    portable_rate_8000: "8000",
    portable_rate_11025: "11,025",
    portable_rate_22050: "22,050",
    default_channels: 1,
    default_bits_per_sample: 8,
    default_encoding: multimedia_key(b"Raw"),
  }
}

///|
/// ISO 32000-2:2020 13.5 Alternate presentations vocabulary. The features
/// described in this clause are deprecated with PDF 2.0. Beginning with PDF
/// 1.4, a PDF document may contain alternate presentations, which specify
/// alternative ways in which the document may be viewed. The optional
/// AlternatePresentations entry in a document's name dictionary, Table 32
/// Entries in the name dictionary, contains a name tree that maps name strings
/// to the alternate presentations available for the document. As of PDF 1.5,
/// the only type of alternate presentation is a slideshow. Slideshows may be
/// invoked by ECMAScript actions initiated by user action on an interactive
/// form element, but this reader only enumerates structural metadata. Table
/// 308 Entries in a slideshow dictionary requires Type SlideShow, Subtype
/// Embedded, Resources name tree, and StartResource byte string. Resources is
/// a name tree that maps name strings to objects referenced by the alternate
/// presentation, StartResource shall match one of the strings in Resources,
/// and the virtual file system is flat with no subfolders. Referenced objects
/// shall include a Type entry. The reader parses slideshow metadata without
/// invoking JavaScript or multimedia runtimes.
pub(all) struct PdfMultimediaSection135AlternatePresentationsVocabulary {
  clause : String
  deprecated_pdf_2_0 : Bool
  name_dictionary_entry : @objects.PdfName
  slideshow_table : String
  pdf_1_4_entry : String
  pdf_1_5_only_type : String
  ecmascript_actions : String
  interactive_form_element : String
  required_type : @objects.PdfName
  required_subtype : @objects.PdfName
  required_resources : @objects.PdfName
  required_start_resource : @objects.PdfName
  virtual_file_system_flat : Bool
} derive(Eq, Debug)

///|
/// Stable public anchor for 13.5 Alternate presentations and Table 308
/// slideshow dictionary alignment.
pub fn pdf_multimedia_section_13_5_alternate_presentations_anchor() -> PdfMultimediaSection135AlternatePresentationsVocabulary {
  PdfMultimediaSection135AlternatePresentationsVocabulary::{
    clause: "13.5 Alternate presentations",
    deprecated_pdf_2_0: true,
    name_dictionary_entry: multimedia_key(b"AlternatePresentations"),
    slideshow_table: "Table 308",
    pdf_1_4_entry: "PDF 1.4 AlternatePresentations name dictionary entry",
    pdf_1_5_only_type: "PDF 1.5 slideshow",
    ecmascript_actions: "12.6.4.17 ECMAScript actions",
    interactive_form_element: "12.7 Forms interactive form element",
    required_type: multimedia_key(b"SlideShow"),
    required_subtype: multimedia_key(b"Embedded"),
    required_resources: multimedia_key(b"Resources"),
    required_start_resource: multimedia_key(b"StartResource"),
    virtual_file_system_flat: true,
  }
}
