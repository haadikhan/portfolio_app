import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:image_picker/image_picker.dart";
import "package:firebase_storage/firebase_storage.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../../../models/app_user.dart";
import "../../../providers/auth_providers.dart";
import "../../../models/user_kyc.dart";

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cnic = TextEditingController();
  final _phone = TextEditingController();

  File? _frontFile;
  File? _backFile;
  File? _selfieFile;

  // existing URLs already saved in Firestore (shown when no new file picked)
  String? _existingFrontUrl;
  String? _existingBackUrl;
  String? _existingSelfieUrl;

  bool _seeded = false;
  bool _uploading = false;

  @override
  void dispose() {
    _cnic.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _seedFromRecord(UserKycRecord? kyc, AppUser? profile) {
    if (_seeded) return;
    _seeded = true;
    _cnic.text = kyc?.cnicNumber ?? "";
    _phone.text = kyc?.phone ?? "";
    _existingFrontUrl = kyc?.cnicFrontUrl;
    _existingBackUrl = kyc?.cnicBackUrl;
    _existingSelfieUrl = kyc?.selfieUrl;
  }

  Future<File?> _pickImage(ImageSource source) async {
    final xfile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (xfile == null) return null;
    return File(xfile.path);
  }

  Future<String?> _upload(File file, String uid, String slot) async {
    final ref = FirebaseStorage.instance.ref(
      "deposit_proofs/$uid/kyc_${slot}_${DateTime.now().millisecondsSinceEpoch}.jpg",
    );
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _submit(String uid) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _uploading = true);
    try {
      String? frontUrl = _existingFrontUrl;
      String? backUrl = _existingBackUrl;
      String? selfieUrl = _existingSelfieUrl;

      if (_frontFile != null)
        frontUrl = await _upload(_frontFile!, uid, "front");
      if (_backFile != null) backUrl = await _upload(_backFile!, uid, "back");
      if (_selfieFile != null)
        selfieUrl = await _upload(_selfieFile!, uid, "selfie");

      await ref
          .read(authControllerProvider.notifier)
          .submitKyc(
            cnicNumber: _cnic.text.trim(),
            phone: _phone.text.trim(),
            cnicFrontUrl: frontUrl,
            cnicBackUrl: backUrl,
            selfieUrl: selfieUrl,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("kyc_submit_success"))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(
          content: Text("${context.tr("kyc_submit_failed")} $e")));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kycAsync = ref.watch(userKycProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final uid = ref.watch(currentUserProvider)?.uid;
    final busy = ref.watch(authControllerProvider).isLoading || _uploading;

    return AppScaffold(
      title: context.tr("kyc_verification_title"),
      body: kycAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text("${context.tr("error_prefix")} $e")),
        data: (kyc) {
          final profile = profileAsync.valueOrNull;
          _seedFromRecord(kyc, profile);

          final status =
              kyc?.status ?? profile?.kycStatus ?? KycLifecycleStatus.pending;
          final locked =
              status == KycLifecycleStatus.underReview ||
              status == KycLifecycleStatus.approved;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Status banner ───────────────────────────────────────
                _StatusBanner(status: status, kyc: kyc),
                const SizedBox(height: 20),

                // ── Read-only profile info ──────────────────────────────
                _SectionHeader(label: context.tr("your_profile")),
                const SizedBox(height: 10),
                _ReadOnlyField(
                  icon: Icons.person_outline_rounded,
                  label: context.tr("full_name"),
                  value: profile?.name ?? context.tr("em_dash"),
                ),
                const SizedBox(height: 10),
                _ReadOnlyField(
                  icon: Icons.email_outlined,
                  label: context.tr("email_address"),
                  value: profile?.email ?? context.tr("em_dash"),
                ),

                // ── Identity fields ─────────────────────────────────────
                const SizedBox(height: 22),
                _SectionHeader(label: context.tr("identity_details")),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _cnic,
                  enabled: !locked,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.tr("cnic_number"),
                    hintText: context.tr("cnic_hint"),
                    prefixIcon: const Icon(Icons.credit_card_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().length < 8)
                      ? context.tr("cnic_invalid")
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phone,
                  enabled: !locked,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: context.tr("mobile_number"),
                    hintText: context.tr("mobile_hint"),
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? context.tr("mobile_invalid")
                      : null,
                ),

                // ── Document images ─────────────────────────────────────
                const SizedBox(height: 22),
                _SectionHeader(label: context.tr("document_images")),
                const SizedBox(height: 4),
                Text(
                  context.tr("kyc_upload_help"),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                _ImagePickerTile(
                  label: context.tr("cnic_front"),
                  icon: Icons.credit_card_rounded,
                  pickedFile: _frontFile,
                  existingUrl: _existingFrontUrl,
                  locked: locked,
                  onPick: () async {
                    final f = await _pickImage(ImageSource.gallery);
                    if (f != null) setState(() => _frontFile = f);
                  },
                ),
                const SizedBox(height: 10),
                _ImagePickerTile(
                  label: context.tr("cnic_back"),
                  icon: Icons.credit_card_outlined,
                  pickedFile: _backFile,
                  existingUrl: _existingBackUrl,
                  locked: locked,
                  onPick: () async {
                    final f = await _pickImage(ImageSource.gallery);
                    if (f != null) setState(() => _backFile = f);
                  },
                ),
                const SizedBox(height: 10),
                _ImagePickerTile(
                  label: context.tr("selfie_with_cnic"),
                  icon: Icons.face_outlined,
                  pickedFile: _selfieFile,
                  existingUrl: _existingSelfieUrl,
                  locked: locked,
                  onPick: () async {
                    final f = await _pickImage(ImageSource.camera);
                    if (f != null) setState(() => _selfieFile = f);
                  },
                ),

                // ── Submit ──────────────────────────────────────────────
                const SizedBox(height: 28),
                if (!locked)
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: busy ? null : () => _submit(uid!),
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        status == KycLifecycleStatus.rejected
                            ? context.tr("resubmit_kyc")
                            : context.tr("submit_for_review"),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                if (!locked) const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.push("/legal"),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: Text(context.tr("view_legal_consent")),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Status banner ───────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.kyc});
  final KycLifecycleStatus status;
  final UserKycRecord? kyc;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (
      Color bg,
      Color fg,
      IconData icon,
      String titleKey,
      String body,
    ) = switch (status) {
      KycLifecycleStatus.pending => (
        isDark
            ? scheme.secondaryContainer.withValues(alpha: 0.35)
            : const Color(0xFFFFF8E1),
        AppColors.warning,
        Icons.info_outline_rounded,
        "kyc_status_pending_title",
        context.tr("kyc_status_pending_body"),
      ),
      KycLifecycleStatus.underReview => (
        isDark
            ? scheme.primaryContainer.withValues(alpha: 0.4)
            : const Color(0xFFE3F2FD),
        Colors.blue.shade700,
        Icons.hourglass_top_rounded,
        "kyc_status_review_title",
        context.tr("kyc_status_review_body"),
      ),
      KycLifecycleStatus.approved => (
        isDark
            ? scheme.primaryContainer.withValues(alpha: 0.35)
            : const Color(0xFFE8F5E9),
        AppColors.success,
        Icons.verified_rounded,
        "kyc_status_approved_title",
        context.tr("kyc_status_approved_body"),
      ),
      KycLifecycleStatus.rejected => (
        isDark
            ? scheme.errorContainer.withValues(alpha: 0.45)
            : const Color(0xFFFFEBEE),
        AppColors.error,
        Icons.warning_amber_rounded,
        "kyc_status_rejected_title",
        kyc?.rejectionReason?.isNotEmpty == true
            ? "${context.tr("kyc_rejection_reason_prefix")} ${kyc!.rejectionReason}"
            : context.tr("kyc_status_rejected_body"),
      ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(titleKey),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    color: fg.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Read-only profile field ─────────────────────────────────────────────────

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

// ─── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: scheme.onSurfaceVariant,
        letterSpacing: 0.4,
      ),
    );
  }
}

