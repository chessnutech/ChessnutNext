import '../l10n/localized_material.dart';
import '../services/account_switcher_store.dart';
import '../widgets/app_chrome.dart';

class AccountSwitcherScreen extends StatefulWidget {
  const AccountSwitcherScreen({
    required this.onNavigate,
    required this.onSelectAccount,
    required this.onAddAccount,
    required this.store,
    required this.currentUserId,
    this.currentAccount,
    this.now = DateTime.now,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final Future<bool> Function(SavedChessnutAccount account) onSelectAccount;
  final VoidCallback onAddAccount;
  final AccountSwitcherStore store;
  final int currentUserId;
  final SavedChessnutAccount? currentAccount;
  final DateTime Function() now;

  @override
  State<AccountSwitcherScreen> createState() => _AccountSwitcherScreenState();
}

class _AccountSwitcherScreenState extends State<AccountSwitcherScreen> {
  List<SavedChessnutAccount> accounts = const [];
  bool loading = true;
  bool managing = false;
  int? busyUserId;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final currentAccount = widget.currentAccount;
    if (currentAccount != null && currentAccount.isValid) {
      await widget.store.upsert(currentAccount);
    }
    final loaded = await widget.store.read();
    if (!mounted) return;
    setState(() {
      accounts = loaded;
      loading = false;
    });
  }

  Future<void> _select(SavedChessnutAccount account) async {
    if (managing ||
        account.userId == widget.currentUserId ||
        busyUserId != null) {
      return;
    }
    if (account.isExpired(widget.now())) {
      widget.onAddAccount();
      return;
    }
    setState(() => busyUserId = account.userId);
    final success = await widget.onSelectAccount(account);
    if (mounted) setState(() => busyUserId = null);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to switch to this account.')),
      );
    }
  }

  Future<void> _remove(SavedChessnutAccount account) async {
    if (account.userId == widget.currentUserId) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.delete_outline_rounded,
        title: 'Remove account?',
        subtitle: 'This only removes the saved login from this device.',
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ),
        ],
        child: const SizedBox.shrink(),
      ),
    );
    if (confirmed != true) return;
    await widget.store.remove(account.userId);
    if (!mounted) return;
    setState(() {
      accounts = accounts
          .where((item) => item.userId != account.userId)
          .toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      children: (context, spec) => [
        ScreenHeader(
          title: 'Switch account',
          subtitle: 'Chessnut ID',
          leading: IconButton.filledTonal(
            key: const ValueKey('account-switcher-close-button'),
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.close_rounded),
          ),
          trailing: TextButton(
            key: const ValueKey('account-switcher-manage-button'),
            onPressed: loading || accounts.length < 2
                ? null
                : () => setState(() => managing = !managing),
            child: Text(managing ? 'Done' : 'Manage'),
          ),
          trailingPinnedToRight: false,
        ),
        SizedBox(height: spec.gutter * 1.5),
        Center(
          child: Text(
            'Tap an account to switch',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
        const SizedBox(height: 18),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else ...[
          for (final account in accounts) _accountCard(context, account),
          _addAccountCard(context),
        ],
      ],
    );
  }

  Widget _accountCard(BuildContext context, SavedChessnutAccount account) {
    final current = account.userId == widget.currentUserId;
    final expired = account.isExpired(widget.now());
    final busy = busyUserId == account.userId;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        key: ValueKey('account-switcher-card-${account.userId}'),
        padding: const EdgeInsets.all(14),
        borderRadius: 14,
        onTap: current || managing ? null : () => _select(account),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AccountAvatar(account: account),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (account.email.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      account.email,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                  if (current) ...[
                    const SizedBox(height: 7),
                    Text(
                      'Current account',
                      key: const ValueKey('account-switcher-current-label'),
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ] else if (managing) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        key: ValueKey(
                          'account-switcher-remove-${account.userId}',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        ),
                        onPressed: () => _remove(account),
                        child: const Text('Remove'),
                      ),
                    ),
                  ] else if (expired) ...[
                    const SizedBox(height: 7),
                    Text(
                      'Login required',
                      key: ValueKey(
                        'account-switcher-expired-${account.userId}',
                      ),
                      style: TextStyle(
                        color: scheme.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (busy)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _addAccountCard(BuildContext context) {
    return GlassPanel(
      key: const ValueKey('account-switcher-add-account'),
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      onTap: widget.onAddAccount,
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_rounded, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Add account',
              maxLines: 2,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.account});

  final SavedChessnutAccount account;

  @override
  Widget build(BuildContext context) {
    final avatar = account.avatarUrl.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox.square(
        dimension: 58,
        child: avatar.startsWith('http')
            ? Image.network(avatar, fit: BoxFit.cover)
            : ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.person_rounded,
                  size: 34,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
