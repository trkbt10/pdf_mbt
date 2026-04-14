# Implementation Plan

- [ ] 1. Establish reader-layer multimedia foundation
- [ ] 1.1 Add multimedia diagnostics and shared structural parsing behavior
  - Add a dedicated multimedia document error path for malformed clause 13 dictionaries, arrays, names, ranges, and required relationships.
  - Support direct and indirect object resolution with owner context, bounded traversal, cycle reporting, dictionary/name/array/range checks, and ISO default handling.
  - Preserve raw PDF objects and unknown entries while malformed required structures return deterministic multimedia errors.
  - Completed when a minimal valid multimedia dictionary can be resolved through the shared helpers and a malformed required entry reports a multimedia diagnostic without changing lower parser packages.
  - _Requirements: 1, 1.1, 1.2, 4.9_
  - _Boundary: MultimediaCommonParser_

- [ ] 1.2 Define the shared multimedia model vocabulary
  - Add public structural models for raw-retaining dictionaries and streams, MH/BE policy, viability decisions, unknown names, byte strings, vectors, matrices, offsets, durations, object references, and opaque payload carriers.
  - Keep media, script, embedded-file, U3D, PRC, and state payloads raw; do not normalize, decode, execute, fetch, or open them.
  - Completed when parser components can construct typed multimedia values with raw payload identity visible to callers and without new non-standard dependencies.
  - _Requirements: 1, 1.1, 1.2, 4.1, 4.9_
  - _Boundary: MultimediaModel_

- [ ] 1.3 Create reusable multimedia test fixtures
  - Add package-local fixture support for dictionaries, streams, arrays, indirect references, annotation shells, name-tree entries, action payloads, and cycle cases.
  - Include fixture assertions that raw payloads remain observable after typed parsing.
  - Completed when reader white-box tests can build direct and indirect clause 13 objects without duplicating fixture setup.
  - _Requirements: 1, 1.1, 1.2_
  - _Boundary: MultimediaCommonParser_

- [ ] 2. Implement multimedia framework and player policies
- [ ] 2.1 Parse common and media rendition dictionaries
  - Interpret common rendition entries, media criteria dictionaries, media rendition media/play/screen relationships, and required rendition subtype behavior.
  - Apply default play and screen parameters when optional entries are absent, and preserve raw dictionaries and child payloads.
  - Completed when valid common and media rendition dictionaries produce typed models and invalid required rendition subtype values fail deterministically.
  - _Requirements: 1.1, 1.3, 1.4_
  - _Boundary: MultimediaFrameworkParser_

- [ ] 2.2 Parse selector renditions and structural selection inputs
  - Parse ordered selector rendition arrays, nested selector trees, and empty selector behavior without performing playback.
  - Detect recursive selector structures through the shared traversal guard.
  - Completed when nested selector trees preserve order and cycles report a multimedia cycle diagnostic.
  - _Depends: 2.1_
  - _Requirements: 1.5_
  - _Boundary: MultimediaFrameworkParser_

- [ ] 2.3 Parse media clips, permissions, and clip sections
  - Interpret common media clip entries, media clip data, media permissions, content type strings, base URL policy, file specifications, and media clip sections.
  - Apply MH/BE required-entry rules for clip data and clip sections while preserving external URL strings and streams raw.
  - Completed when data clips and section clips expose typed metadata, raw media payloads, permissions, and offsets without extracting files.
  - _Requirements: 1.6, 1.7, 1.8_
  - _Boundary: MultimediaFrameworkParser_

- [ ] 2.4 Parse play parameters, screen parameters, offsets, durations, and timespans
  - Interpret playback controls, duration dictionaries, screen placement, floating-window parameters, media offsets, frame offsets, marker offsets, and timespan dictionaries.
  - Validate numeric ranges, array arity, required subtype names, and ISO defaults for absent optional entries.
  - Completed when playback and screen dictionaries expose defaulted typed values and invalid offset or timespan shapes report multimedia errors.
  - _Requirements: 1.9, 1.10, 1.11, 1.12_
  - _Boundary: MultimediaFrameworkParser_

