/// A tidal extreme: a local maximum or minimum of the tide curve.
pub enum ExtremeKind {
  High
  Low
} derive(Eq, Debug)

pub struct TideExtreme {
  time_jd : Double
  height : Double
  kind : ExtremeKind
} derive(Debug)

/// Find high and low water by sampling the curve and locating local extrema.
pub fn find_extremes(
  station : Station,
  start_jd : Double,
  duration_hours : Double,
  step_hours : Double,
) -> Array[TideExtreme] {
  let samples = (@math.floor(duration_hours / step_hours)).to_int() + 1
  let heights = Array(capacity=samples)
  let times = Array(capacity=samples)
  for i = 0; i < samples; i = i + 1 {
    let jd = start_jd + i.to_double() * step_hours / 24.0
    times.push(jd)
    heights.push(tide_height(station, jd))
  }
  let extremes = Array(capacity=samples)
  for i = 1; i < samples - 1; i = i + 1 {
    let left = heights[i - 1]
    let middle = heights[i]
    let right = heights[i + 1]
    if middle > left && middle > right {
      extremes.push({ time_jd: times[i], height: middle, kind: ExtremeKind::High })
    } else if middle < left && middle < right {
      extremes.push({ time_jd: times[i], height: middle, kind: ExtremeKind::Low })
    }
  }
  extremes
}
