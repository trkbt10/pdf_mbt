# Implementation Plan

- [x] 1. Establish the rendering foundation
- [x] 1.1 Create the rendering package boundary and build configuration
  - Add the new rendering package so it can compile with the allowed upstream packages and standard math support.
  - Keep the package independent from document loading and file access.
  - The completed package is visible to the MoonBit build graph and can be imported by downstream integration work.
  - _Requirements: 1_
  - _Boundary: RasterDeviceModel, RenderingResourceContracts_

- [x] 1.2 Define rendering failures, strictness options, limits, and reporting outcomes
  - Add strict and best-effort outcome handling for unsupported rendering resources, provider failures, and guard-limit violations.
  - Represent render reports for skipped operations, provider fallback use, paint counts, and limit observations.
  - The completed error model distinguishes invalid device setup, invalid resources, unsupported capabilities, and limit failures in tests.
  - _Requirements: 1, 3.5_
  - _Boundary: RasterDeviceModel, RenderingResourceContracts_

- [x] 1.3 Model raster devices, native components, render limits, and writable surfaces
  - Validate dimensions, resolution, native colour spaces, process colourants, spot colourants, bits per component, and allocation limits before rendering.
  - Allocate native component buffers with stable pixel addressing and no out-of-bounds writes.
  - The completed model rejects invalid device configurations and produces surfaces whose dimensions and component counts match the device.
  - _Requirements: 1, 2, 2.2, 3.1, 3.2_
  - _Boundary: RasterDeviceModel_

- [x] 1.4 Validate the foundation with package-local tests and generated API review
  - Cover device validation, limit rejection, pixel addressing, and surface component invariants.
  - Run the tight MoonBit validation loop for the new package foundation.
  - The completed foundation passes targeted rendering package tests and produces reviewed generated API summaries.
  - _Requirements: 1, 2_
  - _Boundary: RasterDeviceModel_

- [x] 2. Implement device colour rendering
- [x] 2.1 (P) Establish rendering provider contracts and resource resolution behavior
  - Accept caller-supplied providers for object resolution, PDF function evaluation, CIE/ICC colour transforms, and glyph masks without importing the reader.
  - Fail strict rendering before painting when a required provider is absent.
  - The completed provider layer wraps provider failures with enough operation or resource context for callers to diagnose them.
  - _Requirements: 2.1, 2.7, 3, 3.3, 3.5, 3.15_
  - _Boundary: RenderingResourceContracts_
  - _Depends: 1.2_

- [x] 2.2 (P) Implement classic DeviceGray, DeviceRGB, and DeviceCMYK conversion rules
  - Convert Gray, RGB, and CMYK values with the ISO classic formulas and required clamping behavior.
  - Support the less-capable classic fallback path independently from strict CIE/ICC conversion.
  - The completed conversions return deterministic native component values for Gray-to-RGB, RGB-to-Gray, Gray-to-CMYK, CMYK-to-Gray, and CMYK-to-RGB cases.
  - _Requirements: 2.3, 2.4, 2.5, 2.6, 2.8_
  - _Boundary: ColourPipeline_
  - _Depends: 1.3_

- [ ] 2.3 Apply device colour policy and CIE/ICC transform dispatch
  - Decide when source device spaces can be used directly, when they need CIE-based definitions, and when strict transforms are required.
  - Dispatch CIE-based and ICCBased colours through the configured transform provider using the device output profile policy.
  - The completed policy either returns native device values or reports a strict missing-transform error before scan conversion begins.
  - _Requirements: 2, 2.1, 2.2, 2.3, 2.4_
  - _Boundary: ColourPipeline_

- [ ] 2.4 Resolve black generation and undercolour removal for RGB to CMYK conversion
  - Select BG2 over BG and UCR2 over UCR from graphics-state rendering parameters or device defaults.
  - Evaluate the selected functions through the provider contract and clamp final CMYK values where the formula requires it.
  - The completed RGB-to-CMYK path observes BG and UCR effects in deterministic tests.
  - _Requirements: 2.7_
  - _Boundary: ColourPipeline, TransferFunctionPipeline_

