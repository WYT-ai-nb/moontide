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
  println("  moontide predict --station demo --date 2026-10-12 --tz 8 --hours 24")
  println("  moontide predict --station-file myport.json --date 2026-10-12 --format json")
  println("")
  println("选项:")
  println("  --station <id>        内置站点（demo / qingdao / xiamen）")
  println("  --station-file <path> 从 JSON 文件加载自定义站点")
  println("  --date <YYYY-MM-DD>   预测起始日期")
  println("  --tz <offset>         UTC 偏移小时数，默认 8")
  println("  --hours <n>           预测时长小时数，默认 24")
  println("  --format <fmt>        markdown（默认）或 json")
}

fn load_station(args : Array[String]) -> @lib.Station? {
  match find_arg(args, "--station-file") {
    Some(path) => {
      let content = try @fs.read_file_to_string(path) catch {
        _ => {
          println("无法读取站点文件: \{path}")
          return None
        }
      }
      match @lib.parse_station_file(content) {
        Some(s) => Some(s)
        None => {
          println("站点文件格式无效: \{path}")
          None
        }
      }
    }
    None => {
      let id = find_arg(args, "--station").unwrap_or("demo")
      match @lib.find_station(id) {
        Some(s) => Some(s)
        None => {
          println("未找到内置站点: \{id}")
          None
        }
      }
    }
  }
}

fn list_stations() -> Unit {
  println("MoonTide 内置站点")
  println("")
  for s in @lib.builtin_stations() {
    println("\{@lib.station_id(s)}\t\{@lib.station_name(s)}")
    println("    位置: \{@lib.format_meters(@lib.station_lat(s))}°, \{@lib.format_meters(@lib.station_lon(s))}°   平均潮差约 \{@lib.format_meters(@lib.mean_tidal_range(s))} m")
    println("    数据来源: \{@lib.station_source(s)}")
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
  if !args.contains("predict") {
    print_help()
    return
  }

  let station = match load_station(args) {
    Some(s) => s
    None => return
  }
  let date = find_arg(args, "--date").unwrap_or("2026-10-12")
  let tz = parse_double_arg(args, "--tz", 8.0)
  let hours = parse_double_arg(args, "--hours", 24.0)
  let format = find_arg(args, "--format").unwrap_or("markdown")

  let prediction = match @lib.predict_on(station, date, tz, hours) {
    Some(p) => p
    None => {
      println("日期格式无效（应为 YYYY-MM-DD 或 YYYY-MM-DD HH:MM）: \{date}")
      return
    }
  }
  if format == "json" {
    println(@lib.render_json(prediction))
  } else {
    println(@lib.render_report(prediction))
  }
}
