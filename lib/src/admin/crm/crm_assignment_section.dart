import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/i18n/app_translations.dart";
import "../../providers/auth_providers.dart";
import "../models/admin_investor_models.dart";
import "crm_providers.dart";

/// Admin-only: assign or reassign an investor to a CRM staff member.
class CrmAssignmentSection extends ConsumerWidget {
  const CrmAssignmentSection({super.key, required this.investorUid});

  final String investorUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(crmStaffMembersProvider);
    final assignAsync = ref.watch(crmAssignmentProvider(investorUid));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: staffAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text("$e"),
          data: (staff) {
            return assignAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text("$e"),
              data: (current) {
                return _AssignmentForm(
                  investorUid: investorUid,
                  staff: staff,
                  currentAssignedTo: current?.assignedToUid ?? "",
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AssignmentForm extends ConsumerStatefulWidget {
  const _AssignmentForm({
    required this.investorUid,
    required this.staff,
    required this.currentAssignedTo,
  });

  final String investorUid;
  final List<AdminInvestorSummary> staff;
  final String currentAssignedTo;

  @override
  ConsumerState<_AssignmentForm> createState() => _AssignmentFormState();
}

class _AssignmentFormState extends ConsumerState<_AssignmentForm> {
  late String? _selectedUid;

  @override
  void initState() {
    super.initState();
    _selectedUid = widget.currentAssignedTo.isEmpty
        ? null
        : widget.currentAssignedTo;
  }

  @override
  void didUpdateWidget(covariant _AssignmentForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentAssignedTo != widget.currentAssignedTo) {
      _selectedUid = widget.currentAssignedTo.isEmpty
          ? null
          : widget.currentAssignedTo;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String?>>[
      DropdownMenuItem<String?>(
        value: null,
        child: Text(context.tr("crm_unassigned")),
      ),
      for (final s in widget.staff)
        DropdownMenuItem<String?>(
          value: s.userId,
          child: Text(s.name.isNotEmpty ? s.name : s.email),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr("crm_assign_to_staff"),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          context.tr("crm_assign_hint"),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          value: _selectedUid,
          items: items,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: context.tr("crm_nav_team"),
          ),
          onChanged: (v) => setState(() => _selectedUid = v),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null) return;
            final to = _selectedUid ?? "";
            final svc = ref.read(crmServiceProvider);
            if (to.isEmpty) {
              if (widget.currentAssignedTo.isNotEmpty) {
                await svc.clearAssignment(widget.investorUid);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr("crm_unassigned"))),
                  );
                }
                return;
              }
            } else {
              await svc.setAssignment(
                investorUid: widget.investorUid,
                assignedToUid: to,
                assignedByUid: uid,
              );
            }
            ref.invalidate(crmAssignmentProvider(widget.investorUid));
            final authUid = ref.read(firebaseAuthProvider).currentUser?.uid;
            ref.invalidate(
              crmAssignedInvestorsProvider(
                (isAdmin: true, crmUid: authUid),
              ),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.tr("crm_assignment_saved"))),
              );
            }
          },
          child: Text(context.tr("save_btn")),
        ),
      ],
    );
  }
}
