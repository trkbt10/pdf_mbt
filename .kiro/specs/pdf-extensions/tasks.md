# Implementation Plan

- [x] 1. Establish extension reader foundations
- [x] 1.1 Add extension-specific diagnostics and parse context
  - Add a reader-layer extension diagnostic that can report the Catalog object, the developer prefix when known, and a concise malformed-structure or version-policy reason.
  - Carry the header version, optional Catalog version, and Catalog object identity through extension parsing without loading any indirect objects inside the extension tree.
  - Keep existing catalog, page, action, form, multimedia, structure, and low-level reader errors unchanged.
  - Completed when malformed present extension metadata can be reported as an extension-specific document error with enough context to identify the violated rule.
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6_
  - _Boundary: ExtensionDiagnostics_

- [x] 1.2 (P) Define public extension metadata models
  - Represent the outer Extensions aggregate, exact developer prefix names, ordered developer entries per prefix, parsed base versions, extension levels, optional URL bytes, optional revision bytes, raw developer dictionaries, and raw prefix values.
  - Preserve unknown prefix names and raw dictionary data without asserting registry membership or interpreting developer-defined behavior.
  - Completed when callers can inspect all clause 7.12 metadata and raw payload identity from typed reader values without any external dependency.
  - _Requirements: 0.1, 0.2, 0.3, 0.6_
  - _Boundary: ExtensionModel_

- [x] 2. Implement extension parsing and validation policies
- [x] 2.1 Parse and compare extension version names
  - Parse BaseVersion and Catalog Version names as two integer components separated by a single period byte, never as floating-point values.
  - Compare parsed BaseVersion values against the file header version and optional Catalog Version value.
  - Provide a version-policy decision for PDF 2.0-only array, URL, and ExtensionRevision syntax.
  - Completed when valid version names produce comparable version pairs and invalid syntax or too-new BaseVersion values raise extension diagnostics.
  - _Requirements: 0.4_
  - _Boundary: ExtensionVersionPolicy_

- [x] 2.2 Parse developer extension dictionaries
  - Validate optional developer Type as the direct name DeveloperExtensions when present.
  - Require direct BaseVersion names and direct ExtensionLevel integers, and parse optional URL and ExtensionRevision as direct byte-preserving strings.
  - Reject indirect, missing, or wrong-typed known developer entries without resolving references.
  - Completed when a valid developer dictionary produces a typed developer entry and each required-entry or directness violation fails deterministically.
  - _Depends: 2.1_
  - _Requirements: 0.3, 0.4, 0.6_
  - _Boundary: ExtensionDirectValidator_

- [x] 2.3 Parse the outer Extensions dictionary and prefix forms
  - Treat a present Extensions value as a direct dictionary and validate optional outer Type as the direct name Extensions.
  - Treat every non-Type key as an exact developer prefix and accept either one direct developer dictionary or, when version policy permits, an array of direct developer dictionaries.
  - Preserve the raw outer dictionary and raw prefix values while rejecting indirect prefix values, non-dictionary array members, and malformed prefix payloads.
  - Completed when single-dictionary and PDF 2.0 array forms both produce ordered prefix groups while malformed outer or prefix values raise extension diagnostics.
  - _Depends: 2.1, 2.2_
  - _Requirements: 0.1, 0.2, 0.3, 0.6_
  - _Boundary: ExtensionDirectValidator_

- [x] 2.4 Validate extension level ordering and PDF 2.0-only entries
  - Check that array entries sharing the same prefix and BaseVersion have monotonically increasing ExtensionLevel values in array order.
  - Apply the established version-policy decision to reject array form, URL, and ExtensionRevision when the document context does not allow PDF 2.0 syntax.
  - Leave registry membership, URL reachability, and developer-specific extension semantics to callers.
  - Completed when repeated prefix arrays enforce ordering and version gates without changing raw metadata retention.
  - _Depends: 2.1, 2.2, 2.3_
  - _Requirements: 0.2, 0.3, 0.5, 0.6_
  - _Boundary: ExtensionDirectValidator_

