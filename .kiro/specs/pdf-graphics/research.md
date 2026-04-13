# Research & Design Decisions

## Summary
- **Feature**: `pdf-graphics`
- **Discovery Scope**: Extension / Integration-focused discovery
- **Key Findings**:
  - The existing `src/content` package already supplies decoded content instructions, exact operator variants, operands, inline images, and resource contexts. Graphics interpretation should consume that public contract instead of reparsing content streams.
  - ISO 32000-2 graphics state and path semantics need a stateful interpreter, but rendering, scan conversion, font/glyph interpretation, color conversion, XObject execution, and transparency compositing remain outside this spec.
  - The current path is explicitly not part of the graphics state stack. `q` and `Q` save and restore graphics-state parameters only, while path painting or `n` clears the current path after applying any pending clip.

## Research Log

### Existing Content Stream Boundary
- **Context**: Requirements 1 and 2 describe content-stream graphics operators and graphics objects. The repository already has a content-stream parser from the previous phase.
- **Sources Consulted**:
  - `src/content/operator.mbt`
  - `src/content/parser.mbt`
  - `src/content/resources.mbt`
  - `src/content/pkg.generated.mbti`
  - `.kiro/specs/pdf-content-streams/design.md`
  - `.kiro/specs/pdf-content-streams/research.md`
- **Findings**:
  - `@content.StandardContentOperator` already recognizes the graphics, path, clipping, text, color, XObject, inline-image, marked-content, compatibility, shading, and Type 3 glyph-width operators.
  - `@content.ContentStream` preserves ordered `ContentInstruction` values with raw `PdfObject` operands and a `ContentResources` context.
  - `@content.ContentResources` exposes exact resource-category lookup without rendering or recursive interpretation.
- **Implications**:
  - Add a new `src/graphics` package that imports `objects` and `content`.
  - Do not add operator recognition, decoded-byte parsing, or stream decoding to the graphics layer.
  - Reader page integration can import `graphics` and reuse `PdfPage::content_stream()`.

### Reader Page Geometry and Initial State
- **Context**: Requirements 2.3, 2.4, 3.1, and 3.11 require device/user-space boundaries, page boxes, UserUnit, Rotate, and the initial clipping path.
- **Sources Consulted**:
  - `src/reader/document_types.mbt`
  - `src/reader/document_structure.mbt`
  - `src/reader/page_wbtest.mbt`
  - `.kiro/specs/pdf-document-structure/design.md`
- **Findings**:
  - `PdfPage` already exposes typed `media_box`, `crop_box`, `rotate`, and `user_unit` accessors.
  - Device space is inherently output-device dependent, so the graphics package cannot compute a universal device transform.
  - The page bridge can create a default graphics context from page metadata while allowing callers to supply an initial device transform when they need one.
- **Implications**:
  - The pure graphics interpreter accepts an explicit `GraphicsInitialState`.
  - The reader bridge builds that initial state from `PdfPage` boxes, Rotate, UserUnit, and an optional caller-supplied initial CTM.
  - Missing or malformed page boxes remain reader/document errors, not graphics package object-loading concerns.

### Graphics State and Extended Graphics State Dictionaries
- **Context**: Requirements 3.1 through 3.10 define graphics state parameters, stack behavior, graphics-state operators, and ExtGState dictionaries.
- **Sources Consulted**:
  - `spec/extracted/8.1-8.5-graphics-state.spec.txt`
  - `.kiro/specs/pdf-graphics/requirements.md`
  - `src/content/resources.mbt`
  - `src/objects/types.mbt`
- **Findings**:
  - Simple graphics-state operands can be validated directly from content operands: line width, cap, join, miter limit, dash pattern, rendering intent, flatness, and matrix operands.
  - `gs` must look up a named dictionary in the current `ExtGState` resource category and apply entries cumulatively.
  - Many ExtGState entries refer to later rendering, color, transparency, function, halftone, or text semantics. This spec can store validated raw values without executing those models.
- **Implications**:
  - Model graphics state with typed simple fields plus raw object fields for later-phase semantics.
  - Keep ExtGState parsing in `src/graphics/ext_gstate.mbt`, using `ContentResources::lookup_resource(ExtGState, name)`.
  - Reject malformed supported entries early, but do not evaluate functions, halftones, soft masks, blend modes, colors, or fonts.

