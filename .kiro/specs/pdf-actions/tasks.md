# Implementation Plan

- [x] 1. Establish action parsing foundations
- [x] 1.1 Add action diagnostics and source ownership metadata
  - Add reader-layer action diagnostics that report a source object when available, the action name when known, and a concise malformed-structure reason.
  - Represent owner context for Catalog, Page, annotation, outline, form-field, presentation, and raw-object action sources.
  - Preserve existing navigation and annotation error categories so only action-specific parsing failures use the new action diagnostics.
  - Done when malformed present action objects can be reported without changing existing raw action hand-off behavior.
  - _Requirements: 0.1, 0.2, 0.3_

- [x] 1.2 Define public structural action models and raw boundary values
  - Represent common action dictionary data, including optional type, required action name, recursive next actions, source identity, and raw dictionary retention.
  - Represent every standard action type as an inspectable structural variant, including unknown action names.
  - Preserve adjacent-domain payloads as raw PDF objects for files, form data, media, scripts, optional content groups, 3D views, and RichMedia commands.
  - Done when the public reader interface can expose all standard action kinds without any execution callback, mutation hook, or external-effect API.
  - _Requirements: 0.2, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.20, 0.21_

- [x] 1.3 Build common action dictionary resolution and recursion handling
  - Resolve direct and indirect action dictionaries lazily through the existing document loader.
  - Validate common dictionary fields, including optional `/Type /Action`, required name-valued `/S`, and valid `Next` shapes.
  - Parse `Next` as absent, a single action, or an ordered array of actions, with indirect-object cycle detection.
  - Treat unknown action names as successful structural values when common fields are valid.
  - Done when a generic caller can parse a valid recursive action tree and invalid common shapes fail deterministically.
  - _Requirements: 0.2, 0.4_

- [x] 1.4 Validate common action parsing behavior
  - Add focused reader tests for absent and valid type entries, missing or non-name action names, unknown action names, direct `Next`, array `Next`, indirect `Next`, and cycle failures.
  - Verify raw dictionaries and source object identities survive common parsing.
  - Done when the targeted tests pass and each malformed common case raises an action-specific or cycle diagnostic.
  - _Requirements: 0.2, 0.4_

- [x] 2. Implement action-kind parsers behind isolated boundaries
- [x] 2.1 (P) Add navigation-related action parsing
  - Parse local Go-To actions, including required destination values and optional structure destinations.
  - Parse remote and embedded Go-To actions while preserving raw file specifications, new-window flags, and recursive target dictionary paths.
  - Parse GoToDp and Thread action operands as structural references or selectors without opening external documents.
  - Include focused tests for required operands, malformed operands, raw payload retention, and embedded target cycle rejection.
  - Done when these action kinds can be parsed through boundary-local helpers with typed navigation values and retained raw adjacent payloads.
  - _Requirements: 0.5, 0.6, 0.7, 0.8, 0.10_
  - _Boundary: DestinationActionParser_
  - _Depends: 1.1, 1.2, 1.3_

- [x] 2.2 (P) Add external-effect and form action parsing
  - Parse Launch actions, including file specifications, platform-specific launch parameter dictionaries, and new-window flags without launching anything.
  - Parse URI actions with byte-preserved URI strings and `IsMap` defaults, and parse JavaScript actions with raw script strings or streams.
  - Represent SubmitForm, ResetForm, and ImportData as raw form-action values owned by the action boundary.
  - Include tests that prove file, network, process, print, script, and form side effects are not invoked while payloads are retained.
  - Done when external-effect and form action dictionaries produce structural values only.
  - _Requirements: 0.4, 0.9, 0.11, 0.20_
  - _Boundary: ExternalActionBoundary_
  - _Depends: 1.1, 1.2, 1.3_

- [x] 2.3 (P) Add annotation visibility and named action parsing
  - Parse Hide action targets as raw annotation references, field names, or ordered arrays and apply the default hide flag structurally.
  - Parse Named actions with required named-action operands while allowing nonstandard names as portable structural data.
  - Include tests for required operands, defaults, array target preservation, and malformed target shapes.
  - Done when Hide and Named actions are represented without mutating annotations or navigating pages.
  - _Requirements: 0.14, 0.15_
  - _Boundary: RawBoundaryPolicy_
  - _Depends: 1.1, 1.2, 1.3_

- [x] 2.4 (P) Add legacy media and rendition action parsing
  - Parse Sound action stream operands and playback flags while preserving the sound payload raw.
  - Parse Movie action annotation-or-title targeting, operation defaults, and exclusivity validation.
  - Parse Rendition action operation and script presence rules while preserving rendition, annotation, and script payloads raw.
  - Include tests for required combinations, defaults, malformed combinations, and no playback or script execution side effects.
  - Done when Sound, Movie, and Rendition actions produce structural values only.
  - _Requirements: 0.12, 0.13, 0.17_
  - _Boundary: MediaActionBoundary_
  - _Depends: 1.1, 1.2, 1.3_

- [x] 2.5 Add display, 3D, and RichMedia handler action parsing
  - Parse Transition actions by reusing the existing transition parser for the required transition dictionary.
  - Parse Go-To-3D-View actions with raw target annotation data and supported view selector shapes.
  - Parse Rich-Media-Execute actions with raw target annotation, optional instance, and required command dictionaries.
  - Include tests for required operands, malformed operands, raw retention, and absence of rendering or handler invocation.
  - Done when Trans, GoTo3DView, and RichMediaExecute actions are structurally parsed without display or handler effects.
  - _Requirements: 0.18, 0.19, 0.21_
  - _Boundary: MediaActionBoundary_
  - _Depends: 1.1, 1.2, 1.3_

