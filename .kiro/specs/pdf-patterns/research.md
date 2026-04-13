# Research & Design Decisions

## Summary
- **Feature**: `pdf-patterns`
- **Discovery Scope**: Extension / Integration-focused discovery
- **Key Findings**:
  - Existing `content` resources already expose `Pattern` and `Shading` resource categories, and existing `graphics` events already classify `sh`; this feature should validate and model those resources rather than change content parsing.
  - Existing colour-space support already models `Pattern` colour spaces and pattern-name operands, but it does not validate the referenced Pattern resource or distinguish coloured tiling, uncoloured tiling, and shading pattern resources.
  - Clause 8.7 can be implemented as structural pattern and shading interpretation without rendering, colour conversion, function evaluation, or mesh rasterization.

## Research Log

### Existing graphics and colour integration
- **Context**: Pattern painting connects colour operators, resource dictionaries, graphics state, and the `sh` operator.
- **Sources Consulted**:
  - `src/content/resources.mbt`
  - `src/content/operator.mbt`
  - `src/graphics/colour_space.mbt`
  - `src/graphics/colour_state.mbt`
  - `src/graphics/colour_operator.mbt`
  - `src/graphics/interpreter.mbt`
  - `.kiro/specs/pdf-colour-spaces/design.md`
  - `.kiro/specs/pdf-graphics/design.md`
- **Findings**:
  - `ContentResources` supports exact lookup for `Pattern` and `Shading` subdictionaries.
  - `ColourSpace::Pattern` already represents optional underlying colour spaces and rejects a Pattern underlying space.
  - `ColourValue` stores numeric components plus an optional pattern name, but the selected pattern resource is not validated.
  - `GraphicsEvent::ShadingSeen` records a `sh` resource name without resolving or validating the shading dictionary.
  - `ColourRestriction::UncolouredTilingPattern` already gives the graphics interpreter an execution mode where colour-setting operators are ignored inside uncoloured pattern cells.
- **Implications**:
  - The feature belongs primarily in `src/graphics`, with optional reader bridge helpers for loaded indirect resources.
  - Pattern resource validation can be added to colour operator and `sh` handling without changing the content parser.
  - Tiling pattern cell interpretation can reuse the existing graphics interpreter with restricted colour mode.

### Pattern and shading dictionary scope
- **Context**: Requirements `0.1` through `0.17` cover Pattern colour spaces, Type 1 tiling patterns, Type 2 shading patterns, the `sh` operator, common shading dictionaries, and shading types 1 through 7.
- **Sources Consulted**:
  - `spec/extracted/8.7-patterns.spec.txt`
  - `.kiro/specs/pdf-patterns/requirements.md`
  - `.kiro/specs/pdf-colour-spaces/requirements.md`
  - `.kiro/specs/pdf-content-streams/design.md`
- **Findings**:
  - A Pattern resource is either a Type 1 tiling pattern stream or a Type 2 shading pattern dictionary.
  - Tiling pattern validation is structural: `PatternType`, `PaintType`, `TilingType`, `BBox`, nonzero `XStep` and `YStep`, `Resources`, and optional `Matrix`.
  - Shading pattern validation wraps a shading dictionary plus optional pattern matrix and ExtGState dictionary.
  - Direct `sh` uses a named `Shading` resource and ignores current colour; the same shading dictionary embedded in a Type 2 pattern is interpreted in pattern space instead.
  - Shading types 4 through 7 are stream dictionaries whose decoded bytes are mesh data, not ordinary content streams.
- **Implications**:
  - Model patterns and shadings as PDF resource definitions, not as rendered pixels.
  - Reuse existing colour-space parsing for shading `ColorSpace`, while explicitly forbidding Pattern colour space there.
  - Decode mesh streams only enough to validate bit packing, counts, flags, and required records. Do not rasterize meshes.

### External dependency verification
- **Context**: Discovery rules require checking new dependencies.
- **Sources Consulted**:
  - `.kiro/steering/tech.md`
  - Existing `moon.pkg` files under `src/`
  - `src/filters/pipeline.mbt`
- **Findings**:
  - Project steering requires standard-library-only implementation.
  - Existing local packages provide all needed contracts: `objects`, `content`, `filters`, and `graphics`.
  - `filters.decode_stream` already decodes PDF stream filters. A small graphics-local MSB bit reader is sufficient for shading mesh structural validation because the existing bit readers are package-private.
- **Implications**:
  - No third-party graphics, PDF, colour, or mesh library is introduced.
  - Native and wasm targets remain compatible.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Keep patterns as raw names | Continue storing only `ColourValue.pattern` and `ShadingSeen` names | Minimal code change | Does not validate Pattern resources, tiling dictionaries, shading dictionaries, or `sh` operands | Rejected |
| Add structural pattern domain inside `graphics` | Parse Pattern and Shading resources into typed models and events | Preserves existing package boundary, supports tests, avoids rendering | Adds public graphics API and mesh validation logic | Selected |
| Add a rendering engine | Paint tiling cells and gradients to pixels | Closest to visual output | Violates product non-goals and requires functions, fonts, images, transparency, and device colour management | Rejected |
| Use an external PDF or graphics library | Delegate pattern and shading interpretation | Potentially broad feature coverage | Conflicts with no external dependency policy and target compatibility | Rejected |

