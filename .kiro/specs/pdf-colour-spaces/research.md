# Research & Design Decisions

## Summary
- **Feature**: `pdf-colour-spaces`
- **Discovery Scope**: Extension
- **Key Findings**:
  - The existing `graphics` package already records colour operators as deferred events and stores current colour fields as raw `PdfObject`; this feature should replace that deferred area with typed colour semantics without changing the parser or renderer boundary.
  - ISO 32000-2 colour spaces require both resource-based lookup for content stream `CS`/`cs` operators and direct object parsing for image, shading, and nested colour-space definitions; the design needs reusable colour-space object parsing rather than operator-only logic.
  - ICCBased support can be structural and dependency-light by validating PDF stream dictionary entries and the ICC header/component signatures from direct profile streams; full colour management and rendering conversions remain out of scope.

## Research Log

### Existing graphics integration
- **Context**: Colour operators are present in `src/content/operator.mbt`, but `src/graphics/interpreter.mbt` currently classifies them as `ColorOperatorSeen`.
- **Sources Consulted**:
  - `src/content/operator.mbt`
  - `src/content/resources.mbt`
  - `src/graphics/state.mbt`
  - `src/graphics/interpreter.mbt`
  - `src/graphics/ext_gstate.mbt`
  - `src/reader/graphics.mbt`
- **Findings**:
  - `ContentResources` already exposes exact category lookup for the `ColorSpace` resource subdictionary.
  - `GraphicsState` includes stroking and nonstroking colour-space/value fields, rendering intent, overprint flags, overprint mode, and black point compensation, but several are raw `PdfObject` or `PdfName`.
  - `ExtGState` already applies `RI`, `OP`, `op`, `OPM`, and `UseBlackPtComp`; these should be tightened into colour-specific types and validation.
  - The reader package constructs a `GraphicsInitialState` but keeps device-specific rendering out of graphics interpretation.
- **Implications**:
  - The feature belongs primarily in `src/graphics`, with limited changes to reader call sites caused by public initial-state/state shape changes.
  - No dependency should point from `graphics` back to `reader`; indirect object loading remains outside the graphics package.

### PDF colour-space requirements
- **Context**: Requirements are generated from local ISO 32000-2 clause 8.6 extraction and span device, CIE-based, special colour spaces, defaults, rendering intents, black point compensation, overprint, and colour operators.
- **Sources Consulted**:
  - `spec/extracted/8.6-colour-spaces.spec.txt`
  - `.kiro/specs/pdf-colour-spaces/requirements.md`
- **Findings**:
  - Content stream colour-space selection uses names only; parameterized colour spaces are resolved through `ColorSpace` resources.
  - Explicit colour-space objects outside content streams use direct name/array objects and can nest other colour-space definitions.
  - Device default colour-space remapping changes the selected colour space but passes component values unchanged.
  - Pattern, Separation, DeviceN, rendering intent, implicit CIE conversion, overprint, and black point compensation all require preserving state for a downstream renderer even though this project phase does not render.
- **Implications**:
  - The design must separate PDF colour specification from output-device rendering.
  - Component count, range, initial value, and operand-form validation are in scope; raster conversion, gamut mapping, overprint compositing, and tint transform evaluation are out of scope.