- [ ] 2.5 Preserve native process and spot colourant values for separation-aware painting
  - Keep process and spot colourant components available when the destination is a separation target.
  - Route unsupported colourant combinations to explicit strict errors or best-effort skipped paint records.
  - The completed colour output can feed both normal native surfaces and separation-plane rendering without losing named colourants.
  - _Requirements: 2, 3.16, 3.17_
  - _Boundary: ColourPipeline_

- [ ] 2.6 Cover colour rendering with deterministic unit tests
  - Verify each classic conversion formula, strict provider fallback, CIE/ICC dispatch, BG/UCR behavior, clamping, and spot preservation.
  - Include tests for both matching and nonmatching native device colour spaces.
  - The completed colour test suite fails on formula regressions and passes under `moon test` for the rendering package.
  - _Requirements: 2, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 3.16, 3.17_
  - _Boundary: ColourPipeline_

- [ ] 3. Implement transfer functions
- [ ] 3.1 (P) Resolve graphics-state transfer references and precedence
  - Select TR2 over TR and support single-function or per-component transfer sets.
  - Resolve Identity and provider-backed PDF functions with strict errors for unsupported required functions.
  - The completed resolver chooses the expected transfer source for RGB, Gray, and CMYK devices in isolation tests.
  - _Requirements: 3_
  - _Boundary: TransferFunctionPipeline_
  - _Depends: 1.2, 2.1_

- [ ] 3.2 Apply transfer functions in additive native component form
  - Apply transfers after native colour conversion and before halftoning.
  - Convert subtractive components to additive form before function evaluation and keep transferred output in additive form.
  - The completed transfer step processes each native component independently and exposes additive values for halftone input.
  - _Requirements: 3, 3.1_
  - _Boundary: TransferFunctionPipeline_

- [ ] 3.3 Implement the DeviceGray-to-DeviceCMYK transfer special case
  - Use only the gray transfer function for DeviceGray source colours rendered on CMYK devices.
  - Keep cyan, magenta, and yellow components untransformed for this compatibility case.
  - The completed special case produces black-only CMYK output after transfer for DeviceGray source paints.
  - _Requirements: 3_
  - _Boundary: TransferFunctionPipeline_

- [ ] 3.4 Validate transfer precedence, additive form, overrides, and gray behavior
  - Test TR/TR2 precedence, halftone transfer overrides, subtractive component conversion, independent component processing, and the gray-to-CMYK exception.
  - Include provider failure coverage for required transfer function evaluation.
  - The completed tests demonstrate that transfer output is ready for halftone application.
  - _Requirements: 3, 3.1, 3.10_
  - _Boundary: TransferFunctionPipeline_

- [ ] 4. Implement halftone processing
- [ ] 4.1 (P) Implement predefined spot functions and screen ordering
  - Support the predefined spot function names needed by clause 10 and choose the first recognized name when an array is supplied.
  - Generate stable whitening order values for screen cells while treating unrecognized names as default-halftone fallback conditions.
  - The completed spot-function layer produces deterministic screen ordering for representative predefined names.
  - _Requirements: 3.3, 3.6_
  - _Boundary: HalftoneProcessor_
  - _Depends: 1.2, 2.1_

- [ ] 4.2 Parse single-screen halftones and named/default fallback
  - Parse single-screen frequency, angle, accurate-screen flag, spot function, and optional transfer override.
  - Honor named device halftone lookup and default device halftone fallback when explicit parameters are absent or unsupported.
  - The completed parser accepts valid Type 1 halftones and rejects malformed required entries with rendering errors.
  - _Requirements: 3.5, 3.6_
  - _Boundary: HalftoneProcessor_

- [ ] 4.3 Implement threshold arrays and device-space addressing
  - Store threshold-array dimensions, bit depth, decoded values, and tiling behavior with render-limit validation.
  - Map device pixels to threshold samples independently from the current transformation matrix.
  - The completed threshold lookup treats zero thresholds correctly and returns stable component decisions for repeated tiles.
  - _Requirements: 3.4, 3.7_
  - _Boundary: HalftoneProcessor_

