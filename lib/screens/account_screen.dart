import 'dart:async';

import '../l10n/app_strings.dart';
import '../l10n/localized_material.dart';

import '../services/auth_service.dart';
import '../services/chessnut_api_client.dart';
import '../services/wallet_display.dart';
import '../widgets/app_chrome.dart';
import '../widgets/app_feedback.dart';
import '../widgets/chessnut_motion.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/lichess_authorization_dialog.dart';
import '../widgets/membership_dialog.dart';

const chessnutProfileAvatars = <String>[
  'assets/avatars/avatar-01.png',
  'assets/avatars/avatar-02.png',
  'assets/avatars/avatar-03.png',
  'assets/avatars/avatar-04.png',
  'assets/avatars/avatar-05.png',
  'assets/avatars/avatar-06.png',
  'assets/avatars/avatar-07.png',
  'assets/avatars/avatar-08.png',
  'assets/avatars/avatar-09.png',
  'assets/avatars/avatar-10.png',
  'assets/avatars/avatar-11.png',
  'assets/avatars/avatar-12.png',
  'assets/avatars/avatar-13.png',
  'assets/avatars/avatar-14.png',
  'assets/avatars/avatar-15.png',
  'assets/avatars/avatar-16.png',
  'assets/avatars/avatar-17.png',
  'assets/avatars/avatar-18.png',
  'assets/avatars/avatar-19.png',
  'assets/avatars/avatar-20.png',
  'assets/avatars/avatar-21.png',
  'assets/avatars/avatar-22.png',
  'assets/avatars/avatar-23.png',
  'assets/avatars/avatar-24.png',
  'assets/avatars/avatar-25.png',
  'assets/avatars/avatar-26.png',
  'assets/avatars/avatar-27.png',
  'assets/avatars/avatar-28.png',
  'assets/avatars/avatar-29.png',
  'assets/avatars/avatar-30.png',
];

