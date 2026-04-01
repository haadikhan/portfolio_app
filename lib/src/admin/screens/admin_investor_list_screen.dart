import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../models/admin_investor_models.dart";
import "../providers/admin_providers.dart";

class AdminInvestorListScreen extends ConsumerStatefulWidget {
  const AdminInvestorListScreen({super.key});

  @override
  ConsumerState<AdminInvestorListScreen> createState() =>
      _AdminInvestorListScreenState();
}

class _AdminInvestorListScreenState extends ConsumerState<AdminInvestorListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final async = ref.watch(filteredInvestorsProvider);
    final query = ref.watch(investorSearchQueryProvider);
    if (_searchController.text != query) {
      _searchController.text = query;
      _searchController.selection =
          TextSelection.collapsed(offset: _searchController.text.length);
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Investors",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            "View all investors and inspect full financial profile.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            onChanged: (v) =>
                ref.read(investorSearchQueryProvider.notifier).state = v,
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Search by name, email, or phone",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => ref
                          .read(investorSearchQueryProvider.notifier)
                          .state = "",
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Error: $e")),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text("No investors found for current search."),
                  );
                }
                return _InvestorTable(items: items);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestorTable extends StatelessWidget {
  const _InvestorTable({required this.items});

  final List<AdminInvestorSummary> items;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd();
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
            DataColumn(label: Text("Email")),
            DataColumn(label: Text("Phone")),
            DataColumn(label: Text("KYC")),
            DataColumn(label: Text("Joined")),
            DataColumn(label: Text("")),
          ],
          rows: [
            for (final i in items)
              DataRow(
                cells: [
                  DataCell(Text(i.name.isNotEmpty ? i.name : i.userId)),
                  DataCell(Text(i.email.isNotEmpty ? i.email : "—")),
                  DataCell(Text(i.phone.isNotEmpty ? i.phone : "—")),
                  DataCell(
                    Chip(
                      label: Text(i.kycStatus),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  DataCell(
                    Text(
                      i.createdAt != null
                          ? fmt.format(i.createdAt!.toLocal())
                          : "—",
                    ),
                  ),
                  DataCell(
                    FilledButton(
                      onPressed: () => context.go("/investors/${i.userId}"),
                      child: const Text("View"),
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
