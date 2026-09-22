import '../l10n/app_strings.dart';
import '../l10n/localized_material.dart';

import '../models/app_models.dart';
import '../services/chessnut_api_client.dart';
import '../services/wallet_display.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_feedback.dart';
import '../widgets/chessnut_motion.dart';
import '../widgets/membership_dialog.dart';

class PointsScreen extends StatefulWidget {
  const PointsScreen({
    required this.onNavigate,
    required this.apiClient,
    this.initialBalance,
    this.walletDebugToolsEnabled =
        const bool.fromEnvironment('CHESSNUT_ENABLE_WALLET_DEBUG_TOOLS'),
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ChessnutApiClient apiClient;
  final WalletBalance? initialBalance;
  final bool walletDebugToolsEnabled;

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  bool loading = true;
  bool debugAdjustLoading = false;
  WalletBalance? balance;
  WalletLedger? ledger;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    balance = widget.initialBalance;
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    if (widget.apiClient.session == null) {
      setState(() {
        loading = false;
        balance = null;
        ledger = null;
        errorMessage = 'Sign in to sync points, membership, and ledger.';
      });
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
    });
    final balanceResult = await widget.apiClient.walletBalance();
    final ledgerResult = await widget.apiClient.walletLedger();
    if (!mounted) return;
    setState(() {
      loading = false;
      if (balanceResult.isSuccess && balanceResult.data != null) {
        balance = balanceResult.data;
        ledger = ledgerResult.data;
      } else {
        errorMessage = balanceResult.status.errorMessage ??
            'Wallet is not available right now. Check your connection and try again.';
      }
    });
  }

