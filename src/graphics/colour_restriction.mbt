///|
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