## Design Decisions

### Decision: Model pattern resources structurally
- **Context**: Clause 8.7 defines pattern and shading dictionaries, but project steering keeps rendering out of the current phase.
- **Alternatives Considered**:
  1. Render tiling cells and gradients immediately.
  2. Store raw PDF dictionaries only.
  3. Parse and validate structural models while preserving raw resource references where downstream domains are deferred.
- **Selected Approach**: Add typed `PatternResource`, `TilingPattern`, `ShadingPattern`, and `Shading` models that validate required entries, defaults, dimensions, colour-space restrictions, and stream byte packing. Rendering and final colour output stay out of scope.
- **Rationale**: This gives downstream renderers a reliable parsed contract while keeping the current library parser-first and device-independent.
- **Trade-offs**: Function values, colour conversion, transparency, text, image masks, and XObject execution still need later specs.
- **Follow-up**: Rendering specs must revalidate the pattern models before using them for pixels.

### Decision: Resolve resources without reversing dependencies
- **Context**: `graphics` cannot import `reader`, but many PDF resources are indirect objects.
- **Alternatives Considered**:
  1. Let `graphics` load indirect Pattern and Shading resources.
  2. Reject all indirect Pattern and Shading resources.
  3. Let `graphics` validate direct resources and expose indirect references as unresolved sources; add reader-owned helpers for loaded resources.
- **Selected Approach**: `graphics` parses direct dictionaries and streams and records indirect resource references. `reader` may provide page-level helpers that load resource objects and call the graphics parsers.
- **Rationale**: This preserves the existing `objects`, `content`, `graphics`, `reader` dependency direction.
- **Trade-offs**: Pure `graphics.interpret_content` cannot fully validate indirect pattern resources without a caller-supplied loaded resource map.
- **Follow-up**: Reader integration tasks must decide how much page-level resource validation to expose without changing the content parser.

### Decision: Reuse colour and graphics state contracts
- **Context**: Pattern selection is expressed through Pattern colour spaces and `SCN` or `scn`, while uncoloured pattern cell interpretation ignores colour operators.
- **Alternatives Considered**:
  1. Add a separate pattern interpreter independent of graphics state.
  2. Extend existing colour operator handling and graphics interpretation events.
- **Selected Approach**: Extend colour operator handling to validate pattern resources when available, add explicit pattern selection events, and reuse `ColourRestriction::UncolouredTilingPattern` when interpreting uncoloured tiling pattern content streams.
- **Rationale**: This avoids duplicate graphics-state behavior and aligns with prior colour-space design.
- **Trade-offs**: `GraphicsState` and `GraphicsEvent` public shapes may change and require `moon info` review.
- **Follow-up**: Tests must cover coloured tiling, uncoloured tiling with underlying components, and shading pattern selection paths.

### Decision: Decode mesh streams for conformance, not geometry output
- **Context**: Shading types 4 through 7 define packed mesh data with edge flags, coordinates, components, and implicit patch state.
- **Alternatives Considered**:
  1. Store mesh streams without reading bytes.
  2. Fully tessellate and shade meshes.
  3. Decode records enough to validate bit widths, decode-array shape, complete records, and edge flag rules.
- **Selected Approach**: Add a structural mesh data parser that produces compact summaries and raises errors for malformed packing or impossible record sequences.
- **Rationale**: Requirements include mesh stream validity, but rasterization is not part of this phase.
- **Trade-offs**: Downstream renderers may need to re-read or extend mesh data for tessellation quality and colour interpolation.
- **Follow-up**: Performance tests should bound allocations for large mesh streams.

## Risks & Mitigations
- Indirect pattern resources can hide malformed dictionaries from pure graphics interpretation - provide reader-owned validation helpers and make unresolved references explicit in events.
- Mesh stream validation can become a renderer - keep output to structural summaries and do not compute pixels, scan conversion, or colour interpolation.
- Shading function validation can pull in clause 7.10 too early - preserve function objects structurally and validate only presence, array shape, and Indexed colour-space restrictions in this spec.
- Pattern cell interpretation can recursively encounter patterns or XObjects - keep recursive execution out of boundary and rely on resource summaries/events.
- Public graphics API churn can break reader tests - regenerate `pkg.generated.mbti` and run `moon check`, targeted `moon test`, and `moon info` during implementation.

## References
- `spec/extracted/8.7-patterns.spec.txt` - local ISO 32000-2 pattern and shading extraction.
- `.kiro/specs/pdf-patterns/requirements.md` - canonical requirements for this design.
- `.kiro/specs/pdf-colour-spaces/design.md` - existing Pattern colour-space and colour operator boundary.
- `.kiro/specs/pdf-graphics/design.md` - existing graphics interpreter and event boundary.
- `.kiro/specs/pdf-content-streams/design.md` - upstream content resource and operator parsing boundary.
- `.kiro/steering/product.md` - parser-first product scope and rendering non-goals.
- `.kiro/steering/tech.md` - MoonBit tooling, standard-library-only dependency policy, and package conventions.
- `.kiro/steering/structure.md` - repository layout and dependency direction.
