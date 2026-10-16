///|
/// One timestamped reference height used for validation.
pub struct ReferencePrediction {
  time_jd : Double
  height : Double
} derive(Debug)

///|
/// Error statistics for a MoonTide prediction compared with an external source.
pub struct ValidationStats {
  sample_count : Int32
  bias : Double
  mean_absolute_error : Double
  root_mean_square_error : Double
  max_absolute_error : Double
  tolerance : Double
  passed : Bool
} derive(Debug)

///|
fn object_field(root : Json, name : String) -> Json? {
  match root {
    Json::Object(map) => map.get(name)
    _ => None
  }
}

///|
fn array_field(root : Json, name : String) -> Array[Json]? {
  match object_field(root, name) {
    Some(Json::Array(values)) => Some(values)
    _ => None
  }
}

///|
fn first_station(metadata : Json) -> Json? {
  match array_field(metadata, "stations") {
    Some(stations) if stations.length() > 0 => Some(stations[0])
    _ => None
  }
}

///|
fn noaa_datum_value(datums : Json, wanted : String) -> Double? {
  let mut result = None
  match array_field(datums, "datums") {
    Some(items) =>
      for item in items {
        if json_string(object_field(item, "name")) == Some(wanted) {
          result = json_number(object_field(item, "value"))
          break
        }
      }
    None => ()
  }
  result
}

///|
fn noaa_conversion_datum(datums : Json?) -> Double {
  match datums {
    Some(root) =>
      match (noaa_datum_value(root, "MSL"), noaa_datum_value(root, "MLLW")) {
        (Some(msl), Some(mllw)) => msl - mllw
        _ => 0.0
      }
    None => 0.0
  }
}

///|
/// Return NOAA constituent names that MoonTide's harmonic catalog cannot use.
pub fn noaa_unsupported_constituents(harcon : Json) -> Array[String] {
  let unsupported = Array(capacity=0)
  match array_field(harcon, "HarmonicConstituents") {
    Some(items) =>
      for item in items {
        match json_string(object_field(item, "name")) {
          Some(name) =>
            if find_constituent(name) is None && !unsupported.contains(name) {
              unsupported.push(name)
            }
          None => ()
        }
      }
    None => ()
  }
  unsupported
}

///|
/// Build a station from NOAA CO-OPS metadata, harmonic constants, and datums.
///
/// NOAA harmonic constants are referenced to MSL while the common prediction
/// API used in validation is referenced to MLLW. When datum data is supplied,
/// MoonTide records `MSL - MLLW` as the station datum so predictions use the
/// same vertical reference.
pub fn station_from_noaa(
  metadata : Json,
  harcon : Json,
  datums? : Json,
) -> Station? {
  let station_json = match first_station(metadata) {
    Some(value) => value
    None => return None
  }
  let id = match json_string(object_field(station_json, "id")) {
    Some(value) => value
    None => return None
  }
  let name = match json_string(object_field(station_json, "name")) {
    Some(value) => value
    None => return None
  }
  let lat = match json_number(object_field(station_json, "lat")) {
    Some(value) => value
    None => return None
  }
  let lon = match json_number(object_field(station_json, "lng")) {
    Some(value) => value
    None => return None
  }
  let raw_components = match array_field(harcon, "HarmonicConstituents") {
    Some(values) => values
    None => return None
  }
  let components = Array(capacity=raw_components.length())
  for item in raw_components {
    let component_name = match json_string(object_field(item, "name")) {
      Some(value) => value
      None => continue
    }
    let constituent = match find_constituent(component_name) {
      Some(value) => value
      None => continue
    }
    let amplitude = match json_number(object_field(item, "amplitude")) {
      Some(value) => value
      None => continue
    }
    let phase_lag = match json_number(object_field(item, "phase_GMT")) {
      Some(value) => value
      None => continue
    }
    components.push({ constituent, amplitude, phase_lag, })
  }
  if components.is_empty() {
    return None
  }
  let datum = noaa_conversion_datum(datums)
  Some({
    id,
    name,
    lat,
    lon,
    datum,
    components,
    source: "NOAA CO-OPS station \{id}; harmonic constants + published datums",
  })
}

///|
/// Parse NOAA CO-OPS prediction JSON (`time_zone=gmt`).
pub fn predictions_from_noaa(root : Json) -> Array[ReferencePrediction]? {
  let items = match array_field(root, "predictions") {
    Some(values) => values
    None => return None
  }
  let predictions = Array(capacity=items.length())
  for item in items {
    let timestamp = match json_string(object_field(item, "t")) {
      Some(value) => value
      None => return None
    }
    let height_text = match json_string(object_field(item, "v")) {
      Some(value) => value
      None => return None
    }
    let moment = match parse_local_datetime(timestamp) {
      Some(value) => value
      None => return None
    }
    let height = @string.parse_double(height_text) catch { _ => return None }
    predictions.push({ time_jd: moment_to_jd(moment, 0.0), height, })
  }
  if predictions.is_empty() {
    None
  } else {
    Some(predictions)
  }
}

///|
/// Compare modeled tide heights with externally supplied reference predictions.
pub fn compare_with_reference(
  station : Station,
  references : Array[ReferencePrediction],
  tolerance : Double,
) -> ValidationStats? {
  if references.is_empty() {
    return None
  }
  let mut bias = 0.0
  let mut absolute_error = 0.0
  let mut squared_error = 0.0
  let mut max_absolute_error = 0.0
  for reference in references {
    let error = tide_height(station, reference.time_jd) - reference.height
    let absolute = if error < 0.0 { -error } else { error }
    bias = bias + error
    absolute_error = absolute_error + absolute
    squared_error = squared_error + error * error
    if absolute > max_absolute_error {
      max_absolute_error = absolute
    }
  }
  let count = references.length().to_double()
  let mean_absolute_error = absolute_error / count
  Some({
    sample_count: references.length(),
    bias: bias / count,
    mean_absolute_error,
    root_mean_square_error: (squared_error / count).sqrt(),
    max_absolute_error,
    tolerance,
    passed: mean_absolute_error <= tolerance,
  })
}

///|
/// Render NOAA validation statistics as Markdown.
pub fn validation_stats_to_markdown(stats : ValidationStats) -> String {
  let result = if stats.passed { "PASS" } else { "FAIL" }
  "- Samples: \{stats.sample_count}\n" +
  "- Bias: \{format_meters(stats.bias)} m\n" +
  "- Mean absolute error: \{format_meters(stats.mean_absolute_error)} m\n" +
  "- Root mean square error: \{format_meters(stats.root_mean_square_error)} m\n" +
  "- Maximum absolute error: \{format_meters(stats.max_absolute_error)} m\n" +
  "- Mean-error tolerance: \{format_meters(stats.tolerance)} m\n" +
  "- Result: **\{result}**\n"
}
