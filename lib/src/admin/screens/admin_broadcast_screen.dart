import "package:cloud_functions/cloud_functions.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Sends an in-app announcement to every user via [broadcastAnnouncement].
class AdminBroadcastScreen extends ConsumerStatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  ConsumerState<AdminBroadcastScreen> createState() =>
      _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends ConsumerState<AdminBroadcastScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _processing = false;

  final _fn = FirebaseFunctions.instanceFor(region: "us-central1");

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.length < 2 || body.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Title and message must each be at least 2 characters."),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Broadcast to all investors"),
        content: const Text(
          "This creates an inbox notification for every user and sends a "
          "push where tokens exist. Continue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Send"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _processing = true);
    try {
      final result = await _fn.httpsCallable("broadcastAnnouncement").call({
        "title": title,
        "body": body,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      final count = data["userCount"] as int? ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Sent to $count user inbox(es)."),
        ),
      );
      _titleController.clear();
      _bodyController.clear();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final hint = (e.code == "internal" &&
              (e.message == null ||
                  e.message == "internal" ||
                  e.message!.isEmpty))
          ? " Browser console CORS usually means redeploy functions or set "
              "Cloud Run invoker to public for this callable."
          : "";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Error: ${e.message ?? e.code} (${e.code}).$hint",
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Notifications — broadcast",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            "Send an announcement to every investor in-app inbox. "
            "Push notifications are sent when FCM tokens are registered.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: "Title",
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    maxLength: 200,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bodyController,
                    decoration: const InputDecoration(
                      labelText: "Message",
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    maxLength: 2000,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _processing ? null : _send,
                    icon: _processing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.send_rounded, color: scheme.onPrimary),
                    label: Text(_processing ? "Sending…" : "Broadcast"),
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
