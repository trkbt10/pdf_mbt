# Implementation Plan

- [x] 1. Establish logical-structure foundations
- [x] 1.1 Add structure-specific diagnostics and reusable reader parsing behavior
  - Add a dedicated logical-structure document error path for malformed mark information, structure roots, elements, namespaces, content references, attributes, and tagged-report inputs.
  - Support bounded indirect-object resolution, cycle reporting, dictionary/name/array/string/number/boolean checks, indirect-reference requirements, and ISO default handling.
  - Preserve raw PDF objects and owner context so malformed producer data can be reported without changing lower parser packages.
  - Done when a minimal logical-structure dictionary can be resolved through shared behavior and malformed required entries report structure-specific diagnostics.
  - _Requirements: 0.1, 0.2, 0.5, 0.10, 0.11_
  - _Boundary: StructureSharedFoundation_

- [x] 1.2 Define raw-preserving logical-structure value models
  - Represent mark information, structure trees, elements, ordered children, content items, parent lookups, role maps, namespaces, attributes, standard type metadata, accessibility properties, and tagged diagnostics as inspectable read-side values.
  - Preserve raw dictionaries, streams, names, byte strings, arrays, object references, associated-file references, schema references, and pronunciation lexicon references.
  - Exclude writer mutation, rendering, text extraction, XML parsing, PDF/UA certification, external file access, and structure repair from the value vocabulary.
  - Done when the public interface can express every designed structure component without requiring component parsers to exist yet.
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.10, 0.11, 0.12, 0.13, 0.14, 1.1, 1.12, 1.15, 1.31, 1.48, 1.49_
  - _Boundary: StructureValueModel_

- [x] 1.3 Create reusable logical-structure fixtures
  - Add package-local fixture builders for catalogs, mark information, structure roots, nested elements, ID trees, parent trees, namespaces, role maps, class maps, content references, attributes, and cycle cases.
  - Include valid and malformed fixture paths that preserve raw object identity and exact byte-string keys.
  - Keep fixture support independent of content rendering and XML/pronunciation parsing.
  - Done when white-box tests can construct direct and indirect logical-structure documents without duplicating setup.
  - _Requirements: 0.1, 0.2, 0.5, 0.8, 0.9, 0.10, 0.12_
  - _Boundary: StructureFixtureSupport_

- [x] 2. Parse catalog mark data and the structure hierarchy
- [x] 2.1 (P) Read mark information and catalog language
  - Interpret absent mark information with ISO defaults for marked, user properties, and suspects.
  - Validate present mark information as a dictionary with boolean flags and preserve the deprecated suspects flag as data.
  - Expose catalog language as the document-level natural-language source without requiring a structure tree.
  - Done when callers can inspect defaulted and present mark information, and malformed present flags fail with structure diagnostics.
  - _Requirements: 0.1, 1.1, 1.49_
  - _Boundary: MarkInfoReader_
  - _Depends: 1.1, 1.2, 1.3_

- [x] 2.2 Resolve the structure tree root and root-level maps
  - Return absence when the catalog has no structure tree root and validate `/Type /StructTreeRoot` when one is present.
  - Normalize root children while preserving root dictionaries, role maps, class maps, namespaces, pronunciation lexicons, associated files, and parent-tree next-key values.
  - Enumerate ID trees and parent trees through existing bounded tree traversal policies with structure-specific errors.
  - Done when a valid root exposes ordered root children and all root-level maps, while malformed required root shapes fail deterministically.
  - _Requirements: 0.1, 0.2, 0.5, 0.10, 0.12, 1.45_
  - _Boundary: StructureTreeReader_
  - _Depends: 1.1, 1.2, 1.3_

