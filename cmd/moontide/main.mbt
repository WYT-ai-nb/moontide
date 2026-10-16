///|
fn find_arg(args : Array[String], name : String) -> String? {
  for i = 0; i < args.length(); i = i + 1 {
    if args[i] == name && i + 1 < args.length() {
      return Some(args[i + 1])
    }
  }
  None
}

///|
fn parse_double_arg(
  args : Array[String],
  name : String,
  default : Double,
) -> Double {
  match find_arg(args, name) {
    Some(value) => @string.parse_double(value) catch { _ => default }
    None => default
  }
}

///|
fn print_help() -> Unit {
  println("MoonTide - local-first tide and coastal activity prediction")
  println("")
  println("Usage:")
  println("  moontide list")
  println("  moontide validate --station demo")
  println(
    "  moontide predict --station demo --date 2026-10-12 --tz 8 --hours 24",
  )
  println("  moontide stats --station demo --date 2026-10-12 --hours 48")
  println("  moontide events --station demo --date 2026-10-12 --format csv")
  println("  moontide curve --station demo --date 2026-10-12")
  println("  moontide plan --station demo --date 2026-10-12")
  println("  moontide export --station demo --date 2026-10-12 --format ics")
  println(
    "  moontide validate-reference --metadata <file> --harcon <file> --datums <file> --predictions <file>",
  )
  println("")
  println("Common options:")
  println("  --station <id>         Built-in station: demo, qingdao, xiamen")
  println("  --date <YYYY-MM-DD>    Prediction start date")
  println("  --tz <offset>          UTC offset in hours, default 8")
  println("  --hours <n>            Prediction duration, default 24")
  println("  --format <fmt>         markdown, json, csv, or ics")
  println("  --metadata <file>      NOAA station metadata JSON")
  println("  --harcon <file>        NOAA harmonic constituents JSON")
  println("  --datums <file>        NOAA datum JSON")
  println("  --predictions <file>   NOAA prediction JSON")
  println("  --tolerance <m>        Mean-error threshold, default 0.3 m")
}

///|
fn load_station(args : Array[String]) -> @lib.Station? {
  let id = find_arg(args, "--station").unwrap_or("demo")
  match @lib.find_station(id) {
    Some(station) => Some(station)
    None => {
      println("Unknown built-in station: " + id)
      None
    }
  }
}

///|
fn load_prediction(args : Array[String]) -> @lib.Prediction? {
  let station = match load_station(args) {
    Some(value) => value
    None => return None
  }
  let date = find_arg(args, "--date").unwrap_or("2026-10-12")
  let tz = parse_double_arg(args, "--tz", 8.0)
  let hours = parse_double_arg(args, "--hours", 24.0)
  match @lib.predict_on(station, date, tz, hours) {
    Some(prediction) => Some(prediction)
    None => {
      println("Invalid date (expected YYYY-MM-DD or YYYY-MM-DD HH:MM): " + date)
      None
    }
  }
}

///|
fn list_stations() -> Unit {
  println(@lib.stations_to_markdown(@lib.builtin_stations()))
}

///|
fn validate_station(args : Array[String]) -> Unit {
  let station = match load_station(args) {
    Some(value) => value
    None => return
  }
  let tz = parse_double_arg(args, "--tz", 8.0)
  let hours = parse_double_arg(args, "--hours", 24.0)
  let issues = @lib.validate_station(station)
  issues.append(@lib.validate_timezone(tz))
  issues.append(@lib.validate_hours(hours))
  println(@lib.validation_to_markdown(issues))
}

///|
fn print_stats(args : Array[String]) -> Unit {
  let prediction = match load_prediction(args) {
    Some(value) => value
    None => return
  }
  let samples = @lib.sample_series(
    prediction.station,
    prediction.start_jd,
    prediction.duration_hours,
    1.0 / 12.0,
  )
  let stats = @lib.compute_stats(samples)
  let coefficient = @lib.tide_coefficient(
    stats.range,
    @lib.mean_tidal_range(prediction.station),
  )
  println(@lib.stats_to_markdown(stats, coefficient))
  println("")
  println("Dominant state: " + @lib.state_label(@lib.dominant_state(samples)))
}

///|
fn print_events(args : Array[String]) -> Unit {
  let prediction = match load_prediction(args) {
    Some(value) => value
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
        "High"
      } else {
        "Low"
      }
      println(
        @lib.format_local_datetime(extreme.time_jd, prediction.tz) +
        "  " +
        kind +
        "  " +
        @lib.format_meters(extreme.height) +
        " m",
      )
    }
  }
}

