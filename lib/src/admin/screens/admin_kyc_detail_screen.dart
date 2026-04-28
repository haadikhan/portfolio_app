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
      builder: (_) => const _KycRejectReasonDialog(),
    );
    // Cancel returns null silently. The new dialog disables the Reject button
    // while the field is empty, so an empty string should be unreachable —
    // surface a SnackBar if it ever happens so the failure stays visible.
    if (reason == null) return;
    if (reason.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rejection reason is required.")),
        );
      }
      return;
    }
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
          if (k.missingKycFirestoreBody) ...[
            const SizedBox(height: 12),
            Material(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "No kyc/{uid} document was found in Firestore for this user. "
                        "Form fields below are empty because the submission did not persist or only legacy profile data exists. "
                        "Ask the investor to submit again after fixing rules/network, or check the Firebase console.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
          const SizedBox(height: 8),
          _InfoTable(
            rows: {
              "CNIC": k.cnicNumber ?? "—",
              "Address": k.address ?? "—",
            },
          ),
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
          if (k.paymentProofDocuments != null &&
              k.paymentProofDocuments!.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              "Source-of-funds / payment proof",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final e in k.paymentProofDocuments!.entries)
                  _ImageTile(
                    label: _paymentProofFieldLabel(e.key),
                    url: e.value,
                  ),
              ],
            ),
          ],
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

String _paymentProofFieldLabel(String key) {
  switch (key) {
    case "salarySlipUrl":
      return "Salary slip";
    case "passportFrontUrl":
      return "Passport (front)";
    case "passportBackUrl":
      return "Passport (back)";
    case "aqamaUrl":
      return "Residence permit (Iqama)";
    case "businessProofUrl":
      return "Business proof";
    case "inheritanceProofUrl":
      return "Inheritance proof";
    default:
      return key;
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.label, required this.url});

  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final raw = url?.trim();
    final isHttp =
        raw != null &&
        (raw.startsWith("http://") || raw.startsWith("https://"));
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
              : isHttp
                  ? Image.network(
                      raw,
                      fit: BoxFit.cover,
                      width: 220,
                      height: 140,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    )
                  : FutureBuilder<Uint8List?>(
                      future: _fetchImageBytes(raw),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
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

/// Dialog used by the KYC reject flow. Owns its `TextEditingController`
/// lifecycle and keeps the Reject button disabled until the trimmed text is
/// non-empty, so the previous silent failure path (empty-reason → caller
/// returns silently) is no longer reachable.
class _KycRejectReasonDialog extends StatefulWidget {
  const _KycRejectReasonDialog();

  @override
  State<_KycRejectReasonDialog> createState() => _KycRejectReasonDialogState();
}

class _KycRejectReasonDialogState extends State<_KycRejectReasonDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    final next = _controller.text.trim().isNotEmpty;
    if (next != _canSubmit) {
      setState(() => _canSubmit = next);
    }
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.isEmpty) return;
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Reject KYC"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: "Reason (visible to investor)",
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          Text(
            "Reason is required so the investor knows what to fix before re-submitting.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: const Text("Reject"),
        ),
      ],
    );
  }
}