- [x] 3. Integrate Catalog access and public API surface
- [x] 3.1 Expose optional document-level extension access
  - Return absence when the Catalog has no Extensions entry.
  - Parse a present Catalog Extensions entry using the file header version and optional Catalog Version value as validation context.
  - Raise extension diagnostics for malformed present metadata while preserving existing raw Catalog entry access and lazy page traversal behavior.
  - Completed when a document caller can request extension metadata and receive absence, typed values, or an extension error according to the Catalog state.
  - _Depends: 2.1, 2.2, 2.3, 2.4_
  - _Requirements: 0.1, 0.2, 0.4_
  - _Boundary: ExtensionAccess, CatalogExtensionHelpers_

- [x] 3.2 Regenerate and review the reader public interface
  - Regenerate the reader package interface after adding the extension models, accessor, and diagnostic variant.
  - Review that public additions are limited to the extension metadata API and that lower object, lexer, parser, filter, and CLI packages remain unchanged.
  - Completed when the generated interface diff contains only the intended reader-layer extension additions and no new non-standard dependency appears.
  - _Depends: 3.1_
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6_
  - _Boundary: ExtensionAccess, ExtensionModel, ExtensionDiagnostics_

- [x] 4. Validate extension behavior with focused tests
- [x] 4.1 Add valid dictionary and array coverage
  - Cover the minimal single-prefix dictionary form and verify prefix, BaseVersion, ExtensionLevel, raw developer dictionary, and raw outer dictionary preservation.
  - Cover the PDF 2.0 array form with repeated ISO_ prefix entries and verify ordered developer entries, URL bytes, and ExtensionLevel ordering.
  - Completed when valid clause 7.12 examples parse into typed metadata with observable raw payload retention.
  - _Depends: 2.1, 2.2, 2.3, 2.4, 3.1_
  - _Requirements: 0.1, 0.2, 0.3, 0.5, 0.6_
  - _Boundary: ExtensionAccess tests, ExtensionDirectValidator tests_

- [x] 4.2 Add malformed structure and directness coverage
  - Cover invalid outer Type, invalid developer Type, missing BaseVersion, missing ExtensionLevel, wrong scalar types, and non-dictionary prefix payloads.
  - Cover indirect Extensions values, indirect prefix values, indirect developer entries, indirect known entries, and indirect array members.
  - Completed when every malformed direct-object or required-entry case raises the extension diagnostic instead of being silently accepted or resolved.
  - _Depends: 2.2, 2.3, 3.1_
  - _Requirements: 0.1, 0.2, 0.3, 0.6_
  - _Boundary: ExtensionDirectValidator tests_

- [x] 4.3 Add version-policy and document integration coverage
  - Cover version-name tuple parsing, BaseVersion greater than the header version, BaseVersion greater than Catalog Version, and PDF 2.0-only syntax in a document below PDF 2.0.
  - Open minimal PDF fixtures through the document facade and request extensions from real Catalog metadata.
  - Verify ordinary page-count access still works for a fixture with valid Extensions metadata and no extension parsing path changes page traversal.
  - Completed when document-level tests prove version checks, optional Catalog absence, malformed present metadata, and existing page access behavior together.
  - _Depends: 2.1, 2.4, 3.1_
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6_
  - _Boundary: ExtensionAccess tests, ExtensionVersionPolicy tests_

- [x] 5. Run final MoonBit validation
  - Run formatting, type checking, targeted reader tests, the full test suite, and public API generation.
  - Inspect validation output for unintended lower-layer API changes, dependency changes, eager indirect loading, URL access, or extension behavior execution.
  - Completed when validation commands pass and the implementation remains limited to typed read access for Catalog Extensions metadata.
  - _Depends: 3.2, 4.1, 4.2, 4.3_
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6_
  - _Boundary: ExtensionAccess, ExtensionModel, ExtensionDirectValidator, ExtensionVersionPolicy, ExtensionDiagnostics_
