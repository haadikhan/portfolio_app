import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:intl/intl.dart";

import "../../core/i18n/app_translations.dart";
import "../models/admin_investor_models.dart";
import "crm_providers.dart";

class CrmInvestorListScreen extends ConsumerStatefulWidget {
  const CrmInvestorListScreen({super.key});

  @override
  ConsumerState<CrmInvestorListScreen> createState() =>
      _CrmInvestorListScreenState();
}

class _CrmInvestorListScreenState extends ConsumerState<CrmInvestorListScreen> {
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
    final async = ref.watch(crmFilteredInvestorsProvider);
    final query = ref.watch(crmInvestorSearchQueryProvider);
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
            context.tr("crm_assigned_investors"),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr("crm_assigned_investors_subtitle"),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            onChanged: (v) =>
                ref.read(crmInvestorSearchQueryProvider.notifier).state = v,
            controller: _searchController,
            decoration: InputDecoration(
              hintText: context.tr("crm_search_investors"),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => ref
                          .read(crmInvestorSearchQueryProvider.notifier)
                          .state = "",
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("${context.tr("error_prefix")} $e")),
              data: (items) {
                if (items.isEmpty) {
                  return Center(child: Text(context.tr("crm_no_investors")));
                }
                return _CrmInvestorTable(items: items);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CrmInvestorTable extends StatelessWidget {
  const _CrmInvestorTable({required this.items});

  final List<AdminInvestorSummary> items;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd();
    final kycLabel = context.tr("crm_kyc_column");
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
          columns: [
            DataColumn(label: Text(context.tr("investors"))),
            const DataColumn(label: Text("Email")),
            const DataColumn(label: Text("Phone")),
            DataColumn(label: Text(kycLabel)),
            DataColumn(label: Text(context.tr("crm_col_joined"))),
            const DataColumn(label: Text("")),
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
                      onPressed: () =>
                          context.go("/crm/investors/${i.userId}"),
                      child: Text(context.tr("reports_action_view")),
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
