///|
let noaa_metadata_fixture =
  #|{"count":1,"stations":[{"id":"8518750","name":"The Battery","lat":40.700554,"lng":-74.01417,"timezonecorr":-5}]}

///|
let noaa_harcon_fixture =
  #|{"units":"meters","HarmonicConstituents":[
  #|{"name":"M2","amplitude":0.671,"phase_GMT":18.2,"speed":28.984104},
  #|{"name":"S2","amplitude":0.128,"phase_GMT":42.9,"speed":30.0},
  #|{"name":"N2","amplitude":0.156,"phase_GMT":0.5,"speed":28.43973},
  #|{"name":"K1","amplitude":0.103,"phase_GMT":178.5,"speed":15.041069},
  #|{"name":"M4","amplitude":0.024,"phase_GMT":264.1,"speed":57.96821},
  #|{"name":"O1","amplitude":0.051,"phase_GMT":176.3,"speed":13.943035},
  #|{"name":"M6","amplitude":0.023,"phase_GMT":150.4,"speed":86.95232},
  #|{"name":"Q1","amplitude":0.011,"phase_GMT":196.6,"speed":13.398661},
  #|{"name":"P1","amplitude":0.033,"phase_GMT":178.8,"speed":14.958931},
  #|{"name":"K2","amplitude":0.036,"phase_GMT":44.5,"speed":30.082138},
  #|{"name":"MS4","amplitude":0.015,"phase_GMT":258.9,"speed":58.984104}
  #|]}

///|
let noaa_datums_fixture =
  #|{"units":"meters","datums":[{"name":"MSL","value":1.785},{"name":"MLLW","value":1.002}]}

///|
let noaa_predictions_fixture =
  #|{"predictions":[
  #|{"t":"2026-10-12 00:00","v":"1.355"},
  #|{"t":"2026-10-12 01:00","v":"1.518"},
  #|{"t":"2026-10-12 02:00","v":"1.516"},
  #|{"t":"2026-10-12 03:00","v":"1.329"},
  #|{"t":"2026-10-12 04:00","v":"1.007"},
  #|{"t":"2026-10-12 05:00","v":"0.660"},
  #|{"t":"2026-10-12 06:00","v":"0.361"},
  #|{"t":"2026-10-12 07:00","v":"0.135"},
  #|{"t":"2026-10-12 08:00","v":"0.062"},
  #|{"t":"2026-10-12 09:00","v":"0.243"},
  #|{"t":"2026-10-12 10:00","v":"0.641"},
  #|{"t":"2026-10-12 11:00","v":"1.087"},
  #|{"t":"2026-10-12 12:00","v":"1.444"},
  #|{"t":"2026-10-12 13:00","v":"1.664"},
  #|{"t":"2026-10-12 14:00","v":"1.724"},
  #|{"t":"2026-10-12 15:00","v":"1.594"},
  #|{"t":"2026-10-12 16:00","v":"1.291"},
  #|{"t":"2026-10-12 17:00","v":"0.911"},
  #|{"t":"2026-10-12 18:00","v":"0.556"},
  #|{"t":"2026-10-12 19:00","v":"0.262"},
  #|{"t":"2026-10-12 20:00","v":"0.080"},
  #|{"t":"2026-10-12 21:00","v":"0.116"},
  #|{"t":"2026-10-12 22:00","v":"0.397"},
  #|{"t":"2026-10-12 23:00","v":"0.788"}
  #|]}

///|
fn parse_fixture(text : String) -> Json {
  @json.parse(text) catch {
    _ => abort("invalid test fixture")
  }
}

///|
fn fixture_station() -> Station {
  match
    station_from_noaa(
      parse_fixture(noaa_metadata_fixture),
      parse_fixture(noaa_harcon_fixture),
      datums=parse_fixture(noaa_datums_fixture),
    ) {
    Some(station) => station
    None => abort("failed to parse NOAA fixture station")
  }
}

///|
test "NOAA station uses published MSL to MLLW conversion" {
  let station = fixture_station()
  @test.assert_eq(station.id, "8518750")
  @test.assert_eq(station.components.length(), 11)
  @test.assert_eq(close(station.datum, 0.783, 1.0e-9), true)
}

///|
test "NOAA prediction JSON parses into reference points" {
  match predictions_from_noaa(parse_fixture(noaa_predictions_fixture)) {
    Some(predictions) => @test.assert_eq(predictions.length(), 24)
    None => @test.fail("expected NOAA predictions")
  }
}

///|
test "MoonTide agrees with NOAA reference predictions" {
  let station = fixture_station()
  let references = match
    predictions_from_noaa(parse_fixture(noaa_predictions_fixture)) {
    Some(values) => values
    None => {
      @test.fail("expected NOAA predictions")
      return
    }
  }
  let stats = match compare_with_reference(station, references, 0.12) {
    Some(value) => value
    None => {
      @test.fail("expected validation statistics")
      return
    }
  }
  @test.assert_eq(stats.sample_count, 24)
  @test.assert_eq(stats.mean_absolute_error < 0.12, true)
  @test.assert_eq(stats.max_absolute_error < 0.25, true)
  @test.assert_eq(stats.passed, true)
}

///|
test "unsupported NOAA constituents are reported" {
  let harcon = @json.parse(
    "{\"HarmonicConstituents\":[{\"name\":\"M2\"},{\"name\":\"CUSTOM\"}]}",
  ) catch {
    _ => abort("invalid fixture")
  }
  let unsupported = noaa_unsupported_constituents(harcon)
  @test.assert_eq(unsupported.length(), 1)
  @test.assert_eq(unsupported[0], "CUSTOM")
}
