# Research & Design Decisions

## Summary
- **Feature**: `pdf-rendering`
- **Discovery Scope**: Complex Integration
- **Key Findings**:
  - The existing implementation deliberately stops at device-independent graphics, colour, pattern, XObject, image, and text semantics. Rendering must therefore be a downstream package rather than an expansion of `src/graphics`.
  - ISO 32000-2 clause 10 requires device-dependent policy: native colour spaces, output profiles, transfer functions, halftones, scan conversion, and separation simulation vary by raster device. The design uses explicit device configuration and renderer-owned adapters for colour management and glyph rasterization.
  - The project steering allows no external dependencies, so ICC colour management is represented as a caller-supplied transform contract. The in-project implementation covers normative classic DeviceGray, DeviceRGB, and DeviceCMYK conversions and preserves unsupported CIE/ICC conversions as explicit rendering errors or caller policy decisions.

## Research Log

### Existing package boundary and integration points
- **Context**: Rendering consumes page semantics already modeled by earlier specs.
- **Sources Consulted**: `.kiro/steering/product.md`, `.kiro/steering/tech.md`, `.kiro/steering/structure.md`, `src/graphics/*.mbt`, `src/text/*.mbt`, `src/reader/graphics.mbt`, `.kiro/specs/pdf-graphics/design.md`, `.kiro/specs/pdf-colour-spaces/design.md`, `.kiro/specs/pdf-patterns/design.md`, `.kiro/specs/pdf-xobjects-images/design.md`, `.kiro/specs/pdf-text/design.md`.
- **Findings**:
  - `src/graphics` already emits ordered `GraphicsEvent` values with state snapshots, current colours, paths, image descriptors, XObject/form events, and shading events.
  - `GraphicsState` preserves `BG`, `BG2`, `UCR`, `UCR2`, `TR`, `TR2`, `HT`, and `SM` as deferred raw ExtGState entries; `SA`, `FL`, rendering intent, overprint, black point compensation, and halftone origin are already typed.
  - `src/text` defines renderer-independent glyph events and paint intent types, but reader-level text materialization is not yet wired in the current worktree.
  - `src/reader` owns document object loading, page resources, page geometry, optional content evaluation, and error wrapping.
- **Implications**:
  - Rendering should be implemented in a new `src/rendering` package that depends on `graphics`, `text`, `objects`, `content`, and `filters`.
  - Reader integration should live in `src/reader/rendering.mbt` so rendering never imports `reader` or performs object graph traversal itself.
  - Text rendering must be adapter-based: `src/rendering` can consume supplied `@text.TextProgram` glyph events and a glyph rasterizer, but it must not become a font-program interpreter.

### ISO clause 10 rendering pipeline
- **Context**: Requirements were generated from `spec/extracted/10-rendering.spec.txt` and cover colour conversion, transfer functions, halftones, scan conversion, and separations.
- **Sources Consulted**: `.kiro/specs/pdf-rendering/requirements.md`, `spec/extracted/10-rendering.spec.txt`, `spec/extracted/8.1-8.5-graphics-state.spec.txt`, `spec/extracted/8.6-colour-spaces.spec.txt`, `spec/extracted/11-transparency.spec.txt`.
- **Findings**:
  - The rendering order is colour conversion to native device colour, transfer functions, optional halftoning, and scan conversion.
  - Halftones and transfer functions operate in device space and native device colour components; subtractive components are passed to transfer functions in additive form.
  - Type 1, 5, 6, 10, and 16 halftones share a common colourant-selection contract but differ in threshold source and cell geometry.
  - Scan conversion has specific half-open pixel rules for filled/stroked shapes, centre sampling for images, clipping intersection rules, and implementation-defined glyph rasterization freedom.
  - Separation simulation is a rendering concern that needs simulated subtractive process/spot colourants and a multiply blend path, but it does not require implementing the full transparency model.
- **Implications**:
  - A single `RenderingPipeline` should sequence device colour conversion, transfer, halftone, and surface painting.
  - Halftone parsing and application should be isolated from path/image scan conversion so continuous-tone devices can bypass halftoning.
  - Scan conversion must define deterministic project behaviour for shapes and images while preserving a glyph rasterizer boundary.

