///|
/// The result of a tide prediction for a station over a time window.
pub struct Prediction {
  station : Station
  start_jd : Double
  duration_hours : Double
  tz : Double
  extremes : Array[TideExtreme]
  max_height : Double
  min_height : Double
  tidal_range : Double
  spring_neap : String
  sunrise_hour : Double
  sunset_hour : Double
  activities : Array[Activity]
} derive(Debug)

///|
/// Rough mean tidal range from the dominant constituents.
pub fn mean_tidal_range(station : Station) -> Double {
  let mut total = 0.0
  for hc in station.components {
    if hc.constituent.name == "M2" ||
      hc.constituent.name == "S2" ||
      hc.constituent.name == "K1" ||
      hc.constituent.name == "O1" {
      total = total + hc.amplitude
    }
  }
  total * 2.0
}

///|
fn classify_spring_neap(tidal_range : Double, mean_range : Double) -> String {
  if mean_range <= 0.0 {
    return "中潮"
  }
  let ratio = tidal_range / mean_range
  if ratio > 1.2 {
    "大潮"
  } else if ratio < 0.8 {
    "小潮"
  } else {
    "中潮"
  }
}

///|
/// Predict tides for a station starting at a local clock moment.
pub fn predict(
  station : Station,
  start : Moment,
  tz : Double,
  duration_hours : Double,
) -> Prediction {
  let start_jd = moment_to_jd(start, tz)
  let step_hours = 1.0 / 12.0 // five minutes
  let samples = @math.floor(duration_hours / step_hours).to_int() + 1
  let mut min_height = tide_height(station, start_jd)
  let mut max_height = min_height
  for i = 0; i < samples; i = i + 1 {
    let h = tide_height(station, start_jd + i.to_double() * step_hours / 24.0)
    if h < min_height {
      min_height = h
    }
    if h > max_height {
      max_height = h
    }
  }

  let extremes = find_extremes(station, start_jd, duration_hours, step_hours)
  let tidal_range = max_height - min_height
  let mean_range = mean_tidal_range(station)
  let spring_neap = classify_spring_neap(tidal_range, mean_range)

  let doy = day_of_year(start.year, start.month, start.day)
  let (sunrise_hour, sunset_hour) = match sunrise_sunset(station.lat, doy) {
    Some((rise, set)) => (rise, set)
    None => (6.0, 18.0)
  }
  let activities = recommend(extremes, sunrise_hour, sunset_hour, tz)

  {
    station,
    start_jd,
    duration_hours,
    tz,
    extremes,
    max_height,
    min_height,
    tidal_range,
    spring_neap,
    sunrise_hour,
    sunset_hour,
    activities,
  }
}

///|
/// Convenience wrapper: parse a local date string and predict.
pub fn predict_on(
  station : Station,
  date : String,
  tz : Double,
  duration_hours : Double,
) -> Prediction? {
  match parse_local_datetime(date) {
    Some(start) => Some(predict(station, start, tz, duration_hours))
    None => None
  }
}
