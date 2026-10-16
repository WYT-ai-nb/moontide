///|
fn dabs(x : Double) -> Double {
  if x < 0.0 {
    -x
  } else {
    x
  }
}

///|
fn two_digits(n : Int32) -> String {
  if n < 10 {
    "0\{n}"
  } else {
    n.to_string()
  }
}

///|
pub fn format_meters(x : Double) -> String {
  let negative = x < 0.0
  let cents = @math.round(dabs(x) * 100.0).to_int()
  let whole = cents / 100
  let frac = cents % 100
  let sign = if negative { "-" } else { "" }
  "\{sign}\{whole}.\{two_digits(frac)}"
}

///|
fn tz_label(tz : Double) -> String {
  let sign = if tz < 0.0 { "-" } else { "+" }
  let hours = @math.floor(dabs(tz)).to_int()
  let minutes = @math.round((dabs(tz) - hours.to_double()) * 60.0).to_int()
  if minutes == 0 {
    "UTC\{sign}\{hours}"
  } else {
    "UTC\{sign}\{hours}:\{two_digits(minutes)}"
  }
}

///|
fn format_clock(hour : Double) -> String {
  let h = hour - 24.0 * @math.floor(hour / 24.0)
  let hh = @math.floor(h).to_int()
  let mm = @math.floor((h - hh.to_double()) * 60.0).to_int()
  "\{two_digits(hh)}:\{two_digits(mm)}"
}

///|
fn lat_label(lat : Double) -> String {
  let ns = if lat >= 0.0 { "北纬" } else { "南纬" }
  "\{ns} \{format_meters(dabs(lat))}°"
}

///|
fn lon_label(lon : Double) -> String {
  let ew = if lon >= 0.0 { "东经" } else { "西经" }
  "\{ew} \{format_meters(dabs(lon))}°"
}

///|
/// Render an ASCII tide curve over a window.
pub fn render_curve(
  station : Station,
  start_jd : Double,
  duration_hours : Double,
  step_hours : Double,
  tz : Double,
) -> String {
  let samples = @math.floor(duration_hours / step_hours).to_int() + 1
  let heights = Array(capacity=samples)
  let times = Array(capacity=samples)
  for i = 0; i < samples; i = i + 1 {
    let jd = start_jd + i.to_double() * step_hours / 24.0
    times.push(jd)
    heights.push(tide_height(station, jd))
  }

  let mut lo = heights[0]
  let mut hi = heights[0]
  for h in heights {
    if h < lo {
      lo = h
    }
    if h > hi {
      hi = h
    }
  }
  let span = if hi - lo < 0.0001 { 1.0 } else { hi - lo }

  let rows = 15
  let grid = Array::makei(rows, fn(_) { Array::makei(samples, fn(_) { '.' }) })

  // Mark extremes first so they stay visible even when the curve overlaps.
  let extremes = find_extremes(station, start_jd, duration_hours, step_hours)
  for e in extremes {
    let col = @math.round((e.time_jd - start_jd) / (step_hours / 24.0)).to_int()
    if col >= 0 && col < samples {
      let row = @math.round((hi - e.height) / span * (rows - 1).to_double()).to_int()
      let clamped = if row < 0 {
        0
      } else if row >= rows {
        rows - 1
      } else {
        row
      }
      grid[clamped][col] = if e.kind == ExtremeKind::High { 'H' } else { 'L' }
    }
  }

  // Draw the curve.
  for i = 0; i < samples; i = i + 1 {
    let row = @math.round((hi - heights[i]) / span * (rows - 1).to_double()).to_int()
    let clamped = if row < 0 { 0 } else if row >= rows { rows - 1 } else { row }
    if grid[clamped][i] == '.' {
      grid[clamped][i] = '#'
    }
  }

  let lines = Array(capacity=rows + 4)
  lines.push(
    "潮高范围：\{format_meters(hi)} m（顶）到 \{format_meters(lo)} m（底），每格 \{format_meters(step_hours)} 小时",
  )
  for r = 0; r < rows; r = r + 1 {
    lines.push(String::from_iter(grid[r].iter()))
  }

  // Time axis: one label every six hours.
  let tick_hours = 6.0
  let labels = Array(
    capacity=@math.floor(duration_hours / tick_hours).to_int() + 2,
  )
  let mut k = 0
  for t = 0.0; t <= duration_hours; t = t + tick_hours {
    labels.push(format_local_time(start_jd + t / 24.0, tz))
    k = k + 1
  }
  lines.push(labels.join("  "))
  lines.join("\n")
}