### ICCBased profile constraints
- **Context**: ICCBased colour spaces reference ICC.1:2010 for PDF 2.0 and require component-count compatibility with the embedded profile.
- **Sources Consulted**:
  - [ICC.1:2010 profile specification](https://www.color.org/specification/<local-fixture>)
- **Findings**:
  - ICC.1:2010 identifies profile version 4.3.0.0 and defines profile header fields for profile class and data colour space.
  - PDF 2.0 ICCBased spaces allow source profile component counts 1, 3, or 4 and typical Gray, RGB, CMYK, and Lab ranges.
  - The existing `filters` package can decode a direct profile stream before header validation when a stream filter is present.
- **Implications**:
  - A minimal ICC validator can check decoded stream length, profile size field, version policy, profile class signature, and colour-space signature to derive component count.
  - The design should not add an external colour management library, because the current feature needs structural conformance and state, not device conversion.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Keep raw colour objects in graphics state | Continue recording colour operators without typed interpretation | Minimal code churn | Does not satisfy component count, initial value, default remap, ICCBased, or special-space validation | Rejected |
| Typed colour domain inside `graphics` | Add colour-space/value models, resolvers, and operator application in the existing graphics interpreter | Preserves package boundary, enables tests around clause 8.6, no parser changes | Public graphics API changes and moderate interpreter changes | Selected |
| Renderer-first colour management layer | Add full CIE, ICC, overprint, and pattern rendering behavior | Closer to final raster output | Violates current non-goal of rendering and adds device policy too early | Rejected |
| External ICC colour library | Delegate ICC profile parsing and transforms | Potentially complete colour management | Adds dependency, target compatibility risk, and unnecessary transform scope | Rejected |

## Design Decisions

### Decision: Model colour specification, not rendering
- **Context**: Clause 8.6 describes colour specification while clause 10 and transparency clauses define device-dependent rendering behavior.
- **Alternatives Considered**:
  1. Implement colour-space parsing plus conversion to XYZ/device values.
  2. Implement typed colour-space/value state and preserve rendering policy inputs.
- **Selected Approach**: Implement typed colour-space definitions, validated colour values, default remapping, rendering intent, black point compensation policy, and overprint state. Do not compute final device colours.
- **Rationale**: This matches steering non-goals and the current `GraphicsProgram` role as a device-independent event stream.
- **Trade-offs**: Downstream renderers must still implement colour conversion, tint transform evaluation, overprint compositing, and pattern painting.
- **Follow-up**: Rendering specs must revalidate against the public `ColourSpace` and `ColourValue` contracts.

### Decision: Build a MoonBit colour model rather than adopt dependencies
- **Context**: The project uses no external dependencies and targets native first, wasm second.
- **Alternatives Considered**:
  1. Add an ICC/CMS dependency.
  2. Add a compact structural validator using existing `filters` and `objects`.
- **Selected Approach**: Build a small structural model and ICC header validator in `src/graphics`.
- **Rationale**: Clause 8.6 implementation needs PDF object validation, component counts, and current state, not colour transform output.
- **Trade-offs**: ICC profile internals beyond the header and component signature remain deferred.
- **Follow-up**: A future rendering or colour-management feature can adopt a CMM behind a renderer-owned boundary.

### Decision: Resolve resources without coupling graphics to reader
- **Context**: `graphics` cannot import `reader` without reversing existing dependency direction.
- **Alternatives Considered**:
  1. Let `graphics` load indirect objects through `PdfFile`.
  2. Keep `graphics` direct-object oriented and report unresolved values where direct validation is impossible.
- **Selected Approach**: `graphics` resolves names through `ContentResources` and validates direct names, arrays, dictionaries, streams, and permitted indirect references as object references. It never calls `PdfFile::load_object`.
- **Rationale**: This preserves `objects -> content -> graphics -> reader` usage direction and keeps tests package-local.
- **Trade-offs**: Full validation of indirect ICC profile streams and indirect tint functions depends on a reader-level materialization path or future resolver integration.
- **Follow-up**: If implementation finds many unresolved indirect colour resources in reader workflows, add a reader-owned preprocessing helper rather than importing reader from graphics.

### Decision: Generalize operator handling through `ColourUse`
- **Context**: Stroking and nonstroking operators have parallel behavior and differ only by target state field.
- **Alternatives Considered**:
  1. Duplicate operator logic for stroking and nonstroking.
  2. Route through a `ColourUse` target and shared helpers.
- **Selected Approach**: Use `ColourUse::{Stroking, Nonstroking}` for selection, value application, initial value, and event reporting.
- **Rationale**: This reduces duplicated validation while keeping public event semantics explicit.
- **Trade-offs**: Error messages must still name the original operator and target for clarity.
- **Follow-up**: Tests must cover both stroking and nonstroking paths for representative operators.

## Risks & Mitigations
- Public graphics API churn may affect reader and tests - update call sites and regenerate `pkg.generated.mbti` with `moon info`.
- ICC stream validation can overreach into filter decoding - keep the validator limited to direct streams and existing `filters.decode_stream`.
- Special colour spaces can pull rendering policy into graphics - store alternate spaces, tint functions, attributes, and policy flags, but do not evaluate or paint them.
- Requirement `0.22` has a malformed heading from extraction - treat it as the continuation of Separation tint semantics while still listing the numeric ID independently in traceability.
- Device default remapping inside nested special spaces is easy to miss - centralize remap logic in the colour-space resolver and test indexed, pattern, Separation, and DeviceN alternates.

## References
- `spec/extracted/8.6-colour-spaces.spec.txt` - Local ISO 32000-2 colour-space extraction used as the primary project source.
- `.kiro/specs/pdf-colour-spaces/requirements.md` - Generated requirement set for this design.
- [ICC.1:2010 profile specification](https://www.color.org/specification/<local-fixture>) - Official ICC profile format source for ICCBased structural validation.