class AccountScreen extends StatefulWidget {
  const AccountScreen({
    required this.onNavigate,
    required this.apiClient,
    this.lichessAuthorizationPresenter = showLichessAuthorization,
    this.session,
    this.onSessionUpdated,
    this.showAccountSwitcher = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ChessnutApiClient apiClient;
  final LichessAuthorizationPresenter lichessAuthorizationPresenter;
  final ChessnutLoginSession? session;
  final ValueChanged<ChessnutLoginSession>? onSessionUpdated;
  final bool showAccountSwitcher;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  ChessnutLoginSession? sessionOverride;
  late final SocialAuthBroker socialAuthBroker;
  bool walletLoading = false;
  WalletBalance? walletBalance;
  String? walletErrorMessage;

  ChessnutLoginSession? get session => sessionOverride ?? widget.session;

  void _profileUpdated(ChessnutLoginSession session) {
    setState(() => sessionOverride = session);
    widget.onSessionUpdated?.call(session);
  }

  @override
  void initState() {
    super.initState();
    socialAuthBroker = FlutterSocialAuthBroker();
    _loadWallet();
  }

  @override
  void didUpdateWidget(AccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      sessionOverride = null;
      walletBalance = null;
      _loadWallet();
    }
  }

  Future<void> _loadWallet() async {
    if (widget.apiClient.session == null) {
      setState(() {
        walletLoading = false;
        walletBalance = null;
        walletErrorMessage = 'Sign in to sync points and membership.';
      });
      return;
    }
    setState(() {
      walletLoading = true;
      walletErrorMessage = null;
    });
    final balanceResult = await widget.apiClient.walletBalance();
    if (!mounted) return;
    setState(() {
      walletLoading = false;
      if (balanceResult.isSuccess && balanceResult.data != null) {
        walletBalance = balanceResult.data;
      } else {
        walletBalance = null;
        walletErrorMessage = balanceResult.status.errorMessage ??
            'Wallet is not available right now. Check your connection and try again.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isPortraitPhone = !isLandscape && mediaQuery.size.width < 700;

    final leadingChildren = <Widget>[
      _AccountHero(
        session: session,
        apiClient: widget.apiClient,
        walletLoading: walletLoading,
        walletBalance: walletBalance,
        walletErrorMessage: walletErrorMessage,
        onProfileUpdated: _profileUpdated,
      ),
      _WalletCard(
        onOpenWallet: () => widget.onNavigate('Points'),
        loading: walletLoading,
        balance: walletBalance,
      ),
      if (!isPortraitPhone)
        _SessionCard(
          onNavigate: widget.onNavigate,
          apiClient: widget.apiClient,
          session: session,
          showAccountSwitcher: widget.showAccountSwitcher,
        ),
      if (!isLandscape) ...[
        _LinkedAccountsCard(
          apiClient: widget.apiClient,
          session: session,
          socialAuthBroker: socialAuthBroker,
          onSessionUpdated: _profileUpdated,
        ),
        _PlatformGrid(
          session: session,
          apiClient: widget.apiClient,
          lichessAuthorizationPresenter: widget.lichessAuthorizationPresenter,
          onSessionUpdated: _profileUpdated,
          onNavigate: widget.onNavigate,
        ),
        if (isPortraitPhone)
          _SessionCard(
            onNavigate: widget.onNavigate,
            apiClient: widget.apiClient,
            session: session,
            showAccountSwitcher: widget.showAccountSwitcher,
          ),
      ],
    ];

    final trailingChildren = <Widget>[
      if (isLandscape) ...[
        _PlatformGrid(
          session: session,
          apiClient: widget.apiClient,
          lichessAuthorizationPresenter: widget.lichessAuthorizationPresenter,
          onSessionUpdated: _profileUpdated,
          onNavigate: widget.onNavigate,
        ),
        _LinkedAccountsCard(
          apiClient: widget.apiClient,
          session: session,
          socialAuthBroker: socialAuthBroker,
          onSessionUpdated: _profileUpdated,
        ),
      ],
    ];

    return ResponsivePage(
      children: (context, spec) => [
        ScreenHeader(
          title: 'Account',
          subtitle: 'Me',
          leading: IconButton.filledTonal(
            key: const ValueKey('account-back-button'),
            onPressed: () => widget.onNavigate('Back'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        SizedBox(height: spec.gutter),
        ResponsiveSplit(
          breakpoint: 860,
          spacing: spec.gutter,
          leadingFlex: 6,
          trailingFlex: 5,
          leading: SectionColumn(
            spacing: 12,
            children: leadingChildren,
          ),
          trailing: SectionColumn(
            spacing: 12,
            children: trailingChildren,
          ),
        ),
      ],
    );
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero({
    required this.session,
    required this.apiClient,
    required this.walletLoading,
    required this.walletBalance,
    required this.walletErrorMessage,
    required this.onProfileUpdated,
  });

  final ChessnutLoginSession? session;
  final ChessnutApiClient apiClient;
  final bool walletLoading;
  final WalletBalance? walletBalance;
  final String? walletErrorMessage;
  final ValueChanged<ChessnutLoginSession> onProfileUpdated;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);
    final username = _profileName(session);
    final avatar = _profileAvatar(session?.avatarUrl);
    final membershipSummary = _membershipSummary(context);
    final isMember = membershipSummary != null;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Row(
        children: [
          _ProfileAvatar(
            avatarUrl: avatar,
            width: 58,
            height: 58,
            fallbackLetter: username.substring(0, 1).toUpperCase(),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      flex: isMember ? 4 : 1,
                      fit: FlexFit.loose,
                      child: Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (isMember) ...[
                      const SizedBox(width: 8),
                      _VipBadge(label: strings.t('VIP member')),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (membershipSummary == null)
                  Text(
                    _walletSummary(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  _MembershipStatusLink(
                    label: membershipSummary,
                    onTap: showMembershipPurchaseEntry
                        ? () => showMembershipDialog(
                              context,
                              apiClient: apiClient,
                            )
                        : null,
                  ),
              ],
            ),
          ),
          IconButton.filledTonal(
            key: const ValueKey('account-edit-profile'),
            tooltip: 'Edit profile',
            onPressed: session == null
                ? null
                : () => _showProfileDialog(context, username, avatar),
            icon: Icon(Icons.edit_rounded, color: scheme.primary),
          ),
        ],
      ),
    );
  }

  String _walletSummary(BuildContext context) {
    final strings = AppStrings.of(context);
    if (session == null) {
      return strings.t('Sign in to sync points and profile.');
    }
    if (walletLoading) {
      return strings.t('Loading account wallet...');
    }
    final balance = walletBalance;
    if (balance == null) {
      return strings.t(walletErrorMessage ?? 'Wallet unavailable.');
    }
    return '${formatWalletPoints(balance.balance)} ${strings.t('points')}';
  }

  String? _membershipSummary(BuildContext context) {
    final balance = walletBalance;
    if (balance?.memberActive != true) return null;
    final strings = AppStrings.of(context);
    final expireDate = _formatMembershipExpiry(balance!.memberExpireAt);
    if (expireDate.isEmpty) return strings.t('Premium is active.');
    return '${strings.t('Valid until')} $expireDate';
  }

  void _showProfileDialog(
    BuildContext context,
    String username,
    String avatarUrl,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (context) => _ProfileEditorDialog(
        apiClient: apiClient,
        initialUsername: username,
        initialAvatarUrl: avatarUrl,
        onSaved: onProfileUpdated,
      ),
    );
  }
}

class _VipBadge extends StatelessWidget {
  const _VipBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Container(
        key: const ValueKey('account-vip-badge'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'VIP',
          style: TextStyle(
            color: scheme.onPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _MembershipStatusLink extends StatelessWidget {
  const _MembershipStatusLink({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: const ValueKey('account-member-status'),
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 15,
              color: scheme.primary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.visible,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: scheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.width,
    required this.height,
    required this.fallbackLetter,
  });

  final String avatarUrl;
  final double width;
  final double height;
  final String fallbackLetter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(width >= 56 ? 18 : 12);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: radius,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.26)),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: avatarUrl.startsWith('assets/')
          ? Image.asset(
              avatarUrl,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _AvatarFallback(letter: fallbackLetter),
            )
          : _AvatarFallback(letter: fallbackLetter),
    );
  }
}

String _profileName(ChessnutLoginSession? session) {
  final username = session?.username.trim() ?? '';
  if (username.isNotEmpty) return username;
  final email = session?.email.trim() ?? '';
  if (email.isNotEmpty) return email;
  return 'Chessnut Player';
}

String _profileAvatar(String? avatarUrl) {
  final value = avatarUrl?.trim() ?? '';
  if (chessnutProfileAvatars.contains(value)) return value;
  return chessnutProfileAvatars.first;
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Text(
      letter,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontSize: 27,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _ProfileEditorDialog extends StatefulWidget {
  const _ProfileEditorDialog({
    required this.apiClient,
    required this.initialUsername,
    required this.initialAvatarUrl,
    required this.onSaved,
  });

  final ChessnutApiClient apiClient;
  final String initialUsername;
  final String initialAvatarUrl;
  final ValueChanged<ChessnutLoginSession> onSaved;

  @override
  State<_ProfileEditorDialog> createState() => _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends State<_ProfileEditorDialog> {
  late final TextEditingController usernameController;
  late String selectedAvatarUrl;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    usernameController = TextEditingController(text: widget.initialUsername);
    selectedAvatarUrl = _profileAvatar(widget.initialAvatarUrl);
  }

  @override
  void dispose() {
    usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      icon: Icons.person_rounded,
      title: 'Edit profile',
      subtitle: 'Choose how you appear in Chessnut.',
      actions: [
        Expanded(
          child: OutlinedButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PrimaryButton(
            label: saving ? 'Saving' : 'Save profile',
            icon: Icons.check_rounded,
            onPressed: saving ? null : _save,
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: usernameController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 360 ? 5 : 6;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: chessnutProfileAvatars.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final avatar = chessnutProfileAvatars[index];
                  final selected = selectedAvatarUrl == avatar;
                  final name = avatar.split('/').last.replaceAll('.png', '');
                  return _AvatarChoice(
                    key: ValueKey('profile-avatar-$name'),
                    avatarUrl: avatar,
                    selected: selected,
                    onTap: () => setState(() => selectedAvatarUrl = avatar),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final username = usernameController.text.trim();
    if (username.isEmpty) {
      showAppFeedback(
        context,
        'Enter a username.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }

    setState(() => saving = true);
    final result = await widget.apiClient.updateProfile(
      username: username,
      avatarUrl: selectedAvatarUrl,
    );
    if (!mounted) return;
    setState(() => saving = false);

    if (result.isSuccess && result.data != null) {
      widget.onSaved(result.data!);
      Navigator.of(context).pop();
      showAppFeedback(
        context,
        'Profile updated.',
        tone: AppFeedbackTone.success,
      );
      return;
    }

    showAppFeedback(
      context,
      result.status.errorMessage ??
          'Profile update failed. Check your connection and try again.',
      tone: AppFeedbackTone.error,
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.avatarUrl,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String avatarUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.55),
              width: selected ? 2 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(avatarUrl, fit: BoxFit.cover),
              ),
              if (selected)
                Align(
                  alignment: Alignment.topRight,
                  child: ChessnutPulseBadge(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.onOpenWallet,
    required this.loading,
    required this.balance,
  });

  final VoidCallback onOpenWallet;
  final bool loading;
  final WalletBalance? balance;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);
    final hintColor = scheme.onSurfaceVariant.withValues(alpha: 0.82);
    return GlassPanel(
      onTap: onOpenWallet,
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Wallet',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                loading
                    ? '...'
                    : balance == null
                        ? '--'
                        : formatWalletPoints(balance!.balance),
                style: TextStyle(
                  color: scheme.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.t('Tap to view details'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: hintColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: hintColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatMembershipExpiry(String rawValue) {
  final raw = rawValue.trim();
  if (raw.isEmpty) return '';
  final dateMatch =
      RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(raw);
  if (dateMatch != null) {
    return '${dateMatch.group(1)}/'
        '${dateMatch.group(2)!.padLeft(2, '0')}/'
        '${dateMatch.group(3)!.padLeft(2, '0')}';
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  return '${parsed.year.toString().padLeft(4, '0')}/'
      '${parsed.month.toString().padLeft(2, '0')}/'
      '${parsed.day.toString().padLeft(2, '0')}';
}

class _LinkedAccountsCard extends StatefulWidget {
  const _LinkedAccountsCard({
    required this.apiClient,
    required this.session,
    required this.socialAuthBroker,
    required this.onSessionUpdated,
  });

  final ChessnutApiClient apiClient;
  final ChessnutLoginSession? session;
  final SocialAuthBroker socialAuthBroker;
  final ValueChanged<ChessnutLoginSession> onSessionUpdated;

  @override
  State<_LinkedAccountsCard> createState() => _LinkedAccountsCardState();
}

class _LinkedAccountsCardState extends State<_LinkedAccountsCard> {
  String? busyKey;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Linked accounts',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          _LinkedAccountTile(
            icon: Icons.g_mobiledata_rounded,
            title: 'Google',
            linked: session?.bindGoogle ?? false,
            busy: busyKey == 'google',
            onTap: session == null
                ? null
                : () => _toggleGoogle(session.bindGoogle),
          ),
          const Divider(height: 1),
          _LinkedAccountTile(
            icon: Icons.apple_rounded,
            title: 'Apple',
            linked: session?.bindApple ?? false,
            busy: busyKey == 'apple',
            onTap:
                session == null ? null : () => _toggleApple(session.bindApple),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleGoogle(bool linked) async {
    if (linked) {
      await _unbind('google');
      return;
    }
    await _run('google', () async {
      final credential = await widget.socialAuthBroker.signInWithGoogle(
        const AuthRuntimeConfig(),
      );
      final token = credential.identityToken?.trim() ?? '';
      if (token.isEmpty) {
        return _LinkedAccountResult.failure(
          'Google sign in did not finish. Please try again.',
        );
      }
      final result = await widget.apiClient.bindGoogle(token);
      return _sessionResult(result, google: true);
    });
  }

  Future<void> _toggleApple(bool linked) async {
    if (linked) {
      await _unbind('apple');
      return;
    }
    await _run('apple', () async {
      final credential = await widget.socialAuthBroker.signInWithApple(
        const AuthRuntimeConfig(),
      );
      final token = credential.identityToken?.trim() ?? '';
      if (token.isEmpty) {
        return _LinkedAccountResult.failure(
          'Apple sign in did not finish. Please try again.',
        );
      }
      final result = await widget.apiClient.bindApple(token);
      return _sessionResult(result, apple: true);
    });
  }

  Future<void> _unbind(String bindType) async {
    await _run(bindType, () async {
      final result = await widget.apiClient.freeUserBind(bindType);
      if (!result.isSuccess) {
        return _LinkedAccountResult.failure(
          result.status.errorMessage ??
              'Linked account update failed. Please try again.',
        );
      }
      final session = widget.session;
      if (session == null) {
        return _LinkedAccountResult.success(null);
      }
      return _LinkedAccountResult.success(_sessionWithBinding(
        session,
        bindType: bindType,
        linked: false,
      ));
    });
  }

  Future<void> _run(
    String key,
    Future<_LinkedAccountResult> Function() action,
  ) async {
    if (busyKey != null) return;
    setState(() => busyKey = key);
    final result = await action().catchError((Object error) {
      if (error is AuthException) {
        return _LinkedAccountResult.failure(error.message);
      }
      return _LinkedAccountResult.failure(
        'Linked account update failed. Please try again.',
      );
    });
    if (!mounted) return;
    setState(() => busyKey = null);
    final session = result.session;
    if (result.success && session != null) {
      widget.apiClient.session = session;
      widget.onSessionUpdated(session);
    }
    showAppFeedback(
      context,
      result.message,
      tone: result.success ? AppFeedbackTone.success : AppFeedbackTone.error,
    );
  }

  _LinkedAccountResult _sessionResult(
    ApiResult<bool> result, {
    bool google = false,
    bool apple = false,
  }) {
    if (!result.isSuccess) {
      return _LinkedAccountResult.failure(
        result.status.errorMessage ??
            'Linked account update failed. Please try again.',
      );
    }
    final session = widget.session;
    if (session == null) return _LinkedAccountResult.success(null);
    return _LinkedAccountResult.success(session.copyWith(
      bindGoogle: google ? true : null,
      bindApple: apple ? true : null,
    ));
  }
}

class _LinkedAccountResult {
  const _LinkedAccountResult({
    required this.success,
    required this.message,
    this.session,
  });

  factory _LinkedAccountResult.success(ChessnutLoginSession? session) =>
      _LinkedAccountResult(
        success: true,
        message: 'Linked account updated.',
        session: session,
      );

  factory _LinkedAccountResult.failure(String message) => _LinkedAccountResult(
        success: false,
        message: message,
      );

  final bool success;
  final String message;
  final ChessnutLoginSession? session;
}

class _LinkedAccountTile extends StatelessWidget {
  const _LinkedAccountTile({
    required this.icon,
    required this.title,
    required this.linked,
    required this.busy,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool linked;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: linked ? scheme.primary : null),
      title: Text(title),
      subtitle: Text(linked ? 'Linked' : 'Not linked'),
      trailing: busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: onTap,
              child: Text(linked ? 'Unlink' : 'Link'),
            ),
    );
  }
}

ChessnutLoginSession _sessionWithBinding(
  ChessnutLoginSession session, {
  required String bindType,
  required bool linked,
}) {
  return session.copyWith(
    bindApple: bindType == 'apple' ? linked : null,
    bindChess: bindType == 'chesscom' ? linked : null,
    bindGoogle: bindType == 'google' ? linked : null,
    bindLichess: bindType == 'lichess' ? linked : null,
  );
}

class _PlatformGrid extends StatefulWidget {
  const _PlatformGrid({
    required this.session,
    required this.apiClient,
    required this.lichessAuthorizationPresenter,
    required this.onSessionUpdated,
    required this.onNavigate,
  });

  final ChessnutLoginSession? session;
  final ChessnutApiClient apiClient;
  final LichessAuthorizationPresenter lichessAuthorizationPresenter;
  final ValueChanged<ChessnutLoginSession> onSessionUpdated;
  final ValueChanged<String> onNavigate;

  @override
  State<_PlatformGrid> createState() => _PlatformGridState();
}

class _PlatformGridState extends State<_PlatformGrid> {
  bool authorizingLichess = false;
  bool refreshingLichessStatus = false;

  bool get _isLichessLinked {
    final session = _effectiveSession;
    final name = session?.lichessName.trim() ?? '';
    return session?.bindLichess == true || name.isNotEmpty;
  }

  ChessnutLoginSession? get _effectiveSession {
    final apiSession = widget.apiClient.session;
    if (apiSession is ChessnutLoginSession) return apiSession;
    return widget.session;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_refreshStoredLichessStatus());
  }

  @override
  void didUpdateWidget(covariant _PlatformGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        oldWidget.apiClient.session != widget.apiClient.session) {
      unawaited(_refreshStoredLichessStatus());
    }
  }

  Future<void> _refreshStoredLichessStatus() async {
    if (refreshingLichessStatus || widget.apiClient.session == null) return;
    setState(() => refreshingLichessStatus = true);
    final result = await widget.apiClient.getLichessToken();
    if (!mounted) return;
    setState(() => refreshingLichessStatus = false);
    final current = widget.apiClient.session is ChessnutLoginSession
        ? widget.apiClient.session as ChessnutLoginSession
        : widget.session;
    if (current is! ChessnutLoginSession) return;
    if (result.isSuccess && result.data != null) {
      _applyLichessSession(
        current,
        linked: true,
        lichessName: result.data!.lichessName,
      );
      return;
    }
    if (isLichessAuthorizationExpiredStatus(result.status)) {
      _applyLichessSession(current, linked: false, lichessName: '');
    }
  }

  Future<void> _authorizeLichess() async {
    if (authorizingLichess) return;
    if (_isLichessLinked) {
      await _showLichessStatusDialog();
      return;
    }
    if (widget.apiClient.session == null) {
      showAppFeedback(context, 'Sign in before authorizing Lichess.');
      return;
    }
    setState(() => authorizingLichess = true);
    final result = await widget.apiClient.bindLichess();
    if (!mounted) return;
    if (!result.isSuccess) {
      final refreshed = await _refreshLichessBinding();
      if (!mounted) return;
      setState(() => authorizingLichess = false);
      if (refreshed.success) {
        await _showLichessStatusDialog();
        return;
      }
      showAppFeedback(
        context,
        result.status.errorMessage ??
            'Lichess authorization is not available right now. Please try again later.',
      );
      return;
    }
    final authorizationUri = Uri.tryParse(result.data ?? '');
    if (authorizationUri == null || !authorizationUri.hasScheme) {
      setState(() => authorizingLichess = false);
      showAppFeedback(
        context,
        'Lichess authorization could not open. Try again later.',
      );
      return;
    }

    final completed = await widget.lichessAuthorizationPresenter(
      context,
      authorizationUri: authorizationUri,
    );
    if (!mounted) return;

    final refreshed = await _refreshLichessBinding();
    if (!mounted) return;
    setState(() => authorizingLichess = false);
    if (refreshed.success) {
      showAppFeedback(
        context,
        'Lichess authorized.',
        tone: AppFeedbackTone.success,
      );
      return;
    }
    if (!completed) {
      showAppFeedback(
        context,
        'Lichess authorization was not completed. Try again when the Lichess page finishes.',
        tone: AppFeedbackTone.warning,
      );
      return;
    }
    showAppFeedback(
      context,
      refreshed.message ??
          'Lichess sign-in status could not be checked. Please try again later.',
    );
  }

  Future<_LichessRefreshResult> _refreshLichessBinding() async {
    final tokenResult = await widget.apiClient.waitForLichessToken();
    if (!tokenResult.isSuccess || tokenResult.data == null) {
      return _LichessRefreshResult.failure(
        tokenResult.status.errorMessage ??
            'Lichess sign-in status could not be checked. Please try again later.',
      );
    }
    final current = widget.apiClient.session is ChessnutLoginSession
        ? widget.apiClient.session as ChessnutLoginSession
        : widget.session;
    if (current is ChessnutLoginSession) {
      _applyLichessSession(
        current,
        linked: true,
        lichessName: tokenResult.data!.lichessName,
      );
    }
    return _LichessRefreshResult.success(tokenResult.data!.lichessName);
  }

  Future<void> _showLichessStatusDialog() async {
    final name = _effectiveSession?.lichessName.trim() ?? '';
    final action = await showDialog<_LichessStatusAction>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (context) => AppDialogShell(
        icon: Icons.public_rounded,
        title: 'Lichess authorized',
        subtitle: name.isEmpty ? 'Lichess' : name,
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Keep linked',
                maxLines: 2,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(_LichessStatusAction.unlink),
              icon: const Icon(Icons.link_off_rounded),
              label: const Text(
                'Unlink Lichess',
                maxLines: 2,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
            ),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text(
                  'Connected as',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name.isEmpty ? 'Lichess' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Your Chessnut account is already connected to Lichess. You can keep this link, or unlink it if you want to authorize a different Lichess account.',
            ),
          ],
        ),
      ),
    );
    if (!mounted || action != _LichessStatusAction.unlink) return;
    await _unlinkLichess();
  }

  Future<void> _unlinkLichess() async {
    if (authorizingLichess) return;
    setState(() => authorizingLichess = true);
    final result = await widget.apiClient.freeUserBind('lichess');
    if (!mounted) return;
    setState(() => authorizingLichess = false);
    if (!result.isSuccess) {
      showAppFeedback(
        context,
        result.status.errorMessage ??
            'Linked account update failed. Please try again.',
      );
      return;
    }
    final current = widget.apiClient.session is ChessnutLoginSession
        ? widget.apiClient.session as ChessnutLoginSession
        : widget.session;
    if (current is ChessnutLoginSession) {
      _applyLichessSession(current, linked: false, lichessName: '');
    }
    showAppFeedback(
      context,
      'Lichess account unlinked.',
      tone: AppFeedbackTone.success,
    );
  }

  void _applyLichessSession(
    ChessnutLoginSession current, {
    required bool linked,
    required String lichessName,
  }) {
    if (current.bindLichess == linked &&
        current.lichessName.trim() == lichessName.trim()) {
      return;
    }
    final updated = _sessionWithLichess(
      current,
      linked: linked,
      lichessName: lichessName,
    );
    widget.apiClient.session = updated;
    widget.onSessionUpdated(updated);
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveGrid(
      minTileWidth: 116,
      maxColumns: 3,
      childAspectRatio: 1.18,
      children: [
        _AccountTile(
          key: const ValueKey('account-shortcut-lichess'),
          subtitleKey: const ValueKey('account-shortcut-lichess-subtitle'),
          icon: Icons.public_rounded,
          title: 'Lichess',
          subtitle: _lichessStatus,
          loading: authorizingLichess,
          onTap: _authorizeLichess,
        ),
        _AccountTile(
          key: const ValueKey('account-shortcut-records'),
          icon: Icons.history_rounded,
          title: 'Game Record',
          subtitle: 'PGN sync',
          onTap: () => widget.onNavigate('Records'),
        ),
        _AccountTile(
          key: const ValueKey('account-shortcut-engine'),
          icon: Icons.memory_rounded,
          title: 'Engine Lab',
          subtitle: 'Models',
          onTap: () => widget.onNavigate('Engine'),
        ),
      ],
    );
  }

  String get _lichessStatus {
    if (authorizingLichess) return 'Authorizing...';
    if (refreshingLichessStatus) return 'Checking...';
    final session = _effectiveSession;
    final name = session?.lichessName.trim() ?? '';
    if (session?.bindLichess == true || name.isNotEmpty) {
      return name.isEmpty ? 'Authorized' : name;
    }
    return 'Authorize Lichess';
  }
}

enum _LichessStatusAction { unlink }

class _LichessRefreshResult {
  const _LichessRefreshResult({
    required this.success,
    this.lichessName,
    this.message,
  });

  factory _LichessRefreshResult.success(String lichessName) =>
      _LichessRefreshResult(success: true, lichessName: lichessName);

  factory _LichessRefreshResult.failure(String message) =>
      _LichessRefreshResult(success: false, message: message);

  final bool success;
  final String? lichessName;
  final String? message;
}

ChessnutLoginSession _sessionWithLichess(
  ChessnutLoginSession session, {
  required bool linked,
  required String lichessName,
}) {
  return ChessnutLoginSession(
    userId: session.userId,
    token: session.token,
    refreshToken: session.refreshToken,
    avatarUrl: session.avatarUrl,
    bindApple: session.bindApple,
    bindChess: session.bindChess,
    bindGoogle: session.bindGoogle,
    bindLichess: linked,
    chessName: session.chessName,
    email: session.email,
    lichessName: lichessName,
    noPassword: session.noPassword,
    phone: session.phone,
    region: session.region,
    username: session.username,
  );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    super.key,
    this.subtitleKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final Key? subtitleKey;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      borderRadius: 13,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.secondary.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(9),
            ),
            child: loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.secondary,
                    ),
                  )
                : Icon(icon, size: 18, color: scheme.secondary),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            key: subtitleKey,
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.onNavigate,
    required this.apiClient,
    required this.session,
    required this.showAccountSwitcher,
  });

  final ValueChanged<String> onNavigate;
  final ChessnutApiClient apiClient;
  final ChessnutLoginSession? session;
  final bool showAccountSwitcher;

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.logout_rounded,
        title: 'Sign out?',
        subtitle:
            'You will return to the login screen. Your saved games remain on this device.',
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
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign out'),
            ),
          ),
        ],
        child: const SizedBox.shrink(),
      ),
    );
    if (confirmed == true && context.mounted) {
      onNavigate('Auth');
    }
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (context) => DeleteAccountDialog(
        onLoadCaptcha: apiClient.getDeleteUserImage,
        onDelete: ({required code, required captchaId}) async {
          final result = await apiClient.deleteUser(
            code: code,
            captchaId: captchaId,
          );
          if (result.isSuccess) {
            onNavigate('Auth');
          }
          return result;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      key: const ValueKey('account-session-card'),
      padding: EdgeInsets.zero,
      borderRadius: 14,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (session == null)
              ListTile(
                leading: const Icon(Icons.login_rounded),
                title: const Text('Sign in'),
                subtitle: const Text('Go to login'),
                onTap: () => onNavigate('Auth'),
              )
            else ...[
              if (showAccountSwitcher) ...[
                ListTile(
                  key: const ValueKey('account-switch-button'),
                  leading: const Icon(Icons.switch_account_rounded),
                  title: const Text('Switch account'),
                  subtitle: const Text('Use another saved Chessnut ID'),
                  onTap: () => onNavigate('AccountSwitcher'),
                ),
                const Divider(height: 1),
              ],
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign out'),
                subtitle: const Text('Return to login'),
                onTap: () => _confirmSignOut(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Delete account'),
                subtitle: const Text('Verification code required'),
                onTap: () => _showDeleteAccountDialog(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