///|
/// Render a full Markdown prediction report.
pub fn render_report(p : Prediction) -> String {
  let lines = Array(capacity=80)
  lines.push("# MoonTide 潮汐预测")
  lines.push("")
  lines.push("- 站点：\{p.station.name}（\{p.station.id}）")
  lines.push(
    "- 位置：\{lat_label(p.station.lat)}，\{lon_label(p.station.lon)}",
  )
  lines.push(
    "- 时间窗：\{format_local_datetime(p.start_jd, p.tz)} 起 \{format_meters(p.duration_hours)} 小时（\{tz_label(p.tz)}）",
  )
  lines.push("- 天文期：\{p.spring_neap}")
  lines.push("- 潮差：\{format_meters(p.tidal_range)} m")
  lines.push(
    "- 日出/日落：\{format_clock(p.sunrise_hour)} / \{format_clock(p.sunset_hour)}（近似）",
  )
  lines.push("")
  lines.push("## 高低潮")
  lines.push("")
  if p.extremes.is_empty() {
    lines.push("本时间窗内未识别到高低潮。")
  } else {
    lines.push("| 时刻 | 类型 | 潮高 |")
    lines.push("| --- | --- | --- |")
    for e in p.extremes {
      let kind = if e.kind == ExtremeKind::High { "高潮" } else { "低潮" }
      lines.push(
        "| \{format_local_datetime(e.time_jd, p.tz)} | \{kind} | \{format_meters(e.height)} m |",
      )
    }
  }
  lines.push("")
  lines.push("## 活动建议")
  lines.push("")
  for activity in p.activities {
    lines.push("### \{activity.title}")
    lines.push("")
    lines.push(activity.detail)
    if !activity.windows.is_empty() {
      lines.push("")
      lines.push("推荐时段：\{activity.windows.join("、")}")
    }
    lines.push("")
  }
  lines.push("## 潮汐曲线")
  lines.push("")
  lines.push("```text")
  lines.push(render_curve(p.station, p.start_jd, p.duration_hours, 1.0, p.tz))
  lines.push("```")
  lines.push("")
  lines.push(
    "> 内置站点常数仅用于演示，正式使用请以当地《潮汐表》或海洋站发布的调和常数为准。",
  )
  lines.join("\n")
}

///|
/// Render a prediction as compact JSON-compatible text.
pub fn render_json(p : Prediction) -> String {
  let extremes = Array(capacity=p.extremes.length())
  for e in p.extremes {
    let kind = if e.kind == ExtremeKind::High { "high" } else { "low" }
    extremes.push(
      "{\"time\":\"\{format_local_datetime(e.time_jd, p.tz)}\",\"kind\":\"\{kind}\",\"height\":\{format_meters(e.height)}}",
    )
  }
  let activities = Array(capacity=p.activities.length())
  for a in p.activities {
    let windows = a.windows.map(w => "\"\{w}\"").join(",")
    activities.push(
      "{\"title\":\"\{a.title}\",\"detail\":\"\{a.detail}\",\"windows\":[\{windows}]}",
    )
  }
  "{\"station\":\"\{p.station.name}\",\"tidal_range\":\{format_meters(p.tidal_range)},\"spring_neap\":\"\{p.spring_neap}\",\"extremes\":[\{extremes.join(",")}],\"activities\":[\{activities.join(",")}]}"
}