// ─── Image picker tile ────────────────────────────────────────────────────────

class _ImagePickerTile extends StatelessWidget {
  const _ImagePickerTile({
    required this.label,
    required this.icon,
    required this.pickedFile,
    required this.existingUrl,
    required this.locked,
    required this.onPick,
  });

  final String label;
  final IconData icon;
  final File? pickedFile;
  final String? existingUrl;
  final bool locked;
  final VoidCallback onPick;

  bool get _hasImage => pickedFile != null || (existingUrl?.isNotEmpty == true);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: locked ? null : onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _hasImage
              ? scheme.primaryContainer.withValues(alpha: 0.4)
              : scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hasImage
                ? AppColors.success.withValues(alpha: 0.4)
                : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _hasImage
                    ? AppColors.success.withValues(alpha: 0.12)
                    : scheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: pickedFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(pickedFile!, fit: BoxFit.cover),
                    )
                  : Icon(
                      _hasImage ? Icons.check_circle_outline_rounded : icon,
                      color: _hasImage ? AppColors.success : scheme.primary,
                      size: 20,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pickedFile != null
                        ? context.tr("photo_new_selected")
                        : _hasImage
                        ? context.tr("photo_uploaded")
                        : context.tr("tap_select_photo"),
                    style: TextStyle(
                      fontSize: 11,
                      color: _hasImage
                          ? AppColors.success
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!locked)
              Icon(
                _hasImage
                    ? Icons.edit_outlined
                    : Icons.add_photo_alternate_outlined,
                color: scheme.primary,
                size: 20,
              ),
            if (locked)
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
