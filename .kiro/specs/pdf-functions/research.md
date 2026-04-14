# Research & Design Decisions

## Summary
- **Feature**: `pdf-functions`
- **Discovery Scope**: Extension / Integration-focused discovery
- **Key Findings**:
  - Existing colour, pattern, shading, transparency, and rendering designs preserve PDF functions as raw `PdfObject` values; clause 7.10 should become a dedicated typed domain that downstream packages can consume without moving evaluation into `graphics`.
  - Type 0 and Type 4 functions are stream-backed and need decoded stream bytes, but `PdfStream.data` remains raw by project contract. The new function layer should depend on `filters.decode_stream` and own any bit reader or calculator scanner needed for function semantics.
  - The project can implement all required function types with MoonBit standard library plus existing local packages. No external PostScript, PDF, numerical, or colour-management dependency is needed.

## Research Log

### Existing function usage and integration points
- **Context**: Clause 7.10 functions are referenced by colour spaces, shadings, transparency soft masks, transfer functions, halftones, and rendering parameters.
- **Sources Consulted**:
  - `src/graphics/colour_space.mbt`
  - `src/graphics/pattern_shading.mbt`
  - `src/graphics/soft_mask.mbt`
  - `src/rendering/device.mbt`
  - `.kiro/specs/pdf-colour-spaces/design.md`
  - `.kiro/specs/pdf-patterns/design.md`
  - `.kiro/specs/pdf-rendering/design.md`
  - `.kiro/specs/pdf-transparency/design.md`
- **Findings**:
  - `SeparationParams.tint_transform`, `DeviceNParams.tint_transform`, shading `Function` entries, soft-mask transfer functions, transfer function refs, and halftone spot functions are currently raw objects or provider placeholders.
  - `graphics` must remain device-independent and must not import `reader`.
  - `rendering` is the device-dependent consumer, but function semantics are reusable outside rendering and should not be owned by rendering.
- **Implications**:
  - Add a new `src/functions` package with a public parser, typed function model, and evaluator.
  - Update consumers to depend on typed function contracts where direct objects are available, while preserving unresolved indirect references until `reader` materializes them.
  - Revalidate public APIs in `graphics`, `rendering`, and `reader` when raw function fields are narrowed to `@functions` types.

### Function dictionary and stream semantics
- **Context**: Requirements `0.1` through `0.4` define common function dictionary entries, sampled functions, exponential interpolation functions, and stitching functions.
- **Sources Consulted**:
  - `spec/extracted/7.10-functions.spec.txt`
  - `.kiro/specs/pdf-functions/requirements.md`
  - `src/objects/types.mbt`
  - `src/filters/pipeline.mbt`
- **Findings**:
  - `FunctionType`, `Domain`, and sometimes `Range` are common to all function dictionaries. Type 0 and Type 4 require `Range`.
  - Type 0 sample values are a high-order-bit-first stream with no byte padding between values. Existing graphics mesh bit readers are package-private, so `src/functions` needs its own MSB bit reader.
  - Type 2 output count is inferred from `C0` and `C1`; Type 3 output count is inferred from the selected subfunction unless `Range` is present.
  - Type 3 can contain indirect subfunctions; evaluating a stitching function requires those references to be materialized.
- **Implications**:
  - The parser should produce `FunctionSource::IndirectFunction` for unresolved references rather than importing `reader`.
  - Evaluation validates input arity, clips input to `Domain`, applies type-specific evaluation, and clips output to `Range` when present.
  - `FunctionLimits` should bound sample table multiplication, decoded stream bytes, recursion depth, and calculator stack growth as implementation limits allowed by the PDF specification.

### Type 4 calculator subset
- **Context**: Requirements `0.5` and `0.6` define Type 4 calculator functions as a small PostScript-like expression language.
- **Sources Consulted**:
  - `spec/extracted/7.10-functions.spec.txt`
  - `src/lexer/classifier.mbt`
  - `src/lexer/lexer.mbt`
  - `.kiro/specs/pdf-objects/research.md`
