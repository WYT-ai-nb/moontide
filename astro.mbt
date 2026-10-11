/// Fundamental astronomical arguments, all in degrees.
pub struct Astro {
  s : Double   // mean longitude of the Moon
  h : Double   // mean longitude of the Sun
  p : Double   // mean longitude of lunar perigee
  n : Double   // mean longitude of the ascending node
  pp : Double  // mean longitude of perihelion
} derive(Debug)

pub fn to_radians(degrees : Double) -> Double {
  degrees * @math.PI / 180.0
}

pub fn to_degrees(radians : Double) -> Double {
  radians * 180.0 / @math.PI
}

/// Reduce an angle to `[0, 360)`.
pub fn normalize_degrees(x : Double) -> Double {
  x - 360.0 * @math.floor(x / 360.0)
}

/// Fundamental arguments for a Julian day, following the standard Schureman series.
pub fn astro_at(jd : Double) -> Astro {
  let t = (jd - 2451545.0) / 36525.0
  let s = 218.3164477 + 481267.88123421 * t - 0.0015786 * t * t + t * t * t / 538841.0 - t * t * t * t / 65194000.0
  let h = 280.46645 + 36000.7697489 * t + 0.00030322222 * t * t
  let p = 83.3532465 + 4069.0137287 * t - 0.0103200 * t * t - t * t * t / 80053.0 + t * t * t * t / 18999000.0
  let n = 125.04455501 - 1934.13626197 * t + 0.0020708 * t * t - t * t * t / 450000.0
  let pp = 282.93734098 + 1.71945766667 * t + 0.00045688889 * t * t
  {
    s: normalize_degrees(s),
    h: normalize_degrees(h),
    p: normalize_degrees(p),
    n: normalize_degrees(n),
    pp: normalize_degrees(pp),
  }
}
