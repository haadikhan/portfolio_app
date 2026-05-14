import "dart:async";

import "package:flutter_riverpod/flutter_riverpod.dart";

import "package:portfolio_app/src/features/market/data/models/kmi30_index_tick.dart";
import "package:portfolio_app/src/features/market/data/repositories/psx_repository.dart";
import "package:portfolio_app/src/features/market/presentation/providers/kmi30_companies_providers.dart";
import "package:portfolio_app/src/providers/auth_providers.dart";

/// Polls KMI30 index from PSX REST (`PsxRepository.fetchIndexTick`).
/// Emits every 5 minutes while a user is signed in (daily klines).
final kmi30IndexTickProvider = StreamProvider<Kmi30IndexTick?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return Stream<Kmi30IndexTick?>.value(null);
  }

  final controller = StreamController<Kmi30IndexTick?>();
  var active = true;

  Future<void> loop() async {
    final PsxRepository repo = ref.read(psxRepositoryProvider);
    while (active && !controller.isClosed) {
      try {
        final tick = await repo.fetchIndexTick("KMI30");
        if (!controller.isClosed) {
          controller.add(tick);
        }
      } catch (_) {
        if (!controller.isClosed) {
          controller.add(null);
        }
      }
      await Future<void>.delayed(const Duration(minutes: 5));
    }
  }

  ref.onDispose(() {
    active = false;
    unawaited(controller.close());
  });

  unawaited(loop());
  return controller.stream;
});