- [ ] 4.4 Add angled and 16-bit threshold halftones
  - Parse and validate Type 10 square-pair threshold streams and Type 16 one- or two-rectangle threshold streams.
  - Check exact decoded byte lengths before allocation and interpret 16-bit samples in high-byte-first order.
  - The completed support rejects inconsistent dimensions and paints sample pixels from both primary and secondary threshold regions.
  - _Requirements: 3.8, 3.9_
  - _Boundary: HalftoneProcessor_

- [ ] 4.5 Implement colourant-specific halftone sets and transfer overrides
  - Dispatch Type 5 entries by process or spot colourant name and use Default for missing colourants.
  - Reject nested Type 5 component halftones and preserve component-specific transfer overrides.
  - The completed Type 5 dispatch selects the expected screen and override for primary, nonprimary, and fallback colourants.
  - _Requirements: 3.5, 3.10_
  - _Boundary: HalftoneProcessor_

- [ ] 4.6 Apply halftones or continuous-tone pass-through during painting
  - Bypass halftoning for continuous-tone devices after transfer functions.
  - For halftoned devices, convert additive native colour values to representable device pixel marks using device-space cell coordinates.
  - The completed halftone application produces device-representable marks and remains unaffected by CTM changes.
  - _Requirements: 3.1, 3.2, 3.4, 3.10_
  - _Boundary: HalftoneProcessor_

- [ ] 4.7 Validate halftone parsing, lookup, component dispatch, and bounds
  - Cover Types 1, 5, 6, 10, and 16, threshold byte counts, predefined names, default fallback, and Type 5 Default behavior.
  - Include guard-limit tests for oversized threshold data and unsupported filters.
  - The completed halftone tests pass deterministically with constructed objects and decoded stream fixtures.
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 3.10_
  - _Boundary: HalftoneProcessor_

- [ ] 5. Implement scene building and scan conversion
- [ ] 5.1 (P) Build ordered render scenes from graphics and optional text semantics
  - Preserve graphics event order and source offsets while turning paint events into renderer operations.
  - Include text glyph paint operations only when compatible text events and glyph providers are supplied.
  - The completed scene builder returns stable ordered paint operations without mutating graphics or text input values.
  - _Requirements: 1, 3.11, 3.14_
  - _Boundary: RenderSceneBuilder_
  - _Depends: 1.2_

- [ ] 5.2 (P) Fill paths and clips using half-open device-pixel rules
  - Flatten curves within the configured flatness tolerance and render-limit bounds.
  - Mark every affected fill pixel whose half-open square intersects the shape and build clipping masks with the same fill rule.
  - The completed fill and clip conversion paints zero-width or zero-height rectangles as visible one-pixel lines where required.
  - _Requirements: 3.11, 3.12, 3.14_
  - _Boundary: ScanConverter_
  - _Depends: 1.3_

- [ ] 5.3 Render strokes with line width, zero-width behavior, and automatic adjustment
  - Convert stroked paths into device-space coverage for nonzero-width strokes.
  - Apply automatic stroke adjustment when enabled and render sub-half-pixel adjusted strokes as single-pixel lines.
  - The completed stroke conversion produces uniform adjusted lines within one half pixel of the requested width.
  - _Requirements: 3.14, 3.15_
  - _Boundary: ScanConverter_

- [ ] 5.4 Render sampled images with centre sampling and clipping
  - Determine the transformed image region in device space and paint only pixels whose centres lie inside that region.
  - Map pixel centres back to source samples without averaging over the pixel area.
  - The completed image path paints clipped image regions deterministically and skips unused high-resolution source samples.
  - _Requirements: 3.14_
  - _Boundary: ScanConverter_

- [ ] 5.5 Approximate shadings with smoothness limits and provider failures
  - Use smoothness tolerance to bound shading approximation where provider-backed shading evaluation is available.
  - Report strict unsupported outcomes or best-effort skipped paint when required shading evaluation is unavailable.
  - The completed shading path respects smoothness limits and records provider gaps without corrupting the raster surface.
  - _Requirements: 3.13_
  - _Boundary: ScanConverter, ColourPipeline_