### Coordinate Systems and Matrix Order
- **Context**: Requirements 2.1 through 2.8 define coordinate spaces, common transformations, and transformation-matrix mathematics.
- **Sources Consulted**:
  - `spec/extracted/8.1-8.5-graphics-state.spec.txt`
  - `.kiro/specs/pdf-graphics/requirements.md`
- **Findings**:
  - PDF matrices are six numbers `[a b c d e f]` representing the 3-by-3 affine matrix used by PDF.
  - A new transformation from `cm` is premultiplied with the existing CTM: `M' = MT x M`.
  - Matrix inversion is useful for downstream rendering or hit testing but non-invertible matrices are not an error when merely modeling content; painting with them has unpredictable rendering behavior.
- **Implications**:
  - Provide matrix construction, concatenation, point transformation, determinant, and optional inverse.
  - `cm` uses the ISO premultiplication order.
  - Non-invertible CTMs are represented and can be flagged in validation, but the interpreter does not fail solely because a CTM is non-invertible.

### Current Path, Painting, and Clipping
- **Context**: Requirements 3.11 through 3.19 define path construction, painting, fill rules, stroking dependencies, and clipping behavior.
- **Sources Consulted**:
  - `spec/extracted/8.1-8.5-graphics-state.spec.txt`
  - `.kiro/specs/pdf-graphics/requirements.md`
  - `src/content/operator.mbt`
- **Findings**:
  - Current path is an internal object, not a graphics-state parameter, and must not be saved by `q`.
  - Path construction begins with `m` or `re`; line and curve operators require a defined current point.
  - Clipping operators set a pending clip rule that takes effect only when the next path-painting operator terminates the path.
  - Stroking/filling require path snapshots plus graphics-state snapshots; actual rasterization and fill-rule point classification are rendering concerns.
- **Implications**:
  - Represent path segments and subpaths as typed internal data.
  - Emit graphics events for stroke, fill, fill-stroke, end-path, and clip updates, then clear the current path.
  - Store fill-rule choices and stroke parameters without converting them into pixels or filled regions.

### External Dependency Verification
- **Context**: Discovery requires checking new dependencies.
- **Sources Consulted**:
  - `.kiro/steering/tech.md`
  - Existing `moon.pkg` files under `src/`
- **Findings**:
  - Steering requires standard-library-only implementation.
  - Existing local packages provide all needed input contracts: `objects`, `content`, and `reader`.
  - No third-party geometry, rendering, or graphics library is required for this modeling layer.
- **Implications**:
  - No external library or web dependency research is needed.
  - The package remains suitable for native and wasm targets.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Extend `src/content` with graphics execution | Add graphics state and path behavior directly to content parsing | Fewer packages | Blurs syntax parsing with semantic interpretation; makes content parser heavier | Rejected |
| Add graphics behavior to `src/reader` only | Interpret page contents directly in reader | Easy access to page metadata | Not reusable for Form XObjects, appearance streams, or already parsed content streams | Rejected |
| New `src/graphics` package plus reader bridge | Interpret `@content.ContentStream` into graphics-state/path events; reader provides page initial state | Preserves dependency direction, keeps parsing separate, supports pure and page workflows | Requires new public API surface and document error wrapping | Selected |
| Rendering-backed graphics engine | Convert paths to pixels or display primitives | Closer to visual output | Exceeds product and requirement scope; would require font, color, transparency, and device models | Rejected |

## Design Decisions

### Decision: Interpret Graphics Semantics Without Rendering
- **Context**: The requirements cover graphics state, coordinate systems, path construction, path painting, and clipping, while project steering defers rendering.
- **Alternatives Considered**:
  1. Build a renderer or scan converter.
  2. Build a stateful graphics interpreter that emits typed graphics events.
  3. Only expose helper types and leave all interpretation to users.
- **Selected Approach**: Build a stateful interpreter over `@content.ContentStream` that validates operands, updates graphics state, tracks current path and clipping, and emits `GraphicsEvent` values.
- **Rationale**: This satisfies the clause 8.1-8.5 semantics needed by downstream consumers while avoiding clause 10 rendering and clause 11 transparency implementation.
- **Trade-offs**: The output is not visual; downstream layers must still render, extract, or execute XObjects/text.
- **Follow-up**: During implementation, keep event payloads stable enough for future text, color, and rendering phases.

### Decision: Separate Current Path From Graphics State
- **Context**: ISO states that the current path is not part of the graphics state and is not saved/restored by `q` and `Q`.
- **Alternatives Considered**:
  1. Store current path inside `GraphicsState`.
  2. Store current path in the interpreter, separate from the state stack.
