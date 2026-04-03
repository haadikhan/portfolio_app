import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../providers/auth_providers.dart";
import "../providers/notification_providers.dart";

/// Investor vs admin: deep links differ for [action] / [refId].
enum NotificationShellKind { investor, admin }

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({
    super.key,
    this.shell = NotificationShellKind.investor,
  });

  final NotificationShellKind shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid;
    final async = ref.watch(userNotificationsStreamProvider);

    final listBody = uid == null
        ? Center(child: Text(context.tr("sign_in_required")))
        : async.when(
            data: (snap) {
              if (snap.docs.isEmpty) {
                return Center(child: Text(context.tr("notifications_empty")));
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(userNotificationsStreamProvider);
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: snap.docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final doc = snap.docs[i];
                    final d = doc.data();
                    final read = d["read"] == true;
                    final title = (d["title"] as String?) ?? "";
                    final body = (d["body"] as String?) ?? "";
                    final action = (d["action"] as String?) ?? "none";
                    final refId = d["refId"] as String?;
                    final created = d["createdAt"] as Timestamp?;
                    final subtitle = created != null
                        ? DateFormat.yMMMd().add_jm().format(created.toDate())
                        : "";

                    return ListTile(
                      leading: Icon(
                        read
                            ? Icons.notifications_none
                            : Icons.notifications,
                        color: read
                            ? Theme.of(context).colorScheme.outline
                            : Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          fontWeight:
                              read ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subtitle.isNotEmpty) Text(subtitle),
                          Text(body),
                        ],
                      ),
                      isThreeLine: true,
                      onTap: () async {
                        if (!read) {
                          await doc.reference.update({
                            "read": true,
                            "readAt": FieldValue.serverTimestamp(),
                          });
                        }
                        if (!context.mounted) return;
                        _navigateForAction(context, action, refId);
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text("$e")),
          );

    if (shell == NotificationShellKind.admin) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr("notifications"),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (uid != null)
                  TextButton(
                    onPressed: () => _markAllRead(context, ref, uid),
                    child: Text(context.tr("mark_all_read")),
                  ),
              ],
            ),
          ),
          Expanded(child: listBody),
        ],
      );
    }

    return AppScaffold(
      title: context.tr("notifications"),
      showNotificationAction: false,
      actions: [
        if (uid != null)
          TextButton(
            onPressed: () => _markAllRead(context, ref, uid),
            child: Text(context.tr("mark_all_read")),
          ),
      ],
      body: listBody,
    );
  }

  Future<void> _markAllRead(
    BuildContext context,
    WidgetRef ref,
    String uid,
  ) async {
    final db = ref.read(firebaseFirestoreProvider);
    final qs = await db
        .collection("users")
        .doc(uid)
        .collection("notifications")
        .where("read", isEqualTo: false)
        .get();
    if (qs.docs.isEmpty) return;
    var batch = db.batch();
    var n = 0;
    for (final d in qs.docs) {
      batch.update(d.reference, {
        "read": true,
        "readAt": FieldValue.serverTimestamp(),
      });
      n++;
      if (n >= 450) {
        await batch.commit();
        batch = db.batch();
        n = 0;
      }
    }
    if (n > 0) await batch.commit();
    if (context.mounted) {
      ref.invalidate(userNotificationsStreamProvider);
    }
  }

  void _navigateForAction(
    BuildContext context,
    String action,
    String? refId,
  ) {
    if (shell == NotificationShellKind.admin) {
      switch (action) {
        case "open_deposits":
          context.go("/deposits");
          return;
        case "open_withdrawals":
          context.go("/withdrawals");
          return;
        case "open_kyc":
          if (refId != null && refId.isNotEmpty) {
            context.go("/kyc/$refId");
          }
          return;
        default:
          return;
      }
    }
    switch (action) {
      case "open_wallet":
        context.go("/wallet-ledger");
        return;
      case "open_portfolio":
        context.go("/portfolio");
        return;
      default:
        return;
    }
  }
}
