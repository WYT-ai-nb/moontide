///|
/// A scored activity window.
pub struct ScoredWindow {
  window : TideWindow
  score : Double
  reason : String
} derive(Debug)

///|
/// A ranked set of windows for one activity.
pub struct ActivityPlan {
  activity : String
  windows : Array[ScoredWindow]
  note : String
} derive(Debug)

///|
type TideExtremeList = Array[TideExtreme]

///|
fn clamp(value : Double, low : Double, high : Double) -> Double {
  if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
/// Number of overlapping hours between two windows.
pub fn overlap_hours(a : TideWindow, b : TideWindow) -> Double {
  let start = if a.start_jd > b.start_jd { a.start_jd } else { b.start_jd }
  let end = if a.end_jd < b.end_jd { a.end_jd } else { b.end_jd }
  let hours = (end - start) * 24.0
  if hours > 0.0 {
    hours
  } else {
    0.0
  }
}

///|
fn daylight_overlap(
  window : TideWindow,
  sunrise : Double,
  sunset : Double,
  tz : Double,
) -> Double {
  let start_hour = local_hour_of(window.start_jd, tz)
  let end_hour = local_hour_of(window.end_jd, tz)
  let start = if start_hour < end_hour { start_hour } else { 0.0 }
  let end = if start_hour < end_hour { end_hour } else { 24.0 }
  let overlap_start = if start > sunrise { start } else { sunrise }
  let overlap_end = if end < sunset { end } else { sunset }
  if overlap_end > overlap_start {
    overlap_end - overlap_start
  } else {
    0.0
  }
}

///|
/// Score a window for a low-tide activity such as beachcombing.
pub fn score_low_tide_window(
  window : TideWindow,
  sunrise : Double,
  sunset : Double,
  tz : Double,
  height_span : Double,
) -> Double {
  let day = daylight_overlap(window, sunrise, sunset, tz)
  let duration = (window.end_jd - window.start_jd) * 24.0
  let day_score = if duration <= 0.0 { 0.0 } else { day / duration }
  let span_score = clamp(height_span / 4.0, 0.0, 1.0)
  50.0 * day_score + 30.0 * span_score + 20.0
}

///|
/// Score a window for fishing during the start of a flood tide.
pub fn score_fishing_window(
  window : TideWindow,
  sunrise : Double,
  sunset : Double,
  tz : Double,
  flood_rate : Double,
) -> Double {
  let day = daylight_overlap(window, sunrise, sunset, tz)
  let duration = (window.end_jd - window.start_jd) * 24.0
  let day_score = if duration <= 0.0 { 0.0 } else { day / duration }
  let flow_score = clamp(flood_rate / 0.6, 0.0, 1.0)
  40.0 * day_score + 40.0 * flow_score + 20.0
}

///|
/// Rank windows by descending score.
pub fn rank_windows(windows : Array[ScoredWindow]) -> Array[ScoredWindow] {
  let ranked = windows.copy()
  ranked.sort_by(fn(a, b) {
    if a.score > b.score {
      -1
    } else if a.score < b.score {
      1
    } else {
      0
    }
  })
  ranked
}

///|
/// Build a beachcombing plan from high/low water extremes.
pub fn beach_plan(
  extremes : TideExtremeList,
  sunrise : Double,
  sunset : Double,
  tz : Double,
  range : Double,
) -> ActivityPlan {
  let windows = Array(capacity=extremes.length())
  for extreme in extremes {
    if extreme.kind == ExtremeKind::Low {
      let window = window_around(extreme, 1.5, 1.5, "赶海")
      windows.push({
        window,
        score: score_low_tide_window(window, sunrise, sunset, tz, range),
        reason: "低潮前后滩涂露出，适合赶海",
      })
    }
  }
  let ranked = rank_windows(windows)
  let note = if ranked.is_empty() {
    "本时间窗没有可用的低潮段。"
  } else {
    "优先选择白天且潮差较大的低潮窗口。"
  }
  { activity: "赶海", windows: ranked, note, }
}

///|
/// Build a fishing plan from low-water to high-water transitions.
pub fn fishing_activity_plan(
  extremes : TideExtremeList,
  sunrise : Double,
  sunset : Double,
  tz : Double,
  station : Station,
) -> ActivityPlan {
  let windows = Array(capacity=extremes.length())
  for i = 0; i < extremes.length(); i = i + 1 {
    let extreme = extremes[i]
    if extreme.kind == ExtremeKind::Low &&
      i + 1 < extremes.length() &&
      extremes[i + 1].kind == ExtremeKind::High {
      let window = window_around(extreme, 0.0, 2.0, "钓鱼")
      let mid_jd = (window.start_jd + window.end_jd) / 2.0
      let flood_rate = tide_rate(station, mid_jd, 0.1)
      windows.push({
        window,
        score: score_fishing_window(window, sunrise, sunset, tz, flood_rate),
        reason: "涨潮初期水流恢复，鱼群活动更活跃",
      })
    }
  }
  let ranked = rank_windows(windows)
  let note = if ranked.is_empty() {
    "本时间窗没有识别到明显的涨潮段。"
  } else {
    "涨潮初期的前两小时通常比平潮更容易出鱼。"
  }
  { activity: "钓鱼", windows: ranked, note, }
}

///|
/// Build a bird-watching plan from daytime low-water windows.
pub fn birding_plan(
  extremes : TideExtremeList,
  sunrise : Double,
  sunset : Double,
  tz : Double,
) -> ActivityPlan {
  let windows = Array(capacity=extremes.length())
  for extreme in extremes {
    if extreme.kind == ExtremeKind::Low {
      let window = window_around(extreme, 2.0, 2.0, "观鸟")
      windows.push({
        window,
        score: score_low_tide_window(window, sunrise, sunset, tz, 3.0),
        reason: "低潮滩涂暴露，水鸟集中觅食",
      })
    }
  }
  let ranked = rank_windows(windows)
  let note = if ranked.is_empty() {
    "本时间窗没有可用的白天低潮段。"
  } else {
    "建议在低潮前抵达并保持安静观察。"
  }
  { activity: "观鸟", windows: ranked, note, }
}

///|
/// Build all activity plans for a prediction.
pub fn plans_for(prediction : Prediction) -> Array[ActivityPlan] {
  [
    beach_plan(
      prediction.extremes,
      prediction.sunrise_hour,
      prediction.sunset_hour,
      prediction.tz,
      prediction.tidal_range,
    ),
    fishing_activity_plan(
      prediction.extremes,
      prediction.sunrise_hour,
      prediction.sunset_hour,
      prediction.tz,
      prediction.station,
    ),
    birding_plan(
      prediction.extremes,
      prediction.sunrise_hour,
      prediction.sunset_hour,
      prediction.tz,
    ),
  ]
}
