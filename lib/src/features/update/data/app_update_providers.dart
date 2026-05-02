import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../../providers/auth_providers.dart";

/// SharedPreferences key: last acknowledged publish generation from Firestore.
const kAppReleaseAckGenerationKey = "app_release_ack_generation";

final releaseAcknowledgedGenerationNotifierProvider =
    AsyncNotifierProvider<ReleaseAcknowledgedGenerationNotifier, int>(
  ReleaseAcknowledgedGenerationNotifier.new,
);

class ReleaseAcknowledgedGenerationNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(kAppReleaseAckGenerationKey) ?? 0;
  }

  Future<void> acknowledgeUpTo(int generation) async {
    if (generation <= 0) return;
    final p = await SharedPreferences.getInstance();
    final prev = p.getInt(kAppReleaseAckGenerationKey) ?? 0;
    if (generation <= prev) return;
    await p.setInt(kAppReleaseAckGenerationKey, generation);
    state = AsyncData(generation);
  }
}

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.versionName,
    required this.versionCode,
    required this.requiredAfterDays,
    required this.publishedAt,
    required this.title,
    required this.message,
    required this.isActive,
    this.releaseGeneration = 0,
    this.packageId,
    this.releaseRef,
    this.apkStoragePath,
    this.apkUrl,
  });

  final String versionName;
  final int versionCode;

  /// 0 = immediate block when outstanding; otherwise grace days after publish.
  final int requiredAfterDays;
  final DateTime? publishedAt;
  final String title;
  final String message;
  final bool isActive;

  /// >0 once admin published with newer flow (`FieldValue.increment` on write).
  /// When absent in Firestore, gate falls back to versionCode compares (legacy docs).
  final int releaseGeneration;
  final String? packageId;
  final String? releaseRef;
  final String? apkStoragePath;
  final String? apkUrl;

  factory AppReleaseInfo.fromMap(Map<String, dynamic> map) {
    final ts = map["publishedAt"];
    final date = ts is Timestamp ? ts.toDate() : null;
    return AppReleaseInfo(
      versionName: (map["versionName"] ?? "").toString(),
      versionCode: (map["versionCode"] as num?)?.toInt() ?? 0,
      requiredAfterDays: (map["requiredAfterDays"] as num?)?.toInt() ?? 7,
      releaseGeneration: (map["releaseGeneration"] as num?)?.toInt() ?? 0,
      publishedAt: date,
      title: (map["title"] ?? "").toString(),
      message: (map["message"] ?? "").toString(),
      isActive: map["isActive"] == true,
      packageId: (map["packageId"] as String?)?.trim(),
      releaseRef: (map["releaseRef"] as String?)?.trim(),
      apkStoragePath: (map["apkStoragePath"] as String?)?.trim(),
      apkUrl: (map["apkUrl"] as String?)?.trim(),
    );
  }
}

class AppUpdateGateState {
  const AppUpdateGateState({
    required this.installedVersionCode,
    required this.installedVersionName,
    required this.release,
    required this.isOutdated,
    required this.isBlocked,
    required this.daysLeft,
  });

  final int installedVersionCode;
  final String installedVersionName;
  final AppReleaseInfo? release;
  final bool isOutdated;
  final bool isBlocked;
  final int daysLeft;

  bool get showGraceBanner => isOutdated && !isBlocked;
}

AppUpdateGateState _legacyVersionGate({
  required int installedCode,
  required String installedName,
  required AppReleaseInfo release,
}) {
  final isOutdated = installedCode < release.versionCode;
  final publishedAt = release.publishedAt;
  final graceLegacy = release.requiredAfterDays <= 0
      ? 7
      : release.requiredAfterDays.clamp(1, 365);
  if (!isOutdated || publishedAt == null) {
    return AppUpdateGateState(
      installedVersionCode: installedCode,
      installedVersionName: installedName,
      release: release,
      isOutdated: isOutdated,
      isBlocked: false,
      daysLeft: isOutdated ? graceLegacy : 0,
    );
  }
  final deadline = publishedAt.add(Duration(days: graceLegacy));
  final now = DateTime.now();
  final remaining = deadline.difference(now);
  final rawDays = (remaining.inHours / 24).ceil();
  final daysLeft = rawDays.clamp(0, graceLegacy);
  final isBlocked = now.isAfter(deadline);
  return AppUpdateGateState(
    installedVersionCode: installedCode,
    installedVersionName: installedName,
    release: release,
    isOutdated: isOutdated,
    isBlocked: isBlocked,
    daysLeft: daysLeft,
  );
}

