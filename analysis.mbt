///|
/// The instantaneous direction of the tide.
pub enum TideState {
  Rising
  Falling
  HighSlack
  LowSlack
} derive(Eq, Debug)

///|
/// One sampled point on a tide curve.
pub struct TideSample {
  jd : Double
  height : Double
  rate : Double
  state : TideState
} derive(Debug)

///|
/// Aggregate information about a sampled tide series.
pub struct TideStats {
  min_height : Double
  max_height : Double
  mean_height : Double
  range : Double
  max_flood_rate : Double
  max_ebb_rate : Double
  rising_fraction : Double
} derive(Debug)

///|
/// A closed interval on the tide timeline.
pub struct TideWindow {
  start_jd : Double
  end_jd : Double
  label : String
} derive(Debug)

///|
/// Approximate rate of change in meters per hour.
pub fn tide_rate(
  station : Station,
  jd : Double,
  delta_hours : Double,
) -> Double {
  let delta = if delta_hours <= 0.0 { 0.05 } else { delta_hours }
  let before = tide_height(station, jd - delta / 24.0)
  let after = tide_height(station, jd + delta / 24.0)
  (after - before) / (2.0 * delta)
}

///|
/// Classify a tide point by its local rate and height.
pub fn tide_state(
  station : Station,
  jd : Double,
  tolerance : Double,
) -> TideState {
  let rate = tide_rate(station, jd, 0.05)
  if rate > tolerance {
    Rising
  } else if rate < -tolerance {
    Falling
  } else {
    let height = tide_height(station, jd)
    if height >= station.datum {
      HighSlack
    } else {
      LowSlack
    }
  }
}

///|
/// Sample a station over a time window.
pub fn sample_series(
  station : Station,
  start_jd : Double,
  duration_hours : Double,
  step_hours : Double,
) -> Array[TideSample] {
  let step = if step_hours <= 0.0 { 1.0 } else { step_hours }
  let count = @math.floor(duration_hours / step).to_int() + 1
  let samples = Array(capacity=count)
  for i = 0; i < count; i = i + 1 {
    let jd = start_jd + i.to_double() * step / 24.0
    samples.push({
      jd,
      height: tide_height(station, jd),
      rate: tide_rate(station, jd, 0.05),
      state: tide_state(station, jd, 0.005),
    })
  }
  samples
}

///|
/// Compute descriptive statistics from a sampled series.
pub fn compute_stats(samples : Array[TideSample]) -> TideStats {
  if samples.is_empty() {
    return {
      min_height: 0.0,
      max_height: 0.0,
      mean_height: 0.0,
      range: 0.0,
      max_flood_rate: 0.0,
      max_ebb_rate: 0.0,
      rising_fraction: 0.0,
    }
  }
  let mut min_height = samples[0].height
  let mut max_height = samples[0].height
  let mut sum = 0.0
  let mut max_flood = 0.0
  let mut max_ebb = 0.0
  let mut rising = 0
  for sample in samples {
    if sample.height < min_height {
      min_height = sample.height
    }
    if sample.height > max_height {
      max_height = sample.height
    }
    sum = sum + sample.height
    if sample.rate > max_flood {
      max_flood = sample.rate
    }
    if sample.rate < max_ebb {
      max_ebb = sample.rate
    }
    if sample.state == TideState::Rising {
      rising = rising + 1
    }
  }
  {
    min_height,
    max_height,
    mean_height: sum / samples.length().to_double(),
    range: max_height - min_height,
    max_flood_rate: max_flood,
    max_ebb_rate: max_ebb,
    rising_fraction: rising.to_double() / samples.length().to_double(),
  }
}

///|
/// Find the next high or low water after `jd`.
pub fn find_next_extreme(
  station : Station,
  jd : Double,
  horizon_hours : Double,
  step_hours : Double,
) -> TideExtreme? {
  let step = if step_hours <= 0.0 { 0.1 } else { step_hours }
  let extremes = find_extremes(station, jd, horizon_hours, step)
  if extremes.is_empty() {
    None
  } else {
    Some(extremes[0])
  }
}

