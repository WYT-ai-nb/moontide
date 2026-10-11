/// Nodal-correction family for a constituent.
pub enum NodalKind {
  Solar
  SemiDiurnal
  LunarDiurnal
  LuniSolarDiurnal
} derive(Eq, Debug)

/// A tidal harmonic constituent expressed with Doodson numbers.
pub struct Constituent {
  name : String
  d1 : Int
  d2 : Int
  d3 : Int
  d4 : Int
  d5 : Int
  d6 : Int
  speed : Double
  nodal_kind : NodalKind
} derive(Debug)

fn constituent(
  name : String,
  d1 : Int,
  d2 : Int,
  d3 : Int,
  d4 : Int,
  d5 : Int,
  d6 : Int,
  nodal_kind : NodalKind,
) -> Constituent {
  let speed = d1.to_double() * 14.4920521 +
    d2.to_double() * 0.54901653 +
    d3.to_double() * 0.04106864 +
    d4.to_double() * 0.00464183 +
    d5.to_double() * 0.00220641 +
    d6.to_double() * 0.00000196
  { name, d1, d2, d3, d4, d5, d6, speed, nodal_kind }
}

/// The standard set of constituents supported by MoonTide.
pub fn standard_constituents() -> Array[Constituent] {
  [
    constituent("M2", 2, 0, 0, 0, 0, 0, NodalKind::SemiDiurnal),
    constituent("S2", 2, 2, -2, 0, 0, 0, NodalKind::Solar),
    constituent("N2", 2, -1, 0, 1, 0, 0, NodalKind::SemiDiurnal),
    constituent("K2", 2, 2, 0, 0, 0, 0, NodalKind::SemiDiurnal),
    constituent("K1", 1, 1, 0, 0, 0, 0, NodalKind::LuniSolarDiurnal),
    constituent("O1", 1, -1, 0, 0, 0, 0, NodalKind::LunarDiurnal),
    constituent("P1", 1, 1, -2, 0, 0, 0, NodalKind::Solar),
    constituent("Q1", 1, -2, 0, 1, 0, 0, NodalKind::LunarDiurnal),
    constituent("M4", 4, 0, 0, 0, 0, 0, NodalKind::SemiDiurnal),
    constituent("MS4", 4, 2, -2, 0, 0, 0, NodalKind::SemiDiurnal),
    constituent("M6", 6, 0, 0, 0, 0, 0, NodalKind::SemiDiurnal),
  ]
}

/// Find a constituent by name (case-insensitive).
pub fn find_constituent(name : String) -> Constituent? {
  let wanted = name.to_upper()
  for c in standard_constituents() {
    if c.name == wanted {
      return Some(c)
    }
  }
  None
}
