import "models/kmi30_bar.dart";

/// Pakistani bullion: 1 tola = 11.664 g; 1 troy oz = 31.1034768 g (international spot).
const double kGramsPerPakTola = 11.664;
const double kGramsPerTroyOz = 31.1034768;

/// PKR amounts in the app are stored as **per troy ounce**; UI can show per tola instead.
enum GoldPkrUnit {
  troyOz,
  tola,
}

/// Multiply PKR **per troy ounce** to get PKR **per Pakistani tola**.
double pkrPerTolaFromPkrPerTroyOz(double pkrPerOz) =>
    pkrPerOz * (kGramsPerPakTola / kGramsPerTroyOz);

/// Scale stored PKR (per troy oz) for display under [unit].
double goldPkrDisplayFactor(GoldPkrUnit unit) => switch (unit) {
      GoldPkrUnit.troyOz => 1.0,
      GoldPkrUnit.tola => kGramsPerPakTola / kGramsPerTroyOz,
    };

/// Scale chart bars (PKR per troy oz in storage) for per-tola display.
List<Kmi30Bar> scaleGoldBarsPkr(List<Kmi30Bar> bars, double factor) {
  if (factor == 1.0) return bars;
  return bars
      .map(
        (b) => Kmi30Bar(
          symbol: b.symbol,
          timeframe: b.timeframe,
          timestamp: b.timestamp,
          open: b.open * factor,
          high: b.high * factor,
          low: b.low * factor,
          close: b.close * factor,
          volume: b.volume,
        ),
      )
      .toList();
}
