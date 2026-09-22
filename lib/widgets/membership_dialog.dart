import 'dart:async';

import '../l10n/localized_material.dart';

import '../models/app_models.dart';
import '../services/chessnut_api_client.dart';
import '../services/membership_purchase_service.dart';
import 'app_feedback.dart';
import 'app_chrome.dart';

const showMembershipPurchaseEntry = false;

void showMembershipDialog(BuildContext context,
    {ChessnutApiClient? apiClient,
    MembershipPurchaseService? purchaseService}) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.58),
    builder: (context) => MembershipDialog(
      apiClient: apiClient,
      purchaseService: purchaseService,
    ),
  );
}

class MembershipDialog extends StatefulWidget {
  const MembershipDialog({this.apiClient, this.purchaseService, super.key});

  final ChessnutApiClient? apiClient;
  final MembershipPurchaseService? purchaseService;

  @override
  State<MembershipDialog> createState() => _MembershipDialogState();
}

class _MembershipDialogState extends State<MembershipDialog>
    with WidgetsBindingObserver {
  List<MembershipProduct> products = const [];
  bool loading = true;
  bool purchaseLoading = false;
  MembershipProduct? selectedProduct;
  int _purchaseAttempt = 0;
  int? _activePurchaseAttempt;
  int? _softReleasedPurchaseAttempt;
  Timer? _purchaseFallbackReleaseTimer;
  Timer? _purchaseResumeReleaseTimer;

  MembershipPurchaseService get _purchaseService =>
      widget.purchaseService ?? StoreMembershipPurchaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProducts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelPurchaseReleaseTimers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && purchaseLoading) {
      final attempt = _activePurchaseAttempt;
      if (attempt == null) return;
      _purchaseResumeReleaseTimer?.cancel();
      _purchaseResumeReleaseTimer = Timer(
        const Duration(milliseconds: 900),
        () => _softReleasePurchase(attempt),
      );
    }
  }

  Future<void> _loadProducts() async {
    final apiClient = widget.apiClient;
    if (apiClient == null || apiClient.session == null) {
      setState(() => loading = false);
      return;
    }
    final result = await apiClient.membershipProducts();
    if (!mounted) return;
    setState(() {
      loading = false;
      if (result.isSuccess) {
        products = result.data?.products ?? const [];
      }
      selectedProduct = _defaultProduct(products);
    });
  }

  Future<void> _purchaseSelected() async {
    final apiClient = widget.apiClient;
    final product = selectedProduct ?? _defaultProduct(_visibleProducts());
    if (apiClient == null || product == null || purchaseLoading) return;
    final attempt = ++_purchaseAttempt;
    setState(() {
      purchaseLoading = true;
      _activePurchaseAttempt = attempt;
      _softReleasedPurchaseAttempt = null;
    });
    _purchaseFallbackReleaseTimer?.cancel();
    _purchaseFallbackReleaseTimer = Timer(
      const Duration(seconds: 10),
      () => _softReleasePurchase(attempt),
    );
    MembershipPurchaseOutcome outcome;
    try {
      outcome = await _purchaseService.purchase(product, apiClient);
    } catch (_) {
      outcome = const MembershipPurchaseOutcome(
        success: false,
        message: 'Purchase was not completed. You can try again when ready.',
      );
    }
    if (!mounted) return;
    final stillCurrent = _activePurchaseAttempt == attempt;
    if (stillCurrent) {
      _cancelPurchaseReleaseTimers();
      if (purchaseLoading) {
        setState(() => purchaseLoading = false);
      }
    }
    final wasSoftReleased = _softReleasedPurchaseAttempt == attempt;
    if ((stillCurrent && !wasSoftReleased) || outcome.success) {
      showAppFeedback(
        context,
        outcome.message,
        tone: outcome.success ? AppFeedbackTone.success : AppFeedbackTone.error,
      );
    }
    if (outcome.success) Navigator.of(context).pop();
  }

  Future<void> _restorePurchase() async {
    final apiClient = widget.apiClient;
    if (apiClient == null || purchaseLoading) return;
    setState(() => purchaseLoading = true);
    MembershipPurchaseOutcome outcome;
    try {
      outcome = await _purchaseService.restore(apiClient);
    } catch (_) {
      outcome = MembershipPurchaseOutcome(
        success: false,
        message: MembershipPurchaseMessages.restoreFailed(
          'Store restore failed. Please try again.',
        ),
      );
    }
    if (!mounted) return;
    setState(() => purchaseLoading = false);
    showAppFeedback(
      context,
      outcome.message,
      tone: outcome.success ? AppFeedbackTone.success : AppFeedbackTone.error,
    );
    if (outcome.success) Navigator.of(context).pop();
  }

  List<MembershipProduct> _visibleProducts() {
    return sortMembershipProducts(
      products.isEmpty ? fallbackMembershipProducts : products,
    );
  }

  void _softReleasePurchase(int attempt) {
    if (!mounted ||
        !purchaseLoading ||
        _activePurchaseAttempt != attempt ||
        _softReleasedPurchaseAttempt == attempt) {
      return;
    }
    setState(() {
      purchaseLoading = false;
      _softReleasedPurchaseAttempt = attempt;
    });
    showAppFeedback(
      context,
      MembershipPurchaseMessages.purchaseNotCompleted,
      tone: AppFeedbackTone.error,
    );
  }

  void _cancelPurchaseReleaseTimers() {
    _purchaseFallbackReleaseTimer?.cancel();
    _purchaseFallbackReleaseTimer = null;
    _purchaseResumeReleaseTimer?.cancel();
    _purchaseResumeReleaseTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visibleProducts = _visibleProducts();
    selectedProduct ??= _defaultProduct(visibleProducts);
    return AppDialogShell(
      icon: Icons.workspace_premium_rounded,
      title: 'Chessnut Premium',
      subtitle: 'Auto-renewing plans get the best price',
      actions: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: purchaseLoading ? null : _purchaseSelected,
                icon: const Icon(Icons.shopping_bag_rounded),
                label: Text(
                  purchaseLoading ? 'Processing purchase' : 'Continue purchase',
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: purchaseLoading ? null : _restorePurchase,
                child: const Text(
                  'Restore purchase',
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed:
                    purchaseLoading ? null : () => Navigator.of(context).pop(),
                child: const Text(
                  'Not now',
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ],
      child: SectionColumn(
        spacing: 12,
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 3),
          ResponsiveGrid(
            minTileWidth: 188,
            maxColumns: 2,
            spacing: 8,
            childAspectRatio: 1.28,
            children: [
              for (final product in visibleProducts)
                _PlanCard(
                  title: product.title.replaceFirst('Premium ', ''),
                  price:
                      '\$${_formatPrice(product.price)} / ${product.period == 'year' ? 'year' : 'month'}',
                  caption: product.renewing ? 'Auto-renews' : 'One-time access',
                  selected: selectedProduct?.id == product.id,
                  recommended: product.recommended,
                  onTap: () => setState(() => selectedProduct = product),
                ),
            ],
          ),
          GlassPanel(
            padding: const EdgeInsets.all(12),
            borderRadius: 14,
            tint: scheme.primary.withValues(alpha: 0.07),
            child: const Column(
              children: [
                _BenefitRow(
                  icon: Icons.record_voice_over_rounded,
                  title: 'Unlimited Grandeur',
                  subtitle: 'No 100-point charge while membership is active.',
                ),
                SizedBox(height: 10),
                _BenefitRow(
                  icon: Icons.memory_rounded,
                  title: 'Unlimited personal engine training',
                  subtitle:
                      'No $personalEngineTrainingCostPoints-point charge for personal engine training.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

MembershipProduct? _defaultProduct(List<MembershipProduct> products) {
  final sortedProducts = sortMembershipProducts(products);
  if (sortedProducts.isEmpty) return null;
  for (final product in sortedProducts) {
    if (product.id == 'premium_yearly_auto') return product;
  }
  for (final product in sortedProducts) {
    if (product.recommended) return product;
  }
  return sortedProducts.first;
}

List<MembershipProduct> sortMembershipProducts(
  List<MembershipProduct> products,
) {
  final indexed = products.indexed.toList();
  indexed.sort((a, b) {
    final rankCompare =
        _membershipProductRank(a.$2).compareTo(_membershipProductRank(b.$2));
    if (rankCompare != 0) return rankCompare;
    return a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexed) entry.$2];
}

int _membershipProductRank(MembershipProduct product) {
  final period = product.period.toLowerCase();
  if (period == 'year' && product.renewing) return 0;
  if (period == 'year') return 1;
  if (period == 'month' && product.renewing) return 2;
  if (period == 'month') return 3;
  return 10;
}

String _formatPrice(String price) {
  if (price.endsWith('.00')) {
    return price.substring(0, price.length - 3);
  }
  return price;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.caption,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  final String title;
  final String price;
  final String caption;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.secondary;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        borderRadius: 14,
        tint: color.withValues(alpha: selected ? 0.12 : 0.06),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                if (recommended) _MiniPill(label: 'Best price', color: color),
              ],
            ),
            const SizedBox(height: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (!recommended && selected) ...[
              const SizedBox(height: 3),
              Text(
                'Selected',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
