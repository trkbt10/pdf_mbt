///|
/// Page graphics interpretation options. The caller may supply the initial
/// CTM; otherwise identity is used as the device-independent modeling
/// baseline. UserUnit, Rotate, and the initial clipping path are derived from
/// page metadata.
pub(all) struct GraphicsPageOptions {
  initial_ctm : @graphics.GraphicsMatrix?
  materialize_xobjects : Bool
  evaluate_optional_content : Bool
} derive(Eq, Debug)

///|
pub fn GraphicsPageOptions::default() -> GraphicsPageOptions {
  GraphicsPageOptions::{
    initial_ctm: None,
    materialize_xobjects: false,
    evaluate_optional_content: false,
  }
}

///|
pub fn GraphicsPageOptions::with_materialized_xobjects(
  initial_ctm : @graphics.GraphicsMatrix?,
) -> GraphicsPageOptions {
  GraphicsPageOptions::{
    initial_ctm,
    materialize_xobjects: true,
    evaluate_optional_content: true,
  }
}

///|
/// Builds the initial graphics state inputs for a page. CropBox seeds the
/// initial clipping path when present; MediaBox is used otherwise. UserUnit
/// defaults to 1.0 and Rotate defaults to 0, while device CTM construction is
/// caller supplied.
pub fn PdfPage::graphics_initial_state(
  self : PdfPage,
  options : GraphicsPageOptions,
) -> @graphics.GraphicsInitialState raise PdfDocumentError {
  let box = match self.crop_box() {
    Some(crop_box) => crop_box
    None =>
      match self.media_box() {
        Some(media_box) => media_box
        None =>
          raise PdfDocumentError::InvalidPage(
            self.object_id(),
            "page graphics interpretation requires CropBox or MediaBox",
          )
      }
  }
  let clip = @graphics.GraphicsPath::from_rect(
    @graphics.GraphicsRect::new(box.left, box.bottom, box.right, box.top),
  )
  @graphics.GraphicsInitialState::{
    ctm: match options.initial_ctm {
      Some(value) => value
      None => @graphics.GraphicsMatrix::identity()
    },
    initial_clip: Some(clip),
    user_unit: match self.user_unit() {
      Some(value) => value
      None => 1.0
    },
    page_rotate: match self.rotate() {
      Some(value) => value
      None => 0
    },
    colour_restriction: @graphics.ColourRestriction::Normal,
  }
}

///|
/// Parses this page's content stream and interprets graphics operators into a
/// graphics program while preserving content errors and wrapping graphics
/// failures at the document boundary.
pub fn PdfPage::graphics_program(
  self : PdfPage,
  options : GraphicsPageOptions,
) -> @graphics.GraphicsProgram raise PdfDocumentError {
  let initial = self.graphics_initial_state(options)
  let content = if options.materialize_xobjects ||
    options.evaluate_optional_content {
    self.materialized_content_stream()
  } else {
    self.content_stream()
  }
  let interpret_options = if options.evaluate_optional_content {
    @graphics.GraphicsInterpretOptions::{
      optional_content_state: self.optional_content_state(),
    }
  } else {
    @graphics.GraphicsInterpretOptions::default()
  }
  try
    @graphics.interpret_content_with_options(
      content, initial, interpret_options,
    )
  catch {
    error => raise PdfDocumentError::GraphicsError(error)
  } noraise {
    program => program
  }
}

///|
/// Convenience accessor returning only ordered page graphics events.
pub fn PdfPage::graphics_events(
  self : PdfPage,
  options : GraphicsPageOptions,
) -> Array[@graphics.GraphicsEvent] raise PdfDocumentError {
  self.graphics_program(options).events
}