  Future<void> _debugAdjustWallet(int amount) async {
    if (debugAdjustLoading || widget.apiClient.session == null) return;
    setState(() => debugAdjustLoading = true);
    final result = await widget.apiClient.debugAdjustWalletPoints(
      amount: amount,
    );
    if (!mounted) return;
    if (!result.isSuccess || result.data == null) {
      setState(() => debugAdjustLoading = false);
      showAppFeedback(
        context,
        result.status.errorMessage ?? 'Wallet test tools are unavailable.',
        tone: AppFeedbackTone.error,
      );
      return;
    }
    showAppFeedback(
      context,
      amount >= 0 ? '+$amount points' : '$amount points',
      tone: amount >= 0 ? AppFeedbackTone.success : AppFeedbackTone.warning,
    );
    await _loadWallet();
    if (!mounted) return;
    setState(() => debugAdjustLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      children: (context, spec) => [
        ScreenHeader(
          title: 'Daily points',
          subtitle: 'Account ledger',
          leading: IconButton.filledTonal(
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          trailing: IconButton.filledTonal(
            onPressed: _loadWallet,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        SizedBox(height: spec.gutter),
        ResponsiveSplit(
          breakpoint: 840,
          spacing: spec.gutter,
          leadingFlex: 5,
          trailingFlex: 6,
          leading: SectionColumn(
            spacing: 12,
            children: [
              _WalletBalanceCard(
                loading: loading,
                balance: balance,
                errorMessage: errorMessage,
                onSignIn: () => widget.onNavigate('Auth'),
              ),
              if (widget.walletDebugToolsEnabled &&
                  widget.apiClient.isLocalTestBackend)
                _LocalWalletTesterCard(
                  loading: debugAdjustLoading || loading,
                  onAdjust: _debugAdjustWallet,
                ),
              if (showMembershipPurchaseEntry &&
                  widget.apiClient.session != null &&
                  balance?.memberActive != true)
                _PremiumRuleCard(apiClient: widget.apiClient),
            ],
          ),
          trailing: SectionColumn(
            spacing: 10,
            children: _ledgerRows(),
          ),
        ),
      ],
    );
  }

  List<Widget> _ledgerRows() {
    if (loading) {
      return const [
        _LedgerRow(
          title: 'Loading wallet ledger',
          amount: '...',
          positive: true,
        ),
      ];
    }
    final items = ledger?.items ?? const <WalletLedgerItem>[];
    if (items.isEmpty) {
      return const [
        _EmptyLedgerCard(),
      ];
    }
    final strings = AppStrings.of(context);
    return [
      for (final item in items)
        _LedgerRow(
          title: localizedWalletLedgerTitle(strings, item.title),
          amount: formatWalletDelta(item.amount),
          positive: item.amount >= 0,
        ),
    ];
  }
}

class _LocalWalletTesterCard extends StatelessWidget {
  const _LocalWalletTesterCard({
    required this.loading,
    required this.onAdjust,
  });

  final bool loading;
  final ValueChanged<int> onAdjust;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      tint: scheme.tertiary.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.tertiary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.science_rounded, color: scheme.tertiary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Local QA wallet tools',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Hidden unless the local QA build flag is enabled.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _WalletAdjustButton(
                key: const ValueKey('wallet-debug-add-100'),
                label: '+100',
                icon: Icons.add_rounded,
                enabled: !loading,
                onPressed: () => onAdjust(100),
              ),
              _WalletAdjustButton(
                key: const ValueKey('wallet-debug-add-500'),
                label: '+500',
                icon: Icons.add_circle_outline_rounded,
                enabled: !loading,
                onPressed: () => onAdjust(500),
              ),
              _WalletAdjustButton(
                key: const ValueKey('wallet-debug-subtract-100'),
                label: '-100',
                icon: Icons.remove_rounded,
                enabled: !loading,
                onPressed: () => onAdjust(-100),
              ),
              _WalletAdjustButton(
                key: const ValueKey('wallet-debug-subtract-500'),
                label: '-500',
                icon: Icons.remove_circle_outline_rounded,
                enabled: !loading,
                onPressed: () => onAdjust(-500),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletAdjustButton extends StatelessWidget {
  const _WalletAdjustButton({
    super.key,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({
    required this.loading,
    required this.balance,
    required this.errorMessage,
    required this.onSignIn,
  });

  final bool loading;
  final WalletBalance? balance;
  final String? errorMessage;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final signedOut = balance == null && errorMessage != null && !loading;
    final strings = AppStrings.of(context);
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: scheme.primary.withValues(alpha: 0.14),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: scheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChessnutFadeSlide(
                  key: ValueKey('wallet-balance-${balance?.balance ?? 'none'}'),
                  child: Text(
                    loading
                        ? '...'
                        : balance == null
                            ? '--'
                            : formatWalletPoints(balance!.balance),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loading
                      ? strings.t('Loading account wallet...')
                      : balance == null
                          ? strings.t(errorMessage ?? 'Wallet unavailable.')
                          : balance!.memberActive
                              ? strings.t(
                                  'Premium active / Grandeur and personal engine training unlimited',
                                )
                              : balance!.claimedToday
                                  ? strings
                                      .t(
                                        'Checked in today / Grandeur 100 / personal engine training 500',
                                      )
                                      .replaceAll(
                                        '500',
                                        '$personalEngineTrainingCostPoints',
                                      )
                                  : strings
                                      .t(
                                        'Daily check-in available / Grandeur 100 / personal engine training 500',
                                      )
                                      .replaceAll(
                                        '500',
                                        '$personalEngineTrainingCostPoints',
                                      ),
                ),
                if (signedOut) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onSignIn,
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Sign in'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumRuleCard extends StatelessWidget {
  const _PremiumRuleCard({required this.apiClient});

  final ChessnutApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      tint: scheme.primary.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Premium removes point costs',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Grandeur and personal engine training become unlimited.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () =>
                showMembershipDialog(context, apiClient: apiClient),
            icon: const Icon(Icons.shopping_bag_rounded),
            label: const Text('Upgrade membership'),
          ),
        ],
      ),
    );
  }
}

class _EmptyLedgerCard extends StatelessWidget {
  const _EmptyLedgerCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 12,
      tint: scheme.outline.withValues(alpha: 0.05),
      child: Row(
        children: [
          Icon(Icons.receipt_long_rounded, color: scheme.outline),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'No point activity yet.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.title,
    required this.amount,
    required this.positive,
  });

  final String title;
  final String amount;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFFEF4444);
    return ChessnutFadeSlide(
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: 12,
        child: Row(
          children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800))),
            Text(amount,
                style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