- **Findings**:
  - Existing PDF lexical scanning does not treat braces as ordinary object delimiters because braces belong to Type 4 calculator syntax, not general PDF object parsing.
  - The calculator language has no arrays, strings, procedures, variables, or names beyond the allowed operator names. Curly-brace blocks are syntactic conditional blocks only.
  - A full PostScript interpreter is explicitly unnecessary; a function-local scanner, block parser, and stack evaluator cover the required operator list.
- **Implications**:
  - Add `calculator_token.mbt`, `calculator_parser.mbt`, and `calculator_eval.mbt` under `src/functions`.
  - The evaluator should model stack values as a discriminated union of numbers and booleans, with integer-only checks for bitwise operators where PostScript semantics require integers.
  - Unsupported names, composite syntax, unbalanced braces, stack underflow, type mismatch, and remaining invalid output arity become `PdfFunctionError` diagnostics.

### Dependency and compatibility check
- **Context**: The design introduces a new reusable package and may affect existing downstream package imports.
- **Sources Consulted**:
  - `.kiro/steering/tech.md`
  - `.kiro/steering/structure.md`
  - `src/*/moon.pkg`
  - `src/filters/pipeline.mbt`
- **Findings**:
  - Steering requires MoonBit, standard-library-only implementation, independently testable layers, and no reader import from semantic packages.
  - `src/filters` already imports only `objects` and exposes `decode_stream`.
  - `src/graphics` already imports `filters`; adding an import of `functions` keeps dependency direction downstream from low-level function semantics to graphics semantics.
- **Implications**:
  - `src/functions/moon.pkg` may import `moonbitlang/core/math`, `objects`, and `filters`.
  - `src/graphics`, `src/rendering`, and `src/reader` may import `src/functions` where direct function parsing or evaluation is needed.
  - No external runtime prerequisite or network dependency is introduced.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Keep raw function objects | Preserve functions as `PdfObject` and leave evaluation to each consumer | Minimal change | Duplicates logic, cannot enforce common clipping or Type 4 syntax, keeps renderer providers under-specified | Rejected |
| Put function evaluation in `graphics` | Add function parsing and evaluation inside existing graphics package | Close to shading and colour usage | Makes functions a graphics-only concern and couples non-graphics users to graphics | Rejected |
| Dedicated `src/functions` package | Parse, validate, and evaluate clause 7.10 functions in a reusable package | Clear ownership, no reader dependency, reusable by colour, pattern, transparency, and rendering | Requires public API changes in consumers that currently store raw objects | Selected |
| External PostScript or PDF library | Delegate Type 4 and function evaluation | Potentially broad coverage | Violates no external dependency policy and over-scopes the required calculator subset | Rejected |

## Design Decisions

### Decision: Own PDF functions in a dedicated package
- **Context**: Functions are common data structures used by several PDF domains, not graphics-only resources.
- **Alternatives Considered**:
  1. Keep every consumer responsible for raw function parsing.
  2. Add function evaluation to `src/graphics`.
  3. Add `src/functions` as a reusable low-level semantic package.
- **Selected Approach**: Create `src/functions` with typed models, parser, evaluator, errors, limits, and tests. Consumers import it when they need typed function semantics.
- **Rationale**: This follows the existing package-per-domain layout and keeps device-independent graphics and device-dependent rendering from owning shared clause 7.10 behavior.
- **Trade-offs**: Existing public fields that currently expose raw function objects may need migration and `moon info` review.
- **Follow-up**: Implementation tasks should update graphics, rendering, and reader integration only where direct function typing is needed by current requirements.

### Decision: Parse structurally and evaluate through one contract
- **Context**: Common domain/range clipping applies to all function types, while each function type has specific parameters and evaluation rules.
- **Alternatives Considered**:
  1. Provide separate public evaluators per function type only.
  2. Expose one `PdfFunction::evaluate` contract that dispatches to type-specific evaluators.
- **Selected Approach**: Parse each function into a typed variant and expose a shared evaluation contract that enforces arity, domain clipping, type-specific evaluation, range clipping, and output arity validation.
- **Rationale**: A shared contract prevents downstream consumers from forgetting common clipping and dimensionality rules.
- **Trade-offs**: Type-specific diagnostics must still name the failing function type and field.
- **Follow-up**: Unit tests should prove common clipping once and add representative per-type cases.