- [x] 2.6 (P) Add optional-content state action parsing
  - Parse ordered Set-OCG-state operation arrays beginning with `ON`, `OFF`, or `Toggle` operators.
  - Preserve following optional-content group dictionaries or references as raw group operands, including repeated groups and repeated operators.
  - Apply the structural `PreserveRB` default without changing optional-content state.
  - Include tests for valid ordered sequences, repeated operands, malformed leading operands, and default preservation behavior.
  - Done when SetOCGState actions expose ordered operations while leaving all optional-content state unchanged.
  - _Requirements: 0.16_
  - _Boundary: OptionalContentActionParser_
  - _Depends: 1.1, 1.2, 1.3_

- [x] 3. Integrate action sources, triggers, and dispatch
- [x] 3.1 Add Catalog action and URI source accessors
  - Parse Catalog open actions as either existing destination form or typed action form while preserving raw Catalog entry access.
  - Parse Catalog additional-action dictionaries through the owner-specific trigger parser.
  - Expose Catalog URI base data as byte-preserved structural metadata for URI actions.
  - Done when missing optional Catalog action entries return absence and present malformed action entries raise action diagnostics.
  - _Requirements: 0.1, 0.3, 0.11_

- [x] 3.2 Add Page, annotation, outline, presentation, and raw object action adapters
  - Parse typed actions from existing raw Page, annotation, outline, and presentation action hand-off fields on demand.
  - Keep existing raw fields and traversal semantics unchanged for callers that do not request typed actions.
  - Parse caller-supplied raw objects through the same document-owned indirect loading policy.
  - Done when every designed action source can produce typed action metadata without changing existing raw source APIs.
  - _Requirements: 0.1, 0.3_

- [x] 3.3 Add owner-specific additional-action trigger parsing
  - Parse annotation, Page, form-field, and Catalog additional-action dictionaries using only the standard keys for each owner.
  - Preserve unknown trigger keys in the raw dictionary without promoting them to standard trigger slots.
  - Expose activation precedence and page open or close ordering metadata without dispatching viewer events.
  - Done when each owner context returns the expected trigger slots, raw dictionary, and ordering metadata for valid input.
  - _Requirements: 0.3_

- [x] 3.4 Wire action-kind dispatch into the common parser
  - Connect all boundary-local action-kind parsers to the common action-name dispatch path.
  - Ensure recursive `Next` parsing uses the same dispatch behavior for each child action.
  - Preserve action-specific validation failures as action diagnostics with source context.
  - Done when public and package-local action parsing entry points return the same typed kind for each standard action name.
  - _Requirements: 0.2, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.20, 0.21_
  - _Depends: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [x] 3.5 Validate source and trigger integration behavior
  - Add integration tests for Catalog open actions, Catalog URI base, Page additional actions, outline raw actions, annotation raw actions, and raw object parsing.
  - Add trigger tests for annotation mouse and page lifecycle keys, Page open and close keys, form-field keys, and Catalog document lifecycle keys.
  - Verify annotation activation precedence and page lifecycle ordering are metadata only.
  - Done when typed source adapters pass without changing existing navigation, annotation, outline, or presentation tests.
  - _Requirements: 0.1, 0.3, 0.11_

- [x] 4. Validate boundaries, compatibility, and public API
- [x] 4.1 Review generated public reader API and package boundaries
  - Regenerate the reader interface summary and inspect that action models, trigger models, and public accessors are the intended additions.
  - Confirm lower packages do not expose new public APIs for this feature and no non-standard dependency is introduced.
  - Done when the public interface diff is limited to reader-layer action metadata and package dependency direction remains unchanged.
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.20, 0.21_

- [x] 4.2 Add raw-boundary and no-side-effect regression coverage
  - Verify external files, URI strings, scripts, form payloads, sound streams, movie data, rendition data, 3D operands, and RichMedia command data remain raw and byte-preserved where applicable.
  - Verify no parser path opens files, resolves URIs, launches processes, submits forms, runs scripts, plays media, renders transitions, mutates optional content, or invokes handlers.
  - Done when representative security-sensitive actions parse as structural metadata and tests can observe unchanged raw payloads.
  - _Requirements: 0.9, 0.11, 0.12, 0.13, 0.16, 0.17, 0.18, 0.19, 0.20, 0.21_

- [x] 4.3 Add full action-tree and compatibility regression coverage
  - Verify mixed action trees preserve `Next` array order, recursively parse children, and reject indirect cycles.
  - Verify malformed action dictionaries fail only when typed action APIs are requested, preserving lazy reader behavior.
  - Verify existing destination, transition, annotation, outline, and presentation behavior remains compatible.
  - Done when full reader tests pass with action parsing added beside the existing raw hand-off contracts.
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.10, 0.18_

- [x] 4.4 Run final MoonBit validation
  - Run formatting, type checking, full tests, and public API generation for the project.
  - Inspect generated interface and test output for unintended lower-layer or dependency changes.
  - Done when final validation commands complete successfully and the implementation remains ready for the implementation review gate.
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.20, 0.21_
