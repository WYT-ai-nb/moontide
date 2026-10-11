/// Severity of a station or option validation issue.
pub enum ValidationLevel {
  Error
  Warning
  Info
} derive(Eq, Debug)

/// One validation issue.
pub struct ValidationIssue {
  level : ValidationLevel
  field : String
  message : String
} derive(Debug)

fn issue(level : ValidationLevel, field : String, message : String) -> ValidationIssue {
  { level, field, message }
}

/// Validate station coordinates.
pub fn validate_coordinates(lat : Double, lon : Double) -> Array[ValidationIssue] {
  let issues = Array(capacity=4)
  if lat < -90.0 || lat > 90.0 {
    issues.push(issue(ValidationLevel::Error, "lat", "纬度必须在 -90 到 90 之间"))
  }
  if lon < -180.0 || lon > 180.0 {
    issues.push(issue(ValidationLevel::Error, "lon", "经度必须在 -180 到 180 之间"))
  }
  if lat > 66.5 || lat < -66.5 {
    issues.push(issue(ValidationLevel::Warning, "lat", "极区日照模型可能不适用"))
  }
  issues
}

/// Validate station datum.
pub fn validate_datum(datum : Double) -> Array[ValidationIssue] {
  if datum < -100.0 || datum > 100.0 {
    [issue(ValidationLevel::Error, "datum", "基准面偏移超出合理范围")]
  } else if datum != 0.0 {
    [issue(ValidationLevel::Info, "datum", "非零基准面将直接改变报告中的绝对潮高")]
  } else {
    []
  }
}

/// Validate one harmonic component.
pub fn validate_harmonic(harmonic : Harmonic) -> Array[ValidationIssue] {
  let issues = Array(capacity=3)
  if harmonic.amplitude < 0.0 {
    issues.push(issue(ValidationLevel::Error, harmonic.constituent.name, "振幅不能为负数"))
  }
  if harmonic.amplitude > 20.0 {
    issues.push(issue(ValidationLevel::Warning, harmonic.constituent.name, "振幅异常大，请检查单位"))
  }
  if harmonic.phase_lag < 0.0 || harmonic.phase_lag >= 360.0 {
    issues.push(issue(ValidationLevel::Warning, harmonic.constituent.name, "迟角建议归一化到 0 到 360 度"))
  }
  issues
}

/// Validate a station and all of its harmonic components.
pub fn validate_station(station : Station) -> Array[ValidationIssue] {
  let issues = Array(capacity=station.components.length() + 8)
  issues.append(validate_coordinates(station.lat, station.lon))
  issues.append(validate_datum(station.datum))
  if station.components.is_empty() {
    issues.push(issue(ValidationLevel::Error, "components", "站点至少需要一个分潮"))
  }
  let mut has_m2 = false
  let mut has_s2 = false
  for harmonic in station.components {
    issues.append(validate_harmonic(harmonic))
    if harmonic.constituent.name == "M2" {
      has_m2 = true
    }
    if harmonic.constituent.name == "S2" {
      has_s2 = true
    }
  }
  if !has_m2 {
    issues.push(issue(ValidationLevel::Warning, "M2", "缺少 M2 会影响半日潮精度"))
  }
  if !has_s2 {
    issues.push(issue(ValidationLevel::Warning, "S2", "缺少 S2 会影响大潮小潮变化"))
  }
  issues
}

/// Validate a UTC offset.
pub fn validate_timezone(tz : Double) -> Array[ValidationIssue] {
  if tz < -12.0 || tz > 14.0 {
    [issue(ValidationLevel::Warning, "tz", "UTC 偏移超出常见范围，请确认单位是小时")]
  } else {
    []
  }
}

/// Validate a prediction window in hours.
pub fn validate_hours(hours : Double) -> Array[ValidationIssue] {
  if hours <= 0.0 {
    [issue(ValidationLevel::Error, "hours", "预测时长必须大于 0")]
  } else if hours > 24.0 * 31.0 {
    [issue(ValidationLevel::Warning, "hours", "预测时长超过 31 天，报告可能过长")]
  } else {
    []
  }
}

/// Return true when no error-level issues exist.
pub fn is_valid(issues : Array[ValidationIssue]) -> Bool {
  !issues.any(item => item.level == ValidationLevel::Error)
}
