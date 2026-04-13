# Implementation Plan

- [x] 1. Establish colour implementation prerequisites
- [x] 1.1 Prepare package prerequisites for colour semantics
  - Ensure the graphics package has the allowed dependencies needed for numeric colour helpers and direct ICC profile stream decoding.
  - Keep the dependency set limited to existing project packages and standard MoonBit libraries, with no external colour-management dependency.
  - A baseline check can compile the existing graphics, content, and reader packages after the prerequisite imports are in place.
  - _Requirements: 0.1, 0.12, 0.13, 0.20_
  - _Boundary: GraphicsIntegration_

- [x] 1.2 Establish initial-state inputs for typed colour interpretation
  - Add the interpreter input needed to distinguish normal page content from colour-restricted contexts.
  - Preserve page-level callers as normal interpretation while making the restricted modes available for later pattern and Type 3 glyph callers.
  - Existing reader page graphics construction still produces a valid initial graphics state with normal colour interpretation.
  - _Requirements: 0.1, 0.2, 0.25_
  - _Boundary: GraphicsIntegration_

- [x] 2. Build the core colour-space model
- [x] 2.1 Model device spaces and shared component rules
  - Represent DeviceGray, DeviceRGB, and DeviceCMYK as explicit device spaces with component counts, ranges, and initial values.
  - Enforce the additive and subtractive initial-value differences for gray/RGB and CMYK.
  - Device colour-space selection can produce valid typed initial colour values without consulting resources.
  - _Requirements: 0.3, 0.4, 0.5, 0.6, 0.7_
  - _Boundary: ColourSpaceModel_

- [x] 2.2 Add calibrated CIE-based colour-space validation
  - Validate CalGray, CalRGB, and Lab dictionaries for required white points, optional black points, gamma values, matrices, and ranges.
  - Clamp component values where the PDF rules require nearest valid values without error.
  - Calibrated spaces expose the expected component counts, component ranges, and initial values for graphics-state use.
  - _Requirements: 0.8, 0.9, 0.10, 0.11_
  - _Boundary: ColourSpaceModel_

- [x] 2.3 Add special colour-space structural validation
  - Represent Pattern, Indexed, Separation, and DeviceN spaces without evaluating pattern dictionaries or tint transforms.
  - Enforce forbidden nesting, reject recursive Indexed bases, and compute Indexed lookup byte lengths with overflow-aware arithmetic before comparing direct data.
  - Enforce Separation tint rules and special All/None colourant semantics.
  - Special spaces expose component counts and initial values that match colour selection operators.
  - _Requirements: 0.18, 0.19, 0.20, 0.21, 0.22_
  - _Boundary: ColourSpaceModel_

- [x] 2.4 Add DeviceN and NChannel attributes validation
  - Validate DeviceN component name uniqueness, repeated None handling, All rejection, alternate-space restrictions, and tint-transform presence.
  - Reject unreasonable DeviceN component counts before allocating component arrays.
  - Validate NChannel attributes for process colour-space consistency, required spot colourants, process component order, and mixing-hint shapes.
  - DeviceN and NChannel definitions that violate structural constraints are rejected before they can become current colour spaces.
  - _Requirements: 0.23_
  - _Boundary: ColourSpaceModel_

- [x] 2.5 Add ICCBased profile validation
  - Validate ICCBased profile stream dictionaries for component count, range length, alternate-space compatibility, metadata shape, and permitted source component counts.
  - Decode direct profile streams before header checks while keeping indirect stream loading outside graphics.
  - Reject profiles shorter than the 128-byte ICC header and bound every header read by decoded stream length.
  - Direct ICCBased streams with mismatched headers, incompatible alternates, or unsupported profile shapes fail with graphics-state validation errors.
  - _Requirements: 0.12, 0.13_
  - _Boundary: ICCProfileHeaderValidator_

- [x] 3. Implement colour state and resource resolution
- [x] 3.1 Store typed current stroking and nonstroking colour state
  - Replace raw current colour-space and colour fields with typed state for both stroking and nonstroking uses.
  - Reset the current colour to the selected space initial value whenever the current colour space changes.
  - Graphics state save, restore, copy, and final snapshots preserve independent typed colour states.
  - _Requirements: 0.1, 0.2, 0.4, 0.5, 0.6, 0.7, 0.8_
  - _Boundary: ColourStateController_

