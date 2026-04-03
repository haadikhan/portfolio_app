import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../core/i18n/app_translations.dart";
import "../models/admin_investor_models.dart";
import "../providers/admin_providers.dart";
import "crm_models.dart";
import "crm_providers.dart";

class CrmInvestorDetailScreen extends ConsumerStatefulWidget {
  const CrmInvestorDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<CrmInvestorDetailScreen> createState() =>
      _CrmInvestorDetailScreenState();
}

class _CrmInvestorDetailScreenState extends ConsumerState<CrmInvestorDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(investorDetailProvider(widget.userId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("$e")),
      data: (detail) {
        if (detail == null) {
          return const Center(child: Text("—"));
        }
        final u = detail.summary;
        final currency = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => context.go("/crm/investors"),
                icon: const Icon(Icons.arrow_back),
                label: Text(context.tr("crm_nav_investors")),
              ),
              const SizedBox(height: 8),
              Text(
                u.name.isNotEmpty ? u.name : u.userId,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                u.email.isNotEmpty ? u.email : "—",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Chip(label: Text("${context.tr("crm_kyc_label")}: ${u.kycStatus}")),
                  Chip(
                    label: Text(
                      "${context.tr("current_balance")}: ${currency.format(detail.wallet.balance)}",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabs: [
                  Tab(text: context.tr("crm_tab_overview")),
                  Tab(text: context.tr("crm_notes")),
                  Tab(text: context.tr("crm_followups")),
                  Tab(text: context.tr("crm_communications")),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _OverviewTab(detail: detail),
                    _NotesTab(userId: widget.userId),
                    _FollowupsTab(userId: widget.userId),
                    _CommsTab(userId: widget.userId),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.detail});

  final AdminInvestorDetail detail;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);
    final dt = DateFormat.yMMMd().add_Hm();
    final tx = detail.transactions;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr("crm_tab_overview"), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (tx.isEmpty)
            Text(context.tr("txn_empty_generic"))
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text("Date")),
                    DataColumn(label: Text("Type")),
                    DataColumn(label: Text("Status")),
                    DataColumn(label: Text("Amount")),
                  ],
                  rows: [
                    for (final t in tx.take(20))
                      DataRow(
                        cells: [
                          DataCell(Text(
                            t.createdAt != null
                                ? dt.format(t.createdAt!.toLocal())
                                : "—",
                          )),
                          DataCell(Text(t.type)),
                          DataCell(Text(t.status)),
                          DataCell(Text(currency.format(t.amount))),
                        ],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NotesTab extends ConsumerStatefulWidget {
  const _NotesTab({required this.userId});

  final String userId;

  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  final _body = TextEditingController();
  CrmNoteType _type = CrmNoteType.other;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final notes = ref.watch(crmNotesStreamProvider(widget.userId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: notes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text("$e"),
            data: (list) {
              if (list.isEmpty) {
                return Center(child: Text(context.tr("crm_notes_empty")));
              }
              return ListView.separated(
                padding: const EdgeInsets.only(top: 16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final n = list[i];
                  final dt = DateFormat.yMMMd().add_Hm();
                  return ListTile(
                    title: Text(n.body),
                    subtitle: Text(
                      "${n.type.name} · ${dt.format(n.createdAt.toLocal())}",
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<CrmNoteType>(
          value: _type,
          decoration: InputDecoration(labelText: context.tr("crm_note_type")),
          items: [
            for (final t in CrmNoteType.values)
              DropdownMenuItem(value: t, child: Text(t.name)),
          ],
          onChanged: (v) => setState(() => _type = v ?? CrmNoteType.other),
        ),
        TextField(
          controller: _body,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: context.tr("crm_note_body_hint"),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: uid == null || _body.text.trim().isEmpty
              ? null
              : () async {
                  await ref.read(crmServiceProvider).addNote(
                        investorUid: widget.userId,
                        authorUid: uid,
                        body: _body.text.trim(),
                        type: _type,
                      );
                  if (context.mounted) {
                    _body.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr("crm_note_added"))),
                    );
                  }
                },
          child: Text(context.tr("crm_add_note")),
        ),
      ],
    );
  }
}

class _FollowupsTab extends ConsumerStatefulWidget {
  const _FollowupsTab({required this.userId});

  final String userId;

  @override
  ConsumerState<_FollowupsTab> createState() => _FollowupsTabState();
}

class _FollowupsTabState extends ConsumerState<_FollowupsTab> {
  final _title = TextEditingController();
  DateTime _due = DateTime.now().add(const Duration(days: 1));

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (d != null) setState(() => _due = d);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final role = ref.watch(adminRoleProvider).valueOrNull ?? "";
    final isAdmin = role.toLowerCase() == "admin";
    final assignAsync = ref.watch(crmAssignmentProvider(widget.userId));
    final assignedTo = assignAsync.valueOrNull?.assignedToUid ?? "";
    final ownerForCreate =
        isAdmin ? (assignedTo.isNotEmpty ? assignedTo : null) : uid;
    final async = ref.watch(crmFollowupsStreamProvider(widget.userId));
    final dt = DateFormat.yMMMd().add_Hm();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text("$e"),
            data: (list) {
              if (list.isEmpty) {
                return Center(child: Text(context.tr("crm_followups_empty")));
              }
              return ListView.separated(
                padding: const EdgeInsets.only(top: 16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final f = list[i];
                  return ListTile(
                    title: Text(f.title),
                    subtitle: Text(
                      "${context.tr("crm_due_date")}: ${dt.format(f.dueAt.toLocal())} · ${f.status.name}",
                    ),
                    trailing: f.status == CrmFollowupStatus.pending
                        ? TextButton(
                            onPressed: () async {
                              await ref.read(crmServiceProvider).updateFollowupStatus(
                                    followupId: f.id,
                                    status: CrmFollowupStatus.completed,
                                  );
                            },
                            child: Text(context.tr("crm_mark_complete")),
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
        TextField(
          controller: _title,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: context.tr("crm_followup_title")),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr("crm_due_date")),
          subtitle: Text(DateFormat.yMMMd().format(_due)),
          trailing: IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: _pickDue,
          ),
        ),
        if (isAdmin && assignedTo.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.tr("crm_followup_assign_required"),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        FilledButton(
          onPressed: uid == null ||
                  _title.text.trim().isEmpty ||
                  ownerForCreate == null
              ? null
              : () async {
                  await ref.read(crmServiceProvider).addFollowup(
                        investorUid: widget.userId,
                        ownerUid: ownerForCreate,
                        dueAt: _due,
                        title: _title.text.trim(),
                      );
                  if (context.mounted) {
                    _title.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr("crm_followup_added"))),
                    );
                  }
                },
          child: Text(context.tr("crm_add_followup")),
        ),
      ],
    );
  }
}

