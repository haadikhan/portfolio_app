import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../../../core/i18n/app_translations.dart";
import "../../../core/theme/app_colors.dart";
import "../../../core/widgets/app_scaffold.dart";
import "../providers/change_request_providers.dart";

/// History of service / change requests for the signed-in investor.
class ServiceRequestsScreen extends ConsumerWidget {
  const ServiceRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(changeRequestsProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: context.tr("service_requests_title"),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("${context.tr("error_prefix")} $e")),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr("service_requests_empty"),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _TicketCard(
              request: requests[i],
              scheme: scheme,
            ),
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.request,
    required this.scheme,
  });

  final ChangeRequest request;
  final ColorScheme scheme;

  static final _dateFmt = DateFormat.yMMMd().add_jm();

  String _typeKey() {
    switch (request.requestType.trim().toLowerCase()) {
      case "profile":
        return "sr_type_profile";
      case "phone":
        return "sr_type_phone";
      case "bank":
        return "sr_type_bank";
      case "nominee":
        return "sr_type_nominee";
      default:
        return "sr_type_profile";
    }
  }

  (Color bg, Color fg, String labelKey) _statusStyle(BuildContext context) {
    if (request.isPending) {
      return (
        AppColors.warning.withValues(alpha: 0.2),
        const Color(0xFFB45309),
        "sr_status_pending",
      );
    }
    if (request.isApproved) {
      return (
        AppColors.success.withValues(alpha: 0.15),
        AppColors.success,
        "sr_status_approved",
      );
    }
    return (
      scheme.errorContainer.withValues(alpha: 0.5),
      scheme.error,
      "sr_status_rejected",
    );
  }

  String _shortTicketId() {
    final id = request.ticketId;
    if (id.length <= 8) return id;
    return id.substring(id.length - 8);
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusStyle(context);
    final typeLabel =
        context.tr(_typeKey()); // keys cover profile/phone/bank/nominee

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    typeLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    "${context.tr("sr_ticket_id_label")}: ${_shortTicketId()}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status.$1,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                context.tr(status.$3),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: status.$2,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            "${context.tr("sr_requested_at_label")}: ${_dateFmt.format(request.requestedAt)}",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.tr("sr_requested_values_section"),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: 6),
          ...request.requestedFields.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      e.key,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text("${e.value}", style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          if (request.reviewedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              "${context.tr("sr_reviewed_at_label")}: ${_dateFmt.format(request.reviewedAt!)}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (request.reviewNote != null && request.reviewNote!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "${context.tr("sr_review_note_label")}: ${request.reviewNote}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