### External standards and dependency policy
- **Context**: Requirement 2.1 references ISO 15076-1:2010 / ICC.1:2010 for CIE-based colour conversion.
- **Sources Consulted**:
  - [PDF Association ISO 32000 normative references](https://pdfa.org/resource/normative-references-of-iso-32000/) — public reference list for ISO 32000-2:2020 context.
  - [ICC.1:2010 profile specification](https://www.color.org/specification/<local-fixture>) — ICC profile architecture, profile headers, PCS/device transforms, embedded profiles.
  - `.kiro/steering/tech.md` — standard-library-only project dependency policy.
- **Findings**:
  - ICC colour management is a specialized transformation problem with profile parsing, tag lookup, rendering intents, and PCS/device conversion.
  - The current project already validates ICCBased stream structure and profile headers but does not execute ICC transforms.
  - Introducing a complete CMM would violate the current no-external-dependency steering unless explicitly approved.
- **Implications**:
  - Rendering must expose a `ColourTransformProvider` contract for CIE/ICC conversions and provide deterministic classic device conversions in-project.
  - Missing colour transform support must be observable as a rendering error or explicit approximation policy, never hidden behind silent success.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Extend `src/graphics` into a renderer | Add pixel surface, colour conversion, halftones, and scan conversion directly to graphics interpretation | Fewer packages initially | Violates prior non-rendering boundary; couples device policy to semantic interpretation | Rejected |
| New downstream `src/rendering` package | Consume `GraphicsProgram`, optional text events, reader-materialized resources, and explicit device config | Preserves package direction and keeps rendering device-dependent | Requires bridge contracts for text glyphs, ICC transforms, and indirect resources | Selected |
| External renderer or CMM dependency | Adopt PDFium, LittleCMS-style CMM, or platform APIs | Mature rendering and colour behavior | Not available in MoonBit project stack; violates standard-library-only steering | Rejected |
| Minimal structural renderer only | Parse rendering parameters but never write pixels | Low risk | Does not satisfy scan conversion or raster output requirements | Rejected |

## Design Decisions

### Decision: Add `src/rendering` as the device-dependent layer
- **Context**: Earlier specs intentionally modeled graphics without rendering.
- **Alternatives Considered**:
  1. Expand `src/graphics` with rendering responsibilities.
  2. Add `src/rendering` downstream of `src/graphics` and `src/text`.
- **Selected Approach**: Create `src/rendering` for raster device modeling, colour conversion, transfer functions, halftones, scan conversion, separation simulation, and raster surface output.
- **Rationale**: This follows existing dependency direction and lets semantic interpretation remain reusable for extraction and analysis workflows.
- **Trade-offs**: Public renderer APIs need explicit adapters for resources, colour transforms, and glyph rasterization.
- **Follow-up**: Implementation tasks must add package-boundary tests so `graphics` and `text` never import `rendering`.

### Decision: Use provider contracts for ICC/CIE and glyph rasterization
- **Context**: Clause 10 references device profiles and glyph rasterization, but the project has no CMM or font-program renderer.
- **Alternatives Considered**:
  1. Implement a complete ICC CMM and font rasterizer in this feature.
  2. Reject all CIE and text rendering.
  3. Define renderer-owned provider contracts with deterministic built-in fallbacks where ISO gives explicit formulas.
- **Selected Approach**: Implement classic DeviceGray/RGB/CMYK conversions, expose a `ColourTransformProvider` for CIE/ICC transforms, and expose a `GlyphRasterizer` for text outlines/masks.
- **Rationale**: This satisfies the current package and dependency constraints while making unsupported device-dependent work explicit.
- **Trade-offs**: Full fidelity depends on caller-supplied providers or later specs.
- **Follow-up**: Tests must cover both successful provider paths and missing-provider diagnostics.

### Decision: Parse halftone definitions into a common colourant contract
- **Context**: Type 1, 5, 6, 10, and 16 halftones differ structurally but are selected per native component or colourant.
- **Alternatives Considered**:
  1. Implement each halftone type as a separate path through the renderer.
  2. Normalize halftones into `HalftoneScreen` / `HalftoneSet` and apply through one processor.
- **Selected Approach**: Parse all halftone dictionaries into a normalized model with component lookup, transfer-function override, and threshold lookup.
- **Rationale**: It keeps Type 5 colourant dispatch, default fallback, and nonprimary colourant transfer overrides consistent.
- **Trade-offs**: Some type-specific validation remains in parser modules.
- **Follow-up**: Include tests for Type 5 default selection and transfer override precedence.

### Decision: Keep transparency compositing separate except separation simulation
- **Context**: Clause 10.8.3 uses multiply blending for separation simulation, while general transparency belongs to clause 11.
- **Alternatives Considered**:
  1. Fold transparency compositing into this rendering feature.
  2. Implement only the separation simulation blend needed by clause 10.
- **Selected Approach**: Implement separation simulation multiply blending as a local rendering operation and treat general transparency group compositing as a dependency/revalidation trigger for `pdf-transparency`.
- **Rationale**: This avoids expanding the spec beyond clause 10 while satisfying separation simulation.
- **Trade-offs**: Pages requiring general transparency need the transparency layer before complete final appearance is possible.
- **Follow-up**: Revalidate once `pdf-transparency` design is generated.

## Risks & Mitigations
- ICC/CIE colour conversion fidelity risk — provide a required provider path for strict mode, classic conversion fallback only where ISO supplies formulas, and explicit errors when a transform is unavailable.
- Performance risk in scan conversion and halftoning — use bounding boxes, row spans, threshold caches, and per-render limits for surface dimensions, halftone cell sizes, and path flattening work.
- Package-cycle risk — keep object loading in `reader`, expose resolver/provider contracts to `rendering`, and add compile-time package boundary tests.
- Text rendering incompleteness risk — render glyph events only when supplied by `@text` and a `GlyphRasterizer`; otherwise report unsupported text paint operations without affecting nontext rendering.
- Transparency interaction risk — isolate opaque rendering and separation simulation now, and require revalidation when general transparency compositing is added.

## References
- `spec/extracted/10-rendering.spec.txt` — local extracted source for ISO 32000-2:2020 clause 10.
- `.kiro/specs/pdf-rendering/requirements.md` — generated requirement IDs for this design.
- `.kiro/specs/pdf-colour-spaces/design.md` — upstream colour-state and colour-space contracts consumed by rendering.
- `.kiro/specs/pdf-graphics/design.md` — upstream graphics-event and graphics-state contracts consumed by rendering.
- [PDF Association ISO 32000 normative references](https://pdfa.org/resource/normative-references-of-iso-32000/) — public ISO 32000-2:2020 reference context.
- [ICC.1:2010 profile specification](https://www.color.org/specification/<local-fixture>) — ICC profile architecture referenced by CIE/ICC colour conversion requirements.
