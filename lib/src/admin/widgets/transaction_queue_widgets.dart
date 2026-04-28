import "dart:convert";
import "dart:typed_data";

import "package:cloud_firestore/cloud_firestore.dart";
import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../providers/auth_providers.dart";
import "../providers/admin_transaction_providers.dart";

// ── User name cache (shared) ──────────────────────────────────────────────────

final userNameCacheProvider =
    FutureProvider.family<String, String>((ref, uid) async {
  final doc = await ref
      .read(firebaseFirestoreProvider)
      .collection("users")
      .doc(uid)
      .get();
  final name = (doc.data()?["name"] as String? ?? "").trim();
  final email = (doc.data()?["email"] as String? ?? "").trim();
  return name.isNotEmpty ? name : (email.isNotEmpty ? email : uid);
});

// ── Queue list ────────────────────────────────────────────────────────────────

class QueueList extends ConsumerWidget {
  const QueueList({
    super.key,
    required this.docs,
    required this.filter,
    required this.txnType,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final String? filter;
  final String txnType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = filter == null
        ? docs
        : docs
            .where((d) =>
                (d.data()["status"] as String? ?? "").toLowerCase() ==
                filter)
            .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              txnType == "deposit"
                  ? Icons.inbox_outlined
                  : Icons.outbox_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              filter == null
                  ? "No $txnType requests yet"
                  : "No $filter ${txnType}s",
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final doc = filtered[i];
        return QueueTile(doc: doc, txnType: txnType);
      },
    );
  }
}

// ── Queue tile ────────────────────────────────────────────────────────────────

class QueueTile extends ConsumerWidget {
  const QueueTile({super.key, required this.doc, required this.txnType});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String txnType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = doc.data();
    final txnId = doc.id;
    final userId = (data["userId"] as String? ?? "").trim();
    final amount = (data["amount"] as num?)?.toDouble() ?? 0;
    final status = (data["status"] as String? ?? "pending").toLowerCase();
    final isPending = status == "pending";
    final proofUrl = (data["proofUrl"] as String? ?? "").trim();
    final paymentMethod = (data["paymentMethod"] as String? ?? "").trim();
    final currency = NumberFormat.currency(symbol: "PKR ", decimalDigits: 0);
    final dt = DateFormat.yMMMd().add_Hm();
    final createdAt = _parseTime(data["createdAt"]);