///|
fn print_curve(args : Array[String]) -> Unit {
  let prediction = match load_prediction(args) {
    Some(value) => value
    None => return
  }
  println(
    @lib.render_curve(
      prediction.station,
      prediction.start_jd,
      prediction.duration_hours,
      1.0,
      prediction.tz,
    ),
  )
}

///|
fn print_plan(args : Array[String]) -> Unit {
  let prediction = match load_prediction(args) {
    Some(value) => value
    None => return
  }
  println(@lib.plans_to_markdown(@lib.plans_for(prediction), prediction.tz))
}

///|
fn export_prediction(args : Array[String]) -> Unit {
  let prediction = match load_prediction(args) {
    Some(value) => value
    None => return
  }
  let format = find_arg(args, "--format").unwrap_or("csv")
  if format == "ics" {
    println(
      @lib.extremes_to_ics(
        prediction.station,
        prediction.extremes,
        prediction.tz,
      ),
    )
  } else if format == "json" {
    println(@lib.render_json(prediction))
  } else {
    let samples = @lib.sample_series(
      prediction.station,
      prediction.start_jd,
      prediction.duration_hours,
      1.0 / 12.0,
    )
    println(@lib.samples_to_csv(samples, prediction.tz))
  }
}

///|
fn read_json_file(path : String) -> Json? {
  let text = @fs.read_file_to_string(path) catch {
    @fs.IOError(message) => {
      println("Failed to read " + path + ": " + message)
      return None
    }
  }
  let json = @json.parse(text) catch {
    _ => {
      println("Invalid JSON: " + path)
      return None
    }
  }
  Some(json)
}

///|
fn validate_reference(args : Array[String]) -> Unit {
  let metadata_path = match find_arg(args, "--metadata") {
    Some(value) => value
    None => {
      println("--metadata is required")
      return
    }
  }
  let harcon_path = match find_arg(args, "--harcon") {
    Some(value) => value
    None => {
      println("--harcon is required")
      return
    }
  }
  let predictions_path = match find_arg(args, "--predictions") {
    Some(value) => value
    None => {
      println("--predictions is required")
      return
    }
  }
  let metadata = match read_json_file(metadata_path) {
    Some(value) => value
    None => return
  }
  let harcon = match read_json_file(harcon_path) {
    Some(value) => value
    None => return
  }
  let datums = match find_arg(args, "--datums") {
    Some(path) => read_json_file(path)
    None => None
  }
  let station = match @lib.station_from_noaa(metadata, harcon, datums?) {
    Some(value) => value
    None => {
      println("Failed to build a station from NOAA data")
      return
    }
  }
  let unsupported = @lib.noaa_unsupported_constituents(harcon)
  let reference_json = match read_json_file(predictions_path) {
    Some(value) => value
    None => return
  }
  let references = match @lib.predictions_from_noaa(reference_json) {
    Some(value) => value
    None => {
      println("Failed to parse NOAA predictions")
      return
    }
  }
  let tolerance = parse_double_arg(args, "--tolerance", 0.3)
  let stats = match
    @lib.compare_with_reference(station, references, tolerance) {
    Some(value) => value
    None => {
      println("No usable reference samples")
      return
    }
  }
  println("# MoonTide NOAA Validation")
  println("")
  println("- Station: " + station.name + " (" + station.id + ")")
  println("- Source: " + station.source)
  println(
    "- Datum offset (MSL - MLLW): " + @lib.format_meters(station.datum) + " m",
  )
  println(
    "- Harmonic constituents: " +
    (station.components.length() + unsupported.length()).to_string() +
    " total, " +
    station.components.length().to_string() +
    " used, " +
    unsupported.length().to_string() +
    " ignored",
  )
  if unsupported.length() > 0 {
    println("- Ignored by the current catalog: " + unsupported.join(", "))
  }
  println(@lib.validation_stats_to_markdown(stats))
  if !stats.passed {
    abort("NOAA validation exceeded the configured mean-error tolerance")
  }
}

///|
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
  if args.contains("validate-reference") {
    validate_reference(args)
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
    Some(value) => value
    None => return
  }
  let format = find_arg(args, "--format").unwrap_or("markdown")
  if format == "json" {
    println(@lib.render_json(prediction))
  } else {
    println(@lib.render_report(prediction))
  }
}
