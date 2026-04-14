# Research & Design Decisions

## Summary
- **Feature**: `pdf-actions`
- **Discovery Scope**: Extension / Complex Integration
- **Key Findings**:
  - The existing `src/reader` package already owns Catalog, Page, outline, annotation, destination, optional-content, transition, and lazy object-loading contracts. Action dictionaries should be parsed as a reader-layer structural extension instead of introducing a new package or changing lower PDF object parsing.
  - Actions overlap with navigation, annotations, forms, file specifications, multimedia, optional content, 3D, RichMedia, and JavaScript. This feature should type the action dictionary grammar and action-owned operands, but it must not execute actions, open files, resolve URIs, run scripts, submit forms, mutate annotations, play media, or render transitions.
  - `Next` action chains and embedded Go-To target dictionaries are recursive object graphs. The design needs bounded indirect-reference traversal, object-id cycle detection, and raw hand-off preservation for adjacent-domain payloads.

## Research Log

### Existing Reader Integration Points
- **Context**: Actions are referenced by Catalog `OpenAction` and `AA`, Page `AA`, outline item `A`, annotation `A` and `AA`, presentation navigation nodes, and future form-field dictionaries.
- **Sources Consulted**:
  - `src/reader/document_types.mbt`
  - `src/reader/catalog.mbt`
  - `src/reader/navigation_common.mbt`
  - `src/reader/destination.mbt`
  - `src/reader/outline.mbt`
  - `src/reader/annotations.mbt`
  - `src/reader/presentation.mbt`
  - `src/reader/optional_content.mbt`
  - `src/reader/document_error.mbt`
  - `src/reader/moon.pkg`
- **Findings**:
  - `PdfDocument` holds private access to `PdfFile` and the validated `PdfCatalog`, so action parsing can lazily load indirect action dictionaries without expanding lower-level public state.
  - `PdfCatalog::entry` already exposes raw `OpenAction`, `AA`, `Names`, and other Catalog values. `PdfPage::entry` and typed annotation models expose raw Page and annotation action values.
  - `PdfDestination` and `PdfTransition` are already parsed in `src/reader`; actions should reuse these contracts for Go-To and transition actions.
  - Existing reader errors separate malformed navigation and annotation structures from low-level reader failures.
- **Implications**:
  - Add action parsing inside `src/reader` and keep the package dependency direction unchanged.
  - Add an action-specific reader diagnostic rather than overloading navigation or annotation errors.
  - Preserve raw values currently exposed by navigation and annotation APIs until typed action accessor methods can wrap them without breaking compatibility.

### ISO 32000-2 Clause 12.6 Action Grammar
- **Context**: Requirements were generated from `spec/extracted/12.6-actions.spec.txt` and cover common action dictionaries, trigger events, and standard action types.
- **Sources Consulted**:
  - `spec/extracted/12.6-actions.spec.txt`
  - `.kiro/specs/pdf-actions/requirements.md`
  - `.kiro/specs/pdf-interactive-navigation/design.md`
  - `.kiro/specs/pdf-annotations/design.md`
  - `.kiro/specs/pdf-forms-signatures/requirements.md`
- **Findings**:
  - Every action dictionary requires an `S` name and may contain optional `Type /Action` and recursive `Next` action dictionaries or arrays.
  - Additional-action dictionaries differ by owner: annotation, Page, form field, and Catalog use different event keys.
  - Standard action types mix parser-owned structure with adjacent-domain effects. For example, `GoTo` can reuse destination parsing, while `Launch`, `URI`, `JavaScript`, `SubmitForm`, media, 3D, and RichMedia are unsafe or out-of-scope to execute in a parser library.
  - `GoToE` target dictionaries are recursive and need cycle validation independent of the main `Next` action graph.
- **Implications**:
  - Model action kind as a discriminated MoonBit enum with exact action subtype data and raw dictionaries.
  - Parse every standard `S` name listed by 12.6.4, including raw boundary variants for form actions whose detailed semantics live in 12.7.
  - Represent trigger dictionaries as typed structural maps and expose ordering metadata without implementing event dispatch.

### Adjacent Spec Boundaries
- **Context**: Action dictionaries reference domains already designed or planned elsewhere in the SDD roadmap.
- **Sources Consulted**:
  - `.kiro/specs/pdf-interactive-navigation/design.md`
  - `.kiro/specs/pdf-interactive-navigation/research.md`
  - `.kiro/specs/pdf-annotations/design.md`
  - `.kiro/specs/pdf-annotations/research.md`
  - `.kiro/specs/pdf-graphics/design.md`
  - `.kiro/specs/pdf-rendering/design.md`
  - `.kiro/specs/pdf-forms-signatures/requirements.md`
