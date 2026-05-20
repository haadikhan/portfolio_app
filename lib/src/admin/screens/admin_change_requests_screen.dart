import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../core/i18n/app_translations.dart";
import "../../features/service_requests/models/change_request.dart";
import "../providers/admin_change_request_providers.dart";

String _localizedRequestType(BuildContext context, String requestType) {
  final trimmed = requestType.trim().toLowerCase();
  if (trimmed.isEmpty) return requestType.trim();
  final key = "sr_type_$trimmed";
  final s = context.tr(key);
  if (s == key) return requestType.trim();
  return s;
}

class AdminChangeRequestsScreen extends ConsumerStatefulWidget {
  const AdminChangeRequestsScreen({super.key});

  @override
  ConsumerState<AdminChangeRequestsScreen> createState() =>
      _AdminChangeRequestsScreenState();
}

class _AdminChangeRequestsScreenState extends ConsumerState<AdminChangeRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dt = DateFormat.yMMMd().add_Hm();
    final pendingAsync = ref.watch(pendingChangeRequestsAdminProvider);
    final allAsync = ref.watch(adminAllChangeRequestsProvider);
    final acting = ref.watch(adminChangeRequestActionProvider).isLoading;

    Widget buildList(List<ChangeRequest> list, {required bool pendingOnly}) {
      if (list.isEmpty) {
        return Center(
          child: Text(
            pendingOnly
                ? context.tr("admin_cr_empty")
                : context.tr("admin_cr_all_empty"),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final r = list[i];
          return AdminChangeRequestTicketTile(request: r, dt: dt, interactionsDisabled: acting);
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr("admin_change_requests_title"),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: context.tr("sr_tab_pending")),
              Tab(text: context.tr("sr_tab_all")),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                pendingAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text("${context.tr("error_prefix")} $e")),
                  data: (list) => buildList(list, pendingOnly: true),
                ),
                allAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text("${context.tr("error_prefix")} $e")),
                  data: (list) => buildList(list, pendingOnly: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminChangeRequestTicketTile extends ConsumerWidget {
  const AdminChangeRequestTicketTile({
    super.key,
    required this.request,
    required this.dt,
    required this.interactionsDisabled,
    this.actionsEnabled = true,
  });

  final ChangeRequest request;
  final DateFormat dt;
  final bool interactionsDisabled;
  final bool actionsEnabled;

  String _uidShort(String uid) =>
      uid.length <= 8 ? uid : uid.substring(0, 8);

  String _ticketShort(String id) =>
      id.length <= 8 ? id : id.substring(0, 8);

  Map<String, String> _flatten(Map<String, dynamic> m) {
    return <String, String>{
      for (final e in m.entries)
        e.key.toString(): (e.value == null ? "—" : "${e.value}"),
    };
  }

  Future<void> _confirmApprove(BuildContext context, WidgetRef ref) async {
    final noteCtrl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr("admin_cr_confirm_approve")),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr("admin_cr_optional_note_title")),
              const SizedBox(height: 10),
              TextField(
                controller: noteCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.tr("admin_cr_note_hint"),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr("cancel")),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr("admin_cr_approve")),
            ),
          ],
        ),
      );
      if (ok != true) return;

      await ref
          .read(adminChangeRequestActionProvider.notifier)
          .approve(request, note: noteCtrl.text.trim().isEmpty
              ? null
              : noteCtrl.text.trim());
      final state = ref.read(adminChangeRequestActionProvider);
      if (!context.mounted) return;
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${state.error}")),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("admin_cr_approved_success"))),
      );
    } finally {
      noteCtrl.dispose();
    }
  }

  Future<void> _confirmReject(BuildContext context, WidgetRef ref) async {
    final noteCtrl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.tr("admin_cr_confirm_reject")),
          content: TextField(
            controller: noteCtrl,
            decoration: InputDecoration(
              labelText: context.tr("admin_cr_note_hint"),
              hintText: context.tr("admin_cr_note_hint"),
              border: const OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.tr("cancel")),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error,
                foregroundColor: Theme.of(ctx).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.tr("admin_cr_reject")),
            ),
          ],
        ),
      );
      if (ok != true) return;
      if (noteCtrl.text.trim().isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr("admin_cr_note_required"))),
        );
        return;
      }

      await ref
          .read(adminChangeRequestActionProvider.notifier)
          .reject(request, note: noteCtrl.text.trim());

      final state = ref.read(adminChangeRequestActionProvider);
      if (!context.mounted) return;
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${state.error}")),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("admin_cr_rejected_success"))),
      );
    } finally {
      noteCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    Widget statusBadge() {
      late Color fg;
      late Color bg;
      late String txt;
      if (request.isPending) {
        txt = context.tr("sr_status_pending");
        fg = const Color(0xFFB45309);
        bg = fg.withValues(alpha: 0.12);
      } else if (request.isApproved) {
        txt = context.tr("sr_status_approved");
        fg = scheme.primary;
        bg = fg.withValues(alpha: 0.12);
      } else {
        txt = context.tr("sr_status_rejected");
        fg = scheme.error;
        bg = fg.withValues(alpha: 0.12);
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          txt,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
            color: fg,
          ),
        ),
      );
    }

    final curMap = _flatten(request.currentFields);
    final reqMap = _flatten(request.requestedFields);

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(14),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        childrenPadding:
            const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            statusBadge(),
            Text(
              _localizedRequestType(context, request.requestType),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${context.tr("admin_cr_investor_label")}: ${_uidShort(request.uid)}",
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            Text(
              "${context.tr("sr_ticket_id_label")}: ${_ticketShort(request.ticketId)}",
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            Text(
              "${context.tr("sr_requested_at_label")}: ${dt.format(request.requestedAt.toLocal())}",
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.tr("sr_current_fields_label"),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final e in curMap.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      e.key,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                  Expanded(child: Text(e.value)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.tr("sr_requested_values_section"),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final e in reqMap.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      e.key,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                  Expanded(child: Text(e.value)),
                ],
              ),
            ),
          if (request.reviewNote != null &&
              request.reviewNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              "${context.tr("sr_review_note_label")}: ${request.reviewNote}",
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
          if (actionsEnabled &&
              request.isPending &&
              !interactionsDisabled) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed:
                        interactionsDisabled ? null : () => _confirmApprove(context, ref),
                    child: Text(context.tr("admin_cr_approve")),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed:
                        interactionsDisabled ? null : () => _confirmReject(context, ref),
                    child: Text(context.tr("admin_cr_reject")),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
