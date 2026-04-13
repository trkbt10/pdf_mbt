///|
/// PDF fill-rule selection for path painting and clipping.
pub(all) enum FillRule {
  NonZero
  EvenOdd
} derive(Eq, Debug)

///|
/// One immutable path construction segment in a graphics path snapshot.
/// Segments define shapes, line trajectories, and regions by adding line
/// segments, cubic Bezier curves, and closures to a path.
pub(all) enum PathSegment {
  LineTo(GraphicsPoint)
  CurveTo(GraphicsPoint, GraphicsPoint, GraphicsPoint)
  ClosePath
} derive(Eq, Debug)

///|
/// Ordered subpath with its starting point and constructed segments.
pub(all) struct PathSubpath {
  start : GraphicsPoint
  segments : Array[PathSegment]
  current : GraphicsPoint
  closed : Bool
} derive(Eq, Debug)

///|
/// Snapshot of a PDF current path. Paths are device-independent shapes that
/// painting operators can fill, stroke, or use as a clipping boundary. Path
/// data is not part of GraphicsState.
pub(all) struct GraphicsPath {
  subpaths : Array[PathSubpath]
} derive(Eq, Debug)

///|
/// One accumulated clipping intersection derived from a completed path.
pub(all) struct ClipEntry {
  path : GraphicsPath
  rule : FillRule
} derive(Eq, Debug)

///|
/// Approximate clipping-path model: initial page clip plus successive path
/// intersections. Rendering or scan conversion is intentionally deferred.
pub(all) struct ClipState {
  initial_clip : GraphicsPath?
  clips : Array[ClipEntry]
} derive(Eq, Debug)

///|
struct CurrentPath {
  subpaths : Array[PathSubpath]
  mut current_point : GraphicsPoint?
} derive(Eq, Debug)

///|
fn CurrentPath::new() -> CurrentPath {
  CurrentPath::{ subpaths: [], current_point: None }
}

///|
fn CurrentPath::is_empty(self : CurrentPath) -> Bool {
  self.subpaths.length() == 0
}

///|
fn CurrentPath::snapshot(self : CurrentPath) -> GraphicsPath {
  GraphicsPath::{ subpaths: copy_subpaths(self.subpaths) }
}

///|
fn CurrentPath::clear(self : CurrentPath) -> Unit {
  self.subpaths.clear()
  self.current_point = None
}

///|
fn CurrentPath::move_to(self : CurrentPath, point : GraphicsPoint) -> Unit {
  if self.subpaths.length() > 0 {
    let last_index = self.subpaths.length() - 1
    let last = self.subpaths[last_index]
    if last.segments.length() == 0 && !last.closed {
      self.subpaths[last_index] = PathSubpath::{
        start: point,
        segments: [],
        current: point,
        closed: false,
      }
      self.current_point = Some(point)
      return
    }
  }
  self.subpaths.push(PathSubpath::{
    start: point,
    segments: [],
    current: point,
    closed: false,
  })
  self.current_point = Some(point)
}

///|
fn CurrentPath::line_to(
  self : CurrentPath,
  point : GraphicsPoint,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  self.append_segment(PathSegment::LineTo(point), point, offset)
}

///|
fn CurrentPath::curve_to(
  self : CurrentPath,
  control1 : GraphicsPoint,
  control2 : GraphicsPoint,
  end_point : GraphicsPoint,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  self.append_segment(
    PathSegment::CurveTo(control1, control2, end_point),
    end_point,
    offset,
  )
}

///|
fn CurrentPath::close_path(
  self : CurrentPath,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  self.require_current_point(offset) |> ignore
  let last_index = self.subpaths.length() - 1
  let last = self.subpaths[last_index]
  if !last.closed {
    let segments = last.segments.copy()
    segments.push(PathSegment::ClosePath)
    self.subpaths[last_index] = PathSubpath::{
      start: last.start,
      segments,
      current: last.start,
      closed: true,
    }
    self.current_point = Some(last.start)
  }
}

///|
fn CurrentPath::rectangle(self : CurrentPath, rect : GraphicsRect) -> Unit {
  let p0 = GraphicsPoint::new(rect.left, rect.bottom)
  let p1 = GraphicsPoint::new(rect.right, rect.bottom)
  let p2 = GraphicsPoint::new(rect.right, rect.top)
  let p3 = GraphicsPoint::new(rect.left, rect.top)
  self.subpaths.push(PathSubpath::{
    start: p0,
    segments: [
      PathSegment::LineTo(p1),
      PathSegment::LineTo(p2),
      PathSegment::LineTo(p3),
      PathSegment::ClosePath,
    ],
    current: p0,
    closed: true,
  })
  self.current_point = Some(p0)
}

///|
pub fn GraphicsPath::from_rect(rect : GraphicsRect) -> GraphicsPath {
  let path = CurrentPath::new()
  path.rectangle(rect)
  path.snapshot()
}

///|
pub fn GraphicsPath::copy(self : GraphicsPath) -> GraphicsPath {
  GraphicsPath::{ subpaths: copy_subpaths(self.subpaths) }
}

///|
pub fn ClipState::new(initial_clip : GraphicsPath?) -> ClipState {
  ClipState::{ initial_clip: copy_optional_path(initial_clip), clips: [] }
}

///|
pub fn ClipState::copy(self : ClipState) -> ClipState {
  let clips : Array[ClipEntry] = []
  for clip in self.clips {
    clips.push(ClipEntry::{ path: clip.path.copy(), rule: clip.rule })
  }
  ClipState::{ initial_clip: copy_optional_path(self.initial_clip), clips }
}

///|
pub fn ClipState::append_clip(
  self : ClipState,
  path : GraphicsPath,
  rule : FillRule,
) -> ClipState {
  let copy = self.copy()
  copy.clips.push(ClipEntry::{ path: path.copy(), rule })
  copy
}

///|
fn CurrentPath::append_segment(
  self : CurrentPath,
  segment : PathSegment,
  new_current : GraphicsPoint,
  offset : Int64,
) -> Unit raise PdfGraphicsError {
  self.require_current_point(offset) |> ignore
  let last_index = self.subpaths.length() - 1
  let last = self.subpaths[last_index]
  let segments = last.segments.copy()
  segments.push(segment)
  self.subpaths[last_index] = PathSubpath::{
    start: last.start,
    segments,
    current: new_current,
    closed: false,
  }
  self.current_point = Some(new_current)
}

///|
fn CurrentPath::require_current_point(
  self : CurrentPath,
  offset : Int64,
) -> GraphicsPoint raise PdfGraphicsError {
  match self.current_point {
    Some(point) => point
    None =>
      raise PdfGraphicsError::InvalidPathState(
        offset, "path construction requires a current point",
      )
  }
}

///|
fn copy_optional_path(path : GraphicsPath?) -> GraphicsPath? {
  match path {
    Some(value) => Some(value.copy())
    None => None
  }
}

///|
fn copy_subpaths(subpaths : Array[PathSubpath]) -> Array[PathSubpath] {
  let output : Array[PathSubpath] = []
  for subpath in subpaths {
    output.push(PathSubpath::{
      start: subpath.start,
      segments: subpath.segments.copy(),
      current: subpath.current,
      closed: subpath.closed,
    })
  }
  output
}