- [x] 3.2 Resolve content colour-space names and default device remapping
  - Resolve device and Pattern names directly while resolving parameterized names through ColorSpace resources.
  - Parse only the direct object tree supplied by content resources and avoid recursive resource loading or reader-owned indirect resolution.
  - Apply DefaultGray, DefaultRGB, and DefaultCMYK remapping with unchanged component values and compatible component counts.
  - Apply default remapping to nested Pattern underlying spaces, Indexed base spaces, and Separation or DeviceN alternates where the PDF rule requires it, while preserving the original alternate metadata for deferred rendering decisions.
  - Missing or malformed named ColorSpace resources raise resource failures with the source operation offset.
  - _Requirements: 0.3, 0.14, 0.18, 0.19, 0.20, 0.21, 0.23_
  - _Boundary: ColourSpaceResolver_

- [x] 3.3 Normalize colour values against the current colour space
  - Accept only operand counts and operand forms supported by the current colour space and operator family.
  - Clamp values for calibrated, ICCBased, Indexed, Separation, and DeviceN spaces where the PDF specification requires nearest valid substitution.
  - A successfully stored current colour value is observable as compatible with the current colour space in the graphics state snapshot.
  - _Requirements: 0.2, 0.5, 0.6, 0.7, 0.8, 0.14, 0.20, 0.21, 0.22, 0.23_
  - _Boundary: ColourStateController_

- [x] 4. Normalize colour-related graphics policies
- [x] 4.1 Implement rendering intent and black point compensation semantics
  - Normalize standard rendering intents and map unknown rendering-intent names to the PDF fallback intent for effective interpretation.
  - Represent black point compensation as ON, OFF, or Default and force the effective value to OFF for AbsoluteColorimetric rendering.
  - Preserve implicit CIE-to-device conversion as downstream renderer policy rather than performing conversion in graphics interpretation.
  - Rendering-intent and black-point policy changes are visible in graphics-state snapshots after ri and ExtGState application.
  - _Requirements: 0.15, 0.16, 0.17_
  - _Boundary: ExtGStateColourPolicy_

- [x] 4.2 Validate overprint state and nonzero overprint mode
  - Preserve separate stroking and nonstroking overprint flags while keeping the existing OP-to-op fallback behaviour.
  - Validate overprint mode as a supported integer policy value and keep nonzero CMYK overprint semantics available to downstream consumers.
  - ExtGState application rejects invalid OPM values and preserves valid overprint policy in the graphics state.
  - _Depends: 3.1_
  - _Requirements: 0.15, 0.24_
  - _Boundary: ExtGStateColourPolicy_

- [x] 4.3 (P) Classify colour-restricted interpretation contexts
  - Represent normal, uncoloured tiling pattern, and Type 3 glyph colour-restricted contexts as interpreter policy state.
  - Classify the operators and graphics-state dictionary entries that are affected by colour restriction without applying cross-boundary state changes in this task.
  - Restricted and unrestricted policy decisions can be queried independently by later operator-integration tasks.
  - _Depends: 1.2_
  - _Requirements: 0.25_
  - _Boundary: ColourRestrictionPolicy_

- [x] 5. Apply colour operators through the interpreter
- [x] 5.1 Apply colour-space selection and convenience colour operators
  - Apply CS and cs by resolving the selected colour space and resetting the target current colour to that space initial value.
  - Apply G, g, RG, rg, K, and k as combined device-space selection and colour-value changes, including default device remapping.
  - Honour the colour restriction policy for these operators and leave colour state unchanged when they are ignored.
  - State snapshots after successful operators contain the updated typed colour space and value; public event publication is finalized in the integration task.
  - _Depends: 3.2, 4.3_
  - _Requirements: 0.2, 0.3, 0.5, 0.6, 0.7, 0.14, 0.25_
  - _Boundary: ColourOperatorInterpreter_

- [x] 5.2 Apply explicit colour-value operators
  - Apply SC and sc for device, non-ICCBased CIE, and Indexed spaces with the required numeric operands.
  - Apply SCN and scn for the same spaces accepted by SC and sc, plus ICCBased, Pattern, Separation, and DeviceN operands, including pattern-name payloads where allowed.
  - Honour the colour restriction policy for explicit colour-value operators and leave colour state unchanged when they are ignored.
  - Operand count, operand type, and unsupported current-space errors identify the source colour operation and leave state unchanged.
  - _Depends: 3.3, 5.1_
  - _Requirements: 0.2, 0.8, 0.12, 0.13, 0.19, 0.20, 0.21, 0.22, 0.23, 0.25_
  - _Boundary: ColourOperatorInterpreter_

