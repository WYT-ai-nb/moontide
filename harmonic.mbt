///|
/// A harmonic component: a constituent plus station-specific amplitude and Greenwich phase lag.
pub struct Harmonic {
  constituent : Constituent
  amplitude : Double
  phase_lag : Double
} derive(Debug)

///|
/// Equilibrium argument (degrees) for a constituent at `t_hours` since J2000.0.
pub fn equilibrium_argument(
  c : Constituent,
  a : Astro,
  t_hours : Double,
) -> Double {
  let tau = 15.0 * t_hours + a.h - a.s
  let np = 360.0 - a.n
  let value = c.d1.to_double() * tau +
    c.d2.to_double() * a.s +
    c.d3.to_double() * a.h +
    c.d4.to_double() * a.p +
    c.d5.to_double() * np +
    c.d6.to_double() * a.pp
  normalize_degrees(value)
}

///|
/// Nodal factor and nodal angle (degrees) for a constituent.
pub fn nodal_correction(
  c : Constituent,
  n_degrees : Double,
) -> (Double, Double) {
  let n = to_radians(normalize_degrees(n_degrees))
  match c.nodal_kind {
    NodalKind::Solar => (1.0, 0.0)
    NodalKind::SemiDiurnal => {
      let f = 1.0004 - 0.0373 * @math.cos(n) + 0.0002 * @math.cos(2.0 * n)
      let u = -2.14 * @math.sin(n)
      (f, u)
    }
    NodalKind::LunarDiurnal => {
      let f = 1.0089 +
        0.1871 * @math.cos(n) -
        0.0147 * @math.cos(2.0 * n) +
        0.0014 * @math.cos(3.0 * n)
      let u = 10.8 * @math.sin(n) -
        1.3 * @math.sin(2.0 * n) +
        0.2 * @math.sin(3.0 * n)
      (f, u)
    }
    NodalKind::LuniSolarDiurnal => {
      let f = 1.0060 +
        0.1150 * @math.cos(n) -
        0.0088 * @math.cos(2.0 * n) +
        0.0006 * @math.cos(3.0 * n)
      let u = -8.9 * @math.sin(n) + 0.7 * @math.sin(2.0 * n)
      (f, u)
    }
  }
}

///|
/// Tide height in meters for a station at a Julian day.
pub fn tide_height(station : Station, jd : Double) -> Double {
  let a = astro_at(jd)
  let t_hours = (jd - 2451545.0) * 24.0
  let mut height = station.datum
  for hc in station.components {
    let (f, u) = nodal_correction(hc.constituent, a.n)
    let phase = equilibrium_argument(hc.constituent, a, t_hours) +
      u -
      hc.phase_lag
    height = height + f * hc.amplitude * @math.cos(to_radians(phase))
  }
  height
}