- [x] 2.3 Parse structure elements and depth-first logical order
  - Validate structure element dictionaries, required structure type and parent entries, optional identifiers, references, page references, revision numbers, titles, language, accessibility fields, namespaces, and associated files.
  - Normalize element children as child structure elements, MCID integers, marked-content references, object references, or diagnostics for malformed entries.
  - Track visited indirect elements to reject unbounded structural cycles while preserving child order exactly.
  - Done when parsed elements expose a depth-first logical order with raw dictionaries, parent descriptors, ordered children, and element metadata.
  - _Requirements: 0.2, 0.6, 1.7, 1.16, 1.31, 1.48, 1.49_
  - _Boundary: StructureTreeReader_
  - _Depends: 2.2_

- [x] 2.4 Support element identifier lookup and parent relationship validation
  - Compare ID tree keys as exact byte strings and map element identifiers back to parsed structure elements.
  - Validate that parent entries point to the structure tree root or another parsed structure element.
  - Report duplicate, missing, or mismatched identifier and parent relationships through structure diagnostics.
  - Done when identifier lookup returns the expected element for valid IDs and parent mismatches are visible without corrupting traversal order.
  - _Requirements: 0.2, 0.10, 1.7, 1.17_
  - _Boundary: StructureTreeReader_
  - _Depends: 2.3_

- [x] 3. Model structure content items and reverse associations
- [x] 3.1 Parse marked-content identifiers and marked-content references
  - Interpret integer children as MCID content items using the containing element page context.
  - Interpret marked-content reference dictionaries with page overrides, stream references, stream-owner references, and required MCID values.
  - Enforce indirect-reference requirements for page, stream, and stream-owner entries while preserving raw references.
  - Done when element children can identify page-content and non-page-content marked sequences without scanning content streams by default.
  - _Requirements: 0.6, 0.7, 0.8, 1.2, 1.7_
  - _Boundary: StructureContentResolver_
  - _Depends: 2.3_

- [x] 3.2 Parse object references and annotation/form content links
  - Interpret object reference dictionaries with required object references and optional page overrides.
  - Preserve references to annotations, XObjects, widget annotations, link annotations, and form-related content without executing actions or rendering.
  - Model logical sequencing for annotation, link, and form content through structure children.
  - Done when object content items expose their referenced object and logical page context while subtype-specific behavior remains read-only metadata.
  - _Requirements: 0.6, 0.7, 0.9, 1.3, 1.8, 1.22_
  - _Boundary: StructureContentResolver_
  - _Depends: 2.3_

- [x] 3.3 Resolve parent-tree associations for objects and MCIDs
  - Resolve object content items through `StructParent` keys and marked-content streams through `StructParents` arrays indexed by MCID.
  - Validate the parent-tree value shape for object references versus marked-content arrays.
  - Report missing parent-tree entries, out-of-range MCIDs, and mutually exclusive `StructParent`/`StructParents` declarations as diagnostics.
  - Done when callers can look up parents for both whole-object content items and marked-content identifiers.
  - _Requirements: 0.10, 1.7_
  - _Boundary: StructureContentResolver_
  - _Depends: 2.2, 3.1, 3.2_

- [x] 3.4 Report content-item rule diagnostics without eager content scanning
  - Report leaf-content restrictions, form XObject content-item patterns, real-content versus artifact classification, and hidden-content treatment from available structure metadata.
  - Preserve `ReversedChars`, Unicode mapping, word-break, and MCID-existence checks as downstream-context items unless parsed content data is supplied.
  - Keep base structure inspection usable even when the content report contains warnings or unchecked items.
  - Done when the content report separates hard shape errors, structure diagnostics, and downstream-dependent checks.
  - _Requirements: 0.7, 0.8, 1.2, 1.3, 1.4, 1.6, 1.9, 1.10, 1.11_
  - _Boundary: StructureContentResolver_
  - _Depends: 3.1, 3.2, 3.3_

