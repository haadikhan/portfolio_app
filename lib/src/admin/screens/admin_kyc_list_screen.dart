import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../models/kyc_admin_models.dart";
import "../providers/admin_providers.dart";

class AdminKycListScreen extends ConsumerWidget {
  const AdminKycListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingKycQueueProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "KYC queue",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            "Submissions with status pending or under review.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Error: $e")),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text("No pending KYC submissions."),
                  );
                }
                return _KycTable(items: items);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _KycTable extends StatelessWidget {
  const _KycTable({required this.items});

  final List<KycAdminDocument> items;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd().add_Hm();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          columns: const [
            DataColumn(label: Text("Investor")),
            DataColumn(label: Text("Phone")),
            DataColumn(label: Text("Submitted")),
            DataColumn(label: Text("Status")),
            DataColumn(label: Text("")),
          ],
          rows: [
            for (final k in items)
              DataRow(
                cells: [
                  DataCell(Text(k.displayName?.isNotEmpty == true
                      ? k.displayName!
                      : k.userId)),
                  DataCell(Text(k.phone ?? "—")),
                  DataCell(Text(
                    k.submittedAt != null ? fmt.format(k.submittedAt!.toLocal()) : "—",
                  )),
                  DataCell(
                    Chip(
                      label: Text(k.status),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  DataCell(
                    FilledButton(
                      onPressed: () => context.go("/kyc/${k.userId}"),
                      child: const Text("View details"),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