    final userNameAsync = ref.watch(userNameCacheProvider(userId));
    final userName = userNameAsync.valueOrNull ?? userId;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Proof thumbnail (deposits only) ───────────────────────
            if (txnType == "deposit" && proofUrl.isNotEmpty) ...[
              GestureDetector(
                onTap: () => openProofViewer(context, proofUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: StorageImage(
                    rawUrl: proofUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],

            // ── Main info ─────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currency.format(amount),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  if (paymentMethod.isNotEmpty)
                    Text(paymentMethod,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  if (createdAt != null)
                    Text(dt.format(createdAt.toLocal()),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),

            // ── Status + View button ──────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                TxnStatusBadge(status: status),
                if (isPending) ...[
                  const SizedBox(height: 8),
                  TxnSmallButton(
                    label: "View request",
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () => _openRequestSheet(
                      context,
                      ref,
                      txnId: txnId,
                      userId: userId,
                      amount: amount,
                      userName: userName,
                      txnType: txnType,
                      proofUrl: proofUrl,
                      paymentMethod: paymentMethod,
                      currency: currency,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openRequestSheet(
    BuildContext context,
    WidgetRef ref, {
    required String txnId,
    required String userId,
    required double amount,
    required String userName,
    required String txnType,
    required String proofUrl,
    required String paymentMethod,
    required NumberFormat currency,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RequestSheet(
        txnId: txnId,
        userId: userId,
        amount: amount,
        userName: userName,
        txnType: txnType,
        proofUrl: proofUrl,
        paymentMethod: paymentMethod,
        currency: currency,
      ),
    );
  }
}

// ── Request detail bottom sheet ───────────────────────────────────────────────

class _RequestSheet extends ConsumerStatefulWidget {
  const _RequestSheet({
    required this.txnId,
    required this.userId,
    required this.amount,
    required this.userName,
    required this.txnType,
    required this.proofUrl,
    required this.paymentMethod,
    required this.currency,
  });

  final String txnId;
  final String userId;
  final double amount;
  final String userName;
  final String txnType;
  final String proofUrl;
  final String paymentMethod;
  final NumberFormat currency;

  @override
  ConsumerState<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<_RequestSheet> {
  bool _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    await ref.read(transactionActionProvider.notifier).approve(
          txnId: widget.txnId,
          txnType: widget.txnType,
          amount: widget.amount,
          userId: widget.userId,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    final state = ref.read(transactionActionProvider);
    Navigator.pop(context);
    final actionLabel = widget.txnType == "withdrawal"
        ? "${_capitalize(widget.txnType)} completed."
        : "${_capitalize(widget.txnType)} approved.";
    ScaffoldMessenger.of(context).showSnackBar(
      state.hasError
          ? SnackBar(
              content: Text("Error: ${state.error}"),
              backgroundColor: Colors.red)
          : SnackBar(
              content: Text(actionLabel),
              backgroundColor: Colors.green.shade700),
    );
  }

  Future<void> _reject() async {
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject transaction"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add a rejection note (optional):"),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                hintText: "e.g. Invalid proof of payment",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600),
            child: const Text("Reject"),
          ),
        ],
      ),
    );
    final note = noteCtrl.text;
    noteCtrl.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    await ref.read(transactionActionProvider.notifier).reject(
          txnId: widget.txnId,
          rejectionNote: note,
          userId: widget.userId,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Transaction rejected.")),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : "${s[0].toUpperCase()}${s.substring(1)}";

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${_capitalize(widget.txnType)} request",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${widget.currency.format(widget.amount)}  •  ${widget.userName}",
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                      if (widget.paymentMethod.isNotEmpty)
                        Text(
                          widget.paymentMethod,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Image area ──────────────────────────────────────────────
          Flexible(
            child: widget.proofUrl.isNotEmpty
                ? GestureDetector(
                    onTap: () => openProofViewer(context, widget.proofUrl),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: StorageImage(
                            rawUrl: widget.proofUrl,
                            width: double.infinity,
                            height: screenH * 0.5,
                            fit: BoxFit.contain,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in_rounded,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text("Tap to zoom",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_not_supported_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          "No payment proof uploaded",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
          ),

          const Divider(height: 1),

          // ── Action buttons ──────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _reject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade400),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text("Reject",
                          style: TextStyle(
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _approve,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                          _busy
                              ? "Processing…"
                              : widget.txnType == "withdrawal"
                                  ? "Approve & Complete"
                                  : "Approve",
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                    ),
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

// ── Approve dialog (kept for admin investor detail screen) ────────────────────

class ApproveDialog extends StatelessWidget {
  const ApproveDialog({
    super.key,
    required this.type,
    required this.amount,
    required this.userName,
    required this.proofUrl,
    required this.paymentMethod,
    required this.currency,
  });

  final String type;
  final double amount;
  final String userName;
  final String proofUrl;
  final String paymentMethod;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Confirm approval"),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    const TextSpan(text: "Approve "),
                    TextSpan(
                        text: type,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    const TextSpan(text: " of "),
                    TextSpan(
                      text: currency.format(amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (userName.isNotEmpty)
                      TextSpan(text: " for $userName"),
                    const TextSpan(text: "?"),
                  ],
                ),
              ),
              if (paymentMethod.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text("Payment method: $paymentMethod",
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
              if (proofUrl.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text("Payment proof:",
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => openProofViewer(context, proofUrl),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: StorageImage(
                      rawUrl: proofUrl,
                      width: 320,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text("Tap to view full size  •  Pinch to zoom",
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500)),
              ] else if (type == "deposit") ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text("No proof of payment was uploaded.",
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel")),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Confirm & Approve")),
      ],
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class TxnStatusBadge extends StatelessWidget {
  const TxnStatusBadge({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final (Color bg, Color fg) = switch (s) {
      "approved" => (Colors.green.shade50, Colors.green.shade800),
      "rejected" => (Colors.red.shade50, Colors.red.shade800),
      "completed" => (Colors.blue.shade50, Colors.blue.shade800),
      _ => (Colors.orange.shade50, Colors.orange.shade800),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

// ── Small button ──────────────────────────────────────────────────────────────

class TxnSmallButton extends StatelessWidget {
  const TxnSmallButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: Text(label),
      );
    }
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(label),
    );
  }
}

// ── Storage-aware image widget ────────────────────────────────────────────────
//
// Firebase Storage download URLs can fail on web due to CORS when loaded with
// plain Image.network. This widget uses the Firebase Storage SDK to fetch a
// fresh authenticated download URL, which the SDK serves via a signed request
// that bypasses browser CORS restrictions.

class StorageImage extends StatefulWidget {
  const StorageImage({
    super.key,
    required this.rawUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  /// Either a `gs://` path, a storage object path, or an https download URL.
  final String rawUrl;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  State<StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<StorageImage> {
  late Future<Uint8List?> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _bytesFuture = _fetchBytes(widget.rawUrl);
  }

  @override
  void didUpdateWidget(StorageImage old) {
    super.didUpdateWidget(old);
    if (old.rawUrl != widget.rawUrl) {
      setState(() => _bytesFuture = _fetchBytes(widget.rawUrl));
    }
  }

  /// Fetches bytes via a callable Cloud Function that reads Storage with
  /// Admin SDK, avoiding browser CORS and Flutter-web storage SDK quirks.
  static Future<Uint8List?> _fetchBytes(String raw) async {
    try {
      final fn = FirebaseFunctions.instanceFor(region: "us-central1");
      final result = await fn.httpsCallable("getStorageImageData").call({
        "rawUrl": raw,
      });
      final data = (result.data as Map?)?.cast<String, dynamic>() ?? {};
      final b64 = (data["bytesBase64"] as String?) ?? "";
      if (b64.isEmpty) return null;
      return base64Decode(b64);
    } catch (e) {
      debugPrint("[StorageImage] _fetchBytes failed for: $raw\nError: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use LayoutBuilder so that width:double.infinity works inside dialogs
    // and other constrained contexts without causing unbounded-width crashes.
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final resolvedW = widget.width.isInfinite
            ? constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 300.0
            : widget.width;
        return FutureBuilder<Uint8List?>(
          future: _bytesFuture,
          builder: (ctx2, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return _placeholder(resolvedW, widget.height, loading: true);
            }
            final bytes = snap.data;
            if (bytes == null || bytes.isEmpty) {
              return _error(resolvedW, widget.height);
            }
            return Image.memory(
              bytes,
              width: resolvedW,
              height: widget.height,
              fit: widget.fit,
              errorBuilder: (_, __, ___) =>
                  _error(resolvedW, widget.height),
            );
          },
        );
      },
    );
  }

  static Widget _placeholder(double w, double h, {bool loading = false}) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey.shade100,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.image_outlined,
                color: Colors.grey.shade400, size: 24),
      ),
    );
  }

  static Widget _error(double w, double h) {
    return Container(
      width: w,
      height: h,
      color: Colors.grey.shade100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined,
              color: Colors.grey.shade400, size: w > 100 ? 28 : 18),
          if (w > 80) ...[
            const SizedBox(height: 4),
            Text(
              "Could not load image",
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Full-screen proof viewer ──────────────────────────────────────────────────

/// Opens a full-screen image viewer with pinch-to-zoom and a close button.
/// Used from both the approve dialog thumbnail and the inline tile thumbnail.
void openProofViewer(BuildContext context, String url) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (ctx, _, __) => _ProofViewerPage(url: url),
    ),
  );
}

class _ProofViewerPage extends StatefulWidget {
  const _ProofViewerPage({required this.url});
  final String url;

  @override
  State<_ProofViewerPage> createState() => _ProofViewerPageState();
}

class _ProofViewerPageState extends State<_ProofViewerPage> {
  final _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          "Payment proof",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map_rounded,
                color: Colors.white),
            tooltip: "Reset zoom",
            onPressed: _resetZoom,
          ),
        ],
      ),
      body: FutureBuilder<Uint8List?>(
        future: _StorageImageState._fetchBytes(widget.url),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          final bytes = snap.data;
          if (bytes == null || bytes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined,
                      color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    "Could not load image.\nCheck your network or storage permissions.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() {}),
                    child: const Text("Retry",
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }
          return Center(
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.5,
              maxScale: 6.0,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                width: double.infinity,
                errorBuilder: (ctx2, err, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

DateTime? _parseTime(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  return DateTime.tryParse(v.toString());
}