- **Selected Approach**: `GraphicsInterpreter` owns `CurrentPath` and `PendingClip`; `GraphicsStateStack` stores only `GraphicsState` snapshots.
- **Rationale**: This mirrors the specification and prevents `Q` from incorrectly restoring a previous path.
- **Trade-offs**: Interpreter methods must coordinate state and path explicitly.
- **Follow-up**: Add tests proving `q`, path edits, and `Q` do not restore the old current path.

### Decision: ExtGState Applies Typed Patches With Raw Deferred Fields
- **Context**: `gs` dictionaries include simple stroke parameters and later-phase rendering, transparency, function, halftone, and text fields.
- **Alternatives Considered**:
  1. Reject entries outside clause 8.4.3.
  2. Store the whole dictionary without validation.
  3. Validate simple known shapes and preserve deferred entries as raw `PdfObject` values.
- **Selected Approach**: Parse an `ExtGStatePatch` that applies simple values to `GraphicsState` and stores deferred values in typed optional raw fields.
- **Rationale**: This honors cumulative `gs` behavior without taking ownership of future rendering and text models.
- **Trade-offs**: Some invalid function or transparency details are detected only by future phases.
- **Follow-up**: Revalidate when color, transparency, function, halftone, or text-state specs are introduced.

### Decision: Page Bridge Supplies Initial Graphics Context
- **Context**: Default user space depends on page boxes, UserUnit, Rotate, and output-device CTM.
- **Alternatives Considered**:
  1. Make `src/graphics` import `src/reader`.
  2. Keep `src/graphics` pure and add reader-side `PdfPage` helpers.
  3. Ignore page metadata and always use identity state.
- **Selected Approach**: `src/graphics` accepts `GraphicsInitialState`; `src/reader/graphics.mbt` builds it from `PdfPage` typed accessors and optional caller options.
- **Rationale**: This avoids a package cycle and keeps document loading in reader.
- **Trade-offs**: Pure callers must provide explicit initial context if they need page-specific clipping or CTM behavior.
- **Follow-up**: Add Form XObject initial-state construction when the XObject execution spec is created.

### Decision: Validate Object Context at the Graphics Layer
- **Context**: Requirement 2 states that graphics operators are only valid in specific graphics-object contexts, but `src/content` intentionally performs syntax parsing only.
- **Alternatives Considered**:
  1. Add context validation to `src/content`.
  2. Validate object context in `src/graphics`.
  3. Leave all invalid context handling to downstream users.
- **Selected Approach**: `GraphicsObjectContext` tracks content-stream level, path object, and text object boundaries while treating text internals, XObjects, inline images, shading, color, and marked content as event categories rather than fully executed subsystems.
- **Rationale**: Context validity is semantic graphics behavior, not lexical parsing.
- **Trade-offs**: Some clause 9 text-state errors remain out of boundary.
- **Follow-up**: Revalidate when `pdf-text`, `pdf-color`, `pdf-xobject`, or `pdf-marked-content` specs add deeper semantics.

## Risks & Mitigations
- Matrix multiplication order can be implemented backward - mitigate with focused tests for `cm` premultiplication, translation, scale, rotation, and point transformation.
- Accidentally saving the current path on `q` would violate ISO behavior - mitigate with state-stack tests that mutate the path between `q` and `Q`.
- ExtGState entries span many future domains - mitigate by validating simple fields now, preserving deferred raw values, and documenting revalidation triggers.
- Path painting could drift into rendering - mitigate by emitting path and state snapshots plus fill/stroke modes, not pixels or device colors.
- Reader page bridge can over-assume device space - mitigate by accepting an explicit initial CTM and documenting identity as a modeling default.

## References
- `spec/extracted/8.1-8.5-graphics-state.spec.txt` - coordinate systems, graphics state, path construction, painting, and clipping requirements.
- `.kiro/specs/pdf-graphics/requirements.md` - canonical requirements used for this design.
- `.kiro/specs/pdf-content-streams/design.md` - upstream content parser and resource-context boundary.
- `.kiro/specs/pdf-content-streams/research.md` - prior content-stream discovery and dependency direction.
- `.kiro/steering/product.md` - parser-first product scope and rendering non-goals.
- `.kiro/steering/tech.md` - MoonBit tooling, no external dependency policy, byte-stream parser principles.
- `.kiro/steering/structure.md` - package layout and dependency direction.
