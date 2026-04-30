# Implementation Plan

- [x] 1. Establish the function domain foundation
- [x] 1.1 Create the package boundary and public safety contract
  - Introduce the function-domain package with only the allowed object, filter, and math dependencies.
  - Define the public error categories, implementation limits, direct-versus-indirect source model, common intervals, and type variants needed by all function kinds.
  - The package can be type-checked on its own and exposes a stable foundation for later parser and evaluator work without importing graphics, rendering, reader, parser, lexer, or content packages.
  - _Requirements: 0.1_
  - _Boundary: FunctionModel_

- [x] 1.2 Add common numeric validation and clipping behavior
  - Validate function type values, required domain arrays, optional and required range arrays, interval ordering, numeric array lengths, and finite numeric values consistently.
  - Implement the shared interpolation rule, input domain clipping, output range clipping, and arity helpers used by every function kind.
  - Common validation tests demonstrate malformed dictionaries fail with typed errors while valid intervals clip and interpolate as specified.
  - _Requirements: 0.1_
  - _Boundary: FunctionParser, FunctionEvaluator_

- [x] 1.3 Establish source classification and type-parser handoff contracts
  - Accept indirect references as unresolved function sources and reject unsupported object shapes without resolving references inside the function package.
  - Define the internal dispatch contract that lets each supported function type register its owned direct parser after its component work is implemented.
  - Foundation smoke tests cover indirect source preservation, unsupported object errors, forbidden dependency directions, and the ability to add type parsers without changing package dependencies.
  - _Requirements: 0.1_
  - _Boundary: FunctionParser_

- [ ] 2. Implement function semantics by type
- [x] 2.1 (P) Parse sampled function tables and bit-packed sample data
  - Validate sampled-function size, bit width, interpolation order, required range, encode defaults, decode defaults, and declared sample count before reading sample data.
  - Read decoded sample bytes as one continuous high-order-bit-first stream for all supported sample widths and preserve first-dimension-fastest table ordering.
  - The parsed sampled model rejects insufficient stream data, invalid bit widths, and limit-exceeding tables, while valid fixtures expose the expected sample values in range order.
  - _Requirements: 0.2_
  - _Boundary: SampledFunctionModel_

- [x] 2.2 Complete sampled function linear evaluation
  - Map clipped inputs through encode intervals, clip encoded coordinates to the sample table, interpolate surrounding sample values linearly, decode output components, and apply range clipping.
  - Support one-dimensional and multidimensional linear interpolation using the declared sample ordering and output component order.
  - Evaluation tests show encoded coordinates, first-dimension-fastest indexing, decode behavior, trailing padding, range clipping, and out-of-domain inputs produce the expected numbers.
  - _Requirements: 0.2_
  - _Boundary: SampledFunctionModel_

- [x] 2.3 Complete sampled function cubic-order evaluation
  - Evaluate `Order 3` sampled functions with cubic interpolation whenever each required dimension has enough samples for cubic processing.
  - Fall back to the required ignored-order behavior only when a declared dimension makes cubic interpolation unavailable.
  - Cubic-order tests show supported `Order 3` fixtures differ from linear interpolation where expected, and small-size fixtures ignore cubic order as specified.
  - _Requirements: 0.2_
  - _Boundary: SampledFunctionModel_

- [x] 2.4 (P) Implement exponential interpolation functions
  - Validate the one-input domain, default and explicit coefficient arrays, required exponent, inferred output count, and optional output range.
  - Evaluate each output component using the exponential interpolation formula and reject invalid numeric preconditions for negative or non-integer exponents.
  - Tests cover defaults, multi-output coefficients, range clipping, non-integer exponent domain failures, negative exponent zero-input failures, and arity errors.
  - _Requirements: 0.3_
  - _Boundary: ExponentialFunctionModel_

- [x] 2.5 (P) Parse calculator function programs
  - Tokenize decoded calculator streams with PDF brace syntax, comments, numbers, booleans, and allowed operator names only.
  - Build conditional block structure for calculator expressions while rejecting composite data, variables, unknown names, unbalanced braces, and procedure-like unsupported syntax.
  - Parser tests show valid top-level and nested conditional streams become bounded programs, while unsupported syntax fails closed with function-domain errors.
  - _Requirements: 0.5, 0.6_
  - _Boundary: CalculatorFunctionModel_

