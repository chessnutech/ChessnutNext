import '../l10n/localized_material.dart';

import '../services/chessnut_api_client.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_feedback.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({
    required this.onNavigate,
    required this.apiClient,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ChessnutApiClient apiClient;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool loading = true;
  String? errorMessage;
  int unreadCount = 0;
  List<InboxMessage> messages = const [];
  int? expandedMessageId;
  final Set<int> markingRead = {};

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    if (widget.apiClient.session == null) {
      setState(() {
        loading = false;
        errorMessage = 'Sign in to view your inbox.';
        unreadCount = 0;
        messages = const [];
      });
      return;
    }

    setState(() {
      loading = true;
      errorMessage = null;
    });
    final result = await widget.apiClient.inboxList(count: 30);
    if (!mounted) return;
    setState(() {
      loading = false;
      if (result.isSuccess && result.data != null) {
        unreadCount = result.data!.unreadCount;
        messages = result.data!.items;
      } else {
        errorMessage = result.status.errorMessage ??
            'Inbox is not available right now. Check your connection and try again.';
        messages = const [];
        unreadCount = 0;
      }
    });
  }

  Future<void> _openMessage(InboxMessage message) async {
    setState(() => expandedMessageId = message.id);
    if (message.read || markingRead.contains(message.id)) return;

    setState(() => markingRead.add(message.id));
    final result = await widget.apiClient.markInboxMessageRead(message.id);
    if (!mounted) return;
    setState(() {
      markingRead.remove(message.id);
      if (result.isSuccess && result.data != null) {
        unreadCount = result.data!.unreadCount;
        messages = [
          for (final item in messages)
            item.id == message.id
                ? item.copyWith(
                    read: true,
                    readAt: result.data!.read ? _nowIsoString() : item.readAt,
                  )
                : item,
        ];
      }
    });
    if (!result.isSuccess && mounted) {
      showAppFeedback(
        context,
        result.status.errorMessage ??
            'Message status could not be updated. Please try again.',
        tone: AppFeedbackTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      children: (context, spec) => [
        ScreenHeader(
          title: 'Inbox',
          subtitle: _inboxSubtitle(),
          leading: IconButton.filledTonal(
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          trailing: IconButton.filledTonal(
            tooltip: 'Refresh inbox',
            onPressed: loading ? null : _loadInbox,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        SizedBox(height: spec.gutter),
        if (loading)
          const _InboxLoadingCard()
        else if (errorMessage != null)
          _InboxMessageCard(
            icon: Icons.wifi_off_rounded,
            title: 'Inbox unavailable',
            body: errorMessage!,
            actionLabel: 'Try again',
            onAction: _loadInbox,
          )
        else if (messages.isEmpty)
          _InboxMessageCard(
            icon: Icons.mark_email_read_rounded,
            title: 'Inbox is clear',
            body:
                'Product updates and important account messages will appear here.',
            actionLabel: 'Back to account',
            onAction: () => widget.onNavigate('Account'),
          )
        else
          SectionColumn(
            spacing: 10,
            children: [
              for (final message in messages)
                _InboxMessageTile(
                  message: message,
                  expanded: expandedMessageId == message.id,
                  markingRead: markingRead.contains(message.id),
                  onTap: () => _openMessage(message),
                  onAction: message.actionRoute.trim().isEmpty
                      ? null
                      : () => widget.onNavigate(message.actionRoute.trim()),
                ),
            ],
          ),
      ],
    );
  }

  String _inboxSubtitle() {
    if (loading) return 'Loading messages';
    if (unreadCount == 1) return '1 unread message';
    if (unreadCount > 1) return '$unreadCount unread messages';
    return 'No new messages';
  }
}

class _InboxMessageTile extends StatelessWidget {
  const _InboxMessageTile({
    required this.message,
    required this.expanded,
    required this.markingRead,
    required this.onTap,
    required this.onAction,
  });

  final InboxMessage message;
  final bool expanded;
  final bool markingRead;
  final VoidCallback onTap;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unread = !message.read;
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      tint: unread ? scheme.primary.withValues(alpha: 0.07) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InboxIcon(unread: unread),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.title,
                      maxLines: expanded ? 3 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      expanded ? message.body : _preview(message.body),
                      maxLines: expanded ? 10 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _InboxStateChip(
                label: unread ? (markingRead ? 'Reading' : 'Unread') : 'Read',
                unread: unread,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _InboxMetaChip(
                icon: Icons.campaign_rounded,
                label: _messageTypeLabel(message.messageType),
              ),
              _InboxMetaChip(
                icon: Icons.schedule_rounded,
                label: _friendlyTime(message.publishedAt),
              ),
            ],
          ),
          if (expanded && message.actionLabel.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(message.actionLabel.trim()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _preview(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.isEmpty ? 'Open message for details.' : compact;
  }
}

class _InboxIcon extends StatelessWidget {
  const _InboxIcon({required this.unread});

  final bool unread;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: unread
            ? scheme.primary.withValues(alpha: 0.14)
            : scheme.secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        unread
            ? Icons.mark_email_unread_rounded
            : Icons.mark_email_read_rounded,
        color: unread ? scheme.primary : scheme.secondary,
      ),
    );
  }
}

class _InboxStateChip extends StatelessWidget {
  const _InboxStateChip({
    required this.label,
    required this.unread,
  });

  final String label;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = unread ? scheme.primary : scheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InboxMetaChip extends StatelessWidget {
  const _InboxMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.secondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _InboxLoadingCard extends StatelessWidget {
  const _InboxLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const GlassPanel(
      padding: EdgeInsets.all(16),
      borderRadius: 14,
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('Loading inbox messages...')),
        ],
      ),
    );
  }
}

class _InboxMessageCard extends StatelessWidget {
  const _InboxMessageCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(body),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

String _messageTypeLabel(String type) {
  return switch (type.trim()) {
    'campaign' => 'Campaign',
    'support' => 'Support',
    'system' => 'System',
    _ => 'Announcement',
  };
}

String _friendlyTime(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw.isEmpty ? 'Just now' : raw;
  final local = parsed.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}

String _nowIsoString() {
  return DateTime.now().toUtc().toIso8601String();
}
