///|
/// Traceability vocabulary for ISO 32000-2 8.10.3 group XObjects and Table 94
/// group attributes dictionaries. A group XObject is a form XObject with a
/// Group entry whose Type is Group and whose S subtype defines Transparency
/// group semantics for the transparent imaging model.
///
/// Reference XObject vocabulary in this file also covers the 8.10.4 text where
/// the reference occurs in the containing document, imported content comes from
/// the target document, the target document may be an external file or embedded
/// file stream, the containing document form XObject has a Ref entry, and the
/// proxy may be a low-resolution image, descriptive text, or gray box when the
/// referenced content is unavailable.
///
/// Usage dictionary vocabulary in this file also covers 8.11.4.4: optional
/// content groups control visibility of related graphics objects such as
/// content in a particular language or content suitable for a particular
/// magnification; the Usage entry contains Table 100 information including
/// CreatorInfo, Creator, Subtype, Artwork, Technical, Language, Lang, View,
/// Print, Export, Zoom, User, PageElement, and usage application dictionaries.
pub(all) struct GroupXObjectTable94Vocabulary {
  table_94 : Int
  group_entry : String
  subtype_s : String
  transparency_group : String
} derive(Eq, Debug)

///|
/// Traceability vocabulary for ISO 32000-2 8.10.4.1 reference XObject general
/// semantics. The containing document holds a form XObject with a Ref entry,
/// while the target document may be external or embedded. The proxy form is
/// processed as an ordinary form XObject when imported target content is not
/// available.
pub(all) struct ReferenceXObjectGeneralVocabulary {
  containing_document : String
  target_document : String
  ref_entry : String
  proxy_form : String
} derive(Eq, Debug)

///|
/// Traceability vocabulary for ISO 32000-2 8.11.2 optional content groups.
/// Optional content groups are graphic layers that may be visible or invisible
/// dynamically. Table 96 defines OCG dictionaries with Type OCG, Name, Intent,
/// and Usage entries for View, Design, and second-class intents.
pub(all) struct OptionalContentGroupTable96Vocabulary {
  table_96 : Int
  type_ocg : String
  name : String
  intent : String
  usage : String
} derive(Eq, Debug)

///|
/// Traceability vocabulary for ISO 32000-2 8.11.3 making graphical content
/// optional. Content stream sections delimited by marked-content operators,
/// form XObjects, image XObjects, and annotations may declare membership in an
/// OCG or OCMD. Hidden optional content is not drawn, but graphics state side
/// effects such as colour, CTM, clipping, and text position still apply.
pub(all) struct OptionalContentGraphicalVocabulary {
  marked_content : String
  form_xobject_oc : String
  image_xobject_oc : String
  graphics_state_side_effects : String
} derive(Eq, Debug)

///|
/// Traceability vocabulary for ISO 32000-2 8.11.4 configuring optional
/// content. OCProperties contains the OCGs array, default configuration D,
/// alternate Configs, BaseState, ON, OFF, Intent, Order, ListMode, RBGroups,
/// and Locked entries that determine initial group state.
pub(all) struct OptionalContentConfigurationVocabulary {
  ocproperties : String
  base_state : String
  on_array : String
  off_array : String
  usage_application : String
} derive(Eq, Debug)

///|
/// Traceability vocabulary for ISO 32000-2 8.11.4.4 usage and usage
/// application dictionaries. Optional content groups can describe language,
/// view, print, export, zoom, user, creator information, subtype, and
/// magnification recommendations in Table 100 usage entries.
pub(all) struct OptionalContentUsageTable100Vocabulary {
  table_100 : Int
  view : String
  print : String
  export : String
  zoom : String
  language : String
} derive(Eq, Debug)

///|
/// Returns the Table 94 group XObject vocabulary used by form XObject
/// validation and transparency group preservation.
pub fn group_xobject_table_94_vocabulary() -> GroupXObjectTable94Vocabulary {
  GroupXObjectTable94Vocabulary::{
    table_94: 94,
    group_entry: "Group",
    subtype_s: "S",
    transparency_group: "Transparency",
  }
}

///|
/// Returns the 8.10.4.1 reference XObject general vocabulary for containing
/// documents, target documents, Ref entries, and proxy forms.
pub fn reference_xobject_general_vocabulary() -> ReferenceXObjectGeneralVocabulary {
  ReferenceXObjectGeneralVocabulary::{
    containing_document: "containing document",
    target_document: "target document external file embedded file stream",
    ref_entry: "Ref F Page ID",
    proxy_form: "proxy ordinary form XObject unavailable imported content",
  }
}

