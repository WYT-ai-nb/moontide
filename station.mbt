///|
/// A tide station: location, datum, harmonic components, and data provenance.
pub struct Station {
  id : String
  name : String
  lat : Double
  lon : Double
  datum : Double
  components : Array[Harmonic]
  source : String
} derive(Debug)

///|
fn harmonic_of(
  name : String,
  amplitude : Double,
  phase_lag : Double,
) -> Harmonic {
  match find_constituent(name) {
    Some(c) => { constituent: c, amplitude, phase_lag, }
    None => abort("unknown constituent: \{name}")
  }
}

///|
/// Stations bundled with MoonTide. Their constants are illustrative demo values.
pub fn builtin_stations() -> Array[Station] {
  [
    {
      id: "demo",
      name: "示例港（演示）",
      lat: 36.0,
      lon: 120.0,
      datum: 0.0,
      components: [
        harmonic_of("M2", 1.20, 300.0),
        harmonic_of("S2", 0.40, 340.0),
        harmonic_of("K1", 0.25, 180.0),
        harmonic_of("O1", 0.18, 220.0),
      ],
      source: "示例数据，用于演示算法，非官方调和常数",
    },
    {
      id: "qingdao",
      name: "青岛（示例常数）",
      lat: 36.06,
      lon: 120.31,
      datum: 0.0,
      components: [
        harmonic_of("M2", 1.35, 310.0),
        harmonic_of("S2", 0.45, 345.0),
        harmonic_of("N2", 0.20, 290.0),
        harmonic_of("K1", 0.28, 175.0),
        harmonic_of("O1", 0.20, 215.0),
      ],
      source: "示例常数（非官方），正式使用请以当地《潮汐表》为准",
    },
    {
      id: "xiamen",
      name: "厦门（示例常数）",
      lat: 24.45,
      lon: 118.07,
      datum: 0.0,
      components: [
        harmonic_of("M2", 1.80, 280.0),
        harmonic_of("S2", 0.60, 320.0),
        harmonic_of("K1", 0.35, 160.0),
        harmonic_of("O1", 0.28, 200.0),
      ],
      source: "示例常数（非官方），正式使用请以当地《潮汐表》为准",
    },
  ]
}

///|
/// Find a built-in station by id (case-insensitive).
pub fn find_station(id : String) -> Station? {
  let wanted = id.to_lower()
  for s in builtin_stations() {
    if s.id.to_lower() == wanted {
      return Some(s)
    }
  }
  None
}

///|
pub fn station_id(station : Station) -> String {
  station.id
}

///|
pub fn station_name(station : Station) -> String {
  station.name
}

///|
pub fn station_lat(station : Station) -> Double {
  station.lat
}

///|
pub fn station_lon(station : Station) -> Double {
  station.lon
}

///|
pub fn station_source(station : Station) -> String {
  station.source
}

///|
fn json_string(value : Json?) -> String? {
  match value {
    Some(Json::String(s)) => Some(s)
    _ => None
  }
}

///|
fn json_number(value : Json?) -> Double? {
  match value {
    Some(Json::Number(n, ..)) => Some(n)
    _ => None
  }
}

///|
/// Parse a station from MoonTide's JSON format.
pub fn station_from_json(root : Json) -> Station? {
  let object = match root {
    Json::Object(m) => m
    _ => return None
  }
  let id = match json_string(object.get("id")) {
    Some(v) => v
    None => return None
  }
  let name = match json_string(object.get("name")) {
    Some(v) => v
    None => return None
  }
  let lat = match json_number(object.get("lat")) {
    Some(v) => v
    None => return None
  }
  let lon = match json_number(object.get("lon")) {
    Some(v) => v
    None => return None
  }
  let datum = json_number(object.get("datum")).unwrap_or(0.0)
  let source = json_string(object.get("source")).unwrap_or("")
  let components_json = match object.get("components") {
    Some(Json::Array(arr)) => arr
    _ => return None
  }
  let components = Array(capacity=components_json.length())
  for item in components_json {
    let obj = match item {
      Json::Object(m) => m
      _ => return None
    }
    let cname = match json_string(obj.get("name")) {
      Some(v) => v
      None => return None
    }
    let amplitude = match json_number(obj.get("amplitude")) {
      Some(v) => v
      None => return None
    }
    let phase = match json_number(obj.get("phase")) {
      Some(v) => v
      None => return None
    }
    let c = match find_constituent(cname) {
      Some(v) => v
      None => return None
    }
    components.push({ constituent: c, amplitude, phase_lag: phase, })
  }
  Some({ id, name, lat, lon, datum, components, source, })
}

///|
/// Parse a station file containing a single JSON object.
pub fn parse_station_file(content : String) -> Station? {
  let json = @json.parse(content) catch { _ => return None }
  station_from_json(json)
}
