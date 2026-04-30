///|
/// PDF graphics as introduced by ISO 32000-2 Section 8.1 General. PDF content
/// streams use graphics operators to describe the appearance of pages to be
/// reproduced on an output device for printer and display applications. A page
/// description is therefore an abstract, device-independent graphics program,
/// while rendering is the device-dependent part handled later.
///
/// The graphics operators are grouped as graphics state operators, path
/// construction operators, path-painting operators, other painting operators,
/// text operators, and marked-content operators. Graphics state operators
/// manipulate the graphics state, the global framework for the other graphics
/// operators. The graphics state includes the current transformation matrix
/// (CTM), which maps user space coordinates in a PDF content stream toward
/// device space, plus the current colour, current clipping path, and other
/// implicit operands of painting operators.
///
/// Path construction operators maintain the current point and build paths in
/// user space. Path-painting operators fill, stroke, or clip those paths. Other
/// painting operators cover sampled images, geometrically defined shadings, and
/// complete content streams. Text operators handle glyphs as graphical shapes,
/// and marked-content operators attach higher-level logical information. This
/// model also records the relationships among text space, image space, form
/// space, and pattern space before any device-dependent rendering.
///
/// For ISO 32000-2 Section 11.1 transparency, this package models the
/// document-facing vocabulary rather than choosing a device implementation:
/// transparent objects, opaque painting compatibility, blend/composite
/// semantics for overlapping objects, transparency groups, soft masks, PDF
/// transparency property dictionaries, and colour-space/rendering interactions
/// are preserved so processors can later produce equivalent transparency
/// results without requiring one exact implementation strategy.
pub(all) struct PdfGraphics {
  program : GraphicsProgram
} derive(Eq, Debug)

///|
/// Six main groups of PDF graphics operators per Section 8.1
/// General of ISO 32000-2 Graphics clause 8.
///
/// PDF content streams describe page appearance using graphics
/// operators that group into:
///
/// - GraphicsState: graphics state operators manipulate the
///   current transformation matrix CTM, current colour, current
///   clipping path, and other implicit operands.
/// - PathConstruction: path construction operators specify paths
///   that define shapes, line trajectories, and regions.
/// - PathPainting: path-painting operators fill, stroke, or use a
///   path as a clipping boundary.
/// - OtherPainting: paint sampled images, geometrically defined
///   shadings, and form XObjects containing other operators.
/// - Text: text operators select and show character glyphs from
///   fonts. See clause 9 Text for full font handling.
/// - MarkedContent: marked-content operators associate higher-
///   level logical information with content stream objects for
///   PDF document interchange.
///
/// See clause 11 for the transparent imaging model that consumes these
/// graphics objects after content stream interpretation.
pub(all) enum PdfGraphicsOperatorGroup {
  GraphicsState
  PathConstruction
  PathPainting
  OtherPainting
  Text
  MarkedContent
} derive(Eq, Debug)

///|
/// Reports whether the final graphics state carries document-level
/// transparency features from ISO 32000-2 Section 11.1. This is an abstract
/// graphics-side predicate: it observes blend/composite vocabulary, soft masks,
/// alpha constants, alpha-is-shape routing, and text knockout state without
/// selecting a renderer implementation strategy.
pub fn PdfGraphics::uses_transparency_features(self : PdfGraphics) -> Bool {
  let state = self.program.final_state
  if state.blend_mode != BlendMode::Normal {
    return true
  }
  if state.alpha_stroking < 1.0 || state.alpha_nonstroking < 1.0 {
    return true
  }
  if state.alpha_is_shape || !state.text_knockout {
    return true
  }
  match state.soft_mask.source {
    NoSoftMask => false
    _ => true
  }
}