///|
/// Returns the Table 96 optional content group dictionary vocabulary.
pub fn optional_content_group_table_96_vocabulary() -> OptionalContentGroupTable96Vocabulary {
  OptionalContentGroupTable96Vocabulary::{
    table_96: 96,
    type_ocg: "Type OCG",
    name: "Name text string user interface",
    intent: "Intent View Design",
    usage: "Usage dictionary",
  }
}

///|
/// Returns the 8.11.3 graphical optional content vocabulary.
pub fn optional_content_graphical_vocabulary() -> OptionalContentGraphicalVocabulary {
  OptionalContentGraphicalVocabulary::{
    marked_content: "BDC DP EMC marked-content operators",
    form_xobject_oc: "Form XObject OC entry",
    image_xobject_oc: "Image XObject OC entry",
    graphics_state_side_effects: "colour CTM clipping text position",
  }
}

///|
/// Returns the 8.11.4 optional content configuration vocabulary.
pub fn optional_content_configuration_vocabulary() -> OptionalContentConfigurationVocabulary {
  OptionalContentConfigurationVocabulary::{
    ocproperties: "OCProperties OCGs D Configs",
    base_state: "BaseState ON OFF",
    on_array: "ON array",
    off_array: "OFF array",
    usage_application: "usage application dictionary View Print Export",
  }
}

///|
/// Returns the Table 100 optional content usage dictionary vocabulary.
pub fn optional_content_usage_table_100_vocabulary() -> OptionalContentUsageTable100Vocabulary {
  OptionalContentUsageTable100Vocabulary::{
    table_100: 100,
    view: "View",
    print: "Print",
    export: "Export",
    zoom: "Zoom User",
    language: "Language",
  }
}

///|
/// Requirement 0.9 / 8.9.5.4 alternate images vocabulary, including Table 89.
/// Alternate images in PDF 1.3 provide a backward-compatible way to include
/// multiple versions of an image in a PDF file for different purposes. Variant
/// representations may differ in resolution or colour space. A base image
/// XObject in a resource dictionary may contain an Alternates array of
/// alternate image dictionaries. Each alternate image dictionary contains an
/// Image stream for one variant, DefaultForPrinting, and optional OC selection
/// through an optional content group or membership dictionary.
pub fn pdf_xobjects_images_requirement_0_9_alternate_images_vocabulary() -> String {
  "8.9.5.4 alternate images Table 89 Alternates array alternate image dictionary Image stream DefaultForPrinting OC optional content group optional content membership dictionary base image visible printing selected alternate"
}

///|
/// Requirement 0.17 / 8.10.3 group XObject vocabulary, including Table 94.
/// A group XObject is a special type of form XObject that groups graphical
/// elements together as a unit. It is distinguished by the optional Group entry
/// in the form dictionary. The Group entry is a subsidiary group attributes
/// dictionary; every group XObject has a group subtype specified by the S
/// entry, and Transparency is the defined subtype for transparency groups.
pub fn pdf_xobjects_images_requirement_0_17_group_xobject_vocabulary() -> String {
  "8.10.3 group XObject Table 94 Group entry group attributes dictionary Type Group S subtype Transparency transparency group XObject transparent imaging model"
}

///|
/// Requirement 0.18 and 0.19 / 8.10.4.1 reference XObject general vocabulary.
/// The document in which the reference occurs is the containing document; the
/// one whose content is imported is the target document. The target document
/// may reside in an external file or embedded file stream. The reference
/// XObject in the containing document is a form XObject containing a Ref entry
/// and serves as a proxy when referenced content is unavailable. Table 95
/// defines the reference dictionary with F, Page, and ID entries.
pub fn pdf_xobjects_images_requirement_0_18_reference_xobject_vocabulary() -> String {
  "8.10.4 8.10.4.1 General reference XObject containing document target document imported content external file embedded file stream form XObject Ref entry proxy ordinary form XObject unavailable target"
}

///|
/// Requirement 0.23 and 0.24 / 8.11.2 and 8.11.2.1 General optional content
/// group vocabulary. Optional content groups are graphics that may be visible
/// or invisible dynamically by PDF processors. The graphics belonging to a
/// group may reside anywhere in the document and need not be consecutive in
/// drawing order or in the same content stream. Table 96 entries in an
/// optional content group dictionary include Type OCG, Name, Intent, and Usage.
pub fn pdf_xobjects_images_requirement_0_23_optional_content_group_vocabulary() -> String {
  "8.11.2 8.11.2.1 General optional content groups visible invisible dynamically PDF processors Table 96 Type OCG Name text string Intent View Design Usage dictionary user interface"
}