- **Findings**:
  - Interactive navigation intentionally stores action dictionaries as raw hand-off values and expects `pdf-actions` to own typed action semantics later.
  - Annotation parsing preserves `A`, `AA`, and media/action fields raw and does not execute annotation behavior.
  - Forms requirements are present but not yet designed, so SubmitForm, ResetForm, ImportData, and form-field additional actions must remain structural or raw at the forms boundary.
  - Rendering, optional content, media playback, 3D artwork, RichMedia handlers, external files, and URI resolution are outside the parser-library phase.
- **Implications**:
  - The action design should be additive: existing raw action fields remain available, and new typed accessors parse raw values on demand.
  - Form, media, URI, JavaScript, file-system, renderer, and handler effects are out of boundary and must be captured as raw payloads plus metadata.
  - Revalidation is required when future forms, file-specification, JavaScript, multimedia, 3D, or RichMedia specs replace raw boundary contracts.

### MoonBit Implementation Constraints
- **Context**: The design must generate concrete MoonBit implementation tasks for the current repository.
- **Sources Consulted**:
  - `.kiro/steering/product.md`
  - `.kiro/steering/tech.md`
  - `.kiro/steering/structure.md`
  - `<local>/.codex/skills/moonbit-agent-guide/SKILL.md`
  - `moon.mod.json`
  - `src/reader/moon.pkg`
- **Findings**:
  - Steering requires standard library only, byte-oriented parsing, lazy indirect-reference resolution, independent package tests, and no PDF generation.
  - MoonBit package files share one namespace, so a cohesive `action_types.mbt` file can carry public action models without changing import paths.
  - Public API changes should be reviewed through `moon info` and reflected only in `src/reader/pkg.generated.mbti`.
- **Implications**:
  - No external dependency or Web research is needed; this feature uses existing local packages and MoonBit standard data structures only.
  - Public action models should use explicit structs and `pub(all) enum` variants so library users can inspect them without unsafe casts.
  - Tests should be white-box focused in `src/reader` for private helper coverage and black-box enough to validate public action accessors.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Keep actions raw only | Leave existing outline, annotation, and presentation action fields as raw `PdfObject` values | Minimal implementation | Does not satisfy typed action dictionary, trigger, and standard action coverage | Rejected |
| New `src/actions` package | Isolate action parsing outside `reader` | Clear domain name | Cannot access private `PdfDocument`, `PdfPage`, object loader, and existing destination helpers without widening public internals or reversing dependencies | Rejected |
| Focused action files inside `src/reader` | Add typed action models, parsers, source accessors, and tests in the existing document facade package | Preserves lazy loading and dependency direction; can reuse destination, annotation, transition, page, and optional-content helpers | Expands `src/reader` public API and needs strict raw hand-off boundaries | Selected |

## Synthesis Outcomes
- **Generalization**: Catalog, Page, annotation, outline, and form-field action entries share the same action dictionary parser. The design defines one recursive action parser and multiple source adapters rather than duplicating per-owner parsing.
- **Generalization**: `Next` action trees and embedded Go-To target dictionaries both require recursive traversal with cycle detection. The design applies one bounded traversal policy with separate context labels and object-id visited sets.
- **Build vs. Adopt**: No external library is adopted. ISO action dictionaries are project-domain PDF object interpretation that must align with existing `PdfObject`, `PdfDictionary`, `PdfName`, `PdfDestination`, `PdfTransition`, `PdfFile`, and `PdfDocumentError` contracts.
- **Simplification**: The design does not introduce an action execution engine, event loop, security prompt system, ECMAScript runtime, URI resolver, file opener, form submission client, media player, renderer, or document mutation layer. It exposes typed structural metadata and raw boundary payloads only.

## Design Decisions

### Decision: Reader-Layer Typed Action Parsing
- **Context**: Actions are reached through reader-owned document structures and need lazy indirect-reference loading.
- **Alternatives Considered**:
  1. Parse actions in lower `objects` or `parser` packages.
  2. Create a new downstream package.
  3. Add cohesive action files to `src/reader`.
