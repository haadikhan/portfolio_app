import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:portfolio_app/src/features/market/data/models/kmi30_bar.dart";
import "package:portfolio_app/src/features/market/presentation/providers/kmi30_companies_providers.dart";

/// Daily KMI30 index bars for the five-market dashboard hero chart.
final kmi30IndexDailyKlinesProvider =
    FutureProvider.autoDispose<List<Kmi30Bar>>((ref) async {
  final repo = ref.read(psxRepositoryProvider);
  return repo.fetchKlines("KMI30", "1d", limit: 30);
});
