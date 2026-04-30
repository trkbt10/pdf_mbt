# SDD Draft: npm Package for JavaScript/TypeScript

## Requirements

### Requirement 1: pdf_open
The `src/npm` bridge SHALL expose `pdf_open(data : JSUint8Array) -> Int` for
document handle creation from JavaScript byte arrays.

#### 1.1: Handle lifecycle
`pdf_open(JSUint8Array) -> Int` SHALL create a document handle.
`pdf_close(Int) -> Unit` SHALL release the handle. `HandleCounter` is an
implementation detail for stable handle allocation.

#### 1.2: MoonBit JS FFI bridge
The `src/npm` package SHALL be checkable for the JavaScript/wasm bridge and
SHALL export functions callable from JavaScript through MoonBit FFI.

### Requirement 2: pdf_extract_text
The npm bridge SHALL expose high-level page text operations through
`pdf_extract_text(handle : Int, page : Int) -> String` and
`pdf_extract_text_layout(handle : Int, page : Int) -> String`.

#### 2.1: Document opening
`pdf_open(JSUint8Array) -> Int` SHALL open a PDF document handle.

#### 2.2: Text extraction
`pdf_extract_text(Int, Int) -> String` SHALL extract one page of text.
`pdf_extract_text_layout(Int, Int) -> String` SHALL extract one page of layout
text. `pdf_page_text_positions_json(Int, Int) -> String` SHALL expose text
position data.

#### 2.3: Image extraction
`pdf_page_image_count`, `pdf_page_image_info_json`, and
`pdf_page_image_rgba` SHALL expose page images and RGBA pixel data.

#### 2.4: Document info
`pdf_info_json(Int) -> String` and `pdf_page_geometry_json(Int, Int) -> String`
SHALL expose document info and page geometry.

#### 2.5: Capability check
`pdf_check_json(Int) -> String` SHALL expose the capability report.

### Requirement 3: SVG and image data JavaScript API
The npm bridge SHALL expose page SVG and deferred image access through
`pdf_page_to_svg`, `pdf_page_to_svg_deferred`, `pdf_page_svg_image_count`,
`pdf_page_svg_image_info`, `pdf_page_svg_image_mime`, and
`pdf_page_svg_image_data`.

#### 3.1: Object access
`pdf_page_to_svg(Int, Int) -> String` SHALL return an SVG string for a page.

#### 3.2: Stream decoding
`pdf_page_to_svg_deferred(Int, Int) -> String` SHALL return SVG with deferred
image entries.

#### 3.3: Content stream parsing
`pdf_page_svg_image_data(Int, Int, Int) -> JSUint8Array` SHALL return deferred
image bytes and the companion info/mime functions SHALL describe them.

### Requirement 4: ctx_new
The npm bridge SHALL expose context handles through `ctx_new() -> Int`,
`ctx_from_document(Int) -> Int`, `ctx_add_page(Int, Double, Double) -> Int`,
`ctx_set_title(Int, String) -> Unit`, `ctx_to_bytes(Int) -> JSUint8Array`, and
`ctx_close(Int) -> Unit`.

#### 4.1: Create new PDF
`ctx_new() -> Int`, `ctx_add_page(Int, Double, Double) -> Int`,
`ctx_set_title(Int, String) -> Unit`, and `ctx_to_bytes(Int) -> JSUint8Array`
SHALL support creating a PDF byte array.

#### 4.2: Edit existing PDF
`ctx_from_document(Int) -> Int` SHALL create an editing context from an
existing document handle, and `ctx_close(Int) -> Unit` SHALL release it.

### Requirement 5: test_graphics_walk_counter
The npm bridge SHALL expose lightweight wasm API test hooks through
`test_graphics_walk_counter() -> Int` and
`test_reset_graphics_walk_counter() -> Unit`.

#### 5.1: Build command
`test_reset_graphics_walk_counter() -> Unit` SHALL reset the graphics walk
counter used by wasm API tests.

#### 5.2: TypeScript types
`test_graphics_walk_counter() -> Int` SHALL return the graphics walk counter
used by wasm API tests.