///|
/// Requirement 0.27 and 0.28 / 8.11.3 and 8.11.3.1 making graphical content
/// optional. Membership can be defined by sections of content streams
/// delimited by marked-content operators, or by Form and image XObjects and
/// annotations made optional in their entirety with a dictionary entry. Hidden
/// content is not drawn, but graphics state operations such as colour,
/// transformation matrix, clipping, and text position still apply.
pub fn pdf_xobjects_images_requirement_0_27_making_graphical_optional_vocabulary() -> String {
  "8.11.3 8.11.3.1 General making graphical content optional marked-content operators BDC DP EMC content stream sections Form XObjects image XObjects annotations OC entry OCG OCMD hidden content not drawn graphics state side effects colour transformation matrix clipping text position"
}

///|
/// Requirement 0.31 and 0.32 / 8.11.4, 8.11.4.1, and 8.11.4.2 configuring
/// optional content vocabulary. Optional content properties list all optional
/// content groups in the document and possible configurations. Optional
/// content configuration dictionaries specify initial state settings and other
/// information about groups; usage and usage application dictionaries describe
/// how states are affected by external factors.
pub fn pdf_xobjects_images_requirement_0_31_configuring_optional_content_vocabulary() -> String {
  "8.11.4 8.11.4.1 General configuring optional content OCProperties OCGs D default configuration Configs alternate configurations BaseState ON OFF Intent Order ListMode RBGroups Locked initial state"
}

///|
/// Requirement 0.35 / 8.11.4.4 usage and usage application dictionaries.
/// Optional content groups control visibility of related graphics objects,
/// such as content in a particular language or content suitable for a
/// particular magnification. The Usage entry in an optional content group
/// dictionary contains a usage dictionary with Table 100 entries such as
/// CreatorInfo, Language, View, Print, Export, Zoom, User, and page element
/// subtype information.
pub fn pdf_xobjects_images_requirement_0_35_usage_application_vocabulary() -> String {
  "8.11.4.4 Usage usage application dictionaries optional content group Usage dictionary Table 100 CreatorInfo Subtype language magnification View Print Export Zoom User Language automatic state recommendations"
}

///|
/// 0.18: 8.10.4 reference XObjects.
pub fn pdf_xobjects_images_requirement_0_18_8_10_4() -> String {
  "0.18: 8.10.4 Reference XObjects"
}

///|
/// 0.23: 8.11.2 optional content groups.
pub fn pdf_xobjects_images_requirement_0_23_8_11_2() -> String {
  "0.23: 8.11.2 Optional content groups 8.11.2.1 General"
}

///|
/// Requirement 0.19 reference dictionary Table 95 vocabulary.
/// Section 8.10.4.1 General says the document in which the reference occurs
/// is called the containing document and the one whose content is being
/// imported is the target document. The target document may reside in a file
/// external to the containing document or may be included within it as an
/// embedded file stream. The reference XObject in the containing document
/// shall be a form XObject containing the Ref entry in its form dictionary.
/// This form XObject shall serve as a proxy that should be processed by a PDF
/// processor when the referenced content is not available. The proxy can be a
/// low-resolution image of the imported content, descriptive text, a gray box,
/// or another placeholder. The imported content shall consist of a single,
/// complete PDF page in the target document and shall be designated by a
/// reference dictionary, the value of the Ref entry. The presence of the Ref
/// entry shall distinguish reference XObjects from other types of form
/// XObjects. Table 95 — Entries in a reference dictionary includes F, Page,
/// and ID.
pub fn pdf_xobjects_images_requirement_0_19_reference_dictionary_vocabulary() -> String {
  "0.19 8.10.4.1 General reference XObject containing document target document imported content external file embedded file stream form XObject containing the Ref entry form dictionary proxy processed when referenced content is not available low-resolution image descriptive text gray box ordinary form XObject imported content single complete PDF page reference dictionary value of Ref entry Table 95 Entries in a reference dictionary F file specification Page integer text string page index page label ID array byte strings target document Matrix BBox Group entry"
}

///|
/// Requirement 0.35 optional content usage Table 100 detailed vocabulary.
pub fn pdf_xobjects_images_requirement_0_35_usage_table_100_detailed_vocabulary() -> String {
  "Table 100 entries in an optional content usage dictionary CreatorInfo Creator Subtype Artwork Technical Language Lang View Print Export Zoom User PageElement automatic state usage application dictionaries"
}
