import "models/kmi30_company.dart";

const kmi30SeedCompanies = <Kmi30Company>[
  Kmi30Company(symbol: "OGDC", name: "Oil & Gas Dev. Co.", weightPercent: 12.00),
  Kmi30Company(symbol: "MEBL", name: "Meezan Bank", weightPercent: 11.50),
  Kmi30Company(symbol: "MARI", name: "Mari Energies", weightPercent: 10.00),
  Kmi30Company(symbol: "FFC", name: "Fauji Fertilizer Co.", weightPercent: 7.50),
  Kmi30Company(symbol: "PPL", name: "Pakistan Petroleum", weightPercent: 6.50),
  Kmi30Company(symbol: "LUCK", name: "Lucky Cement", weightPercent: 6.00),
  Kmi30Company(symbol: "ENGROH", name: "Engro Holdings", weightPercent: 5.50),
  Kmi30Company(symbol: "HUBC", name: "Hub Power Co.", weightPercent: 5.00),
  Kmi30Company(symbol: "EFERT", name: "Engro Fertilizers", weightPercent: 4.50),
  Kmi30Company(symbol: "SYS", name: "Systems Ltd.", weightPercent: 4.00),
  Kmi30Company(symbol: "PSO", name: "Pakistan State Oil", weightPercent: 3.50),
  Kmi30Company(symbol: "POL", name: "Pakistan Oilfields", weightPercent: 3.00),
  Kmi30Company(symbol: "ENGRO", name: "Engro Corporation", weightPercent: 2.50),
  Kmi30Company(symbol: "SNGP", name: "Sui Northern Gas", weightPercent: 2.00),
  Kmi30Company(symbol: "PSEL", name: "Pakistan Elec. Supply", weightPercent: 1.80),
  Kmi30Company(symbol: "SEARL", name: "The Searle Company", weightPercent: 1.60),
  Kmi30Company(
    symbol: "AIRLINK",
    name: "Air Link Communication",
    weightPercent: 1.40,
  ),
  Kmi30Company(symbol: "ACPL", name: "Attock Cement", weightPercent: 1.30),
  Kmi30Company(symbol: "CHCC", name: "Cherat Cement", weightPercent: 1.20),
  Kmi30Company(symbol: "TRG", name: "TRG Pakistan", weightPercent: 1.10),
  Kmi30Company(symbol: "MLCF", name: "Maple Leaf Cement", weightPercent: 1.00),
  Kmi30Company(symbol: "FCCL", name: "Fauji Cement", weightPercent: 1.40),
  Kmi30Company(symbol: "PKGS", name: "Packages Ltd.", weightPercent: 1.30),
  Kmi30Company(symbol: "NESTLE", name: "Nestle Pakistan", weightPercent: 1.25),
  Kmi30Company(symbol: "HCAR", name: "Honda Atlas Cars", weightPercent: 0.65),
  Kmi30Company(symbol: "NML", name: "Nishat Mills", weightPercent: 0.60),
  Kmi30Company(symbol: "TREET", name: "Treet Corporation", weightPercent: 0.55),
  Kmi30Company(symbol: "MTL", name: "Millat Tractors", weightPercent: 0.50),
  Kmi30Company(symbol: "SAZEW", name: "Sazgar Engineering", weightPercent: 0.45),
  Kmi30Company(symbol: "PAEL", name: "Pak Elektron", weightPercent: 0.40),
];
// Weights sum to 100.0 — update each PSX recomposition cycle (next: Nov 2026).

/// Debug-only guard that seed weights sum to 100%.
void assertKmi30WeightSum() {
  assert(() {
    final sum = kmi30SeedCompanies.fold<double>(
      0,
      (s, c) => s + c.weightPercent,
    );
    assert(
      (sum - 100.0).abs() < 0.1,
      "KMI30 weights sum to $sum — must be 100.0",
    );
    return true;
  }());
}