- [ ] 5.6 Render supplied glyph masks through common paint handling
  - Request glyph masks through the configured glyph provider instead of interpreting font programs in the renderer.
  - Apply glyph coverage through the same colour, transfer, halftone, and clipping path used for other paint operations.
  - The completed glyph path renders supplied masks and fails strict rendering when required masks are unavailable.
  - _Requirements: 3.11, 3.14, 3.15_
  - _Boundary: ScanConverter, RenderingResourceContracts_

- [ ] 5.7 Verify scan conversion and scene behavior
  - Test half-open fill rules, clipping intersections, flatness expansion, stroke adjustment, image centre sampling, smoothness handling, and glyph mask routing.
  - Include small deterministic surfaces so pixel-level expectations are easy to inspect.
  - The completed tests catch one-pixel regressions in fills, clips, strokes, images, and glyph masks.
  - _Requirements: 3.11, 3.12, 3.13, 3.14, 3.15_
  - _Boundary: RenderSceneBuilder, ScanConverter_

- [ ] 6. Integrate the rendering pipeline
- [ ] 6.1 Assemble the render context and per-operation colour pipeline
  - Resolve device, providers, scene, transfer state, halftone state, clip state, and target surface into a single render context.
  - Apply colour conversion, transfer functions, halftones, and scan conversion in the clause 10 sequence for each paint operation.
  - The completed context renders constructed paint operations through the full device-native pipeline.
  - _Requirements: 1, 3.1, 3.11_
  - _Boundary: RenderSceneBuilder, ColourPipeline, TransferFunctionPipeline, HalftoneProcessor, ScanConverter_

- [ ] 6.2 Execute paint operations in deterministic order with strict and best-effort outcomes
  - Stop on strict unsupported rendering outcomes before silently approximating missing capabilities.
  - In best-effort mode, skip unsupported paint operations and record the skip in the render report.
  - The completed renderer produces identical surfaces and reports for repeated runs over the same input and device.
  - _Requirements: 1, 3.5, 3.11, 3.14_
  - _Boundary: RenderSceneBuilder, RenderingResourceContracts_

- [ ] 6.3 Expose public rendering entry points for constructed programs
  - Accept constructed graphics programs, optional text programs, devices, options, and providers from library callers.
  - Return native raster surfaces and render reports without mutating upstream program values.
  - The completed public API renders simple Gray, RGB, and CMYK constructed programs into matching native surfaces.
  - _Requirements: 1, 2, 3.11_
  - _Boundary: RenderSceneBuilder, RasterDeviceModel_

- [ ] 6.4 Validate public renderer scenarios
  - Test simple filled paths, colour conversion through classic fallback and provider stubs, halftoned Gray output, and strict provider failure.
  - Include best-effort report assertions for skipped unsupported operations.
  - The completed renderer scenario tests pass through the public API rather than package-private helpers.
  - _Requirements: 1, 2, 3, 3.1, 3.11, 3.14_
  - _Boundary: RenderSceneBuilder, ColourPipeline, TransferFunctionPipeline, HalftoneProcessor, ScanConverter_

- [ ] 7. Implement separation rendering and simulation
- [ ] 7.1 (P) Model separation targets and independent planes
  - Determine simulated process and spot colourants from the raster device and available output-intent metadata.
  - Allocate independent subtractive planes within render limits.
  - The completed separation target exposes one bounded plane per configured process or spot colourant.
  - _Requirements: 2, 3.16_
  - _Boundary: SeparationRenderer_
  - _Depends: 1.3, 2.5_

- [ ] 7.2 Route process and spot colourants with overprint-aware behavior
  - Paint process and spot components to independent planes when separation output is requested.
  - Respect upstream overprint policy where the graphics state exposes enough information, and report unsupported cases explicitly.
  - The completed separation renderer preserves independent cyan, yellow, and spot plane contributions for overlapping paints.
  - _Requirements: 3.16, 3.17_
  - _Boundary: SeparationRenderer, ColourPipeline_