- [x] 4. Resolve roles, namespaces, and standard structure types
- [x] 4.1 Resolve root role maps and custom structure type chains
  - Interpret root role-map entries as name-to-name mappings and follow transitive chains.
  - Preserve original custom roles, terminal custom roles, standard targets, and circular chains without forcing a parse failure.
  - Always apply a role-map entry when it exists, including entries whose source name matches a standard type name.
  - Done when role resolution returns the original type, resolution chain, recognized target when present, and cycle status.
  - _Requirements: 0.3, 1.15, 1.16, 1.46_
  - _Boundary: RoleNamespaceResolver_
  - _Depends: 2.3_

- [x] 4.2 Parse namespaces and namespace role maps
  - Interpret namespace dictionaries, namespace names, optional schema file specifications, and namespace-specific role maps.
  - Support direct role-map targets and role-map targets that identify another namespace dictionary.
  - Apply the default standard namespace when an element has no namespace and validate that explicit namespaces are declared by the structure tree root.
  - Done when namespace declarations and namespace-specific role-map chains are visible with raw schema and target namespace references preserved.
  - _Requirements: 0.4, 0.5, 1.45, 1.46, 1.47_
  - _Boundary: RoleNamespaceResolver_
  - _Depends: 2.2, 2.3_

- [x] 4.3 (P) Classify standard structure type categories
  - Recognize document, grouping, block, sub-block, inline, ruby, warichu, list, table, caption, figure, formula, and artifact standard types.
  - Validate uppercase heading forms and reject malformed heading names such as lowercase, leading-zero, or suffixed variants.
  - Represent context-sensitive categories for types that may be grouping, block, or inline depending on placement.
  - Done when every standard structure name in the requirements maps to a category or a precise unknown result.
  - _Requirements: 1.12, 1.13, 1.14, 1.15, 1.17, 1.18, 1.19, 1.20, 1.21, 1.22, 1.23, 1.24, 1.25, 1.26, 1.27, 1.28, 1.29, 1.30_
  - _Boundary: StandardStructureCatalog_
  - _Depends: 1.2_

- [x] 4.4 Evaluate supplemental standard-type and namespace diagnostics
  - Report supplemental nesting rules for document, grouping, block, inline, ruby, warichu, list, table, caption, figure, formula, artifact, link, annotation, and form structures.
  - Report missing role maps for custom tagged content and namespace membership issues for PDF 1.7, PDF 2.0, MathML, and other namespaces.
  - Keep Annex L and geometry-dependent checks as diagnostics that can be tightened by future specs rather than hard failures.
  - Done when standard-structure diagnostics identify rule category, affected element, and whether the issue is checked, warning-only, or downstream-dependent.
  - _Requirements: 1.15, 1.16, 1.17, 1.18, 1.19, 1.20, 1.21, 1.22, 1.23, 1.24, 1.25, 1.26, 1.27, 1.28, 1.29, 1.30, 1.45, 1.46, 1.47_
  - _Boundary: StandardStructureCatalog, RoleNamespaceResolver_
  - _Depends: 3.2, 4.1, 4.2, 4.3_

- [x] 5. Resolve structure attributes
- [x] 5.1 Parse direct attribute objects and revision-number pairs
  - Interpret direct attributes as dictionaries or streams with required owners and optional namespace-owner references.
  - Parse attribute arrays with optional revision-number pairs and later-entry precedence for duplicate attributes.
  - Preserve deprecated revision-number behavior without making revision mismatch a hard failure.
  - Done when direct attributes expose owner, namespace, revision, raw payload, and ordered precedence.
  - _Requirements: 0.11, 0.13, 1.31, 1.32_
  - _Boundary: AttributeResolver_
  - _Depends: 2.3_

- [x] 5.2 Resolve attribute classes through class maps
  - Interpret class maps from class names to attribute objects or arrays of attribute objects.
  - Parse element class declarations as a single name or arrays with optional revision-number pairs.
  - Apply direct-attribute precedence over class-map attributes for the same attribute.
  - Done when class-map attributes are attached to elements without mutating element-local attribute data.
  - _Requirements: 0.12, 0.13, 1.31, 1.33_
  - _Boundary: AttributeResolver_
  - _Depends: 2.2, 5.1_

