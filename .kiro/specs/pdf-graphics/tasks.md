# Implementation Plan

- [ ] 1. Establish the graphics interpretation foundation
- [ ] 1.1 Create the graphics package boundary and failure model
  - Add the package entry point for graphics interpretation with allowed imports only from the object and content layers.
  - Define typed graphics failures for bad operands, invalid state, stack underflow, invalid path state, invalid object context, resource failures, and content failures.
  - The package can be checked by the MoonBit toolchain before any reader integration exists.
  - _Requirements: 1, 2, 3_
  - _Boundary: GraphicsInterpreter_

- [ ] 1.2 Implement affine geometry and coordinate-space values
  - Represent points, rectangles, and six-number affine matrices using double-precision values.
  - Support identity, translation, scale, rotation, skew, point transformation, determinant, optional inverse, and PDF matrix premultiplication order.
  - Matrix tests demonstrate that transformed coordinates and CTM concatenation follow the ISO equations.
  - _Requirements: 2.1, 2.2, 2.6, 2.7, 2.8_
  - _Boundary: GraphicsGeometry_

- [ ] 1.3 Model initial page graphics state inputs and clipping baseline
  - Represent initial CTM, initial clip, UserUnit, and page rotation as caller-supplied interpretation inputs.
  - Represent page boxes as graphics rectangles that can seed the initial clipping path without device-specific CTM construction.
  - A standalone initial-state test can construct a page-sized clip and preserve UserUnit and Rotate values.
  - _Requirements: 2.3, 2.4, 3.1, 3.11_
  - _Boundary: GraphicsGeometry, GraphicsState_

- [ ] 2. Implement graphics state semantics
- [ ] 2.1 Store graphics state defaults and validated stroke parameters
  - Initialize CTM, clipping state, raw color slots, line width, cap, join, miter limit, dash pattern, rendering intent, flatness, stroke adjustment, overprint, transparency raw values, black-point compensation, and halftone-origin fields.
  - Validate line width, line cap, line join, miter limit, dash arrays, dash phase normalization, and flatness ranges while preserving deferred raw parameters.
  - State tests show ISO default values, accepted edge values, and rejected malformed parameters.
  - _Requirements: 3, 3.1, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8_
  - _Boundary: GraphicsState_

- [ ] 2.2 Implement graphics state stack behavior
  - Save and restore complete graphics state snapshots with LIFO semantics.
  - Report underflow when restore is requested with an empty stack.
  - Tests prove that restored state values revert while the current path remains outside the saved state.
  - _Requirements: 3.2, 3.12_
  - _Boundary: GraphicsState_

- [ ] 2.3 Resolve and apply cumulative ExtGState dictionaries
  - Require `gs` operands to name ExtGState resources and resolve them through the content resource model.
  - Apply known simple graphics state keys cumulatively and preserve deferred keys as raw values without executing later-phase semantics.
  - ExtGState tests cover missing names, non-dictionary resources, malformed dash entries, simple key updates, OP/op interaction, and cumulative repeated applications.
  - _Requirements: 3.9, 3.10_
  - _Boundary: ExtGStateResolver_
  - _Depends: 2.1_

- [ ] 3. Implement path and object-context state
- [ ] 3.1 (P) Track current path construction
  - Begin subpaths with move and rectangle operations, append lines and all cubic curve variants, and close subpaths according to the current point.
  - Apply consecutive move override, rectangle expansion, undefined-current-point errors, and current-path clearing after path completion.
  - Path tests show ordered subpaths, preserved curve control points, rectangle expansion, close behavior, and errors for invalid construction sequences.
  - _Requirements: 3.11, 3.12, 3.13_
  - _Boundary: CurrentPath_
  - _Depends: 1.2_

- [ ] 3.2 (P) Enforce graphics object context rules
  - Track content-stream, path-object, and text-object contexts as instructions are accepted.
  - Permit path construction, clipping, and path-painting operators only in the contexts allowed by section 8.2.
  - Context tests show valid path and text boundaries, rejected graphics-state operators inside paths, rejected invalid text nesting, and classified deferred-domain operators.
  - _Requirements: 2, 2.5, 3.12, 3.14, 3.19_
  - _Boundary: GraphicsObjectContext_

- [ ] 4. Build the graphics interpreter and event stream
- [ ] 4.1 Apply graphics state operators during interpretation
  - Iterate parsed content instructions in order and validate operands for state-changing operators.
  - Apply save, restore, matrix concatenation, line parameters, dash pattern, rendering intent, flatness, and ExtGState updates.
  - Interpreter tests show state-change events, final-state snapshots, operand failures with offsets, and stack underflow errors.
  - _Requirements: 1, 2, 2.6, 2.8, 3, 3.1, 3.2, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10_
  - _Boundary: GraphicsInterpreter_
  - _Depends: 2.1, 2.2, 2.3, 3.2_