AppUpdateGateState _generationGate({
  required int installedCode,
  required String installedName,
  required AppReleaseInfo release,
  required int acknowledgedGeneration,
}) {
  final outstanding = release.releaseGeneration > acknowledgedGeneration;
  final forceDays = release.requiredAfterDays.clamp(0, 365);
  final publishedAt = release.publishedAt;
  final now = DateTime.now();

  if (!outstanding) {
    return AppUpdateGateState(
      installedVersionCode: installedCode,
      installedVersionName: installedName,
      release: release,
      isOutdated: false,
      isBlocked: false,
      daysLeft: 0,
    );
  }

  if (forceDays == 0) {
    return AppUpdateGateState(
      installedVersionCode: installedCode,
      installedVersionName: installedName,
      release: release,
      isOutdated: true,
      isBlocked: true,
      daysLeft: 0,
    );
  }

  if (publishedAt == null) {
    return AppUpdateGateState(
      installedVersionCode: installedCode,
      installedVersionName: installedName,
      release: release,
      isOutdated: true,
      isBlocked: false,
      daysLeft: forceDays,
    );
  }

  final deadline = publishedAt.add(Duration(days: forceDays));
  final remaining = deadline.difference(now);
  final rawDays = (remaining.inHours / 24).ceil();
  final daysLeft = rawDays.clamp(0, forceDays);
  final isBlocked = now.isAfter(deadline);
  return AppUpdateGateState(
    installedVersionCode: installedCode,
    installedVersionName: installedName,
    release: release,
    isOutdated: true,
    isBlocked: isBlocked,
    daysLeft: daysLeft,
  );
}

final appReleaseStreamProvider = StreamProvider<AppReleaseInfo?>((ref) {
  return ref
      .read(firebaseFirestoreProvider)
      .collection("app_releases")
      .doc("current_android")
      .snapshots()
      .map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        final info = AppReleaseInfo.fromMap(doc.data()!);
        if (!info.isActive) return null;
        return info;
      });
});

final installedAppVersionProvider = FutureProvider<(int, String)>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final code = int.tryParse(info.buildNumber.trim()) ?? 0;
  return (code, info.version);
});

final appUpdateGateProvider = Provider<AsyncValue<AppUpdateGateState>>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const AsyncData(
      AppUpdateGateState(
        installedVersionCode: 0,
        installedVersionName: "",
        release: null,
        isOutdated: false,
        isBlocked: false,
        daysLeft: 0,
      ),
    );
  }

  final appVersionAsync = ref.watch(installedAppVersionProvider);
  final releaseAsync = ref.watch(appReleaseStreamProvider);
  final ackAsync = ref.watch(releaseAcknowledgedGenerationNotifierProvider);

  if (appVersionAsync.hasError) {
    return AsyncError(
      appVersionAsync.error!,
      appVersionAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (releaseAsync.hasError) {
    return AsyncError(
      releaseAsync.error!,
      releaseAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (ackAsync.hasError) {
    return AsyncError(
      ackAsync.error!,
      ackAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (appVersionAsync.isLoading ||
      releaseAsync.isLoading ||
      ackAsync.isLoading) {
    return const AsyncLoading();
  }

  final appVersion = appVersionAsync.valueOrNull ?? (0, "");
  final release = releaseAsync.valueOrNull;
  final installedCode = appVersion.$1;
  final installedName = appVersion.$2;
  final ack = ackAsync.value ?? 0;

  if (release == null || release.versionCode <= 0) {
    return AsyncData(
      AppUpdateGateState(
        installedVersionCode: installedCode,
        installedVersionName: installedName,
        release: null,
        isOutdated: false,
        isBlocked: false,
        daysLeft: 0,
      ),
    );
  }

  if (release.releaseGeneration <= 0) {
    return AsyncData(
      _legacyVersionGate(
        installedCode: installedCode,
        installedName: installedName,
        release: release,
      ),
    );
  }

  return AsyncData(
    _generationGate(
      installedCode: installedCode,
      installedName: installedName,
      release: release,
      acknowledgedGeneration: ack,
    ),
  );
});

final _lastKnownAppUpdateGateProvider = StateProvider<AppUpdateGateState?>(
  (ref) => null,
);

final stableAppUpdateGateProvider = Provider<AsyncValue<AppUpdateGateState>>((
  ref,
) {
  final raw = ref.watch(appUpdateGateProvider);
  final lastKnown = ref.watch(_lastKnownAppUpdateGateProvider);
  ref.listen<AsyncValue<AppUpdateGateState>>(appUpdateGateProvider, (_, next) {
    next.whenData((gate) {
      ref.read(_lastKnownAppUpdateGateProvider.notifier).state = gate;
    });
  });

  if ((raw.isLoading || raw.hasError) && lastKnown != null) {
    return AsyncData(lastKnown);
  }
  return raw;
});

final updatePopupShownThisLaunchProvider = StateProvider<bool>((ref) => false);

final resolvedApkDownloadUrlProvider =
    FutureProvider.family<String?, AppReleaseInfo>((ref, release) async {
      final direct = release.apkUrl;
      if (direct != null && direct.isNotEmpty) return direct;
      final path = release.apkStoragePath;
      if (path == null || path.isEmpty) return null;
      return FirebaseStorage.instance.ref(path).getDownloadURL();
    });