- [x] 5.3 Model standard attribute owners, inheritance, and defaults
  - Recognize standard owners, export-format owners, user-property owners, and namespace owners.
  - Apply format-specific, standard direct, class-map, inherited, and default precedence with source provenance.
  - Preserve arbitrary custom attribute values while validating known standard attribute shapes.
  - Done when resolved attributes identify value, owner, source kind, inheritance/default status, and raw origin.
  - _Requirements: 1.32, 1.33, 1.34, 1.35, 1.36, 1.37, 1.38, 1.39, 1.40, 1.41, 1.42, 1.43, 1.44_
  - _Boundary: AttributeResolver_
  - _Depends: 4.3, 5.1, 5.2_

- [ ] 5.4 Parse layout, list, print-field, table, and artifact attribute groups
  - Interpret placement, writing mode, colors, borders, spacing, rectangles, dimensions, alignment, text decoration, ruby, vertical glyph orientation, column, list, print-field, table, and artifact attributes.
  - Preserve values such as `Auto`, `Normal`, unknown extensible names, byte-string identifiers, and raw rectangles.
  - Report known owner misuse and invalid value shapes as attribute diagnostics.
  - Done when each standard attribute group produces typed values or precise diagnostics while unknown custom attributes remain raw.
  - _Requirements: 1.12, 1.13, 1.14, 1.34, 1.35, 1.36, 1.37, 1.38, 1.39, 1.40, 1.41, 1.42, 1.43, 1.44_
  - _Boundary: AttributeResolver_
  - _Depends: 5.3_

- [ ] 5.5 Parse user properties and correlate the mark-information flag
  - Interpret user-property attribute objects with required property arrays, names, values, optional formatted values, and hidden flags.
  - Preserve non-text, non-number, and non-boolean property values without treating them as errors.
  - Report when user properties are present but the document mark information does not advertise them.
  - Done when callers can list user properties and diagnostics can identify mark-information mismatches.
  - _Requirements: 0.1, 0.14, 1.31_
  - _Boundary: AttributeResolver, MarkInfoReader_
  - _Depends: 2.1, 5.1_

- [ ] 6. Resolve accessibility properties and Tagged PDF reports
- [ ] 6.1 Resolve accessibility text properties and effective language
  - Resolve effective language from catalog and structure ancestors while preserving absent-language state.
  - Expose alternate description, replacement text, abbreviation expansion, phoneme, and phonetic alphabet properties on elements.
  - Default the phonetic alphabet to `ipa` only where a phoneme property is in effect, and leave text-string language escape parsing to future consumers.
  - Done when accessibility properties and effective language can be queried for any parsed element with source provenance.
  - _Requirements: 0.2, 1.3, 1.5, 1.10, 1.11, 1.28, 1.29, 1.31, 1.48, 1.49_
  - _Boundary: AccessibilityPropertyResolver_
  - _Depends: 2.1, 2.3, 5.3_

- [ ] 6.2 Produce core Tagged PDF diagnostics
  - Check the tagged mark flag, structure root presence, real content versus artifact declarations, logical order metadata, annotation sequencing, role-map coverage, and namespace membership.
  - Report conformance issues as errors or warnings without blocking raw structure inspection.
  - Preserve references to affected elements, content items, namespaces, and attributes where available.
  - Done when a tagged-report call returns deterministic errors and warnings for core Tagged PDF structure rules.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.6, 1.7, 1.8, 1.15, 1.16, 1.45, 1.46, 1.47_
  - _Boundary: TaggedPdfReport_
  - _Depends: 2.1, 2.4, 3.4, 4.4_

