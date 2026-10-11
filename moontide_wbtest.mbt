fn close(a : Double, b : Double, eps : Double) -> Bool {
  let d = a - b
  (if d < 0.0 { -d } else { d }) < eps
}

test "julian day J2000 epoch" {
  @test.assert_eq(close(julian_day_utc(2000, 1, 1, 12.0), 2451545.0, 1.0e-6), true)
}

test "julian day calendar roundtrip" {
  let (y, m, d, h) = jd_to_calendar(2451545.0)
  @test.assert_eq(y, 2000)
  @test.assert_eq(m, 1)
  @test.assert_eq(d, 1)
  @test.assert_eq(close(h, 12.0, 1.0e-6), true)
}

test "fundamental arguments at J2000" {
  let a = astro_at(2451545.0)
  @test.assert_eq(close(a.s, 218.3164477, 1.0e-4), true)
  @test.assert_eq(close(a.h, 280.46645, 1.0e-4), true)
  @test.assert_eq(close(a.p, 83.3532465, 1.0e-4), true)
  @test.assert_eq(close(a.n, 125.04455501, 1.0e-4), true)
  @test.assert_eq(close(a.pp, 282.93734098, 1.0e-4), true)
}

test "constituent speeds" {
  let m2 = find_constituent("M2").unwrap()
  let s2 = find_constituent("S2").unwrap()
  let k1 = find_constituent("K1").unwrap()
  let o1 = find_constituent("O1").unwrap()
  @test.assert_eq(close(m2.speed, 28.9841042, 1.0e-6), true)
  @test.assert_eq(close(s2.speed, 30.0, 1.0e-6), true)
  @test.assert_eq(close(k1.speed, 15.0410686, 1.0e-6), true)
  @test.assert_eq(close(o1.speed, 13.9430356, 1.0e-6), true)
}

test "solar constituents have no nodal correction" {
  let s2 = find_constituent("S2").unwrap()
  let (f, u) = nodal_correction(s2, 125.0)
  @test.assert_eq(f, 1.0)
  @test.assert_eq(u, 0.0)
}

test "solar declination peaks at solstices" {
  @test.assert_eq(close(solar_declination(172), 23.44, 0.4), true)
  @test.assert_eq(close(solar_declination(355), -23.44, 0.4), true)
}

test "sunrise before sunset" {
  match sunrise_sunset(36.0, 80) {
    Some((rise, set)) => {
      @test.assert_eq(rise < set, true)
      @test.assert_eq(rise >= 0.0 && set <= 24.0, true)
    }
    None => @test.fail("expected a daylight window")
  }
}

test "day of year handles leap years" {
  @test.assert_eq(day_of_year(2024, 2, 29), 60)
  @test.assert_eq(day_of_year(2023, 3, 1), 60)
}

test "parse local datetime" {
  match parse_local_datetime("2026-10-12 08:30") {
    Some(m) => {
      @test.assert_eq(m.year, 2026)
      @test.assert_eq(m.month, 10)
      @test.assert_eq(m.day, 12)
      @test.assert_eq(close(m.local_hour, 8.5, 1.0e-9), true)
    }
    None => @test.fail("expected a valid moment")
  }
  @test.assert_eq(parse_local_datetime("not-a-date"), None)
}

test "station json roundtrip" {
  let json = "{\"id\":\"test\",\"name\":\"测试港\",\"lat\":30.0,\"lon\":122.0,\"datum\":0.0,\"source\":\"test\",\"components\":[{\"name\":\"M2\",\"amplitude\":1.0,\"phase\":300.0}]}"
  match parse_station_file(json) {
    Some(s) => {
      @test.assert_eq(s.id, "test")
      @test.assert_eq(s.components.length(), 1)
      @test.assert_eq(s.components[0].constituent.name, "M2")
    }
    None => @test.fail("expected a valid station")
  }
}

test "mean tidal range uses dominant constituents" {
  let demo = find_station("demo").unwrap()
  @test.assert_eq(close(mean_tidal_range(demo), 4.06, 1.0e-6), true)
}

test "tide height stays bounded" {
  let demo = find_station("demo").unwrap()
  let start = julian_day_utc(2026, 10, 12, 0.0)
  for i = 0; i < 48; i = i + 1 {
    let h = tide_height(demo, start + i.to_double() / 24.0)
    @test.assert_eq(h > -4.0 && h < 4.0, true)
  }
}

test "prediction finds high and low water" {
  let demo = find_station("demo").unwrap()
  let p = predict(demo, { year: 2026, month: 10, day: 12, local_hour: 0.0 }, 8.0, 48.0)
  @test.assert_eq(p.extremes.is_empty(), false)
  let has_high = p.extremes.any(e => e.kind == ExtremeKind::High)
  let has_low = p.extremes.any(e => e.kind == ExtremeKind::Low)
  @test.assert_eq(has_high, true)
  @test.assert_eq(has_low, true)
  @test.assert_eq(p.activities.length(), 3)
  @test.assert_eq(p.tidal_range > 0.0, true)
}

test "markdown report renders" {
  let demo = find_station("demo").unwrap()
  let p = predict(demo, { year: 2026, month: 10, day: 12, local_hour: 0.0 }, 8.0, 24.0)
  let text = render_report(p)
  @test.assert_eq(text.contains("MoonTide"), true)
  @test.assert_eq(text.contains("示例港"), true)
  @test.assert_eq(text.contains("高低潮"), true)
}