///|
/// Build a time window around an extreme.
pub fn window_around(
  extreme : TideExtreme,
  before_hours : Double,
  after_hours : Double,
  label : String,
) -> TideWindow {
  {
    start_jd: extreme.time_jd - before_hours / 24.0,
    end_jd: extreme.time_jd + after_hours / 24.0,
    label,
  }
}

///|
/// Test whether a window contains a Julian day.
pub fn window_contains(window : TideWindow, jd : Double) -> Bool {
  jd >= window.start_jd && jd <= window.end_jd
}

///|
/// Merge overlapping or touching windows.
pub fn merge_windows(windows : Array[TideWindow]) -> Array[TideWindow] {
  if windows.is_empty() {
    return []
  }
  let sorted = windows.copy()
  sorted.sort_by(fn(a, b) {
    if a.start_jd < b.start_jd {
      -1
    } else if a.start_jd > b.start_jd {
      1
    } else {
      0
    }
  })
  let merged = Array(capacity=sorted.length())
  let first = sorted[0]
  merged.push(first)
  for i = 1; i < sorted.length(); i = i + 1 {
    let current = sorted[i]
    let last = merged[merged.length() - 1]
    if current.start_jd <= last.end_jd {
      if current.end_jd > last.end_jd {
        merged[merged.length() - 1] = {
          start_jd: last.start_jd,
          end_jd: current.end_jd,
          label: last.label,
        }
      }
    } else {
      merged.push(current)
    }
  }
  merged
}

///|
/// Produce windows around every low water in a series.
pub fn low_water_windows(
  extremes : Array[TideExtreme],
  before_hours : Double,
  after_hours : Double,
) -> Array[TideWindow] {
  let windows = Array(capacity=extremes.length())
  for extreme in extremes {
    if extreme.kind == ExtremeKind::Low {
      windows.push(
        window_around(extreme, before_hours, after_hours, "低潮窗口"),
      )
    }
  }
  merge_windows(windows)
}

///|
/// Produce windows around every high water in a series.
pub fn high_water_windows(
  extremes : Array[TideExtreme],
  before_hours : Double,
  after_hours : Double,
) -> Array[TideWindow] {
  let windows = Array(capacity=extremes.length())
  for extreme in extremes {
    if extreme.kind == ExtremeKind::High {
      windows.push(
        window_around(extreme, before_hours, after_hours, "高潮窗口"),
      )
    }
  }
  merge_windows(windows)
}

///|
/// Return the dominant state in a sampled series.
pub fn dominant_state(samples : Array[TideSample]) -> TideState {
  let mut rising = 0
  let mut falling = 0
  let mut high = 0
  let mut low = 0
  for sample in samples {
    match sample.state {
      TideState::Rising => rising = rising + 1
      TideState::Falling => falling = falling + 1
      TideState::HighSlack => high = high + 1
      TideState::LowSlack => low = low + 1
    }
  }
  if rising >= falling && rising >= high && rising >= low {
    Rising
  } else if falling >= high && falling >= low {
    Falling
  } else if high >= low {
    HighSlack
  } else {
    LowSlack
  }
}

///|
/// Convert the dominant state to a human-readable label.
pub fn state_label(state : TideState) -> String {
  match state {
    TideState::Rising => "涨潮"
    TideState::Falling => "落潮"
    TideState::HighSlack => "高潮平潮"
    TideState::LowSlack => "低潮平潮"
  }
}

///|
/// Compute the tide coefficient using the range relative to the mean range.
pub fn tide_coefficient(tidal_range : Double, mean_range : Double) -> Double {
  if mean_range <= 0.0 {
    0.0
  } else {
    tidal_range / mean_range * 100.0
  }
}

///|
/// Return true when a range is above the spring threshold.
pub fn is_spring(tidal_range : Double, mean_range : Double) -> Bool {
  tide_coefficient(tidal_range, mean_range) >= 110.0
}

///|
/// Return true when a range is below the neap threshold.
pub fn is_neap(tidal_range : Double, mean_range : Double) -> Bool {
  tide_coefficient(tidal_range, mean_range) <= 70.0
}