- [ ] 6.3 Add downstream-context and text requirement report items
  - Represent soft-hyphen, Unicode mapping, word-break, reversed-character, MCID existence, text-object placement, and visual rectangle checks as warning or unchecked items when the needed content/font/rendering context is absent.
  - Use accessibility and attribute data to identify where alternate, actual, expansion, and language metadata may satisfy text-related requirements.
  - Keep content-stream scanning and font ToUnicode evaluation outside the default report path.
  - Done when the report clearly distinguishes checked diagnostics from requirements that need external parsed content, font, or rendering context.
  - _Requirements: 1.5, 1.9, 1.10, 1.11, 1.28, 1.29, 1.38, 1.39_
  - _Boundary: TaggedPdfReport, AccessibilityPropertyResolver_
  - _Depends: 6.1, 6.2_

- [ ] 6.4 Aggregate document-level and tree-level reports
  - Provide report generation from either a document or an already parsed structure tree.
  - Return useful diagnostics when a document is marked tagged but has no structure tree.
  - Ensure report generation does not mutate cached data, raw dictionaries, or existing reader state.
  - Done when document-level and tree-level report calls produce equivalent diagnostics for the same parsed structure.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13, 1.14, 1.15, 1.16, 1.17, 1.18, 1.19, 1.20, 1.21, 1.22, 1.23, 1.24, 1.25, 1.26, 1.27, 1.28, 1.29, 1.30, 1.31, 1.32, 1.33, 1.34, 1.35, 1.36, 1.37, 1.38, 1.39, 1.40, 1.41, 1.42, 1.43, 1.44, 1.45, 1.46, 1.47, 1.48, 1.49_
  - _Boundary: TaggedPdfReport_
  - _Depends: 6.2, 6.3_

- [ ] 7. Integrate public reader APIs
- [ ] 7.1 Expose explicit logical-structure access through the reader facade
  - Add public entry points for mark information, document language, optional structure tree access, identifier lookup, parent lookup, role resolution, resolved attributes, accessibility properties, standard-structure diagnostics, and Tagged PDF reports.
  - Keep existing raw catalog, page, annotation, XObject, content, and resource APIs compatible and lazy.
  - Regenerate and review the reader package interface so public additions are limited to the designed logical-structure surface.
  - Done when external callers can use the new read-side APIs and the generated interface diff contains only intended additions.
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.10, 0.11, 0.12, 0.13, 0.14, 1.1, 1.31, 1.48, 1.49_
  - _Boundary: Reader facade, StructureTreeReader, StructureContentResolver, RoleNamespaceResolver, AttributeResolver, StandardStructureCatalog, AccessibilityPropertyResolver, TaggedPdfReport_
  - _Depends: 2.4, 3.4, 4.4, 5.5, 6.4_

- [ ] 7.2 Preserve package boundaries and root re-export policy
  - Confirm no upstream package imports reader and no external dependency is introduced.
  - Update root-level exports only if the project chooses to expose logical-structure APIs from the root package.
  - Preserve ordinary document loading behavior for PDFs without structure trees.
  - Done when package-boundary checks and no-structure smoke paths pass with existing raw APIs unchanged.
  - _Requirements: 0.1, 0.2, 1.1_
  - _Boundary: Reader facade, Package boundary_
  - _Depends: 7.1_

- [ ] 8. Validate logical-structure behavior
- [ ] 8.1 Verify mark information, structure hierarchy, and content associations
  - Cover mark-information defaults and malformed flags, catalog language, root validation, element traversal, ID lookup, parent validation, IDTree, ParentTree, MCID, MCR, OBJR, annotations, and form XObject cases.
  - Include absent optional structures, malformed present structures, cycle cases, parent-tree lookup failures, and exact byte-string identifier comparisons.
  - Done when targeted reader tests prove logical-structure traversal and content association behavior for all base structure requirements.
  - _Requirements: 0.1, 0.2, 0.6, 0.7, 0.8, 0.9, 0.10, 1.1, 1.2, 1.7, 1.8_
  - _Boundary: MarkInfoReader, StructureTreeReader, StructureContentResolver tests_
  - _Depends: 2.4, 3.4_