- [ ] 2.5 (P) Parse media player, software identifier, version, and monitor policy data
  - Interpret media players dictionaries, media player info dictionaries, software identifier dictionaries, software URI names, OS arrays, version arrays, and monitor specifier values.
  - Implement pure comparisons for software identity, version-array ordering with empty-array infinity semantics, and monitor specifier recognition.
  - Completed when caller-supplied software identities can be matched against parsed policy data without querying installed software or host monitors.
  - _Depends: 1.1, 1.2_
  - _Requirements: 1.13, 1.14, 1.15, 1.16, 1.17, 1.18, 1.19, 1.20, 1.21_
  - _Boundary: MediaPlayerPolicy_

- [ ] 2.6 Evaluate MH/BE viability and selector outcomes
  - Evaluate must-honor and best-effort entries against caller-supplied environment data for rendition criteria, clip constraints, play/screen parameters, players, software identifiers, versions, and monitors.
  - Treat unknown MH keys or unrecognized MH values as non-viable where required, ignore unknown BE keys for viability, and return an entry-level decision trace.
  - Completed when media viability reports are deterministic for a supplied environment and selector renditions choose the first viable media rendition without side effects.
  - _Depends: 2.1, 2.2, 2.3, 2.4, 2.5_
  - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.7, 1.8, 1.9, 1.10, 1.14, 1.15, 1.16, 1.17, 1.18, 1.19, 1.20, 1.21_
  - _Boundary: MediaViabilityEvaluator_

- [ ] 3. Implement legacy media, 3D core, and RichMedia asset parsers
- [ ] 3.1 Parse deprecated sound object metadata
  - Interpret sound streams, sampling rate, channels, bits per sample, encoding, compression names, and default values while preserving raw stream data.
  - Reject malformed required sound stream shapes with multimedia diagnostics.
  - Completed when sound stream metadata is inspectable and no audio decoding or playback occurs.
  - _Requirements: 2_
  - _Boundary: LegacyMediaParser_

- [ ] 3.2 Parse deprecated movie dictionary and activation metadata
  - Interpret movie dictionaries, activation dictionaries, start and duration values, rate, volume, mode, floating-window scale, and position.
  - Preserve movie file specifications and runtime targets raw.
  - Completed when movie metadata and activation defaults are visible through typed models without locating or playing movie files.
  - _Requirements: 3_
  - _Boundary: LegacyMediaParser_

- [ ] 3.3 Parse alternate presentation slideshow metadata
  - Enumerate alternate presentation name-tree entries and interpret slideshow dictionaries, resource name trees, and start resources.
  - Validate required Type/Subtype/StartResource relationships while preserving raw slideshow resources.
  - Completed when ordered slideshow entries can be read from the catalog name tree without changing generic name-tree traversal.
  - _Requirements: 4_
  - _Boundary: LegacyMediaParser_

- [ ] 3.4 (P) Parse 3D annotations, streams, references, and activation data
  - Interpret raw 3D annotation dictionaries, 3D stream dictionaries, U3D/PRC subtype metadata, 3D reference dictionaries, animation styles, activation states, default views, and artwork source references.
  - Preserve U3D and PRC stream payloads raw and keep existing raw annotation variants intact.
  - Completed when a raw 3D annotation can produce a typed structural model and subtype mismatches return no typed annotation.
  - _Depends: 1.1, 1.2_
  - _Requirements: 4.1, 4.2_
  - _Boundary: ThreeDParser_

- [ ] 3.5 Parse 3D views, projections, and coordinate metadata
  - Interpret view dictionaries, camera data, overlays, 12-number matrices, 3D vectors, projection dictionaries, and local view-reference validation.
  - Validate coordinate array arity and projection subtype rules without applying transforms or rendering.
  - Completed when 3D view and projection metadata can be inspected with invalid matrices and vectors reported as multimedia errors.
  - _Depends: 3.4_
  - _Requirements: 4.3, 4.4, 4.5_
  - _Boundary: ThreeDParser_

- [ ] 3.6 (P) Parse RichMedia assets, configurations, instances, and view parameters
  - Validate RichMedia asset name-tree keys for length, null characters, forbidden characters, final periods, and F/UF matching.
  - Interpret configurations, instance arrays, embedded file specifications, view parameters, and opaque save/load state data relationships.
  - Completed when RichMedia assets and instances retain raw file/state payloads and invalid asset names produce validation results.
  - _Depends: 1.1, 1.2_
  - _Requirements: 4.18, 4.19, 4.20, 4.22, 4.23, 4.24_
  - _Boundary: RichMediaAssetParser_

