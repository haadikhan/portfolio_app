import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:package_info_plus/package_info_plus.dart";

import "../../../providers/auth_providers.dart";

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.versionName,
    required this.versionCode,
    required this.requiredAfterDays,
    required this.publishedAt,
    required this.title,
    required this.message,
    required this.isActive,
    this.packageId,
    this.releaseRef,
    this.apkStoragePath,
    this.apkUrl,
  });

  final String versionName;
  final int versionCode;
  final int requiredAfterDays;
  final DateTime? publishedAt;
  final String title;
  final String message;
  final bool isActive;
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
  if (appVersionAsync.isLoading || releaseAsync.isLoading) {
    return const AsyncLoading();
  }

  final appVersion = appVersionAsync.valueOrNull ?? (0, "");
  final release = releaseAsync.valueOrNull;
  final installedCode = appVersion.$1;
  final installedName = appVersion.$2;
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

  final isOutdated = installedCode < release.versionCode;
  final publishedAt = release.publishedAt;
  if (!isOutdated || publishedAt == null) {
    return AsyncData(
      AppUpdateGateState(
        installedVersionCode: installedCode,
        installedVersionName: installedName,
        release: release,
        isOutdated: isOutdated,
        isBlocked: false,
        daysLeft: isOutdated ? release.requiredAfterDays.clamp(1, 365) : 0,
      ),
    );
  }
  final graceDays = release.requiredAfterDays.clamp(1, 365);
  final deadline = publishedAt.add(Duration(days: graceDays));
  final now = DateTime.now();
  final remaining = deadline.difference(now);
  final rawDays = (remaining.inHours / 24).ceil();
  final daysLeft = rawDays.clamp(0, graceDays);
  final isBlocked = now.isAfter(deadline);

  return AsyncData(
    AppUpdateGateState(
      installedVersionCode: installedCode,
      installedVersionName: installedName,
      release: release,
      isOutdated: isOutdated,
      isBlocked: isBlocked,
      daysLeft: daysLeft,
    ),
  );
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
