///|
/// A calendar moment expressed in a local clock (the UTC offset is supplied separately).
pub struct Moment {
  year : Int32
  month : Int32
  day : Int32
  local_hour : Double
} derive(Eq, Debug)

///|
fn pad2(n : Int32) -> String {
  if n < 10 {
    "0\{n}"
  } else {
    n.to_string()
  }
}

///|
fn parse_clock(s : String) -> Double {
  let pieces = s.split(":").filter(v => !v.is_empty()).to_array()
  if pieces.length() == 0 {
    return 0.0
  }
  let h = @string.parse_int(pieces[0]) catch { _ => 0 }
  let m = if pieces.length() >= 2 {
    @string.parse_int(pieces[1]) catch {
      _ => 0
    }
  } else {
    0
  }
  h.to_double() + m.to_double() / 60.0
}

///|
/// Parse "YYYY-MM-DD" or "YYYY-MM-DD HH:MM" (the "T" separator is also accepted).
pub fn parse_local_datetime(s : String) -> Moment? {
  let normalized = s.trim().to_owned().replace_all(old="T", new=" ")
  let pieces = normalized
    .split(" ")
    .filter(v => !v.is_empty())
    .map(v => v.to_owned())
    .to_array()
  if pieces.length() == 0 {
    return None
  }
  let date_parts = pieces[0].split("-").to_array()
  if date_parts.length() != 3 {
    return None
  }
  let year = @string.parse_int(date_parts[0]) catch { _ => return None }
  let month = @string.parse_int(date_parts[1]) catch { _ => return None }
  let day = @string.parse_int(date_parts[2]) catch { _ => return None }
  if month < 1 || month > 12 || day < 1 || day > 31 {
    return None
  }
  let hour = if pieces.length() >= 2 { parse_clock(pieces[1]) } else { 0.0 }
  if hour < 0.0 || hour >= 24.0 {
    return None
  }
  Some({ year, month, day, local_hour: hour, })
}

///|
/// Julian day from a Gregorian date and a UTC hour (Meeus, "Astronomical Algorithms").
pub fn julian_day_utc(
  year : Int32,
  month : Int32,
  day : Int32,
  utc_hour : Double,
) -> Double {
  let y = if month <= 2 { (year - 1).to_double() } else { year.to_double() }
  let m = if month <= 2 { (month + 12).to_double() } else { month.to_double() }
  let a = @math.floor(y / 100.0)
  let b = 2.0 - a + @math.floor(a / 4.0)
  @math.floor(365.25 * (y + 4716.0)) +
  @math.floor(30.6001 * (m + 1.0)) +
  day.to_double() +
  b -
  1524.5 +
  utc_hour / 24.0
}

///|
/// Convert a local clock moment to a UTC Julian day.
pub fn moment_to_jd(moment : Moment, tz_offset : Double) -> Double {
  julian_day_utc(
    moment.year,
    moment.month,
    moment.day,
    moment.local_hour - tz_offset,
  )
}

///|
/// Inverse of `julian_day_utc`: returns `(year, month, day, hour)` in UTC.
pub fn jd_to_calendar(jd : Double) -> (Int32, Int32, Int32, Double) {
  let z = @math.floor(jd + 0.5).to_int()
  let f = jd + 0.5 - @math.floor(jd + 0.5)
  let a = if z < 2299161 {
    z
  } else {
    let alpha = @math.floor((z.to_double() - 1867216.25) / 36524.25).to_int()
    z + 1 + alpha - alpha / 4
  }
  let b = a + 1524
  let c = @math.floor((b.to_double() - 122.1) / 365.25).to_int()
  let d = @math.floor(365.25 * c.to_double()).to_int()
  let e = @math.floor((b.to_double() - d.to_double()) / 30.6001).to_int()
  let day_frac = b.to_double() -
    d.to_double() -
    @math.floor(30.6001 * e.to_double()) +
    f
  let day = @math.floor(day_frac).to_int()
  let month = if e < 14 { e - 1 } else { e - 13 }
  let year = if month > 2 { c - 4716 } else { c - 4715 }
  let hour = (day_frac - day.to_double()) * 24.0
  (year, month, day, hour)
}

///|
/// Local hour-of-day `[0, 24)` for a Julian day and UTC offset.
pub fn local_hour_of(jd : Double, tz_offset : Double) -> Double {
  let loc = jd + tz_offset / 24.0 + 0.5
  (loc - @math.floor(loc)) * 24.0
}

///|
/// Format a Julian day as "YYYY-MM-DD HH:MM" in the given UTC offset.
pub fn format_local_datetime(jd : Double, tz_offset : Double) -> String {
  let (y, m, d, h) = jd_to_calendar(jd + tz_offset / 24.0)
  let hh = @math.floor(h).to_int()
  let mm = @math.floor((h - hh.to_double()) * 60.0).to_int()
  "\{pad2(y)}-\{pad2(m)}-\{pad2(d)} \{pad2(hh)}:\{pad2(mm)}"
}

///|
/// Format a Julian day as "HH:MM" in the given UTC offset.
pub fn format_local_time(jd : Double, tz_offset : Double) -> String {
  let h = local_hour_of(jd, tz_offset)
  let hh = @math.floor(h).to_int()
  let mm = @math.floor((h - hh.to_double()) * 60.0).to_int()
  "\{pad2(hh)}:\{pad2(mm)}"
}

///|
fn is_leap(year : Int32) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

///|
fn days_in_month(year : Int32, month : Int32) -> Int32 {
  match month {
    1 => 31
    2 => if is_leap(year) { 29 } else { 28 }
    3 => 31
    4 => 30
    5 => 31
    6 => 30
    7 => 31
    8 => 31
    9 => 30
    10 => 31
    11 => 30
    12 => 31
    _ => 0
  }
}

///|
/// Day of year, `1..365/366`.
pub fn day_of_year(year : Int32, month : Int32, day : Int32) -> Int32 {
  let mut n = day
  for m = 1; m < month; m = m + 1 {
    n = n + days_in_month(year, m)
  }
  n
}