- [ ] 4. Implement dependent 3D and RichMedia structures
- [ ] 4.1 Parse 3D appearance metadata
  - Interpret 3D backgrounds, render modes, lighting schemes, cross sections, node dictionaries, color arrays, opacity ranges, orientation arrays, and node matrices.
  - Preserve unknown render and lighting modes where the specification permits forward-compatible values.
  - Completed when appearance-related 3D dictionaries expose defaulted metadata and no lighting, clipping, projection, or node transform is rendered.
  - _Depends: 3.4, 3.5_
  - _Requirements: 4.3, 4.4_
  - _Boundary: ThreeDAppearanceParser_

- [ ] 4.2 (P) Parse 3D units, markup, and measurements
  - Interpret 3D unit scale sets, Markup3D external data, 3DM external data, linear/perpendicular/angular/radial measurements, comment-note measurements, and projection annotation links.
  - Preserve MD5 bytes, projection references, and comment associations as metadata only.
  - Completed when measurement dictionaries validate required point/vector arrays and unit scaling is available as a pure calculation.
  - _Depends: 3.4, 3.5_
  - _Requirements: 4.6, 4.7, 4.8_
  - _Boundary: ThreeDMeasurementParser_

- [ ] 4.3 Parse RichMedia annotations, settings, presentation, content, and views
  - Interpret RichMedia annotations, settings, activation, deactivation, animation, presentation, window, position, content, default configuration, default view, and extended view dictionaries.
  - Preserve script references, snapshot streams, shared content, opaque state data, and runtime command payloads without executing ECMAScript or RichMedia behavior.
  - Completed when RichMedia annotation models expose settings/content and subtype mismatches return no typed annotation.
  - _Depends: 3.4, 3.6, 4.1_
  - _Requirements: 4.9, 4.10, 4.11, 4.12, 4.13, 4.14, 4.15, 4.16, 4.17, 4.21, 4.22, 4.23, 4.24_
  - _Boundary: RichMediaParser_

- [ ] 5. Integrate public multimedia accessors with existing reader surfaces
- [ ] 5.1 Expose explicit typed access from document, annotation, action, and raw object values
  - Add public reader entry points that parse raw annotations, raw action payloads, catalog name-tree values, and caller-supplied raw objects into multimedia models on demand.
  - Return absent results for annotation subtype mismatches and optional missing entries while preserving existing raw annotation and action APIs.
  - Completed when callers can request typed multimedia models without triggering eager parsing during ordinary page or annotation enumeration.
  - _Depends: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.1, 4.2, 4.3_
  - _Requirements: 1, 1.1, 2, 3, 4, 4.1, 4.10_
  - _Boundary: MultimediaAccessors_

- [ ] 5.2 Connect action and name-tree handoff paths
  - Allow raw rendition action payloads, 3D view action payloads, RichMedia execute command payloads, and alternate presentation name-tree entries to be passed into explicit typed parsers.
  - Confirm action parsing remains structural metadata only and no event delivery, playback, scripting, file access, or UI behavior is introduced.
  - Completed when existing multimedia action values remain byte-for-byte raw-compatible while typed parsing is available as an explicit follow-up step.
  - _Depends: 5.1_
  - _Requirements: 1.1, 1.3, 1.4, 1.5, 2, 3, 4, 4.1, 4.10, 4.17, 4.21_
  - _Boundary: MultimediaAccessors_

- [ ] 5.3 Regenerate and review the reader public API surface
  - Regenerate the reader package interface and review that public additions are limited to multimedia models, typed accessors, and the multimedia error variant.
  - Keep raw 3D and RichMedia annotation variants valid and avoid package dependency direction changes.
  - Completed when the generated interface diff contains only intended multimedia additions.
  - _Depends: 5.1, 5.2_
  - _Requirements: 1, 1.1, 4.1, 4.10_
  - _Boundary: MultimediaAccessors, MultimediaModel_

- [ ] 6. Validate multimedia parsing behavior
- [ ] 6.1 Add framework and viability white-box coverage
  - Cover renditions, media clips, play parameters, screen parameters, offsets, durations, timespans, MH/BE precedence, selector traversal, and viability reports.
  - Include malformed required entries, defaulted optional entries, unknown MH/BE behavior, nested selectors, and bounded cycle cases.
  - Completed when targeted reader tests prove framework parsing and viability behavior for every multimedia framework requirement.
  - _Depends: 2.1, 2.2, 2.3, 2.4, 2.6_
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13_
  - _Boundary: MultimediaFrameworkParser, MediaViabilityEvaluator_

