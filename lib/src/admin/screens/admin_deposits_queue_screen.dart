import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers/admin_transaction_providers.dart";
import "../widgets/transaction_queue_widgets.dart";

class AdminDepositsQueueScreen extends ConsumerStatefulWidget {
  const AdminDepositsQueueScreen({super.key});

  @override
  ConsumerState<AdminDepositsQueueScreen> createState() =>
      _AdminDepositsQueueScreenState();
}

class _AdminDepositsQueueScreenState
    extends ConsumerState<AdminDepositsQueueScreen>
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
    final depositsAsync = ref.watch(allDepositsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Deposits queue",
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text("All deposit transactions — approve or reject pending ones.",
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
            child: depositsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Error: $e")),
              data: (snap) {
                final docs = snap.docs;
                return TabBarView(
                  controller: _tabs,
                  children: [
                    QueueList(docs: docs, filter: null, txnType: "deposit"),
                    QueueList(
                        docs: docs, filter: "pending", txnType: "deposit"),
                    QueueList(
                        docs: docs, filter: "approved", txnType: "deposit"),
                    QueueList(
                        docs: docs, filter: "rejected", txnType: "deposit"),
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
