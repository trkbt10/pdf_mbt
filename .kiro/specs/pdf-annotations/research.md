# Research & Design Decisions

## Summary
- **Feature**: `pdf-annotations`
- **Discovery Scope**: Extension
- **Key Findings**:
  - The existing reader layer already exposes raw `PdfPage::annots()` and owns document/page dictionary interpretation, so annotations fit as a typed `src/reader` extension rather than a new package.
  - Annotation dictionaries span many adjacent domains. The design must type the annotation-owned structural fields while preserving raw hand-off fields for actions, forms, media, redaction execution, 3D, RichMedia, and rendering.
  - Page-level annotation parsing cannot validate cross-page annotation-reference ownership by itself; the design needs a document-level enumeration API for that conformance check.
  - Appearance streams and optional content affect annotation visibility and presentation, but this feature can expose descriptors and deterministic flags without rendering form XObjects or executing viewer behavior.

## Research Log

### Reader integration point
- **Context**: `PdfPage::annots()` currently returns the raw optional Page `Annots` entry.
- **Sources Consulted**: `src/reader/document_structure.mbt`, `src/reader/document_types.mbt`, `src/reader/navigation_common.mbt`, `.kiro/specs/pdf-document-structure/design.md`, `.kiro/specs/pdf-interactive-navigation/design.md`.
- **Findings**:
  - Existing document semantics live in `src/reader` and use `PdfDocumentError` for malformed higher-level structures.
  - Navigation features add focused files such as `destination.mbt`, `articles.mbt`, and `viewer_preferences.mbt` with public `PdfDocument` or `PdfPage` methods.
  - Shared helpers already validate rectangles, colors, names, arrays, indirect object resolution, and cycle conditions.
  - The Page `Tabs` entry is a structural Page value affecting annotation navigation order, but runtime tab traversal belongs to interactive consumers.
- **Implications**: `PdfPage::annotations()` and `PdfDocument::annotations()` should be implemented in `src/reader/annotations.mbt`; `PdfPage::annotation_tab_order()` should report `Tabs` as structure without implementing UI order.

### Requirement breadth and subtype ownership
- **Context**: Requirements 0.1 through 0.29 cover the common annotation dictionary, flags, borders, appearances, markup entries, states, and many standard subtypes.
- **Sources Consulted**: `.kiro/specs/pdf-annotations/requirements.md`, `spec/extracted/12.5-annotations.spec.txt`.
- **Findings**:
  - `Subtype`, `Rect`, common entries, flags, border styles, border effects, appearance dictionaries, markup fields, annotation states, and the subtype-specific entries in 12.5.6 are annotation-owned.
  - 3D and RichMedia are listed as standard annotation types but their detailed semantics are in clause 13, outside this extracted 12.5 feature.
  - Widget annotations overlap with forms, and link/screen/widget annotations overlap with actions.
- **Implications**: The design recognizes all standard subtype names but parses only 12.5-owned fields into annotation models. Adjacent-domain entries remain raw `PdfObject` values with precise field names.

### Appearance and rendering boundary
- **Context**: 12.5.5 defines how appearance streams map into the annotation rectangle and how transparency interacts with page content.
- **Sources Consulted**: `.kiro/specs/pdf-annotations/requirements.md`, `.kiro/specs/pdf-graphics/design.md`, `.kiro/specs/pdf-xobjects-images/design.md`, `src/graphics/form_xobject.mbt`, `src/graphics/optional_content.mbt`.
- **Findings**:
  - The graphics package already models matrices, form XObjects, optional content, and non-rendering graphics interpretation.
  - Rendering an annotation appearance requires a future renderer to compose appearance streams with page content and prior annotations.
  - The annotation feature can validate the appearance dictionary shape and preserve normal, rollover, and down entries without executing them.
- **Implications**: `PdfAnnotationAppearance` is a structural descriptor. It stores stream or subdictionary shapes, selected `AS`, and raw stream references; it does not compute appearance matrices or rendered pixels.

### Optional content and visibility flags
- **Context**: Common annotation entries include `F`, `OC`, `ca`, `CA`, `BM`, and `AP`; flags define screen, print, user interaction, unknown annotation, zoom, and rotation behavior.
- **Sources Consulted**: `src/reader/optional_content.mbt`, `src/graphics/optional_content.mbt`, `.kiro/specs/pdf-xobjects-images/design.md`, `.kiro/specs/pdf-annotations/requirements.md`.
- **Findings**:
  - Optional content evaluation already exists for page graphics, but annotation visibility has additional flag gating.
  - `Hidden` suppresses rendering and interaction, `NoView` suppresses screen display and interaction, `Print` controls print output when appearances exist, and `Invisible` applies to unrecognized annotations without handlers.
  - `NoZoom` and `NoRotate` are coordinate/presentation constraints, not mutations of `Rect`.
- **Implications**: The feature should expose parsed `PdfAnnotationFlags` and lightweight predicate helpers for screen/print/interaction eligibility, while leaving final optional-content and renderer decisions to downstream consumers.

## Architecture Pattern Evaluation

| Option | Description | Strengths | Risks / Limitations | Notes |
|--------|-------------|-----------|---------------------|-------|
| Reader extension | Add typed annotation APIs inside `src/reader` over `PdfPage` | Matches existing document semantics, can load indirect dictionaries, no new dependency direction | Large public model surface in one package | Selected |
| New `src/annotations` package | Move annotation models and parsing to a separate package | Isolates domain concepts | Would need object loading or inverted dependencies, conflicts with current reader-owned document graph | Rejected |
| Raw-only API | Keep returning only `Annots` raw objects | Minimal implementation | Does not satisfy structural validation or subtype coverage | Rejected |
| Rendering-oriented annotations | Parse and execute appearance streams immediately | Closer to viewer behavior | Pulls rendering, forms, optional content, actions, and media into this spec | Rejected |

