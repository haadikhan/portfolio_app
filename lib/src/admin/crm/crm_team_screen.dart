import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/i18n/app_translations.dart";
import "crm_providers.dart";

/// Admin-only: list CRM staff and create accounts via [createCrmUser] callable.
class CrmTeamScreen extends ConsumerStatefulWidget {
  const CrmTeamScreen({super.key});

  @override
  ConsumerState<CrmTeamScreen> createState() => _CrmTeamScreenState();
}

class _CrmTeamScreenState extends ConsumerState<CrmTeamScreen> {
  Future<void> _openCreate() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final name = TextEditingController();
    final formKey = GlobalKey<FormState>();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr("crm_add_crm_user")),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: email,
                  decoration: InputDecoration(labelText: ctx.tr("crm_email")),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Required" : null,
                ),
                TextFormField(
                  controller: password,
                  decoration: InputDecoration(labelText: ctx.tr("crm_password")),
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.length < 6) ? "Min 6 chars" : null,
                ),
                TextFormField(
                  controller: name,
                  decoration: InputDecoration(labelText: ctx.tr("crm_display_name")),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.tr("cancel")),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final fn = FirebaseFunctions.instanceFor(region: "us-central1");
                await fn.httpsCallable("createCrmUser").call(<String, dynamic>{
                  "email": email.text.trim(),
                  "password": password.text,
                  "displayName": name.text.trim(),
                });
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ref.invalidate(crmStaffMembersProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr("crm_user_created"))),
                    );
                  }
                }
              } on FirebaseFunctionsException catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(e.message ?? "$e")),
                  );
                }
              }
            },
            child: Text(ctx.tr("crm_create_user")),
          ),
        ],
      ),
    );
    email.dispose();
    password.dispose();
    name.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(crmStaffMembersProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr("crm_team_title"),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr("crm_team_subtitle"),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _openCreate,
                icon: const Icon(Icons.person_add_outlined),
                label: Text(context.tr("crm_add_crm_user")),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text("${context.tr("error_prefix")} $e"),
              data: (staff) {
                if (staff.isEmpty) {
                  return Center(child: Text(context.tr("crm_team_empty")));
                }
                return ListView.separated(
                  itemCount: staff.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final u = staff[i];
                    return ListTile(
                      title: Text(u.name.isNotEmpty ? u.name : u.userId),
                      subtitle: Text(u.email.isNotEmpty ? u.email : u.userId),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