- **Selected Approach**: Add action model, parser, trigger, and source accessor files inside `src/reader`.
- **Rationale**: `reader` already owns document-level structure, page access, and adjacent typed metadata. This preserves the dependency direction and avoids exposing private file state.
- **Trade-offs**: `src/reader` grows, so file boundaries and tests must remain explicit.
- **Follow-up**: Run `moon info` during implementation and verify that public API additions are intentional.

### Decision: Parse Actions, Do Not Execute Them
- **Context**: Clause 12.6 describes interactive PDF processor behavior, but this project is a parser library.
- **Alternatives Considered**:
  1. Implement action execution and viewer event dispatch.
  2. Parse structural action dictionaries and expose metadata for downstream consumers.
- **Selected Approach**: Parse common action dictionary fields, trigger dictionaries, and standard action payloads while never performing external effects or document mutation.
- **Rationale**: This satisfies parser-library conformance without absorbing security-sensitive viewer responsibilities.
- **Trade-offs**: Applications must interpret or execute actions outside this library if they choose to do so.
- **Follow-up**: Boundary tests must prove representative actions do not open files, resolve URIs, execute scripts, submit forms, play media, alter optional content, or render transitions.

### Decision: Preserve Raw Boundary Payloads Beside Typed Fields
- **Context**: Many action payloads refer to file specifications, form fields, annotations, media, 3D views, RichMedia commands, optional content groups, and JavaScript scripts.
- **Alternatives Considered**:
  1. Deep-parse every referenced domain now.
  2. Keep only raw action dictionaries.
  3. Type action-owned grammar and store adjacent-domain operands raw.
- **Selected Approach**: Use typed variants for action kinds and action-owned required keys, and preserve adjacent-domain objects in raw fields.
- **Rationale**: The action model becomes useful without conflicting with future forms, file-specification, JavaScript, multimedia, 3D, RichMedia, and rendering specs.
- **Trade-offs**: Some fields remain `PdfObject` until adjacent specs mature.
- **Follow-up**: Revalidate action types when adjacent specs add typed payload contracts.

### Decision: Additive Source Accessors Over Existing Raw Fields
- **Context**: Existing navigation and annotation APIs already expose raw action values.
- **Alternatives Considered**:
  1. Replace raw fields in existing models with `PdfAction`.
  2. Add typed accessors and keep raw fields compatible.
- **Selected Approach**: Add methods that parse Catalog, Page, annotation, outline, and raw action values into `PdfAction` on demand while leaving existing raw fields in place.
- **Rationale**: This avoids breaking existing users and lets implementation migrate call sites gradually.
- **Trade-offs**: Some action data is reachable through both raw and typed paths.
- **Follow-up**: Documentation and tests should mark the typed action accessors as authoritative for 12.6 action semantics.

## Risks & Mitigations
- Recursive `Next` trees and `GoToE` target dictionaries can cycle - mitigate with object-id visited sets, direct recursion guards, and clear `PdfDocumentError::InvalidAction` or `CycleDetected` failures.
- Action execution language may invite scope creep - mitigate with explicit non-goals, raw boundary payloads, and tests proving no side effects.
- Form, JavaScript, URI, multimedia, 3D, and RichMedia details are incomplete in this spec - mitigate by representing their action dictionary entries structurally and preserving raw operands for future specs.
- Existing raw action fields may diverge from typed accessors - mitigate by parsing typed actions directly from the stored raw object and retaining raw dictionaries in the resulting model.
- Public model surface is broad - mitigate with cohesive `pub(all) enum` variants, generated interface review, and per-action-family tests.

## References
- `spec/extracted/12.6-actions.spec.txt` - local ISO 32000-2:2020 clause 12.6 excerpt.
- `.kiro/specs/pdf-actions/requirements.md` - authoritative requirements for this feature.
- `.kiro/specs/pdf-interactive-navigation/design.md` - existing raw action hand-off and destination contracts.
- `.kiro/specs/pdf-interactive-navigation/research.md` - prior boundary decision for actions.
- `.kiro/specs/pdf-annotations/design.md` - existing annotation raw action and additional-action fields.
- `.kiro/specs/pdf-annotations/research.md` - annotation boundary decisions.
- `.kiro/specs/pdf-forms-signatures/requirements.md` - adjacent form-action and field additional-action scope.
- `.kiro/steering/product.md`, `.kiro/steering/tech.md`, `.kiro/steering/structure.md` - project-wide MoonBit, dependency, and parser guidance.
