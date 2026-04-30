///|
/// Section 8.6.6.1 General, "Special colour spaces": special colour spaces add
/// features or properties to an underlying colour space. The four special
/// colour space families are Pattern, Indexed, Separation, and DeviceN; they
/// provide patterns, colour mapping, separations, high-fidelity colour, and
/// multitone colour. Section 8.6.6.2 Pattern colour spaces says a Pattern
/// colour space (PDF 1.2) specifies that an area is to be painted with a
/// pattern rather than a single colour, and "Patterns" discusses patterns in
/// detail. Section 8.6.6.3 Indexed colour spaces then specifies a colour map or
/// colour table of arbitrary colours in some other colour space.
pub(all) enum ColourRestriction {
  Normal
  UncolouredTilingPattern
  Type3Glyph
} derive(Eq, Debug)

///|
fn ColourRestriction::is_restricted(self : ColourRestriction) -> Bool {
  match self {
    Normal => false
    UncolouredTilingPattern | Type3Glyph => true
  }
}
