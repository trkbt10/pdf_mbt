///|
test "threshold array screens a single additive component" {
  let thresholds = ThresholdArray::{
    width: 2,
    height: 2,
    bits_per_sample: 8,
    values: [1, 128, 255, 64],
  }

  assert_eq(thresholds.screen_component(0.0, 0, 0), false)
  assert_eq(thresholds.screen_component(0.5, 1, 0), false)
  assert_eq(thresholds.screen_component(0.5, 1, 1), true)
  assert_eq(thresholds.screen_component(1.0, 2, 0), true)
}

///|
test "halftone screen generates threshold values from a spot function" {
  let screen = HalftoneScreen::new(120.0, 30.0, SpotFunction::CosineDot)
  let thresholds = screen.generate_threshold_array(3, 3)

  assert_eq(thresholds.width, 3)
  assert_eq(thresholds.height, 3)
  assert_eq(thresholds.bits_per_sample, 8)
  assert_eq(thresholds.values.length(), 9)
  thresholds.validate()
}

///|
test "spot function samples stay ordered for simple dot center" {
  let center = SpotFunction::SimpleDot.sample(0.0, 0.0)
  let corner = SpotFunction::SimpleDot.sample(1.0, 1.0)

  assert_eq(center > corner, true)
}