- [ ] 4.2 Interpret path painting and clipping effects
  - Emit path paint events containing path, graphics state, paint mode, fill rule, and source offset snapshots.
  - Support stroke, close-and-stroke, fill variants, fill-and-stroke variants, end-path, pending clip rules, and clipping updates after path termination.
  - Tests show current path clearing, fill-rule selection, close variants, no-op path termination, pending clip application, and errors for painting without a current path.
  - _Requirements: 1, 2, 3.11, 3.12, 3.14, 3.15, 3.16, 3.17, 3.18, 3.19_
  - _Boundary: GraphicsInterpreter_
  - _Depends: 3.1, 3.2, 4.1_

- [ ] 4.3 Classify deferred graphics domains without executing them
  - Emit ordered events for text boundaries, XObject invocations, inline images, shadings, marked content, color operators, and future-domain operators.
  - Preserve section 8.2 object ordering without adding font, color-space, XObject, image, shading, marked-content, transparency, or rendering semantics.
  - Public interpreter tests show mixed content streams producing classified events in input order while unsupported domains remain non-rendering events.
  - _Requirements: 1, 2, 2.5_
  - _Boundary: GraphicsInterpreter_
  - _Depends: 3.2, 4.1_

- [ ] 5. Integrate page-level graphics interpretation
- [ ] 5.1 Add reader-side initial-state construction and error wrapping
  - Extend the reader boundary so page graphics failures are reported as document-level graphics errors.
  - Derive initial clip from CropBox when present and MediaBox otherwise, preserve UserUnit defaulting, preserve Rotate, and allow caller-supplied CTM options.
  - Reader tests show page boxes, missing boxes, UserUnit defaults, Rotate propagation, and graphics errors wrapped at the document boundary.
  - _Requirements: 2.3, 2.4, 3.1, 3.11_
  - _Boundary: ReaderGraphicsBridge_
  - _Depends: 1.3, 4.1_

- [ ] 5.2 Expose page graphics program and event APIs
  - Interpret parsed page content with page-derived initial state while keeping graphics independent of reader internals.
  - Return a complete graphics program or ordered graphics events from a page and preserve existing content parsing failures as content errors.
  - Integration tests show parsed page contents flowing through graphics interpretation with resources available to ExtGState lookup.
  - _Requirements: 1, 2.4, 3.1, 3.9, 3.10_
  - _Boundary: ReaderGraphicsBridge_
  - _Depends: 4.2, 4.3, 5.1_

- [ ] 6. Validate public behavior and generated interfaces
- [ ] 6.1 Complete focused graphics unit coverage
  - Cover geometry, state, stack, ExtGState, path, object context, and interpreter behavior at package level.
  - Tests include invalid operands, malformed resources, object-context violations, clipping side effects, and final-state snapshots.
  - `moon test` for the graphics package passes with the new unit and public tests.
  - _Requirements: 1, 2, 2.1, 2.2, 2.5, 2.6, 2.7, 2.8, 3, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12, 3.13, 3.14, 3.15, 3.16, 3.17, 3.18, 3.19_
  - _Boundary: GraphicsInterpreter_
  - _Depends: 4.3_

- [ ] 6.2 Complete reader bridge and regression validation
  - Cover page bridge behavior, page resources, content-error preservation, graphics-error wrapping, deep balanced state stacks, large streams, and many path segments.
  - Regression tests demonstrate linear single-pass interpretation without recursion or device-specific rendering.
  - `moon test` for the reader package passes with graphics bridge coverage.
  - _Requirements: 1, 2.3, 2.4, 3.1, 3.2, 3.9, 3.10, 3.11, 3.12, 3.19_
  - _Boundary: ReaderGraphicsBridge_
  - _Depends: 5.2_

- [ ] 6.3 Refresh formatting, checks, and public interface output
  - Run formatter, package checks, full relevant tests, and interface generation after implementation.
  - Generated public interfaces expose only the intended graphics and reader additions.
  - `moon check`, `moon fmt`, `moon info`, graphics tests, and reader tests complete successfully.
  - _Requirements: 1, 2, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 3, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10, 3.11, 3.12, 3.13, 3.14, 3.15, 3.16, 3.17, 3.18, 3.19_
  - _Boundary: GraphicsInterpreter, ReaderGraphicsBridge_
  - _Depends: 6.1, 6.2_