## Design Decisions

### Decision: Keep annotation parsing in `src/reader`
- **Context**: Annotation arrays are Page entries and annotation dictionaries may be indirect objects.
- **Alternatives Considered**:
  1. Parse annotations in `src/reader`.
  2. Add a standalone annotation package.
- **Selected Approach**: Add `PdfPage::annotations()` and annotation parser files under `src/reader`.
- **Rationale**: `reader` already owns lazy object loading, page identity, document errors, and typed interpretation of Page and Catalog structures.
- **Trade-offs**: The reader public API grows, but dependency direction remains stable and no package needs to import `reader`.
- **Follow-up**: During implementation, keep helpers package-private unless a public contract is required.

### Decision: Add document-level annotation enumeration for ownership validation
- **Context**: 12.5.2 states that a given annotation dictionary is referenced from the `Annots` array of only one page.
- **Alternatives Considered**:
  1. Validate only the current page.
  2. Parse all annotations only through document-level enumeration.
  3. Provide both page-level and document-level APIs.
- **Selected Approach**: Provide both APIs. Page-level parsing stays lazy and local; document-level enumeration performs cross-page duplicate-reference validation.
- **Rationale**: This preserves efficient page-local access while giving conformance-oriented users a way to validate the one-page ownership rule.
- **Trade-offs**: Direct dictionary identity cannot be globally compared; duplicate indirect object ids across pages are detectable and must be rejected.
- **Follow-up**: Tests should cover reused indirect annotation refs across pages and avoid claiming direct dictionary identity checks that the object model cannot prove.

### Decision: Type structural fields and preserve adjacent-domain fields raw
- **Context**: Annotation dictionaries reference actions, destinations, file specifications, sound objects, movie dictionaries, form fields, optional content, 3D, RichMedia, and redaction overlay streams.
- **Alternatives Considered**:
  1. Fully parse every referenced domain.
  2. Preserve all subtype data raw.
  3. Type only annotation-owned structures and keep adjacent-domain values as raw `PdfObject`.
- **Selected Approach**: Option 3.
- **Rationale**: It satisfies 12.5 without absorbing actions, forms, media, renderer, redaction execution, or 3D clauses.
- **Trade-offs**: Some fields are not deeply interpreted until adjacent specs are implemented, but the raw object and exact field context are retained.
- **Follow-up**: Revalidate if `pdf-actions`, `pdf-forms-signatures`, or multimedia specs replace raw hand-off fields with typed contracts.

### Decision: Model appearances as descriptors, not rendered results
- **Context**: Appearance streams are form XObjects and require coordinate mapping, transparency compositing, optional content, and rendering order.
- **Alternatives Considered**:
  1. Render appearance streams during annotation parsing.
  2. Store only raw `AP`.
  3. Validate and expose a typed appearance dictionary descriptor.
- **Selected Approach**: Validate `N`, optional `R`, optional `D`, state subdictionaries, and `AS` selection into a descriptor.
- **Rationale**: This provides reliable structure for downstream renderers while keeping this spec non-rendering.
- **Trade-offs**: Matrix mapping and final visual behavior remain downstream.
- **Follow-up**: Renderer specs must consume `PdfAnnotationAppearance` and page geometry together.

### Decision: Use subtype variants with `Unknown` preservation
- **Context**: PDF annotation types are extensible and interactive processors must handle unrecognized types predictably.
- **Alternatives Considered**:
  1. Reject unknown subtype names.
  2. Collapse unknown subtypes into raw dictionaries only.
  3. Preserve common fields plus `UnknownAnnotation` subtype data.
- **Selected Approach**: Parse common dictionary entries and preserve raw subtype name/data for unknown annotations.
- **Rationale**: This follows the extensibility model while still enforcing common dictionary requirements.
- **Trade-offs**: Unknown subtype behavior is limited to structure and visibility flags.
- **Follow-up**: When new subtype specs are added, convert recognized names to concrete variants without changing common model ownership.

## Risks & Mitigations
- Large subtype surface may produce vague implementation tasks — mitigate with file-level component boundaries and subtype-family test files.
- Adjacent-domain overlap may cause scope creep — mitigate with raw hand-off fields and explicit revalidation triggers.
- Page-local parsing may miss cross-page duplicate references — mitigate with `PdfDocument::annotations()` validation and documented page-local limitations.
- Appearance streams may be mistaken for rendered output — mitigate by naming contracts as descriptors and placing rendering in out-of-boundary sections.
- Indirect annotation cycles or repeated dictionaries may break page traversal — mitigate with bounded object resolution and cycle detection for annotation-owned parent, popup, reply, and appearance references.
- Public model churn is likely when action/forms specs mature — mitigate by keeping raw values alongside any typed hand-off and requiring `moon info` review.

## References
- `.kiro/specs/pdf-annotations/requirements.md` — normative source extracted from ISO 32000-2:2020 clause 12.5.
- `spec/extracted/12.5-annotations.spec.txt` — local extracted clause text used to generate requirements.
- `.kiro/specs/pdf-document-structure/design.md` — reader facade and Page `Annots` boundary.
- `.kiro/specs/pdf-interactive-navigation/design.md` — existing reader-layer structural metadata pattern.
- `.kiro/specs/pdf-graphics/design.md` — non-rendering graphics boundary used by appearance-stream decisions.
- `.kiro/specs/pdf-xobjects-images/design.md` — optional content and form XObject interpretation boundary.
