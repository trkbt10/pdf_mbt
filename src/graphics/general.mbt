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
pub(all) struct PdfGraphics {
  program : GraphicsProgram
} derive(Eq, Debug)
