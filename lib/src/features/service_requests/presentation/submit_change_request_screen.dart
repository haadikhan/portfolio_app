import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../providers/change_request_providers.dart";

/// One editable field in a submit form.
typedef SubmitChangeField = ({String key, String label});

/// Submit a profile / bank / nominee / phone change request.
class SubmitChangeRequestScreen extends ConsumerStatefulWidget {
  const SubmitChangeRequestScreen({
    super.key,
    required this.requestType,
    required this.currentValues,
    required this.editableLabels,
  });

  final String requestType;
  final Map<String, dynamic> currentValues;
  final List<SubmitChangeField> editableLabels;

  @override
  ConsumerState<SubmitChangeRequestScreen> createState() =>
      _SubmitChangeRequestScreenState();
}

class _SubmitChangeRequestScreenState
    extends ConsumerState<SubmitChangeRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;

  String _titleKey() {
    switch (widget.requestType.trim().toLowerCase()) {
      case "profile":
        return "sr_type_profile";
      case "phone":
        return "sr_type_phone";
      case "bank":
        return "sr_type_bank";
      case "nominee":
        return "sr_type_nominee";
      default:
        return "service_requests_submit";
    }
  }

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final e in widget.editableLabels) e.key: TextEditingController(text: "")
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    for (final e in widget.editableLabels) {
      if (_controllers[e.key]!.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr("sr_validation_required"))),
        );
        return;
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr("sr_submit_confirm_title")),
        content: Text(context.tr("sr_submit_confirm_body")),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr("sr_cancel_label")),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr("sr_submit_label")),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final requested = <String, dynamic>{
      for (final e in widget.editableLabels) e.key: _controllers[e.key]!.text.trim(),
    };
    final current = Map<String, dynamic>.from(widget.currentValues);

    try {
      await ref.read(submitChangeRequestProvider.notifier).submit(
            requestType: widget.requestType.trim().toLowerCase(),
            requestedFields: requested,
            currentFields: current,
          );
      if (!mounted) return;
      final state = ref.read(submitChangeRequestProvider);
      if (state.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${state.error}")),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr("sr_submitted_success"))),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${context.tr("error_prefix")} $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final submitting = ref.watch(submitChangeRequestProvider).isLoading;

    return AppScaffold(
      title: context.tr(_titleKey()),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.tr("sr_current_values_section"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.currentValues.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              e.key,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              "${e.value}",
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr("service_requests_submit"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final field in widget.editableLabels)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _controllers[field.key],
                  decoration: InputDecoration(
                    labelText: field.label,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return " ";
                    return null;
                  },
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: submitting ? null : _onSubmit,
              child: submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr("sr_submit_label")),
            ),
          ],
        ),
      ),
    );
  }
}