class _CommsTab extends ConsumerStatefulWidget {
  const _CommsTab({required this.userId});

  final String userId;

  @override
  ConsumerState<_CommsTab> createState() => _CommsTabState();
}

class _CommsTabState extends ConsumerState<_CommsTab> {
  final _summary = TextEditingController();
  CrmCommChannel _channel = CrmCommChannel.call;
  DateTime _when = DateTime.now();

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _when.hour, minute: _when.minute),
    );
    if (t == null || !mounted) return;
    setState(() {
      _when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final async = ref.watch(crmCommunicationsStreamProvider(widget.userId));
    final dt = DateFormat.yMMMd().add_Hm();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text("$e"),
            data: (list) {
              if (list.isEmpty) {
                return Center(child: Text(context.tr("crm_comms_empty")));
              }
              return ListView.separated(
                padding: const EdgeInsets.only(top: 16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final c = list[i];
                  return ListTile(
                    title: Text(c.summary),
                    subtitle: Text(
                      "${c.channel.name} · ${dt.format(c.occurredAt.toLocal())}",
                    ),
                  );
                },
              );
            },
          ),
        ),
        DropdownButtonFormField<CrmCommChannel>(
          value: _channel,
          decoration: InputDecoration(labelText: context.tr("crm_channel")),
          items: [
            for (final ch in CrmCommChannel.values)
              DropdownMenuItem(value: ch, child: Text(ch.name)),
          ],
          onChanged: (v) => setState(() => _channel = v ?? CrmCommChannel.call),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr("crm_occurred_at")),
          subtitle: Text(dt.format(_when.toLocal())),
          trailing: IconButton(
            icon: const Icon(Icons.schedule),
            onPressed: _pickWhen,
          ),
        ),
        TextField(
          controller: _summary,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: context.tr("crm_comm_summary"),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: uid == null || _summary.text.trim().isEmpty
              ? null
              : () async {
                  await ref.read(crmServiceProvider).addCommunication(
                        investorUid: widget.userId,
                        authorUid: uid,
                        channel: _channel,
                        summary: _summary.text.trim(),
                        occurredAt: _when,
                      );
                  if (context.mounted) {
                    _summary.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr("crm_comm_added"))),
                    );
                  }
                },
          child: Text(context.tr("crm_add_communication")),
        ),
      ],
    );
  }
}
