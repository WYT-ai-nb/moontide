fn find_arg(args : Array[String], name : String) -> String? {
  for i = 0; i < args.length(); i = i + 1 {
    if args[i] == name && i + 1 < args.length() {
      return Some(args[i + 1])
    }
  }
  None
}

fn parse_double_arg(args : Array[String], name : String, default : Double) -> Double {
  match find_arg(args, name) {
    Some(value) =>
      try @string.parse_double(value) catch {
        _ => default
      }
    None => default
  }
}

fn print_help() -> Unit {
  println("MoonTide - 本地优先的潮汐与海岸活动预测")
  println("")
  println("用法:")
  println("  moontide list")
  println("  moontide validate --station demo")
  println("  moontide predict --station demo --date 2026-10-12 --tz 8 --hours 24")
  println("  moontide stats --station demo --date 2026-10-12 --hours 48")
  println("  moontide events --station demo --date 2026-10-12 --format csv")
  println("  moontide curve --station demo --date 2026-10-12")
  println("  moontide plan --station demo --date 2026-10-12")
  println("  moontide export --station demo --date 2026-10-12 --format ics")
  println("")
  println("选项:")
  println("  --station <id>        内置站点（demo / qingdao / xiamen）")
  println("  --date <YYYY-MM-DD>   预测起始日期")
  println("  --tz <offset>         UTC 偏移小时数，默认 8")
  println("  --hours <n>           预测时长小时数，默认 24")
  println("  --format <fmt>        markdown、json、csv 或 ics")
}

fn load_station(args : Array[String]) -> @lib.Station? {
  let id = find_arg(args, "--station").unwrap_or("demo")
  match @lib.find_station(id) {
    Some(s) => Some(s)
    None => {
      println("未找到内置站点: \{id}")
      None
    }
  }
}

fn load_prediction(args : Array[String]) -> @lib.Prediction? {
  let station = match load_station(args) {
    Some(s) => s
    None => return None
  }
  let date = find_arg(args, "--date").unwrap_or("2026-10-12")
  let tz = parse_double_arg(args, "--tz", 8.0)
  let hours = parse_double_arg(args, "--hours", 24.0)
  match @lib.predict_on(station, date, tz, hours) {
    Some(prediction) => Some(prediction)
    None => {
      println("日期格式无效（应为 YYYY-MM-DD 或 YYYY-MM-DD HH:MM）: \{date}")
      None
    }
  }
}

fn list_stations() -> Unit {
  println(@lib.stations_to_markdown(@lib.builtin_stations()))
}

fn validate_station(args : Array[String]) -> Unit {
  let station = match load_station(args) {
    Some(s) => s
    None => return
  }
  let tz = parse_double_arg(args, "--tz", 8.0)
  let hours = parse_double_arg(args, "--hours", 24.0)
  let issues = @lib.validate_station(station)
  issues.append(@lib.validate_timezone(tz))
  issues.append(@lib.validate_hours(hours))
  println(@lib.validation_to_markdown(issues))
}

fn print_stats(args : Array[String]) -> Unit {
  let prediction = match load_prediction(args) {
    Some(p) => p
    None => return
  }
  let samples = @lib.sample_series(prediction.station, prediction.start_jd, prediction.duration_hours, 1.0 / 12.0)
  let stats = @lib.compute_stats(samples)
  let coefficient = @lib.tide_coefficient(stats.range, @lib.mean_tidal_range(prediction.station))
  println(@lib.stats_to_markdown(stats, coefficient))
  println("")
  println("主导状态: \{@lib.state_label(@lib.dominant_state(samples))}")
}

fn print_events(args : Array[String]) -> Unit {
  let prediction = match load_prediction(args) {
    Some(p) => p
    None => return
  }
  let format = find_arg(args, "--format").unwrap_or("markdown")
  if format == "csv" {
    println(@lib.extremes_to_csv(prediction.extremes, prediction.tz))
  } else if format == "json" {
    println(@lib.render_json(prediction))
  } else {
    for extreme in prediction.extremes {
      let kind = if extreme.kind == @lib.ExtremeKind::High {
        "高潮"
      } else {
        "低潮"
      }
      println("\{@lib.format_local_datetime(extreme.time_jd, prediction.tz)}  \{kind}  \{@lib.format_meters(extreme.height)} m")
    }
  }
}

fn print_curve(args : Array[String]) -> Unit {
  let prediction = match load_prediction(args) {
    Some(p) => p
    None => return
  }
  println(@lib.render_curve(prediction.station, prediction.start_jd, prediction.duration_hours, 1.0, prediction.tz))
}

fn print_plan(args : Array[String]) -> Unit {
  let prediction = match load_prediction(args) {
    Some(p) => p
    None => return
  }
  println(@lib.plans_to_markdown(@lib.plans_for(prediction), prediction.tz))
}

fn export_prediction(args : Array[String]) -> Unit {
  let prediction = match load_prediction(args) {
    Some(p) => p
    None => return
  }
  let format = find_arg(args, "--format").unwrap_or("csv")
  if format == "ics" {
    println(@lib.extremes_to_ics(prediction.station, prediction.extremes, prediction.tz))
  } else if format == "json" {
    println(@lib.render_json(prediction))
  } else {
    let samples = @lib.sample_series(prediction.station, prediction.start_jd, prediction.duration_hours, 1.0 / 12.0)
    println(@lib.samples_to_csv(samples, prediction.tz))
  }
}

fn main {
  let args = @env.args()
  if args.contains("--help") || args.contains("-h") {
    print_help()
    return
  }
  if args.contains("list") {
    list_stations()
    return
  }
  if args.contains("validate") {
    validate_station(args)
    return
  }
  if args.contains("stats") {
    print_stats(args)
    return
  }
  if args.contains("events") {
    print_events(args)
    return
  }
  if args.contains("curve") {
    print_curve(args)
    return
  }
  if args.contains("plan") {
    print_plan(args)
    return
  }
  if args.contains("export") {
    export_prediction(args)
    return
  }
  if !args.contains("predict") {
    print_help()
    return
  }
  let prediction = match load_prediction(args) {
    Some(p) => p
    None => return
  }
  let format = find_arg(args, "--format").unwrap_or("markdown")
  if format == "json" {
    println(@lib.render_json(prediction))
  } else {
    println(@lib.render_report(prediction))
  }
}
