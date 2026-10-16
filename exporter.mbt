///|
fn csv_cell(value : String) -> String {
  if value.contains(",") || value.contains("\"") || value.contains("\n") {
    "\"\{value.replace_all(old="\"", new="\"\"")}\""
  } else {
    value
  }
}

///|
fn ics_escape(value : String) -> String {
  value
  .replace_all(old="\\", new="\\\\")
  .replace_all(old=";", new="\\;")
  .replace_all(old=",", new="\\,")
  .replace_all(old="\n", new="\\n")
}

///|
fn ics_datetime(jd : Double, tz : Double) -> String {
  let (y, m, d, h) = jd_to_calendar(jd + tz / 24.0)
  let hh = @math.floor(h).to_int()
  let mm = @math.floor((h - hh.to_double()) * 60.0).to_int()
  let ss = @math.floor(((h - hh.to_double()) * 60.0 - mm.to_double()) * 60.0).to_int()
  let zz = if tz < 0.0 { "-" } else { "+" }
  let abs_tz = if tz < 0.0 { -tz } else { tz }
  let th = @math.floor(abs_tz).to_int()
  let tm = @math.round((abs_tz - th.to_double()) * 60.0).to_int()
  "\{y}\{pad2_export(m)}\{pad2_export(d)}T\{pad2_export(hh)}\{pad2_export(mm)}\{pad2_export(ss)}\{zz}\{pad2_export(th)}\{pad2_export(tm)}"
}

///|
fn pad2_export(n : Int32) -> String {
  if n < 10 {
    "0\{n}"
  } else {
    n.to_string()
  }
}

///|
/// Export a sampled tide curve as CSV.
pub fn samples_to_csv(samples : Array[TideSample], tz : Double) -> String {
  let lines = Array(capacity=samples.length() + 1)
  lines.push("time,height_m,rate_m_per_hour,state")
  for sample in samples {
    lines.push(
      "\{csv_cell(format_local_datetime(sample.jd, tz))},\{format_meters(sample.height)},\{format_meters(sample.rate)},\{csv_cell(state_label(sample.state))}",
    )
  }
  lines.join("\n")
}

///|
/// Export high/low water events as CSV.
pub fn extremes_to_csv(extremes : Array[TideExtreme], tz : Double) -> String {
  let lines = Array(capacity=extremes.length() + 1)
  lines.push("time,kind,height_m")
  for extreme in extremes {
    let kind = if extreme.kind == ExtremeKind::High { "high" } else { "low" }
    lines.push(
      "\{csv_cell(format_local_datetime(extreme.time_jd, tz))},\{kind},\{format_meters(extreme.height)}",
    )
  }
  lines.join("\n")
}

///|
/// Export high/low water events as an iCalendar feed.
pub fn extremes_to_ics(
  station : Station,
  extremes : Array[TideExtreme],
  tz : Double,
) -> String {
  let lines = Array(capacity=extremes.length() * 8 + 10)
  lines.push("BEGIN:VCALENDAR")
  lines.push("VERSION:2.0")
  lines.push("PRODID:-//MoonTide//Tide Events//CN")
  lines.push("CALSCALE:GREGORIAN")
  lines.push("METHOD:PUBLISH")
  for i = 0; i < extremes.length(); i = i + 1 {
    let extreme = extremes[i]
    let kind = if extreme.kind == ExtremeKind::High {
      "高潮"
    } else {
      "低潮"
    }
    lines.push("BEGIN:VEVENT")
    lines.push("UID:moontide-\{station.id}-\{i}@local")
    lines.push("DTSTAMP:\{ics_datetime(extremes[0].time_jd, tz)}")
    lines.push("DTSTART:\{ics_datetime(extreme.time_jd, tz)}")
    lines.push("SUMMARY:\{ics_escape("\{station.name} \{kind}")}")
    lines.push(
      "DESCRIPTION:\{ics_escape("潮高 \{format_meters(extreme.height)} m")}",
    )
    lines.push("END:VEVENT")
  }
  lines.push("END:VCALENDAR")
  lines.join("\r\n")
}

///|
/// Render one activity plan as Markdown.
pub fn plan_to_markdown(plan : ActivityPlan, tz : Double) -> String {
  let lines = Array(capacity=plan.windows.length() * 4 + 5)
  lines.push("## \{plan.activity}")
  lines.push("")
  lines.push(plan.note)
  lines.push("")
  if plan.windows.is_empty() {
    lines.push("暂无可推荐时段。")
  } else {
    for i = 0; i < plan.windows.length(); i = i + 1 {
      let item = plan.windows[i]
      lines.push(
        "\{i + 1}. \{format_local_datetime(item.window.start_jd, tz)} 至 \{format_local_datetime(item.window.end_jd, tz)}，评分 \{format_meters(item.score)}。\{item.reason}",
      )
    }
  }
  lines.join("\n")
}

///|
/// Render all activity plans as Markdown.
pub fn plans_to_markdown(plans : Array[ActivityPlan], tz : Double) -> String {
  let sections = Array(capacity=plans.length())
  for plan in plans {
    sections.push(plan_to_markdown(plan, tz))
  }
  sections.join("\n\n")
}

///|
/// Render descriptive statistics as Markdown.
pub fn stats_to_markdown(stats : TideStats, coefficient : Double) -> String {
  let lines = Array(capacity=12)
  lines.push("## 潮汐统计")
  lines.push("")
  lines.push("- 最低潮高：\{format_meters(stats.min_height)} m")
  lines.push("- 最高潮高：\{format_meters(stats.max_height)} m")
  lines.push("- 平均潮高：\{format_meters(stats.mean_height)} m")
  lines.push("- 潮差：\{format_meters(stats.range)} m")
  lines.push(
    "- 最大涨潮速率：\{format_meters(stats.max_flood_rate)} m/h",
  )
  lines.push("- 最大落潮速率：\{format_meters(stats.max_ebb_rate)} m/h")
  lines.push(
    "- 涨潮时间占比：\{format_meters(stats.rising_fraction * 100.0)}%",
  )
  lines.push("- 潮汐系数：\{format_meters(coefficient)}")
  lines.join("\n")
}

///|
/// Render a compact station inventory as Markdown.
pub fn stations_to_markdown(stations : Array[Station]) -> String {
  let lines = Array(capacity=stations.length() * 4 + 4)
  lines.push("# MoonTide 站点列表")
  lines.push("")
  lines.push("| ID | 名称 | 纬度 | 经度 | 平均潮差 | 数据来源 |")
  lines.push("| --- | --- | --- | --- | --- | --- |")
  for station in stations {
    lines.push(
      "| \{station.id} | \{station.name} | \{format_meters(station.lat)} | \{format_meters(station.lon)} | \{format_meters(mean_tidal_range(station))} m | \{station.source} |",
    )
  }
  lines.join("\n")
}

///|
/// Render a validation report as Markdown.
pub fn validation_to_markdown(issues : Array[ValidationIssue]) -> String {
  let lines = Array(capacity=issues.length() * 2 + 5)
  lines.push("## 站点校验")
  lines.push("")
  if issues.is_empty() {
    lines.push("未发现问题。")
  } else {
    for issue in issues {
      let level = match issue.level {
        ValidationLevel::Error => "错误"
        ValidationLevel::Warning => "警告"
        ValidationLevel::Info => "信息"
      }
      lines.push("- [\{level}] \{issue.message}")
    }
  }
  lines.join("\n")
}
