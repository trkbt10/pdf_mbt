# Research & Design Decisions

## Summary
- **Feature**: `pdf-transparency`
- **Discovery Scope**: Extension
- **Key Findings**:
  - The existing architecture already separates syntax, device-independent graphics semantics, document loading, and raster output. Transparency must preserve that dependency direction while spanning `graphics`, `rendering`, and `reader`.
  - `src/graphics` already stores raw or partially typed transparency-related graphics state entries (`BM`, `SMask`, `CA`, `ca`, `AIS`, `TK`) but does not validate blend modes, soft-mask dictionaries, or execute compositing.
  - The `pdf-rendering` design explicitly leaves general transparency compositing, soft masks, knockout groups, and blend modes to this specification, so this design owns the renderer-facing transparency pipeline.

## Research Log

### Existing package boundaries
- **Context**: Transparency affects graphics-state interpretation, Form XObject group metadata, image masks, and final compositing.
- **Sources Consulted**:
  - `.kiro/steering/product.md`
  - `.kiro/steering/tech.md`
  - `.kiro/steering/structure.md`
  - `src/graphics/state.mbt`
  - `src/graphics/ext_gstate.mbt`
  - `src/graphics/form_xobject.mbt`
  - `src/graphics/image.mbt`
  - `src/rendering/device.mbt`
  - `src/rendering/surface.mbt`
  - `src/reader/xobjects.mbt`
- **Findings**:
  - `graphics` may import `objects`, `content`, `filters`, and `math`; it must not import `reader`.
  - `reader` already materializes XObject and Properties resources for page graphics interpretation.
  - `rendering` is downstream and currently models devices and raster surfaces without importing `graphics`.
  - `FormGroupInfo` preserves raw group dictionaries but does not identify Transparency groups.
  - `ImageDescriptor` preserves image soft-mask metadata without validating soft-mask image restrictions.
- **Implications**:
  - Transparency dictionaries and scene metadata belong in `graphics`.
  - Pixel compositing and group stack evaluation belong in `rendering`.
  - Indirect soft masks, group XObjects, and page Group dictionaries must be materialized by `reader`.

### Requirements and ISO clause coverage
- **Context**: `requirements.md` is generated from ISO 32000-2 clause 11 and contains requirements `1`, `2`, and `2.1` through `2.46`.
- **Sources Consulted**:
  - `.kiro/specs/pdf-transparency/requirements.md`
  - `spec/extracted/11-transparency.spec.txt`
- **Findings**:
  - The requirements cover both representation in PDF and rendering/compositing math.
  - Blend modes and compositing formulas are deterministic scalar/vector operations and can be implemented without external dependencies.
  - Colour conversions, transfer functions, tint transforms, CIE/ICC transforms, and PDF functions are referenced by transparency but already belong to colour/rendering provider boundaries.
  - Annex Q transparency presence is mentioned as non-required background, not as an implementation obligation for this spec.
- **Implications**:
  - The design must include typed math contracts for blend modes, alpha, groups, soft masks, spot colours, and overprint policies.
  - Colour conversion and PDF function evaluation must be represented as provider contracts or deferred object references, not implemented inside `graphics`.

### Existing related designs
- **Context**: Active specs define colour spaces, patterns, XObjects/images, and rendering.
- **Sources Consulted**:
  - `.kiro/specs/pdf-colour-spaces/design.md`
  - `.kiro/specs/pdf-patterns/design.md`
  - `.kiro/specs/pdf-xobjects-images/design.md`
  - `.kiro/specs/pdf-rendering/design.md`
- **Findings**:
  - Colour-space parsing and current colour state already live in `graphics`.
  - Pattern and XObject designs preserve loaded-resource semantics in `graphics` and object materialization in `reader`.
  - Rendering owns raster output but excludes general transparency until this spec.
- **Implications**:
  - This spec should extend existing models instead of replacing them.
  - Transparency group metadata should build on Form XObject validation.
  - Transparency rendering should consume `GraphicsProgram` and `GraphicsEvent` rather than changing content parsing.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Graphics-only metadata | Validate transparency dictionaries and expose events without compositing | Small change, preserves current device-independent scope | Fails requirements for blend modes, groups, soft masks, overprint, and rendering parameter behavior | Rejected as incomplete |
| Rendering-only transparency | Let rendering parse raw graphics state and PDF dictionaries while compositing | Keeps graphics small | Violates existing ownership because rendering would need syntax/resource semantics and indirect loading context | Rejected |
| Split semantic model plus rendering compositor | `graphics` owns typed transparency representation; `rendering` owns compositing; `reader` owns materialization | Aligns with current package boundaries and satisfies clause 11 | Requires public contract changes across three packages | Selected |

## Design Decisions

