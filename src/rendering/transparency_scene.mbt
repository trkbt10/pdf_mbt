///|
/// Paint categories that participate in a PDF transparency stack. Fills,
/// strokes, text, images, shadings, form groups, and patterns are ordered from
/// bottom to top before later compositing against a backdrop with shape,
/// opacity, alpha constants, soft masks, blend modes, and colour-space policy.
pub(all) enum TransparencyPaintKind {
  PathFillPaint
  PathStrokePaint
  ImagePaint
  InlineImagePaint
  ShadingPaint
  TextGlyphPaint
  FormGroupPaint
  PatternPaint
  UnsupportedTransparencyPaint(String)
} derive(Eq, Debug)

///|
/// Returns whether this paint kind contributes an enclosing object to the
/// transparent imaging model. Unsupported entries are retained for diagnostics
/// but are not treated as stack objects during compositing.
pub fn TransparencyPaintKind::contributes_to_transparency_stack(
  self : TransparencyPaintKind,
) -> Bool {
  match self {
    UnsupportedTransparencyPaint(_) => false
    _ => true
  }
}

///|
pub(all) struct TransparencyPaint {
  offset : Int64
  kind : TransparencyPaintKind
  state : @graphics.GraphicsState
  source_colour : @graphics.ColourValue?
  shape_source : String
  opacity_source : String
  alpha_constant : Double
  soft_mask : @graphics.EstablishedSoftMask
  blend_mode : @graphics.BlendMode
  overprint_stroking : Bool
  overprint_nonstroking : Bool
  rendering_intent : @graphics.RenderingIntent
  black_point_compensation : @graphics.BlackPointCompensation
} derive(Eq, Debug)

///|
pub(all) struct TransparencyScene {
  paints : Array[TransparencyPaint]
} derive(Eq, Debug)

///|
pub(all) enum TransparencyPatternPaintKind {
  TilingPatternTransparency
  ShadingPatternTransparency
} derive(Eq, Debug)

///|
pub(all) struct TransparencyPatternPolicy {
  kind : TransparencyPatternPaintKind
  implicit_non_isolated_group : Bool
  knockout : Bool
  resets_transparency_parameters : Bool
  group_state : @graphics.GraphicsState
} derive(Eq, Debug)

///|
pub fn build_transparency_scene(
  graphics : @graphics.GraphicsProgram,
  text? : @text.TextProgram = @text.TextProgram::empty(),
) -> TransparencyScene {
  let paints : Array[TransparencyPaint] = []
  for event in graphics.events {
    match event {
      @graphics.GraphicsEvent::PathPainted(offset, operation, _, state) =>
        append_transparency_path_paint(paints, offset, operation, state)
      @graphics.GraphicsEvent::ImagePainted(offset, _, state) =>
        paints.push(
          transparency_paint_from_state(offset, ImagePaint, state, false),
        )
      @graphics.GraphicsEvent::InlineImagePainted(offset, _, state) =>
        paints.push(
          transparency_paint_from_state(offset, InlineImagePaint, state, false),
        )
      @graphics.GraphicsEvent::ShadingPainted(offset, _, state) =>
        paints.push(
          transparency_paint_from_state(offset, ShadingPaint, state, false),
        )
      @graphics.GraphicsEvent::FormXObjectBegan(offset, form, state) =>
        if form.has_transparency_group() {
          paints.push(
            transparency_paint_from_state(offset, FormGroupPaint, state, false),
          )
        }
      @graphics.GraphicsEvent::PatternColourSelected(
        offset,
        colour_use,
        _,
        _,
        state
      ) =>
        paints.push(
          transparency_paint_from_state(
            offset,
            PatternPaint,
            state,
            colour_use == @graphics.ColourUse::Stroking,
          ),
        )
      _ => ()
    }
  }
  for event in text.events {
    match event {
      @text.TextEvent::GlyphShown(glyph) =>
        if !glyph.paint.invisible {
          paints.push(
            transparency_paint_from_state(
              glyph.offset,
              TextGlyphPaint,
              graphics.final_state,
              false,
            ),
          )
        }
      _ => ()
    }
  }
  sort_transparency_paints(paints)
  TransparencyScene::{ paints, }
}

///|
pub fn transparency_pattern_policy(
  kind : TransparencyPatternPaintKind,
  state : @graphics.GraphicsState,
) -> TransparencyPatternPolicy {
  let group_state = state.copy()
  group_state.reset_transparency_parameters()
  TransparencyPatternPolicy::{
    kind,
    implicit_non_isolated_group: true,
    knockout: true,
    resets_transparency_parameters: true,
    group_state,
  }
}

///|
fn append_transparency_path_paint(
  paints : Array[TransparencyPaint],
  offset : Int64,
  operation : @graphics.PathPaintOperation,
  state : @graphics.GraphicsState,
) -> Unit {
  match operation {
    StrokePath | CloseStrokePath =>
      paints.push(
        transparency_paint_from_state(offset, PathStrokePaint, state, true),
      )
    FillPath(_) =>
      paints.push(
        transparency_paint_from_state(offset, PathFillPaint, state, false),
      )
    FillStrokePath(_) | CloseFillStrokePath(_) => {
      paints.push(
        transparency_paint_from_state(offset, PathFillPaint, state, false),
      )
      paints.push(
        transparency_paint_from_state(offset, PathStrokePaint, state, true),
      )
    }
    EndPath => ()
  }
}

///|
fn transparency_paint_from_state(
  offset : Int64,
  kind : TransparencyPaintKind,
  state : @graphics.GraphicsState,
  stroking : Bool,
) -> TransparencyPaint {
  let colour_use = if stroking {
    @graphics.ColourUse::Stroking
  } else {
    @graphics.ColourUse::Nonstroking
  }
  TransparencyPaint::{
    offset,
    kind,
    state,
    source_colour: Some(state.current_colour_value(colour_use)),
    shape_source: "geometry",
    opacity_source: "graphics state",
    alpha_constant: if stroking {
      state.alpha_stroking
    } else {
      state.alpha_nonstroking
    },
    soft_mask: state.soft_mask,
    blend_mode: state.blend_mode,
    overprint_stroking: state.overprint_stroking,
    overprint_nonstroking: state.overprint_nonstroking,
    rendering_intent: state.rendering_intent,
    black_point_compensation: state.black_point_compensation,
  }
}

///|
fn sort_transparency_paints(paints : Array[TransparencyPaint]) -> Unit {
  for i in 0..<paints.length() {
    for j in (i + 1)..<paints.length() {
      if paints[j].offset < paints[i].offset {
        let temp = paints[i]
        paints[i] = paints[j]
        paints[j] = temp
      }
    }
  }
}