- [ ] 8.2 (P) Verify role maps, namespaces, and standard structure metadata
  - Cover root role maps, namespace dictionaries, namespace role maps, default and PDF 2.0 standard namespaces, MathML, custom namespace role mapping, circular chains, and unknown custom roles.
  - Cover every standard structure category, heading-name validation, supplemental list/table/caption/ruby/warichu/link/figure/formula/artifact diagnostics, and namespace membership reporting.
  - Done when targeted reader tests prove standard role and namespace behavior without XML schema parsing or PDF/UA certification.
  - _Requirements: 0.3, 0.4, 0.5, 1.12, 1.13, 1.14, 1.15, 1.16, 1.17, 1.18, 1.19, 1.20, 1.21, 1.22, 1.23, 1.24, 1.25, 1.26, 1.27, 1.28, 1.29, 1.30, 1.45, 1.46, 1.47_
  - _Boundary: RoleNamespaceResolver, StandardStructureCatalog tests_
  - _Depends: 4.4_

- [ ] 8.3 (P) Verify attributes, user properties, and accessibility metadata
  - Cover direct attributes, streams, class maps, revision pairs, owner and namespace owner validation, precedence, inheritance, defaults, standard attribute groups, user properties, and mark-information correlation.
  - Cover catalog and element language inheritance, alternate descriptions, replacement text, abbreviation expansion, phoneme values, and phonetic alphabet defaulting.
  - Done when targeted reader tests prove attribute and accessibility resolution with raw value preservation and source provenance.
  - _Requirements: 0.11, 0.12, 0.13, 0.14, 1.31, 1.32, 1.33, 1.34, 1.35, 1.36, 1.37, 1.38, 1.39, 1.40, 1.41, 1.42, 1.43, 1.44, 1.48, 1.49_
  - _Boundary: AttributeResolver, AccessibilityPropertyResolver tests_
  - _Depends: 5.5, 6.1_

- [ ] 8.4 Verify Tagged PDF reports and PDF 2.0 structure examples
  - Cover missing marked flags, missing structure roots, artifact declarations, unresolved custom roles, namespace membership failures, standard-type rule warnings, attribute owner misuse, text-related unchecked items, and accessibility metadata hints.
  - Parse bundled or synthetic PDF 2.0 logical-structure examples and confirm documents without structure trees still return absent structure rather than errors.
  - Done when report tests exercise errors, warnings, unchecked items, and summary flags across all Tagged PDF requirement groups.
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13, 1.14, 1.15, 1.16, 1.17, 1.18, 1.19, 1.20, 1.21, 1.22, 1.23, 1.24, 1.25, 1.26, 1.27, 1.28, 1.29, 1.30, 1.31, 1.32, 1.33, 1.34, 1.35, 1.36, 1.37, 1.38, 1.39, 1.40, 1.41, 1.42, 1.43, 1.44, 1.45, 1.46, 1.47, 1.48, 1.49_
  - _Boundary: TaggedPdfReport integration tests_
  - _Depends: 6.4_

- [ ] 8.5 Run formatting, type checking, tests, and API validation
  - Run formatting, type checking, targeted reader tests, package boundary tests, public API tests, no-structure smoke tests, and generated-interface review.
  - Confirm ordinary document, page, annotation, form, XObject, content, name-tree, number-tree, multimedia, and interchange tests remain compatible.
  - Done when validation commands pass and the only public API changes are the logical-structure additions required by the design.
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.10, 0.11, 0.12, 0.13, 0.14, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13, 1.14, 1.15, 1.16, 1.17, 1.18, 1.19, 1.20, 1.21, 1.22, 1.23, 1.24, 1.25, 1.26, 1.27, 1.28, 1.29, 1.30, 1.31, 1.32, 1.33, 1.34, 1.35, 1.36, 1.37, 1.38, 1.39, 1.40, 1.41, 1.42, 1.43, 1.44, 1.45, 1.46, 1.47, 1.48, 1.49_
  - _Boundary: Full validation_
  - _Depends: 7.2, 8.1, 8.2, 8.3, 8.4_