- [x] 2.6 Execute calculator arithmetic and numeric operators
  - Evaluate required numeric stack values for arithmetic operators, conversions, rounding, trigonometry, logarithms, exponentiation, roots, and division behavior.
  - Enforce numeric domain, type, stack underflow, and result validity errors for arithmetic operations.
  - Operator tests cover every arithmetic operator and show numeric failures are reported without accepting unsupported PostScript features.
  - _Requirements: 0.6_
  - _Boundary: CalculatorFunctionModel_

- [x] 2.7 Execute calculator relational, boolean, and bitwise operators
  - Evaluate comparisons, boolean literals, logical operators, integer bitwise operations, and bit shifting with calculator-specific value typing.
  - Reject mismatched operand types, invalid integer conversions, stack underflow, and unsupported names through function-domain errors.
  - Operator tests cover every relational, boolean, and bitwise operator with both success and representative failure cases.
  - _Requirements: 0.6_
  - _Boundary: CalculatorFunctionModel_

- [x] 2.8 Execute calculator conditionals, stack operators, and limits
  - Execute `if` and `ifelse` blocks using parsed brace expressions without exposing PostScript procedure objects.
  - Implement stack operators and enforce calculator token, stack depth, nested block, evaluation-step, and final output-count limits.
  - Tests cover conditional branch selection, nested conditionals, every stack operator, bounded execution failures, and exact final numeric output arity.
  - _Requirements: 0.5, 0.6_
  - _Boundary: CalculatorFunctionModel_

- [x] 2.9 Assemble the shared evaluator for direct non-stitching functions
  - Validate input arity, clip inputs once before type-specific execution, dispatch to sampled, exponential, and calculator functions, clip outputs when a range exists, and reject unresolved sources during evaluation.
  - Apply common evaluation-step accounting to direct non-stitching functions without claiming nested recursion behavior before stitching exists.
  - Public evaluation tests show sampled, exponential, and calculator functions share the same arity, clipping, output-count, and error behavior.
  - _Depends: 2.3, 2.4, 2.8_
  - _Requirements: 0.1, 0.2, 0.3, 0.5, 0.6_
  - _Boundary: FunctionEvaluator_

- [x] 2.10 Implement stitching function validation and dispatch
  - Validate one-input stitching domains, function arrays, bounds length, encode pair count, ordered bounds, degenerate first and last bound cases, and compatible subfunction output counts.
  - Select the correct half-open or closed subdomain, encode the input for the selected subfunction, evaluate only materialized direct subfunctions, enforce recursion limits, and apply the stitching range when present.
  - Tests cover k equals one, normal partitions, first-bound degeneracy, last-bound degeneracy, inverted encode pairs, unresolved subfunctions, recursion limits, and incompatible output dimensions.
  - _Depends: 2.9_
  - _Requirements: 0.1, 0.4_
  - _Boundary: StitchingFunctionModel, FunctionEvaluator_

- [x] 2.11 Complete direct parser dispatch for all function types
  - Connect Type 0, Type 2, Type 3, and Type 4 direct parsing through the common function parser after each owned component is implemented.
  - Decode Type 0 and Type 4 streams through the filter boundary, preserve raw stream ownership, and keep unsupported function types rejected consistently.
  - Parser integration tests show every supported direct function type parses from its required dictionary or stream form and malformed direct objects produce typed parser errors.
  - _Depends: 2.10_
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6_
  - _Boundary: FunctionParser_

- [ ] 3. Integrate function sources with consumers
- [x] 3.1 Wire graphics models to typed function sources
  - Convert direct tint transforms, shading functions, mesh optional functions, and soft-mask transfer functions into typed function sources at graphics parsing boundaries.
  - Preserve unresolved indirect references explicitly where graphics cannot materialize them and wrap function-domain failures in graphics diagnostics.
  - Graphics integration tests show direct function-bearing dictionaries parse successfully, indirect references remain visible, and invalid function payloads fail at the graphics boundary.
  - _Depends: 2.11_
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6_
  - _Boundary: GraphicsFunctionIntegration_