- [ ] 7.3 Simulate separations on non-separation devices
  - Convert separation planes to flat XYZ over a white matte, multiply blend them, and convert the result to the actual native device space.
  - Keep simulation local to separation rendering without adding general transparency compositing.
  - The completed simulation returns a raster surface whose pixel format matches the actual device.
  - _Requirements: 3.18_
  - _Boundary: SeparationRenderer, ColourPipeline_

- [ ] 7.4 Validate separation rendering and simulation
  - Test process planes, spot planes, overprint routing, multiply blend simulation, output-intent colourant selection, and actual-device conversion.
  - Include strict failure coverage for invalid simulated devices and missing required transforms.
  - The completed separation tests demonstrate different results for normal last-paint output and separation simulation where overprint matters.
  - _Requirements: 3.16, 3.17, 3.18_
  - _Boundary: SeparationRenderer_

- [ ] 8. Connect page rendering through the reader
- [ ] 8.1 Add reader-side rendering error wrapping and package imports
  - Extend reader errors so rendering failures are preserved as document-level failures.
  - Add only the imports needed for rendering and optional text materialization.
  - The completed reader package compiles with rendering imported and exposes rendering failures without losing the underlying cause.
  - _Requirements: 1_
  - _Boundary: ReaderRenderingBridge_

- [ ] 8.2 Materialize rendering resources and output-intent data
  - Resolve indirect halftones, transfer functions, output profiles, image streams, pattern resources, and shading resources before handing values to the renderer.
  - Use existing reader caches and object-loading behavior rather than resolving references inside the renderer.
  - The completed bridge supplies direct render resources or returns reader-wrapped unresolved-resource errors.
  - _Requirements: 2.1, 3.5, 3.18_
  - _Boundary: ReaderRenderingBridge, RenderingResourceContracts_

- [ ] 8.3 Expose page rendering with optional text inputs
  - Build page graphics programs through existing page APIs and include text programs only when text materialization is available.
  - Pass caller device, options, and providers through to the renderer.
  - The completed page-level rendering call returns a surface whose dimensions and native colour space match the supplied device.
  - _Requirements: 1, 3.11_
  - _Boundary: ReaderRenderingBridge_

- [ ] 8.4 Validate reader bridge success and failure paths
  - Test output intent lookup, indirect resource loading, rendering error wrapping, missing provider failure, and optional text glyph behavior.
  - Use constructed or embedded page fixtures that keep expected raster output small and deterministic.
  - The completed reader tests prove page rendering works without adding reader imports to the rendering package.
  - _Requirements: 1, 2.1, 3.5, 3.11_
  - _Boundary: ReaderRenderingBridge_

- [ ] 9. Complete cross-package validation and generated API review
- [ ] 9.1 Add end-to-end raster fixtures and stable snapshot checks
  - Render bundled simple PDF fixtures with deterministic device configuration.
  - Cover simple paths, image centre sampling, clipping, colour conversion, and text only when a stub glyph rasterizer is supplied.
  - The completed end-to-end tests produce stable small raster snapshots across repeated runs.
  - _Requirements: 1, 2, 3, 3.1, 3.11, 3.14_
  - _Boundary: ReaderRenderingBridge, RenderSceneBuilder, ScanConverter_

- [ ] 9.2 Validate allocation, threshold, path, and provider limits
  - Exercise maximum surface dimensions, threshold byte limits, path flattening expansion limits, halftone cache limits, and provider cache limits.
  - Confirm failures occur before excessive allocation or unsafe indexing.
  - The completed limit tests fail safely for oversized surfaces, threshold streams, path expansion, and unavailable provider capabilities.
  - _Requirements: 1, 3.4, 3.5, 3.12, 3.13_
  - _Boundary: RasterDeviceModel, HalftoneProcessor, ScanConverter, RenderingResourceContracts_

- [ ] 9.3 Regenerate public API summaries and run full MoonBit validation
  - Run formatting, full checks, full tests, and public API summary generation after rendering and reader integration are complete.
  - Review generated interface changes so only intended rendering and reader APIs are exposed.
  - The completed validation has passing MoonBit commands and reviewed generated API diffs ready for implementation handoff.
  - _Requirements: 1, 2, 3_
  - _Boundary: ReaderRenderingBridge, RasterDeviceModel, RenderSceneBuilder_