- [ ] 6.2 (P) Add player policy white-box coverage
  - Cover software URI scheme matching, case-sensitive software names, OS matching, version padding, empty-version infinity semantics, negative version rejection, MU/A/NU eligibility, and monitor specifier defaults.
  - Include caller-supplied software identity data only, with no host inventory lookup.
  - Completed when targeted reader tests prove media player decisions and version comparisons for every player-policy requirement.
  - _Depends: 2.5_
  - _Requirements: 1.14, 1.15, 1.16, 1.17, 1.18, 1.19, 1.20, 1.21_
  - _Boundary: MediaPlayerPolicy_

- [ ] 6.3 (P) Add legacy media white-box coverage
  - Cover sound stream fields and defaults, movie dictionary required file specifications, movie activation defaults, and alternate presentation slideshow validation.
  - Include raw stream and raw resource preservation assertions.
  - Completed when targeted reader tests prove deprecated media structures are parsed but never played or extracted.
  - _Depends: 3.1, 3.2, 3.3_
  - _Requirements: 2, 3, 4_
  - _Boundary: LegacyMediaParser_

- [ ] 6.4 (P) Add 3D and 3D measurement white-box coverage
  - Cover 3D annotation entries, 3D stream U3D/PRC subtype handling, reference dictionaries, activation defaults, default view precedence, projection rules, vectors, matrices, appearance dictionaries, node fields, units, measurements, Markup3D, 3DM, and projection links.
  - Include invalid arity, range, subtype, unit-label, and cycle diagnostics.
  - Completed when targeted reader tests prove 3D and measurement metadata are inspectable without rendering, decoding, drawing, or checksum verification.
  - _Depends: 3.4, 3.5, 4.1, 4.2_
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8_
  - _Boundary: ThreeDParser, ThreeDAppearanceParser, ThreeDMeasurementParser_

- [ ] 6.5 (P) Add RichMedia white-box coverage
  - Cover required annotation content, settings defaults, activation/deactivation defaults, animation defaults, presentation/window/position defaults, content default views, asset filename validation, configuration/instance relationships, view snapshots, view parameters, and opaque state data retention.
  - Include shared content referenced by multiple annotations and subtype mismatch cases.
  - Completed when targeted reader tests prove RichMedia metadata is parsed structurally without ECMAScript, activation events, toolbar behavior, context menus, or media runtime behavior.
  - _Depends: 3.6, 4.3_
  - _Requirements: 4.9, 4.10, 4.11, 4.12, 4.13, 4.14, 4.15, 4.16, 4.17, 4.18, 4.19, 4.20, 4.21, 4.22, 4.23, 4.24_
  - _Boundary: RichMediaParser, RichMediaAssetParser_

- [ ] 6.6 Run integration, performance, formatting, and API validation
  - Parse fixture pages containing Screen, 3D, RichMedia, Sound, Movie, and Projection annotations; parse alternate presentation name trees; parse rendition action payloads; and parse nested but acyclic multimedia graphs.
  - Confirm raw annotation/action APIs still return the same raw values, typed accessors return deep structural models, cycles fail early, and repeated parsing does not mutate the document.
  - Run `moon check`, targeted reader tests, `moon fmt`, and `moon info`; review the generated interface for intended reader API additions only.
  - Completed when the validation commands pass and the only public API changes are the multimedia additions required by the design.
  - _Depends: 5.1, 5.2, 5.3, 6.1, 6.2, 6.3, 6.4, 6.5_
  - _Requirements: 1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 1.10, 1.11, 1.12, 1.13, 1.14, 1.15, 1.16, 1.17, 1.18, 1.19, 1.20, 1.21, 2, 3, 4, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 4.10, 4.11, 4.12, 4.13, 4.14, 4.15, 4.16, 4.17, 4.18, 4.19, 4.20, 4.21, 4.22, 4.23, 4.24_
  - _Boundary: MultimediaAccessors, MultimediaFrameworkParser, MediaPlayerPolicy, MediaViabilityEvaluator, LegacyMediaParser, ThreeDParser, ThreeDAppearanceParser, ThreeDMeasurementParser, RichMediaParser, RichMediaAssetParser_