- [x] 5.3 Integrate colour policy with ExtGState and shading handling
  - Apply unrestricted ri and ExtGState colour entries through typed colour policy instead of raw name storage.
  - Ignore rendering-intent changes, shading paint operators, and colour-related ExtGState entries only in restricted colour contexts.
  - Interpreted event order remains stable around graphics-state, colour, path, text, and deferred-domain operations.
  - _Depends: 4.1, 4.2, 4.3, 5.2_
  - _Requirements: 0.1, 0.15, 0.16, 0.17, 0.24, 0.25_
  - _Boundary: GraphicsIntegration_

- [x] 6. Update public integration surfaces
- [x] 6.1 Publish typed colour state through graphics programs
  - Replace successful colour-operator observation events with state changes carrying the selected colour use, colour space, and colour value.
  - Preserve final-state snapshots and existing non-colour event ordering for callers that inspect graphics programs.
  - Public graphics output for colour operations is device-independent and contains no raster rendering or colour conversion result.
  - _Depends: 5.3_
  - _Requirements: 0.1, 0.2, 0.15, 0.25_
  - _Boundary: GraphicsIntegration_

- [x] 6.2 Keep reader entry points aligned with the new graphics initial state
  - Construct page graphics initial state with normal colour interpretation unless a future caller explicitly selects a restricted context.
  - Keep page resource lookup and indirect object loading ownership in reader/content rather than graphics.
  - Page-level graphics program generation still succeeds for existing fixtures with the new typed colour defaults.
  - _Depends: 6.1_
  - _Requirements: 0.1, 0.3, 0.25_
  - _Boundary: GraphicsIntegration_

- [x] 7. Validate colour behaviour and public API generation
- [x] 7.1 Test colour-space parsing and validation coverage
  - Cover direct device names, calibrated dictionaries, ICCBased stream dictionaries, default remapping compatibility, and special colour-space structural failures.
  - Include malformed inputs for missing required entries, invalid ranges, illegal nesting, recursive Indexed bases, Indexed lookup length overflow, ICC profiles shorter than 128 bytes, ICC header mismatches, excessive DeviceN components, and DeviceN/NChannel attribute contradictions.
  - The colour-space test suite demonstrates accepted and rejected cases for every colour-space family in clause 8.6.
  - _Depends: 2.5, 3.2_
  - _Requirements: 0.3, 0.4, 0.8, 0.9, 0.10, 0.11, 0.12, 0.13, 0.14, 0.18, 0.19, 0.20, 0.21, 0.22, 0.23_
  - _Boundary: ColourSpaceModel, ColourSpaceResolver, ICCProfileHeaderValidator_

- [x] 7.2 (P) Test colour state and operator interpretation
  - Cover initial typed colour state, save/restore copying, CS/cs resets, convenience operators, SC/sc operand checks, and SCN/scn coverage for the SC/sc-supported spaces plus ICCBased, Pattern, Separation, and DeviceN.
  - Cover restricted-context ignore behaviour for colour operators, ri, sh, and colour-related ExtGState entries.
  - Interpreter tests show typed colour state changes where deferred colour observations were previously emitted.
  - _Depends: 5.3, 6.1_
  - _Requirements: 0.1, 0.2, 0.5, 0.6, 0.7, 0.15, 0.16, 0.19, 0.20, 0.21, 0.22, 0.23, 0.25_
  - _Boundary: ColourStateController, ColourOperatorInterpreter, ColourRestrictionPolicy, GraphicsIntegration_

- [x] 7.3 (P) Test ExtGState colour policies and overprint semantics
  - Cover rendering-intent fallback, black point compensation effective values, OP/op fallback, OPM validation, and nonzero overprint preservation.
  - Include invalid ExtGState colour-policy entries that must raise graphics-state validation errors.
  - The ExtGState tests prove colour policy data is normalized for downstream renderers without performing rendering.
  - _Depends: 4.1, 4.2, 5.3_
  - _Requirements: 0.15, 0.16, 0.17, 0.24, 0.25_
  - _Boundary: ExtGStateColourPolicy_

- [x] 7.4 Run repository validation and regenerate public interfaces
  - Format the MoonBit sources, run targeted graphics tests, run the full MoonBit test suite, and regenerate public interface summaries.
  - Public interface changes are limited to the typed colour semantics and graphics initial-state shape described in the design.
  - The repository validation commands complete successfully with updated generated interface files present in the worktree.
  - _Depends: 7.1, 7.2, 7.3_
  - _Requirements: 0.1, 0.2, 0.25_
  - _Boundary: GraphicsIntegration_
