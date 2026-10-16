///|
/// Approximate solar declination in degrees for a day of year (1..365/366).
pub fn solar_declination(day_of_year : Int32) -> Double {
  -23.44 * @math.cos(to_radians(360.0 / 365.0 * (day_of_year + 10).to_double()))
}

///|
/// Simplified NOAA sunrise/sunset in local solar hours, or `None` for polar day/night.
pub fn sunrise_sunset(
  lat_degrees : Double,
  day_of_year : Int32,
) -> (Double, Double)? {
  let lat = to_radians(lat_degrees)
  let decl = to_radians(solar_declination(day_of_year))
  let zenith = to_radians(90.833)
  let cos_hour_angle = (@math.cos(zenith) - @math.sin(lat) * @math.sin(decl)) /
    (@math.cos(lat) * @math.cos(decl))
  if cos_hour_angle > 1.0 || cos_hour_angle < -1.0 {
    return None
  }
  let hour_angle = to_degrees(@math.acos(cos_hour_angle)) / 15.0
  let sunrise = 12.0 - hour_angle
  let sunset = 12.0 + hour_angle
  if sunrise >= sunset {
    return None
  }
  Some((sunrise, sunset))
}
