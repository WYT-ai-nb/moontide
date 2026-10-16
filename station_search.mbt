///|
/// Great-circle distance in kilometers between two coordinates.
pub fn distance_km(
  lat1 : Double,
  lon1 : Double,
  lat2 : Double,
  lon2 : Double,
) -> Double {
  let earth_radius = 6371.0088
  let phi1 = to_radians(lat1)
  let phi2 = to_radians(lat2)
  let delta_phi = to_radians(lat2 - lat1)
  let delta_lambda = to_radians(lon2 - lon1)
  let a = @math.sin(delta_phi / 2.0) * @math.sin(delta_phi / 2.0) +
    @math.cos(phi1) *
    @math.cos(phi2) *
    @math.sin(delta_lambda / 2.0) *
    @math.sin(delta_lambda / 2.0)
  let c = 2.0 * @math.atan2(a.sqrt(), (1.0 - a).sqrt())
  earth_radius * c
}

///|
/// Return stations within a coordinate bounding box.
pub fn stations_in_bounds(
  min_lat : Double,
  max_lat : Double,
  min_lon : Double,
  max_lon : Double,
) -> Array[Station] {
  let result = Array(capacity=builtin_stations().length())
  for station in builtin_stations() {
    if station.lat >= min_lat &&
      station.lat <= max_lat &&
      station.lon >= min_lon &&
      station.lon <= max_lon {
      result.push(station)
    }
  }
  result
}

///|
/// Find the nearest built-in station to a coordinate.
pub fn nearest_station(lat : Double, lon : Double) -> Station? {
  let stations = builtin_stations()
  if stations.is_empty() {
    return None
  }
  let mut best = stations[0]
  let mut best_distance = distance_km(lat, lon, best.lat, best.lon)
  for i = 1; i < stations.length(); i = i + 1 {
    let candidate = stations[i]
    let d = distance_km(lat, lon, candidate.lat, candidate.lon)
    if d < best_distance {
      best = candidate
      best_distance = d
    }
  }
  Some(best)
}

///|
/// Return true when a station contains a named constituent.
pub fn has_constituent(station : Station, name : String) -> Bool {
  let wanted = name.to_upper()
  station.components.any(harmonic => harmonic.constituent.name == wanted)
}

///|
/// Count the number of harmonics in a station.
pub fn harmonic_count(station : Station) -> Int32 {
  station.components.length()
}

///|
/// Compute the sum of amplitudes for a list of constituent names.
pub fn amplitude_sum(station : Station, names : Array[String]) -> Double {
  let mut total = 0.0
  for harmonic in station.components {
    if names.contains(harmonic.constituent.name) {
      total = total + harmonic.amplitude
    }
  }
  total
}

///|
/// Return a simple coverage score for the station constants.
pub fn station_quality_score(station : Station) -> Double {
  let mut score = harmonic_count(station).to_double() * 8.0
  if has_constituent(station, "M2") {
    score = score + 20.0
  }
  if has_constituent(station, "S2") {
    score = score + 15.0
  }
  if has_constituent(station, "K1") {
    score = score + 10.0
  }
  if has_constituent(station, "O1") {
    score = score + 10.0
  }
  if score > 100.0 {
    100.0
  } else {
    score
  }
}

///|
/// Produce a one-line station summary.
pub fn station_summary(station : Station) -> String {
  "\{station.id}: \{station.name}（\{harmonic_count(station)} 个分潮，质量分 \{format_meters(station_quality_score(station))}）"
}

///|
/// Produce a coordinate label for reports.
pub fn coordinate_label(lat : Double, lon : Double) -> String {
  let ns = if lat >= 0.0 { "N" } else { "S" }
  let ew = if lon >= 0.0 { "E" } else { "W" }
  "\{format_meters(if lat < 0.0 { -lat } else { lat })}\{ns} \{format_meters(if lon < 0.0 { -lon } else { lon })}\{ew}"
}

///|
/// Return unique constituent names in stable order.
pub fn component_names(station : Station) -> Array[String] {
  let names = Array(capacity=station.components.length())
  for harmonic in station.components {
    if !names.contains(harmonic.constituent.name) {
      names.push(harmonic.constituent.name)
    }
  }
  names
}

///|
/// Return the speed of the fastest supported constituent.
pub fn fastest_constituent() -> Constituent {
  let constituents = standard_constituents()
  let mut best = constituents[0]
  for c in constituents {
    if c.speed > best.speed {
      best = c
    }
  }
  best
}

///|
/// Return the slowest supported constituent.
pub fn slowest_constituent() -> Constituent {
  let constituents = standard_constituents()
  let mut best = constituents[0]
  for c in constituents {
    if c.speed < best.speed {
      best = c
    }
  }
  best
}

///|
/// Count how many constituents are available in the standard catalog.
pub fn catalog_size() -> Int32 {
  standard_constituents().length()
}

///|
/// Return true when the station is in the northern hemisphere.
pub fn is_northern(station : Station) -> Bool {
  station.lat >= 0.0
}

///|
/// Return true when the station is in the eastern hemisphere.
pub fn is_eastern(station : Station) -> Bool {
  station.lon >= 0.0
}

///|
/// Return a hemisphere label for display.
pub fn hemisphere_label(station : Station) -> String {
  let north_south = if is_northern(station) { "北半球" } else { "南半球" }
  let east_west = if is_eastern(station) { "东半球" } else { "西半球" }
  "\{north_south}\{east_west}"
}

///|
/// Find the closest station and return its distance as text.
pub fn nearest_station_summary(lat : Double, lon : Double) -> String {
  match nearest_station(lat, lon) {
    Some(station) =>
      "\{station.name}，距离约 \{format_meters(distance_km(lat, lon, station.lat, station.lon))} km"
    None => "没有可用的内置站点"
  }
}
