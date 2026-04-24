import "dart:async";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:cloud_functions/cloud_functions.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../providers/auth_providers.dart";

class ProjectionConfig {
  const ProjectionConfig({
    required this.isEnabled,
    required this.globalAnnualRatePct,
  });

  final bool isEnabled;
  final double globalAnnualRatePct;

  factory ProjectionConfig.fromMap(Map<String, dynamic> data) {
    double readRate() {
      const keys = [
        "globalAnnualRatePct",
        "annualRatePct",
        "annualRate",
        "yearlyRatePct",
      ];
      for (final key in keys) {
        final raw = data[key];
        if (raw is num) return raw.toDouble();
        if (raw is String) {
          final sanitized = raw.replaceAll("%", "").trim();
          final parsed = double.tryParse(sanitized);
          if (parsed != null) return parsed;
        }
      }
      return 0;
    }

    return ProjectionConfig(
      isEnabled: data["isEnabled"] == true,
      globalAnnualRatePct: readRate(),
    );
  }
}

class InvestorProjectionOverride {
  const InvestorProjectionOverride({
    required this.enabled,
    required this.annualRatePct,
  });

  final bool enabled;
  final double annualRatePct;

  factory InvestorProjectionOverride.fromMap(Map<String, dynamic> data) {
    return InvestorProjectionOverride(
      enabled: data["enabled"] == true,
      annualRatePct: (data["annualRatePct"] as num?)?.toDouble() ?? 0,
    );
  }
}

final projectionConfigProvider = StreamProvider<ProjectionConfig?>((ref) {
  return authBoundFirestoreStream<ProjectionConfig?>(
    ref,
    whenSignedOut: null,
    body: (_) {
      return ref
          .read(firebaseFirestoreProvider)
          .collection("settings")
          .doc("returns_projection")
          .snapshots()
          .map((doc) {
            final data = doc.data();
            if (!doc.exists || data == null) return null;
            return ProjectionConfig.fromMap(data);
          });
    },
  );
});

final projectionConfigCallableProvider = FutureProvider<ProjectionConfig?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  try {
    final fn = FirebaseFunctions.instanceFor(region: "us-central1");
    final result = await fn.httpsCallable("getReturnsProjectionConfig").call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return ProjectionConfig.fromMap(data);
  } catch (_) {
    return null;
  }
});

final investorProjectionOverrideProvider =
    StreamProvider.family<InvestorProjectionOverride?, String>((ref, uid) {
      return authBoundFirestoreStream<InvestorProjectionOverride?>(
        ref,
        whenSignedOut: null,
        body: (_) {
          return ref
              .read(firebaseFirestoreProvider)
              .collection("settings")
              .doc("returns_projection_overrides")
              .collection("items")
              .doc(uid)
              .snapshots()
              .map((doc) {
                final data = doc.data();
                if (!doc.exists || data == null) return null;
                return InvestorProjectionOverride.fromMap(data);
              });
        },
      );
    });

final resolvedProjectionRateProvider = Provider<AsyncValue<double>>((ref) {
  final user = ref.watch(currentUserProvider);
  final configAsync = ref.watch(projectionConfigProvider);
  final callableConfigAsync = ref.watch(projectionConfigCallableProvider);
  if (user == null) return const AsyncData(0);
  final overrideAsync = ref.watch(investorProjectionOverrideProvider(user.uid));

  final streamConfig = configAsync.valueOrNull;
  final callableConfig = callableConfigAsync.valueOrNull;
  final config = (streamConfig?.globalAnnualRatePct ?? 0) > 0
      ? streamConfig
      : callableConfig;
  final override = overrideAsync.hasError ? null : overrideAsync.valueOrNull;
  final overrideRate = (override?.annualRatePct ?? 0).clamp(0, 100).toDouble();
  if (override != null && override.enabled && overrideRate > 0) {
    return AsyncData(overrideRate);
  }
  if (config == null) {
    return const AsyncData(0);
  }
  return AsyncData(config.globalAnnualRatePct.clamp(0, 100).toDouble());
});

final firstApprovedDepositAtProvider = FutureProvider<DateTime?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  try {
    final snap = await ref
        .read(firebaseFirestoreProvider)
        .collection("transactions")
        .where("userId", isEqualTo: user.uid)
        .get();
    DateTime? earliest;
    for (final doc in snap.docs) {
      final data = doc.data();
      final type = (data["type"] ?? "").toString().trim().toLowerCase();
      final status = (data["status"] ?? "").toString().trim().toLowerCase();
      final isDeposit = type == "deposit";
      final isAccepted = status == "approved" || status == "completed";
      if (!isDeposit || !isAccepted) continue;

      DateTime? dt;
      for (final key in ["approvedAt", "completedAt", "createdAt", "updatedAt"]) {
        final raw = data[key];
        if (raw is Timestamp) {
          dt = raw.toDate();
          break;
        }
        if (raw != null) {
          final parsed = DateTime.tryParse(raw.toString());
          if (parsed != null) {
            dt = parsed;
            break;
          }
        }
      }
      if (dt == null) continue;
      if (earliest == null || dt.isBefore(earliest)) {
        earliest = dt;
      }
    }
    return earliest;
  } catch (_) {
    return null;
  }
});

final liveProfitNowProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  controller.add(DateTime.now());
  final timer = Timer.periodic(const Duration(seconds: 1), (_) {
    controller.add(DateTime.now());
  });
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});
