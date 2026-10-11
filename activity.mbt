/// A recommended activity with an explanation and one or more time windows.
pub struct Activity {
  title : String
  detail : String
  windows : Array[String]
} derive(Debug)

fn in_daylight(local_hour : Double, sunrise : Double, sunset : Double) -> Bool {
  local_hour >= sunrise && local_hour <= sunset
}

fn window(low_jd : Double, before : Double, after : Double, tz : Double) -> String {
  let start = low_jd - before / 24.0
  let end = low_jd + after / 24.0
  "\{format_local_time(start, tz)} - \{format_local_time(end, tz)}"
}

/// Build activity suggestions from tidal extremes and the daylight window.
pub fn recommend(
  extremes : Array[TideExtreme],
  sunrise : Double,
  sunset : Double,
  tz : Double,
) -> Array[Activity] {
  let beach_windows = Array(capacity=extremes.length())
  let bird_windows = Array(capacity=extremes.length())
  let fishing_windows = Array(capacity=extremes.length())

  for i = 0; i < extremes.length(); i = i + 1 {
    let e = extremes[i]
    let hour = local_hour_of(e.time_jd, tz)
    if e.kind == ExtremeKind::Low {
      if e.height <= -0.1 && in_daylight(hour, sunrise, sunset) {
        beach_windows.push(window(e.time_jd, 1.5, 1.5, tz))
      }
      if in_daylight(hour, sunrise, sunset) {
        bird_windows.push(window(e.time_jd, 2.0, 2.0, tz))
      }
      // Rising tide follows a low water; recommend the first two hours of the flood.
      if i + 1 < extremes.length() && extremes[i + 1].kind == ExtremeKind::High {
        fishing_windows.push(window(e.time_jd, 0.0, 2.0, tz))
      }
    }
  }

  let beach = if beach_windows.is_empty() {
    "今日最低潮位偏高，暂不推荐赶海。"
  } else {
    "在最低潮前后 1.5 小时为最佳赶海时段。"
  }
  let birds = if bird_windows.is_empty() {
    "今日最低潮不在白天，观鸟条件一般。"
  } else {
    "低潮会露出滩涂，候鸟集中觅食，建议提前抵达。"
  }
  let fishing = if fishing_windows.is_empty() {
    "本窗口内未识别到明显的涨潮段。"
  } else {
    "涨潮初期（低潮后两小时）鱼群活动较活跃。"
  }

  [
    { title: "赶海", detail: beach, windows: beach_windows },
    { title: "钓鱼", detail: fishing, windows: fishing_windows },
    { title: "观鸟", detail: birds, windows: bird_windows },
  ]
}
