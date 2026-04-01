import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/admin_transaction_providers.dart";
import "../widgets/transaction_queue_widgets.dart";

class AdminWithdrawalsQueueScreen extends ConsumerStatefulWidget {
  const AdminWithdrawalsQueueScreen({super.key});

  @override
  ConsumerState<AdminWithdrawalsQueueScreen> createState() =>
      _AdminWithdrawalsQueueScreenState();
}

class _AdminWithdrawalsQueueScreenState
    extends ConsumerState<AdminWithdrawalsQueueScreen>
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
    final withdrawalsAsync = ref.watch(allWithdrawalsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Withdrawals queue",
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
              "All withdrawal transactions — approve or reject pending ones.",
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: "All"),
              Tab(text: "Pending"),
              Tab(text: "Approved"),
              Tab(text: "Rejected"),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: withdrawalsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Error: $e")),
              data: (snap) {
                final docs = snap.docs;
                return TabBarView(
                  controller: _tabs,
                  children: [
                    QueueList(
                        docs: docs, filter: null, txnType: "withdrawal"),
                    QueueList(
                        docs: docs,
                        filter: "pending",
                        txnType: "withdrawal"),
                    QueueList(
                        docs: docs,
                        filter: "approved",
                        txnType: "withdrawal"),
                    QueueList(
                        docs: docs,
                        filter: "rejected",
                        txnType: "withdrawal"),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