### Decision: Materialize indirect functions outside `src/functions`
- **Context**: Function dictionaries and Type 3 subfunctions can be indirect references, but `src/functions` must not load document objects.
- **Alternatives Considered**:
  1. Import `reader` from `functions`.
  2. Reject all indirect functions.
  3. Preserve unresolved references and let `reader` or callers materialize them before evaluation.
- **Selected Approach**: `parse_function_object` returns `FunctionSource::IndirectFunction` for references. Evaluation requires a direct `PdfFunction`; unresolved references raise a typed error. `reader` may add helper APIs that load indirect function objects and call the function parser.
- **Rationale**: This preserves lazy loading and dependency direction while keeping failure explicit.
- **Trade-offs**: Pure graphics interpretation cannot evaluate unresolved function references without caller-supplied materialization.
- **Follow-up**: Reader integration should focus on page and resource paths that already load colour, pattern, shading, transparency, or rendering resources.

### Decision: Implement Type 4 as a bounded calculator, not PostScript
- **Context**: The PDF Type 4 subset excludes composite objects, procedures, variables, and names beyond the allowed operator list.
- **Alternatives Considered**:
  1. Reuse the general PDF lexer.
  2. Build a complete PostScript interpreter.
  3. Build a function-local scanner, block parser, and stack evaluator for the allowed subset.
- **Selected Approach**: Implement a calculator-specific parser that recognizes numbers, booleans, operators, comments, and curly-brace conditional blocks, then evaluates the allowed operator list with explicit stack limits.
- **Rationale**: This satisfies requirements without broadening PDF object parsing or importing a PostScript runtime.
- **Trade-offs**: Unsupported PostScript syntax is rejected even if some producers include non-conforming extensions.
- **Follow-up**: Tests should cover every listed operator category and rejection of variables, strings, arrays, and unbalanced blocks.

### Decision: Use explicit implementation limits
- **Context**: Sampled functions can be high-dimensional and Type 4 programs can grow stack and recursion depth.
- **Alternatives Considered**:
  1. Allocate based only on PDF declarations.
  2. Add configurable `FunctionLimits` and raise `LimitExceeded` diagnostics.
- **Selected Approach**: Define default limits for decoded bytes, sample count, dimensions, recursion depth, calculator tokens, stack depth, and loop-free instruction count.
- **Rationale**: PDF allows implementation limits; explicit limits avoid overflow and denial-of-service behavior while keeping defaults reviewable.
- **Trade-offs**: Extremely large but technically valid functions may fail unless the caller raises limits.
- **Follow-up**: Performance tests should assert overflow detection and large-table guard behavior.

## Risks & Mitigations
- Sample table product overflow can corrupt Type 0 evaluation - compute dimensions through checked multiplication and compare with `FunctionLimits`.
- Type 4 stack semantics can drift from the allowed subset - keep operator dispatch table explicit and test every operator named in `0.6`.
- Indirect subfunctions can make Type 3 evaluation appear to work structurally but fail at runtime - preserve `IndirectFunction` explicitly and make evaluation errors actionable.
- Downstream public API churn can break graphics, rendering, and reader tests - update imports and regenerate `pkg.generated.mbti` with `moon info`.
- Floating-point edge cases in `pow`, `sqrt`, `ln`, `log`, `idiv`, and `mod` can be underspecified by extraction - validate domain preconditions and return typed evaluation failures instead of silent NaN propagation.

## References
- `spec/extracted/7.10-functions.spec.txt` - Local ISO 32000-2 function extraction used as the primary project source.
- `.kiro/specs/pdf-functions/requirements.md` - Canonical requirements for this design.
- `.kiro/specs/pdf-colour-spaces/design.md` - Existing tint-transform and colour-space integration boundary.
- `.kiro/specs/pdf-patterns/design.md` - Existing shading Function fields and deferred function evaluation boundary.
- `.kiro/specs/pdf-rendering/design.md` - Existing renderer provider and transfer-function integration boundary.
- `.kiro/specs/pdf-transparency/design.md` - Existing soft-mask transfer-function boundary.
- `.kiro/steering/product.md` - Parser-first product scope and rendering non-goals.
- `.kiro/steering/tech.md` - MoonBit tooling, standard-library-only dependency policy, and package conventions.
- `.kiro/steering/structure.md` - Repository layout and dependency direction.