- [ ] 3.2 Add reader materialization for indirect functions
  - Load referenced function objects through existing document object access and parse the materialized value through the function package.
  - Keep lazy object loading owned by the reader layer and preserve underlying function errors inside document-level diagnostics.
  - Reader tests show indirect Type 2 and nested Type 3 functions materialize to direct evaluable functions, while missing or malformed references fail through document errors.
  - _Depends: 2.11_
  - _Requirements: 0.1, 0.4_
  - _Boundary: ReaderFunctionBridge_

- [ ] 3.3 Revalidate rendering-facing function references
  - Replace or adapt existing rendering transfer and halftone function references only where the rendering layer already preserves function-bearing settings.
  - Keep raster policy, colour conversion, and pixel application outside the function package while allowing typed direct functions to be evaluated at rendering boundaries.
  - Rendering-focused checks show typed functions can be accepted without changing raster ownership or introducing reverse dependencies.
  - _Depends: 2.11_
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6_
  - _Boundary: Rendering consumers, FunctionEvaluator_

- [ ] 4. Validate limits, integration, and public API
- [ ] 4.1 Complete common parser and evaluator test coverage
  - Cover function type dispatch, domain and range validation, common interpolation, input clipping, output clipping, arity mismatches, unresolved references, filter failures, and unsupported objects.
  - Tests exercise both black-box public behavior and package-local validation paths.
  - Targeted function-domain tests pass for common parser and evaluator behavior before consumer integration tests run.
  - _Requirements: 0.1_
  - _Boundary: FunctionParser, FunctionEvaluator_

- [ ] 4.2 Complete sampled-function conformance coverage
  - Cover every supported bit width, default encode and decode values, multidimensional ordering, insufficient stream bytes, limit failures, linear interpolation, cubic `Order 3`, ignored cubic order for small dimensions, and range clipping.
  - Include representative fixtures based on the sampled-function mapping examples and verify outputs numerically within the package's tolerance policy.
  - Targeted sampled-function tests pass and demonstrate that the full declared sample array is consumed without byte-boundary padding assumptions.
  - _Requirements: 0.2_
  - _Boundary: SampledFunctionModel_

- [ ] 4.3 Complete exponential and stitching conformance coverage
  - Cover exponential defaults, coefficient length mismatches, exponent edge cases, optional range clipping, stitching bounds, encode mapping, degenerate partitions, recursion limits, and subfunction compatibility.
  - Include tests that combine Type 2 subfunctions inside Type 3 stitching functions to verify cross-type evaluation through the shared evaluator.
  - Targeted tests pass for both standalone exponential functions and nested stitching behavior.
  - _Requirements: 0.3, 0.4_
  - _Boundary: ExponentialFunctionModel, StitchingFunctionModel, FunctionEvaluator_

- [ ] 4.4 Complete calculator numeric and logical operator coverage
  - Cover all arithmetic operators, all relational operators, boolean literals, logical operators, bitwise operators, numeric domain failures, operand type failures, and stack underflow failures.
  - Include success and failure fixtures for integer-only behavior used by bitwise and shift operators.
  - Targeted calculator tests pass for numeric, comparison, boolean, and bitwise behavior.
  - _Requirements: 0.6_
  - _Boundary: CalculatorFunctionModel_

- [ ] 4.5 Complete calculator control-flow, stack, and limit coverage
  - Cover comments, braces, if and ifelse blocks, nested conditionals, every stack operator, output-count errors, unsupported syntax, token limits, stack depth limits, nested block limits, and evaluation-step limits.
  - Include fixtures that prove PDF brace syntax is accepted only as calculator conditional syntax and not as full PostScript procedures.
  - Targeted calculator tests pass for control flow, stack behavior, parser rejection, and bounded execution.
  - _Requirements: 0.5, 0.6_
  - _Boundary: CalculatorFunctionModel_

- [ ] 4.6 Run package-wide verification and public API review
  - Run formatting, type checking, full test coverage, and public interface generation for all affected packages.
  - Review generated public interfaces for the function, graphics, rendering, and reader packages so only intentional API changes remain.
  - The final verification commands pass, generated interface files are updated where public APIs changed, and no forbidden dependency direction or external dependency is introduced.
  - _Requirements: 0.1, 0.2, 0.3, 0.4, 0.5, 0.6_
  - _Boundary: FunctionModel, FunctionParser, FunctionEvaluator, GraphicsFunctionIntegration, ReaderFunctionBridge, Rendering consumers_