### Decision: Split transparency ownership across graphics, rendering, and reader
- **Context**: Clause 11 specifies both PDF representation and pixel-level compositing behavior.
- **Alternatives Considered**:
  1. Keep all transparency behavior in `graphics`.
  2. Move all transparency behavior to `rendering`.
  3. Split structural semantics, compositing, and materialization by existing package ownership.
- **Selected Approach**: `graphics` validates and publishes typed transparency state, groups, blend modes, soft masks, and paint intent; `rendering` evaluates transparency stacks and writes composited samples; `reader` materializes indirect resources and page group metadata.
- **Rationale**: This preserves dependency direction while letting each layer own the data it already understands.
- **Trade-offs**: More public APIs must be reviewed with `moon info`, but implementation tasks can be bounded per package.
- **Follow-up**: Verify `src/rendering/moon.pkg` imports remain downstream-only and do not introduce a reader dependency.

### Decision: Build blend/compositing math in-project
- **Context**: The project has no external dependencies and the formulas are specified directly by ISO 32000-2.
- **Alternatives Considered**:
  1. Add a graphics or image-processing library.
  2. Implement scalar/vector math in `rendering`.
- **Selected Approach**: Implement deterministic scalar/vector blend, alpha, union, group, knockout, and soft-mask computations in `src/rendering`.
- **Rationale**: External libraries would not understand PDF graphics state, group colour-space inheritance, or spot colour behavior without substantial adaptation.
- **Trade-offs**: More tests are required for formula edge cases such as zero alpha and 0/0 handling.
- **Follow-up**: Use focused unit tests for every standard blend mode and group formula variant.

### Decision: Keep colour conversion and PDF function execution behind provider contracts
- **Context**: Soft-mask luminosity, group colour spaces, transfer functions, tint transforms, and DeviceRGB to DeviceCMYK conversion require colour management and PDF function evaluation.
- **Alternatives Considered**:
  1. Implement all colour management and PDF functions in this spec.
  2. Preserve raw objects and require renderer/provider inputs when conversion is needed.
- **Selected Approach**: Transparency records the required conversion context and calls rendering provider contracts where execution is needed.
- **Rationale**: Existing colour and rendering specs already separate structural colour semantics from device colour management.
- **Trade-offs**: Some rendering paths may return unsupported outcomes until providers exist.
- **Follow-up**: Tests must cover both provider-present and provider-missing paths.

### Decision: Treat soft masks as first-class transparency sources
- **Context**: Clause 11 distinguishes graphics-state soft-mask dictionaries, soft-mask images, JPX embedded masks, alpha constants, and alpha-is-shape behavior.
- **Alternatives Considered**:
  1. Leave `SMask` as raw `PdfObject`.
  2. Parse only dictionary subtype and group reference.
  3. Model all soft-mask sources structurally and let rendering evaluate supported ones.
- **Selected Approach**: Add typed `SoftMaskSource`, `SoftMaskDictionary`, and `SoftMaskImage` models in `graphics`, plus rendering evaluators for alpha and luminosity masks.
- **Rationale**: Typed sources are required to choose shape versus opacity inputs and to enforce image-mask restrictions.
- **Trade-offs**: Indirect soft-mask materialization requires reader support.
- **Follow-up**: Ensure image soft-mask validation does not break existing image descriptor tests.

## Risks & Mitigations
- **Risk**: Transparency can expand into full colour management. **Mitigation**: Keep CIE/ICC/function execution behind rendering provider contracts and document unsupported outcomes.
- **Risk**: Group compositing may accidentally double-apply backdrop contribution. **Mitigation**: Centralize group formulas in `TransparencyCompositor` and add isolated, non-isolated, knockout, and non-knockout tests.
- **Risk**: Graphics-state public API changes can ripple into existing specs. **Mitigation**: Update `pkg.generated.mbti` with `moon info` and add compatibility tests around existing graphics events.
- **Risk**: Indirect resource loading could leak into `graphics`. **Mitigation**: Keep all indirect materialization in `reader` and expose unresolved resource variants in `graphics`.

## References
- `.kiro/specs/pdf-transparency/requirements.md` - Clause 11 requirements source for this design.
- `spec/extracted/11-transparency.spec.txt` - Extracted ISO 32000-2 clause 11 text.
- `.kiro/specs/pdf-colour-spaces/design.md` - Existing colour-space ownership and contracts.
- `.kiro/specs/pdf-xobjects-images/design.md` - Existing image, Form XObject, and optional-content boundary.
- `.kiro/specs/pdf-patterns/design.md` - Existing pattern and shading validation boundary.
- `.kiro/specs/pdf-rendering/design.md` - Downstream raster rendering boundary that defers general transparency here.
