import "dart:typed_data";

import "package:firebase_storage/firebase_storage.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:http/http.dart" as http;
import "package:intl/intl.dart";

import "../models/kyc_admin_models.dart";
import "../providers/admin_providers.dart";

class AdminKycDetailScreen extends ConsumerWidget {
  const AdminKycDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(kycDetailProvider(userId));

    return Padding(
      padding: const EdgeInsets.all(24),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
        data: (kyc) {
          if (kyc == null) {
            return const Center(child: Text("KYC document not found."));
          }
          return _KycDetailBody(kyc: kyc, userId: userId);
        },
      ),
    );
  }
}

class _KycDetailBody extends ConsumerStatefulWidget {
  const _KycDetailBody({required this.kyc, required this.userId});

  final KycAdminDocument kyc;
  final String userId;

  @override
  ConsumerState<_KycDetailBody> createState() => _KycDetailBodyState();
}

class _KycDetailBodyState extends ConsumerState<_KycDetailBody> {
  bool _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await ref.read(adminKycServiceProvider).approveKyc(widget.userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("KYC approved.")),
        );
        context.go("/kyc");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text("Reject KYC"),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              labelText: "Reason (visible to investor)",
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text("Reject"),
            ),
          ],
        );
      },
    );
    if (reason == null || reason.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminKycServiceProvider).rejectKyc(widget.userId, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("KYC rejected.")),
        );
        context.go("/kyc");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kyc;
    final fmt = DateFormat.yMMMd().add_Hm();
    final bank = k.bankDetails;
    final nom = k.nominee;
    final risk = k.riskProfile;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => context.go("/kyc"),
                icon: const Icon(Icons.arrow_back),
                label: const Text("Queue"),
              ),
              const Spacer(),
              Chip(label: Text("Status: ${k.status}")),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            k.displayName?.isNotEmpty == true ? k.displayName! : widget.userId,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            "UID: ${widget.userId}  ·  ${k.phone ?? "—"}",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (k.submittedAt != null)
            Text(
              "Submitted: ${fmt.format(k.submittedAt!.toLocal())}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 24),
          Text("Identity", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _ImageTile(label: "CNIC front", url: k.cnicFrontUrl),
              _ImageTile(label: "CNIC back", url: k.cnicBackUrl),
              _ImageTile(label: "Selfie", url: k.selfieUrl),
            ],
          ),
          const SizedBox(height: 28),
          Text("Bank details", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _InfoTable(
            rows: {
              "Account title": bank?["accountTitle"] ?? "—",
              "Bank": bank?["bankName"] ?? "—",
              "IBAN / account": bank?["ibanOrAccountNumber"] ?? "—",
            },
          ),
          const SizedBox(height: 24),
          Text("Nominee", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _InfoTable(
            rows: {
              "Name": nom?["nomineeName"] ?? "—",
              "Relationship": nom?["relationship"] ?? "—",
              "CNIC": nom?["nomineeCnic"] ?? "—",
            },
          ),
          const SizedBox(height: 24),
          Text("Risk profile", style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _InfoTable(
            rows: {
              "Horizon": risk?["investmentHorizon"] ?? "—",
              "Risk tolerance": risk?["riskTolerance"] ?? "—",
              "Monthly income": risk?["monthlyIncomeRange"] ?? "—",
            },
          ),
          if (k.rejectionReason != null &&
              k.rejectionReason.toString().isNotEmpty) ...[
            const SizedBox(height: 24),
            Material(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text("Last rejection: ${k.rejectionReason}"),
              ),
            ),
          ],
          const SizedBox(height: 32),
          if (k.status == "pending" || k.status == "underReview")
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _approve,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("Approve"),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _reject,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text("Reject"),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.label, required this.url});

  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final raw = url?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Container(
          width: 220,
          height: 140,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: raw == null || raw.isEmpty
              ? const Center(child: Text("No image"))
              : FutureBuilder<Uint8List?>(
                  future: _fetchImageBytes(raw),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final bytes = snap.data;
                    if (bytes == null || bytes.isEmpty) {
                      return const Center(
                        child: Icon(Icons.broken_image_outlined),
                      );
                    }
                    return Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<Uint8List?> _fetchImageBytes(String value) async {
    try {
      final ref = _toStorageRef(value);
      final downloadUrl = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) return response.bodyBytes;
      return null;
    } catch (_) {
      return null;
    }
  }

  Reference _toStorageRef(String value) {
    if (value.startsWith("gs://")) {
      return FirebaseStorage.instance.refFromURL(value);
    }
    if (value.startsWith("https://firebasestorage.googleapis.com")) {
      final uri = Uri.parse(value);
      final oIndex = uri.path.indexOf("/o/");
      if (oIndex != -1) {
        final decoded = Uri.decodeComponent(uri.path.substring(oIndex + 3));
        return FirebaseStorage.instance.ref(decoded);
      }
      return FirebaseStorage.instance.refFromURL(value);
    }
    return FirebaseStorage.instance.ref(value);
  }
}

class _InfoTable extends StatelessWidget {
  const _InfoTable({required this.rows});

  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.2), 1: FlexColumnWidth(2)},
      children: [
        for (final e in rows.entries)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  e.key,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(e.value),
              ),
            ],
          ),
      ],
    );
  }
}
