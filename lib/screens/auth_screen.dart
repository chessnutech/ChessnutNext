import 'dart:async';

import '../l10n/localized_material.dart';

import '../services/auth_service.dart';
import '../services/chessnut_api_client.dart';
import '../services/login_credential_store.dart';
import '../services/password_policy.dart';
import '../services/recaptcha_service.dart';
import '../services/session_store.dart';
import '../theme/chessnut_theme.dart';
import '../widgets/app_chrome.dart';
import '../widgets/turnstile_challenge_dialog.dart';
import 'account_screen.dart';

enum AuthMode { login, signup, forgot }

enum LoginMethod { emailPassword, phoneCode }

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.onNavigate,
    required this.apiClient,
    required this.onSignedIn,
    this.onContinueAsGuest,
    this.recaptchaService,
    this.turnstileChallengePresenter = showTurnstileChallenge,
    this.authService,
    this.sessionStore,
    this.credentialStore,
    this.compactLandscapeOverride = false,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ChessnutApiClient apiClient;
  final ValueChanged<ChessnutLoginSession> onSignedIn;
  final VoidCallback? onContinueAsGuest;
  final RecaptchaService? recaptchaService;
  final TurnstileChallengePresenter turnstileChallengePresenter;
  final AuthService? authService;
  final ChessnutSessionStore? sessionStore;
  final LoginCredentialStore? credentialStore;
  final bool compactLandscapeOverride;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _authErrorKey = GlobalKey();
  final TextEditingController accountController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController phoneCodeController = TextEditingController();
  final TextEditingController signupUsernameController =
      TextEditingController();
  final TextEditingController signupEmailController = TextEditingController();
  final TextEditingController signupPasswordController =
      TextEditingController();
  final TextEditingController resetEmailController = TextEditingController();
  final TextEditingController resetCodeController = TextEditingController();
  final TextEditingController resetPasswordController = TextEditingController();
  final TextEditingController resetPasswordConfirmController =
      TextEditingController();
  final FocusNode accountFocusNode = FocusNode();
  final FocusNode passwordFocusNode = FocusNode();
  final FocusNode phoneFocusNode = FocusNode();
  final FocusNode phoneCodeFocusNode = FocusNode();
  final FocusNode signupUsernameFocusNode = FocusNode();
  final FocusNode signupEmailFocusNode = FocusNode();
  final FocusNode signupPasswordFocusNode = FocusNode();
  final FocusNode resetEmailFocusNode = FocusNode();
  final FocusNode resetCodeFocusNode = FocusNode();
  final FocusNode resetPasswordFocusNode = FocusNode();
  final FocusNode resetPasswordConfirmFocusNode = FocusNode();
  AuthMode mode = AuthMode.login;
  bool remember = true;
  bool agree = false;
  bool recaptchaVerified = false;
  String? recaptchaToken;
  String signupAvatarUrl = chessnutProfileAvatars.first;
  bool recaptchaLoading = false;
  bool forgotResetSent = false;
  bool resetCodeSending = false;
  bool resetSubmitting = false;
  SocialAuthProvider? loadingProvider;
  bool passwordLoading = false;
  bool signupLoading = false;
  bool loginPasswordVisible = false;
  bool signupPasswordVisible = false;
  LoginMethod loginMethod = LoginMethod.emailPassword;
  bool phoneLoginAvailable = false;
  bool phoneCodeSending = false;
  bool phoneCodeSent = false;
  int phoneCodeCooldownSeconds = 0;
  Timer? phoneCodeCooldownTimer;
  bool phoneLoginLoading = false;
  AuthFailure? authError;
  late final AuthService authService;
  late final LoginCredentialStore credentialStore;

  @override
  void initState() {
    super.initState();
    authService =
        widget.authService ?? AuthService(apiClient: widget.apiClient);
    credentialStore =
        widget.credentialStore ?? const SecureLoginCredentialStore();
    signupPasswordController.addListener(_refreshSignupPasswordPolicy);
    _loadRememberedCredentials();
    _loadAuthOptions();
  }

  Future<void> _loadRememberedCredentials() async {
    final credentials = await credentialStore.read();
    if (!mounted || credentials == null || !credentials.isValid) return;
    setState(() {
      accountController.text = credentials.account;
      passwordController.text = credentials.password;
      remember = true;
    });
  }

  @override
  void dispose() {
    phoneCodeCooldownTimer?.cancel();
    _scrollController.dispose();
    signupPasswordController.removeListener(_refreshSignupPasswordPolicy);
    accountController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    phoneCodeController.dispose();
    signupUsernameController.dispose();
    signupEmailController.dispose();
    signupPasswordController.dispose();
    resetEmailController.dispose();
    resetCodeController.dispose();
    resetPasswordController.dispose();
    resetPasswordConfirmController.dispose();
    accountFocusNode.dispose();
    passwordFocusNode.dispose();
    phoneFocusNode.dispose();
    phoneCodeFocusNode.dispose();
    signupUsernameFocusNode.dispose();
    signupEmailFocusNode.dispose();
    signupPasswordFocusNode.dispose();
    resetEmailFocusNode.dispose();
    resetCodeFocusNode.dispose();
    resetPasswordFocusNode.dispose();
    resetPasswordConfirmFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadAuthOptions() async {
    final result = await widget.apiClient.authOptions();
    if (!mounted || !result.isSuccess || result.data == null) return;
    final options = result.data!;
    setState(() {
      phoneLoginAvailable = options.supportsPhone;
      if (options.prefersPhone && options.supportsPhone) {
        loginMethod = LoginMethod.phoneCode;
      }
    });
  }

  void _refreshSignupPasswordPolicy() {
    if (mode == AuthMode.signup && mounted) {
      setState(() {});
    }
  }

  String get heading {
    switch (mode) {
      case AuthMode.signup:
        return 'Create your Chessnut ID';
      case AuthMode.forgot:
        return 'Reset password';
      case AuthMode.login:
        return 'Sign in to Chessnut';
    }
  }

  String get copy {
    switch (mode) {
      case AuthMode.signup:
        return 'Create an account after a quick Turnstile human check. No email code required.';
      case AuthMode.forgot:
        return 'Send a secure one-time reset link. If it never arrives, support can verify your account and issue a new link.';
      case AuthMode.login:
        return 'Sync points, records, Grandeur credits, and board preferences across devices.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      scrollController: _scrollController,
      compactLandscapeOverride: widget.compactLandscapeOverride,
      preserveLayoutWhenKeyboardVisible: true,
      children: (context, spec) {
        final compactLandscape = spec.compactLandscape;
        final form = SectionColumn(
          spacing: compactLandscape ? 8 : 12,
          children: [
            if (mode != AuthMode.forgot)
              _AuthTabs(mode: mode, onChanged: _setMode),
            SizedBox(key: _authErrorKey, height: 0),
            AnimatedSwitcher(
              duration: compactLandscape
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              child: authError == null
                  ? const SizedBox.shrink()
                  : _AuthErrorCard(
                      key: ValueKey('${mode.index}:${authError!.message}'),
                      error: authError!,
                      mode: mode,
                      onDismiss: () => setState(() => authError = null),
                    ),
            ),
            AnimatedSwitcher(
              duration: compactLandscape
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: KeyedSubtree(
                key: ValueKey(mode),
                child: _formForMode(),
              ),
            ),
          ],
        );

        if (compactLandscape) {
          return [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: SectionColumn(
                    spacing: 8,
                    children: [
                      _CompactAuthHeader(trailing: _SecurePill()),
                      _IdentityCard(heading: heading, copy: copy),
                      if (mode == AuthMode.login)
                        OutlinedButton.icon(
                          onPressed: widget.onContinueAsGuest ??
                              () => widget.onNavigate('Home'),
                          icon: const Icon(Icons.person_outline_rounded),
                          label: const Text('Continue as guest'),
                        ),
                      if (mode != AuthMode.forgot)
                        _SocialGrid(
                          loadingProvider: loadingProvider,
                          onApple: () =>
                              _socialSignIn(SocialAuthProvider.apple),
                          onGoogle: () =>
                              _socialSignIn(SocialAuthProvider.google),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: spec.gutter),
                Expanded(flex: 6, child: form),
              ],
            ),
          ];
        }

        return [
          ScreenHeader(
            title: 'Welcome',
            subtitle: 'Account',
            trailing: _SecurePill(),
          ),
          SizedBox(height: spec.gutter),
          ResponsiveSplit(
            breakpoint: 820,
            spacing: spec.gutter,
            leadingFlex: 5,
            trailingFlex: 5,
            leading: SectionColumn(
              spacing: 12,
              children: [
                _IdentityCard(heading: heading, copy: copy),
                if (!spec.compact) const _AuthBenefitCard(),
              ],
            ),
            trailing: SectionColumn(
              spacing: 12,
              children: [
                form,
                if (mode == AuthMode.login)
                  OutlinedButton.icon(
                    onPressed: widget.onContinueAsGuest ??
                        () => widget.onNavigate('Home'),
                    icon: const Icon(Icons.person_outline_rounded),
                    label: const Text('Continue as guest'),
                  ),
                if (mode != AuthMode.forgot)
                  _SocialGrid(
                    loadingProvider: loadingProvider,
                    onApple: () => _socialSignIn(SocialAuthProvider.apple),
                    onGoogle: () => _socialSignIn(SocialAuthProvider.google),
                  ),
              ],
            ),
          ),
        ];
      },
    );
  }

  Widget _formForMode() {
    switch (mode) {
      case AuthMode.signup:
        return _SignupForm(
          usernameController: signupUsernameController,
          emailController: signupEmailController,
          passwordController: signupPasswordController,
          usernameFocusNode: signupUsernameFocusNode,
          emailFocusNode: signupEmailFocusNode,
          passwordFocusNode: signupPasswordFocusNode,
          passwordPolicy:
              SignupPasswordPolicy.evaluate(signupPasswordController.text),
          passwordVisible: signupPasswordVisible,
          onPasswordVisibilityChanged: (value) =>
              setState(() => signupPasswordVisible = value),
          agree: agree,
          recaptchaVerified: recaptchaVerified,
          recaptchaLoading: recaptchaLoading,
          selectedAvatarUrl: signupAvatarUrl,
          onAvatarChanged: (value) => setState(() => signupAvatarUrl = value),
          onAgree: (value) => setState(() => agree = value),
          onTerms: () => _showTerms(context),
          onPolicy: () => _showPolicy(context),
          onVerifyRecaptcha: _verifyRecaptcha,
          loading: signupLoading,
          onSubmit: _createAccount,
        );
      case AuthMode.forgot:
        return _ForgotForm(
          resetEmailController: resetEmailController,
          resetEmailFocusNode: resetEmailFocusNode,
          resetCodeController: resetCodeController,
          resetCodeFocusNode: resetCodeFocusNode,
          resetPasswordController: resetPasswordController,
          resetPasswordFocusNode: resetPasswordFocusNode,
          resetPasswordConfirmController: resetPasswordConfirmController,
          resetPasswordConfirmFocusNode: resetPasswordConfirmFocusNode,
          onBack: () => _setMode(AuthMode.login),
          resetSent: forgotResetSent,
          sendingCode: resetCodeSending,
          submitting: resetSubmitting,
          onSendCode: _sendResetCode,
          onSubmit: _resetPassword,
        );
      case AuthMode.login:
        if (loginMethod == LoginMethod.phoneCode) {
          return _PhoneLoginForm(
            phoneController: phoneController,
            codeController: phoneCodeController,
            phoneFocusNode: phoneFocusNode,
            codeFocusNode: phoneCodeFocusNode,
            codeSent: phoneCodeSent,
            sendingCode: phoneCodeSending,
            cooldownSeconds: phoneCodeCooldownSeconds,
            loading: phoneLoginLoading,
            agree: agree,
            onAgree: (value) => setState(() => agree = value),
            onTerms: () => _showTerms(context),
            onPolicy: () => _showPolicy(context),
            onSendCode: _sendPhoneLoginCode,
            onSubmit: _phoneCodeSignIn,
            onUseEmail: () {
              setState(() {
                loginMethod = LoginMethod.emailPassword;
                authError = null;
              });
            },
          );
        }
        return _LoginForm(
          accountController: accountController,
          passwordController: passwordController,
          accountFocusNode: accountFocusNode,
          passwordFocusNode: passwordFocusNode,
          passwordVisible: loginPasswordVisible,
          onPasswordVisibilityChanged: (value) =>
              setState(() => loginPasswordVisible = value),
          remember: remember,
          agree: agree,
          onRemember: _setRememberPassword,
          onAgree: (value) => setState(() => agree = value),
          onForgot: () => _setMode(AuthMode.forgot),
          onTerms: () => _showTerms(context),
          onPolicy: () => _showPolicy(context),
          loading: passwordLoading,
          onSubmit: _passwordSignIn,
          onUsePhone: phoneLoginAvailable
              ? () {
                  setState(() {
                    loginMethod = LoginMethod.phoneCode;
                    authError = null;
                  });
                }
              : null,
        );
    }
  }

  void _setMode(AuthMode value) {
    resetCodeController.clear();
    resetPasswordController.clear();
    resetPasswordConfirmController.clear();
    setState(() {
      mode = value;
      recaptchaVerified = false;
      recaptchaToken = null;
      recaptchaLoading = false;
      forgotResetSent = false;
      resetCodeSending = false;
      resetSubmitting = false;
      authError = null;
    });
  }

  void _setRememberPassword(bool value) {
    setState(() => remember = value);
    if (!value) {
      unawaited(credentialStore.clear());
    }
  }

  void _finishAuth(ChessnutLoginSession session) {
    final refreshToken = session.refreshToken;
    if (remember && refreshToken != null && refreshToken.trim().isNotEmpty) {
      widget.sessionStore?.write(
        StoredChessnutSession(
          userId: session.userId,
          refreshToken: refreshToken,
        ),
      );
    } else {
      widget.sessionStore?.clear();
    }
    widget.onSignedIn(session);
  }

  Future<void> _passwordSignIn() async {
    if (passwordLoading) return;
    final account = accountController.text.trim();
    final password = passwordController.text;
    if (account.isEmpty || password.isEmpty) {
      _showAuthError(
        const AuthFailure(
          reason: AuthFailureReason.backendRejected,
          message: 'Enter your email or account and password.',
        ),
      );
      return;
    }
    if (!_requireTermsAgreement()) return;
    setState(() => passwordLoading = true);
    final result = await widget.apiClient.login(account, password);
    if (!mounted) return;
    setState(() => passwordLoading = false);
    if (result.isSuccess && result.data != null) {
      if (remember) {
        unawaited(
          credentialStore.write(
            StoredLoginCredentials(account: account, password: password),
          ),
        );
      } else {
        unawaited(credentialStore.clear());
      }
      _finishAuth(result.data!);
      return;
    }
    _showAuthError(
      AuthFailure(
        reason: result.status.networkError == null
            ? AuthFailureReason.backendRejected
            : AuthFailureReason.network,
        message: result.status.errorMessage ?? 'Sign in failed.',
      ),
    );
  }

  Future<void> _sendPhoneLoginCode() async {
    if (phoneCodeSending || phoneCodeCooldownSeconds > 0) return;
    final phone = phoneController.text.trim();
    if (phone.isEmpty) {
      _showAuthError(
        const AuthFailure(
          reason: AuthFailureReason.backendRejected,
          message: 'Enter your phone number.',
        ),
      );
      return;
    }
    setState(() => phoneCodeSending = true);
    final result = await widget.apiClient.sendPhoneLoginCode(phone);
    if (!mounted) return;
    setState(() {
      phoneCodeSending = false;
      phoneCodeSent = result.isSuccess;
    });
    if (result.isSuccess) {
      _startPhoneCodeCooldown();
      return;
    }
    _showAuthError(
      AuthFailure(
        reason: result.status.networkError == null
            ? AuthFailureReason.backendRejected
            : AuthFailureReason.network,
        message: result.status.errorMessage ??
            'SMS verification code could not be sent. Please try again later.',
      ),
    );
  }

  void _startPhoneCodeCooldown() {
    phoneCodeCooldownTimer?.cancel();
    setState(() => phoneCodeCooldownSeconds = 60);
    phoneCodeCooldownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        phoneCodeCooldownSeconds--;
        if (phoneCodeCooldownSeconds <= 0) {
          phoneCodeCooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _phoneCodeSignIn() async {
    if (phoneLoginLoading) return;
    final phone = phoneController.text.trim();
    final code = phoneCodeController.text.trim();
    if (phone.isEmpty || code.isEmpty) {
      _showAuthError(
        const AuthFailure(
          reason: AuthFailureReason.backendRejected,
          message: 'Enter your phone number and verification code.',
        ),
      );
      return;
    }
    if (!_requireTermsAgreement()) return;
    setState(() => phoneLoginLoading = true);
    final result = await widget.apiClient.loginWithPhoneCode(
      phone: phone,
      code: code,
    );
    if (!mounted) return;
    setState(() => phoneLoginLoading = false);
    if (result.isSuccess && result.data != null) {
      _finishAuth(result.data!);
      return;
    }
    _showAuthError(
      AuthFailure(
        reason: result.status.networkError == null
            ? AuthFailureReason.backendRejected
            : AuthFailureReason.network,
        message: result.status.errorMessage ?? 'Sign in failed.',
      ),
    );
  }

  Future<void> _verifyRecaptcha() async {
    if (recaptchaLoading || recaptchaVerified) return;
    setState(() => recaptchaLoading = true);
    const action = RecaptchaActionKind.signup;
    const config = TurnstileConfig();
    var result = await widget.turnstileChallengePresenter(
      context,
      challengeUri: config.challengeUri(action: action, mode: 'webview'),
      action: action,
    );
    if (_shouldUseExternalTurnstileFallback(result)) {
      final service = widget.recaptchaService ?? CloudflareTurnstileService();
      result = await service.verify(action: action);
    }
    if (!mounted) return;
    setState(() {
      recaptchaLoading = false;
      recaptchaVerified = result.isVerified;
      recaptchaToken = result.token;
    });
    if (!result.isVerified) {
      _showAuthError(
        AuthFailure(
          reason: AuthFailureReason.backendRejected,
          message:
              result.message ?? 'Cloudflare Turnstile verification failed.',
        ),
      );
    }
  }

  bool _shouldUseExternalTurnstileFallback(RecaptchaResult result) {
    if (result.isVerified) return false;
    final message = result.message ?? '';
    return message.contains('WebView unavailable') ||
        message.contains('Unable to load Cloudflare Turnstile WebView') ||
        message.contains('Try the browser verification');
  }

  Future<void> _createAccount() async {
    if (signupLoading) return;
    final username = signupUsernameController.text.trim();
    final email = signupEmailController.text.trim();
    final password = signupPasswordController.text;
    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _showAuthError(
        const AuthFailure(
          reason: AuthFailureReason.backendRejected,
          message: 'Enter username, email, and password.',
        ),
      );
      return;
    }
    if (!SignupPasswordPolicy.evaluate(password).isValid) {
      _showAuthError(
        const AuthFailure(
          reason: AuthFailureReason.backendRejected,
          message: SignupPasswordPolicy.message,
        ),
      );
      return;
    }
    if (!_requireTermsAgreement()) return;
    final token = recaptchaToken;
    if (!recaptchaVerified || token == null) {
      _showAuthError(
        const AuthFailure(
          reason: AuthFailureReason.backendRejected,
          message: 'Complete Turnstile verification first.',
        ),
      );
      return;
    }

    setState(() => signupLoading = true);
    final result = await widget.apiClient.registerWithTurnstile(
      username: username,
      password: password,
      email: email,
      code: token,
      avatarUrl: signupAvatarUrl,
    );
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() => signupLoading = false);
      _finishAuth(result.data!);
      return;
    }
    setState(() {
      signupLoading = false;
      recaptchaVerified = false;
      recaptchaToken = null;
    });
    _showAuthError(
      AuthFailure(
        reason: result.status.networkError == null
            ? AuthFailureReason.backendRejected
            : AuthFailureReason.network,
        message: result.status.errorMessage ?? 'Account creation failed.',
      ),
    );
  }

  Future<void> _sendResetCode() async {
    if (resetCodeSending) return;
    final email = resetEmailController.text.trim();
    if (email.isEmpty) {
      _showAuthError(
        const AuthFailure(
          reason: AuthFailureReason.backendRejected,
          message: 'Enter your account email.',
        ),
      );
      return;
    }

    setState(() => resetCodeSending = true);
    final result = await widget.apiClient.sendResetPasswordEmail(email);
    if (!mounted) return;
    setState(() {
      resetCodeSending = false;
      forgotResetSent = result.isSuccess;
    });
    if (result.isSuccess) return;
    _showAuthError(
      AuthFailure(
        reason: result.status.networkError == null
            ? AuthFailureReason.backendRejected
            : AuthFailureReason.network,
        message:
            result.status.errorMessage ?? 'Unable to send verification code.',
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (resetSubmitting) return;
    final email = resetEmailController.text.trim();
    final code = resetCodeController.text.trim();
    final password = resetPasswordController.text.trim();
    final confirmation = resetPasswordConfirmController.text.trim();
    if (email.isEmpty) {
      _showAuthError(
        const AuthFailure(
          reason: AuthFailureReason.backendRejected,
          message: 'Enter your account email.',
        ),
      );
      return;
    }
    if (code.length != 6) {
      _showAuthError(
        const AuthFailure(
          reason: AuthFailureReason.backendRejected,
          message: 'Verification code cannot be empty.',
        ),
      );
      return;
    }
    if (password.isEmpty) {
      _showAuthError(
        const AuthFailure(
          reason: AuthFailureReason.backendRejected,
          message: 'Password cannot be empty.',
        ),
      );
      return;
    }
    if (password != confirmation) {
      _showAuthError(
        const AuthFailure(
          reason: AuthFailureReason.backendRejected,
          message: 'Password confirmation required',
        ),
      );
      return;
    }

    setState(() => resetSubmitting = true);
    final result = await widget.apiClient.resetPassword(
      email: email,
      password: password,
      code: code,
    );
    if (!mounted) return;
    setState(() => resetSubmitting = false);
    if (result.isSuccess) {
      await credentialStore.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully.')),
      );
      _setMode(AuthMode.login);
      return;
    }
    _showAuthError(
      AuthFailure(
        reason: result.status.networkError == null
            ? AuthFailureReason.backendRejected
            : AuthFailureReason.network,
        message: result.status.errorMessage ?? 'Unable to reset password.',
      ),
    );
  }

  Future<void> _socialSignIn(SocialAuthProvider provider) async {
    if (loadingProvider != null) return;
    if (!_requireTermsAgreement()) return;
    setState(() => loadingProvider = provider);
    final result = await authService.signInWith(provider);
    if (!mounted) return;
    setState(() => loadingProvider = null);

    if (result.isSuccess) {
      final session = result.session;
      if (session == null || session.token.trim().isEmpty) {
        _showAuthError(
          const AuthFailure(
            reason: AuthFailureReason.backendRejected,
            message: 'Sign in did not finish. Please try again.',
          ),
        );
        return;
      }
      _finishAuth(session);
      return;
    }

    final error = result.error;
    if (error == null || error.reason == AuthFailureReason.cancelled) return;
    _showAuthError(error);
  }

  void _showAuthError(AuthFailure error) {
    setState(() => authError = error);
    _scrollAuthErrorIntoView();
  }

  void _scrollAuthErrorIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _authErrorKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: 0.08,
        );
        return;
      }
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  bool _requireTermsAgreement() {
    if (agree) return true;
    _showAuthError(
      const AuthFailure(
        reason: AuthFailureReason.backendRejected,
        message: 'Please agree to the Terms of Use and Privacy Policy.',
      ),
    );
    return false;
  }

  void _showTerms(BuildContext context) {
    final maxHeight = (MediaQuery.sizeOf(context).height * 0.62)
        .clamp(280.0, 560.0)
        .toDouble();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.description_outlined,
        title: 'Terms of Use',
        subtitle: 'Chessnut account and engine services',
        actions: [
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ),
        ],
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: const SingleChildScrollView(
            child: SectionColumn(
              spacing: 12,
              children: [
                _PolicyTextSection(
                  title: 'Account and fair play',
                  body:
                      'Use Chessnut for lawful chess play, training, records, and board services. Keep your account secure, do not abuse the service, and do not use engine assistance or move-quality lights during online games where it is not allowed.',
                ),
                _PolicyTextSection(
                  title: 'Subscriptions, points, and services',
                  body:
                      'Premium membership, wallet points, analysis reports, cloud engines, online play, imports, and board features may depend on network availability, platform billing rules, and third-party services. Some features may change, pause, or become unavailable while we maintain the service.',
                ),
                _PolicyTextSection(
                  title: 'Service changes and availability',
                  body:
                      'Features, prices, rewards, supported boards, engine options, and online services may be updated, suspended, or discontinued as the product evolves, when required by platform rules, or during maintenance. We work to keep Chessnut reliable, but the service is provided as available and may be affected by networks, devices, app stores, or third-party services.',
                ),
                _PolicyTextSection(
                  title: 'Game data and diagnostics',
                  body:
                      'Chessnut may process account details, PGN/FEN game data, board connection status, device diagnostics, logs, and analysis history to provide sync, review, sharing, support, and troubleshooting features. See the Privacy Policy for more detail.',
                ),
                _PolicyTextSection(
                  title: 'Optional tools and third-party links',
                  body:
                      'The app may connect to optional services such as Lichess, Chess.com, Apple App Store, Google Play, Cloudflare Turnstile, email providers, cloud hosting, and open-source chess engines. Those tools are provided by separate organizations and may have their own terms, privacy notices, availability, billing rules, and fair-play requirements.',
                ),
                _PolicyTextSection(
                  title: 'Language and AI-assisted translation',
                  body:
                      'Some app text, policy summaries, support content, and notices may be translated with AI assistance. We work to review important text, but translations may occasionally be incomplete, inaccurate, or less natural than the English source. If a translation is unclear or conflicts with the English version, the English version controls. You can report translation issues at contact@chessnutech.com.',
                ),
                _PolicyTextSection(
                  title: 'Prohibited uses',
                  body:
                      'Do not use Chessnut for illegal activity, harassment, cheating, unauthorized engine assistance in online games, infringement, spam, scraping, attacking the service, bypassing security, reverse engineering beyond what law allows, or uploading malicious or misleading content. We may limit or terminate access if the service is abused or fair-play rules are violated.',
                ),
                _PolicyTextSection(
                  title: 'Maia and Maia 3',
                  body:
                      'Maia is a University of Toronto CSSLab human-like chess AI project. Chessnut may use Maia and Maia 3 for bot moves and human-style analysis. Maia estimates likely human moves and mistakes; it is not intended to be an absolute best-move engine. Maia 3 is published under AGPL-3.0. Official website: https://maiachess.com. Maia 3 source/model information: https://github.com/CSSLab/maia3.',
                ),
                _PolicyTextSection(
                  title: 'Stockfish',
                  body:
                      'Stockfish is a third-party GPL-licensed open-source chess engine used for engine evaluation, analysis reports, score estimates, and training feedback where fair-play rules permit. Official website: https://stockfishchess.org. Source and license information: https://github.com/official-stockfish/Stockfish.',
                ),
                _PolicyTextSection(
                  title: 'Third-party licenses',
                  body:
                      'Maia, Maia 3, Stockfish, Lichess, Chess.com, app stores, and other integrations are separate third-party projects or services with their own terms and licenses. Chessnut provides notices and source links where required, but those third-party terms remain separate from these Chessnut Terms of Use.',
                ),
                _PolicyTextSection(
                  title: 'Disclaimer and limitation of liability',
                  body:
                      'Chess analysis, engine suggestions, puzzle results, ratings, and training feedback are informational and may be incomplete or inaccurate. To the maximum extent permitted by law, Chessnut and its service providers are not responsible for indirect, incidental, special, consequential, or punitive damages, lost data, lost revenue, or losses caused by unavailable networks, third-party services, or unsupported use.',
                ),
                _PolicyTextSection(
                  title: 'Governing law and contact',
                  body:
                      'These app terms are intended to work with the published Chessnut website terms. Where applicable, the website terms state that separate service agreements are governed by the laws of Hong Kong. Questions about these terms, privacy, open-source notices, or app services can be sent to contact@chessnutech.com.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPolicy(BuildContext context) {
    final maxHeight = (MediaQuery.sizeOf(context).height * 0.62)
        .clamp(280.0, 560.0)
        .toDouble();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (dialogContext) => AppDialogShell(
        icon: Icons.privacy_tip_outlined,
        title: 'Privacy Policy',
        subtitle: 'Account, board, and game data',
        actions: [
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it'),
            ),
          ),
        ],
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: const SingleChildScrollView(
            child: SectionColumn(
              spacing: 10,
              children: [
                _PolicyTextSection(
                  title: 'Information we collect',
                  body:
                      'Depending on the features you use, Chessnut may collect account details such as username, email, avatar, login method, membership, wallet points, purchases, and support messages; game data such as PGN, FEN, SAN moves, results, analysis history, puzzle progress, and imported records; board and device data such as Bluetooth connection status, board model, battery, firmware, clock state, app settings, diagnostics, logs, screenshots, or videos you choose to attach to bug reports.',
                ),
                _PolicyTextSection(
                  title: 'How we use information',
                  body:
                      'We use information to create and secure your account, sync game records and settings, connect Chessnut boards, run bot games and online play, import Lichess or Chess.com history at your request, generate analysis and training reports, process membership and wallet features, provide support, troubleshoot bugs, prevent abuse, improve reliability, and send service messages you request or need to receive.',
                ),
                _PolicyTextSection(
                  title: 'Sharing and third-party processors',
                  body:
                      'We share data only as needed to operate the app, comply with law, protect rights, or deliver features you choose. Processors may include hosting, storage, email, analytics, diagnostics, payment platforms such as Apple and Google, Cloudflare verification, Lichess or Chess.com when you connect or import data, and Maia or Stockfish services for requested chess analysis. We do not sell your personal information from the app.',
                ),
                _PolicyTextSection(
                  title: 'Retention and deletion',
                  body:
                      'We keep account, purchase, wallet, game record, analysis, and diagnostic information while your account is active or as needed for the feature, support, security, legal, tax, or backup purposes. You may delete records or request account deletion where available. Some backup, fraud-prevention, legal, or transaction records may be kept for a limited period when required.',
                ),
                _PolicyTextSection(
                  title: 'Your privacy rights',
                  body:
                      'Depending on where you live, you may have rights to access, correct, export, restrict, object to, or delete personal information. You may also withdraw consent for optional features where consent is the basis for processing. Use the contact address below to exercise privacy rights, ask questions, or make a complaint.',
                ),
                _PolicyTextSection(
                  title: 'Cookies, analytics, and diagnostics',
                  body:
                      'Our website may use cookies, local storage, analytics, advertising, and similar technologies as described in the website privacy policy. The app may use local storage, crash diagnostics, performance logs, and security telemetry to keep you signed in, remember preferences, investigate problems, and improve the service.',
                ),
                _PolicyTextSection(
                  title: 'Children and security',
                  body:
                      'Chessnut is designed for general chess users and is not directed at children below the age required by local law to create an online account without guardian consent. We use reasonable technical and organizational measures to protect information, but no networked service can be guaranteed completely secure.',
                ),
                _PolicyTextSection(
                  title: 'Policy changes and contact',
                  body:
                      'We may update this policy when our app, website, data practices, partners, or legal requirements change. The latest website privacy policy is available at https://www.chessnutech.com/pages/privacy-policy. For privacy questions or complaints, email contact@chessnutech.com.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicyTextSection extends StatelessWidget {
  const _PolicyTextSection({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SectionColumn(
      spacing: 4,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        Text(
          body,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.38,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _SecurePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      borderRadius: 999,
      child: Text(
        'Secure',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _CompactAuthHeader extends StatelessWidget {
  const _CompactAuthHeader({required this.trailing});

  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const LogoButton(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACCOUNT',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                'Welcome',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

class _AuthErrorCard extends StatelessWidget {
  const _AuthErrorCard({
    required this.error,
    required this.mode,
    required this.onDismiss,
    super.key,
  });

  final AuthFailure error;
  final AuthMode mode;
  final VoidCallback onDismiss;

  String get title {
    if (mode == AuthMode.signup &&
        (error.reason == AuthFailureReason.backendRejected ||
            error.reason == AuthFailureReason.unknown)) {
      return 'Create account needs attention';
    }
    return switch (error.reason) {
      AuthFailureReason.needsConfiguration => 'Sign-in setup needed',
      AuthFailureReason.providerUnavailable => 'Sign-in method unavailable',
      AuthFailureReason.network => 'Connection issue',
      AuthFailureReason.cancelled => 'Sign-in cancelled',
      AuthFailureReason.backendRejected ||
      AuthFailureReason.unknown =>
        'Sign-in needs attention',
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = ChessnutTheme.tokensOf(context);
    final color = tokens.danger;
    return Semantics(
      liveRegion: true,
      label: '$title. ${error.message}',
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        borderRadius: 14,
        tint: Color.alphaBlend(
          color.withValues(alpha: 0.10),
          Theme.of(context).brightness == Brightness.dark
              ? const Color(0xE6111C2F)
              : scheme.surface,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.error_outline_rounded, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    error.message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Dismiss error',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.heading, required this.copy});

  final String heading;
  final String copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compactLandscape = isCompactLandscapeDevice(context);
    return GlassPanel(
      padding: EdgeInsets.all(compactLandscape ? 9 : 12),
      borderRadius: 14,
      tint: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xD9121D31)
          : const Color(0xF7FFFFFF),
      child: Row(
        children: [
          const LogoButton(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    heading,
                    key: ValueKey(heading),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  copy,
                  maxLines: compactLandscape ? 2 : null,
                  overflow: compactLandscape ? TextOverflow.ellipsis : null,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.36),
                  blurRadius: 14,
                  spreadRadius: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialGrid extends StatelessWidget {
  const _SocialGrid({
    required this.onApple,
    required this.onGoogle,
    required this.loadingProvider,
  });

  final VoidCallback onApple;
  final VoidCallback onGoogle;
  final SocialAuthProvider? loadingProvider;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      _SocialButton(
        label: 'Apple',
        loading: loadingProvider == SocialAuthProvider.apple,
        enabled: loadingProvider == null,
        icon: const Icon(Icons.apple_rounded),
        onPressed: onApple,
      ),
      _SocialButton(
        label: 'Google',
        loading: loadingProvider == SocialAuthProvider.google,
        enabled: loadingProvider == null,
        icon: const _GoogleMark(),
        onPressed: onGoogle,
      ),
    ];

    return GlassPanel(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isCompactLandscapeDevice(context) ? 8 : 10,
      ),
      borderRadius: 16,
      child: Column(
        children: [
          if (!isCompactLandscapeDevice(context)) ...[
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'or continue with',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color
                              ?.withValues(alpha: 0.62),
                        ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                buttons[i],
                if (i != buttons.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.loading,
    required this.enabled,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final bool enabled;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Continue with $label',
      child: Semantics(
        button: true,
        label: 'Continue with $label',
        child: SizedBox.square(
          dimension: 48,
          child: OutlinedButton(
            onPressed: enabled ? onPressed : null,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: loading ? const _SocialProgress() : icon,
          ),
        ),
      ),
    );
  }
}

class _SocialProgress extends StatelessWidget {
  const _SocialProgress();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [
            Color(0xFF4285F4),
            Color(0xFF34A853),
            Color(0xFFFBBC05),
            Color(0xFFEA4335),
            Color(0xFF4285F4),
          ],
        ),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AuthTabs extends StatelessWidget {
  const _AuthTabs({required this.mode, required this.onChanged});

  final AuthMode mode;
  final ValueChanged<AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(5),
      borderRadius: 12,
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Sign in',
              selected: mode == AuthMode.login,
              onTap: () => onChanged(AuthMode.login),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _TabButton(
              label: 'Create',
              selected: mode == AuthMode.signup,
              onTap: () => onChanged(AuthMode.signup),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primary.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? scheme.primary.withValues(alpha: 0.34)
              : Colors.transparent,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 36,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? scheme.primary : null,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.accountController,
    required this.passwordController,
    required this.accountFocusNode,
    required this.passwordFocusNode,
    required this.passwordVisible,
    required this.onPasswordVisibilityChanged,
    required this.remember,
    required this.agree,
    required this.onRemember,
    required this.onAgree,
    required this.onForgot,
    required this.onTerms,
    required this.onPolicy,
    required this.onSubmit,
    this.onUsePhone,
    required this.loading,
  });

  final TextEditingController accountController;
  final TextEditingController passwordController;
  final FocusNode accountFocusNode;
  final FocusNode passwordFocusNode;
  final bool passwordVisible;
  final ValueChanged<bool> onPasswordVisibilityChanged;
  final bool remember;
  final bool agree;
  final ValueChanged<bool> onRemember;
  final ValueChanged<bool> onAgree;
  final VoidCallback onForgot;
  final VoidCallback onTerms;
  final VoidCallback onPolicy;
  final VoidCallback onSubmit;
  final VoidCallback? onUsePhone;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final compactLandscape = isCompactLandscapeDevice(context);
    return GlassPanel(
      padding: EdgeInsets.all(compactLandscape ? 9 : 12),
      child: SectionColumn(
        spacing: compactLandscape ? 6 : 9,
        children: [
          _AuthField(
            key: const ValueKey('login-account-field'),
            controller: accountController,
            focusNode: accountFocusNode,
            icon: Icons.email_outlined,
            label: 'Email or account',
            helperText:
                compactLandscape ? null : 'Enter your email or Chessnut ID.',
            textInputAction: TextInputAction.next,
          ),
          _AuthField(
            controller: passwordController,
            focusNode: passwordFocusNode,
            icon: Icons.lock_outline_rounded,
            label: 'Password',
            helperText: compactLandscape
                ? null
                : 'Use the password for your Chessnut account.',
            obscure: !passwordVisible,
            suffix: _PasswordVisibilityButton(
              visible: passwordVisible,
              onChanged: onPasswordVisibilityChanged,
            ),
            textInputAction: TextInputAction.done,
          ),
          _AuthRow(
            left: _AuthCheck(
              key: const ValueKey('remember-password-checkbox'),
              value: remember,
              label: 'Remember password',
              onChanged: onRemember,
            ),
            right:
                TextButton(onPressed: onForgot, child: const Text('Forgot?')),
          ),
          _PolicyRow(
            agree: agree,
            onAgree: onAgree,
            onTerms: onTerms,
            onPolicy: onPolicy,
          ),
          PrimaryButton(
            label: loading ? 'Signing in' : 'Sign in',
            icon: Icons.login_rounded,
            onPressed: loading ? null : onSubmit,
          ),
          if (onUsePhone != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onUsePhone,
                icon: const Icon(Icons.sms_outlined),
                label: const Text('Use phone verification code'),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhoneLoginForm extends StatelessWidget {
  const _PhoneLoginForm({
    required this.phoneController,
    required this.codeController,
    required this.phoneFocusNode,
    required this.codeFocusNode,
    required this.codeSent,
    required this.sendingCode,
    required this.cooldownSeconds,
    required this.loading,
    required this.agree,
    required this.onAgree,
    required this.onTerms,
    required this.onPolicy,
    required this.onSendCode,
    required this.onSubmit,
    required this.onUseEmail,
  });

  final TextEditingController phoneController;
  final TextEditingController codeController;
  final FocusNode phoneFocusNode;
  final FocusNode codeFocusNode;
  final bool codeSent;
  final bool sendingCode;
  final int cooldownSeconds;
  final bool loading;
  final bool agree;
  final ValueChanged<bool> onAgree;
  final VoidCallback onTerms;
  final VoidCallback onPolicy;
  final VoidCallback onSendCode;
  final VoidCallback onSubmit;
  final VoidCallback onUseEmail;

  @override
  Widget build(BuildContext context) {
    final compactLandscape = isCompactLandscapeDevice(context);
    return GlassPanel(
      padding: EdgeInsets.all(compactLandscape ? 9 : 12),
      child: SectionColumn(
        spacing: compactLandscape ? 6 : 9,
        children: [
          _AuthField(
            controller: phoneController,
            focusNode: phoneFocusNode,
            icon: Icons.phone_iphone_rounded,
            label: 'Phone number',
            helperText: compactLandscape
                ? null
                : 'Mainland China phone number, for example 13812345678.',
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            textInputAction: TextInputAction.next,
          ),
          _AuthField(
            controller: codeController,
            focusNode: codeFocusNode,
            icon: Icons.verified_outlined,
            label: 'SMS code',
            helperText: codeSent
                ? 'Code sent. It expires in 5 minutes.'
                : 'Send a code to sign in or create an account.',
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            textInputAction: TextInputAction.done,
            suffix: SizedBox(
              width: 108,
              child: TextButton(
                onPressed:
                    sendingCode || cooldownSeconds > 0 ? null : onSendCode,
                child: Text(
                  sendingCode
                      ? 'Sending'
                      : cooldownSeconds > 0
                          ? '${cooldownSeconds}s'
                          : 'Send code',
                ),
              ),
            ),
          ),
          _PolicyRow(
            agree: agree,
            onAgree: onAgree,
            onTerms: onTerms,
            onPolicy: onPolicy,
          ),
          PrimaryButton(
            label: loading ? 'Signing in' : 'Sign in / register',
            icon: Icons.login_rounded,
            onPressed: loading ? null : onSubmit,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onUseEmail,
              icon: const Icon(Icons.email_outlined),
              label: const Text('Use email and password'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignupForm extends StatefulWidget {
  const _SignupForm({
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.usernameFocusNode,
    required this.emailFocusNode,
    required this.passwordFocusNode,
    required this.passwordPolicy,
    required this.passwordVisible,
    required this.onPasswordVisibilityChanged,
    required this.agree,
    required this.recaptchaVerified,
    required this.recaptchaLoading,
    required this.selectedAvatarUrl,
    required this.onAvatarChanged,
    required this.onAgree,
    required this.onTerms,
    required this.onPolicy,
    required this.onVerifyRecaptcha,
    required this.loading,
    required this.onSubmit,
  });

  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode usernameFocusNode;
  final FocusNode emailFocusNode;
  final FocusNode passwordFocusNode;
  final SignupPasswordPolicyResult passwordPolicy;
  final bool passwordVisible;
  final ValueChanged<bool> onPasswordVisibilityChanged;
  final bool agree;
  final bool recaptchaVerified;
  final bool recaptchaLoading;
  final String selectedAvatarUrl;
  final ValueChanged<String> onAvatarChanged;
  final ValueChanged<bool> onAgree;
  final VoidCallback onTerms;
  final VoidCallback onPolicy;
  final VoidCallback onVerifyRecaptcha;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  State<_SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<_SignupForm> {
  bool _passwordTouched = false;

  @override
  void initState() {
    super.initState();
    widget.passwordFocusNode.addListener(_handlePasswordFocusChanged);
  }

  @override
  void dispose() {
    widget.passwordFocusNode.removeListener(_handlePasswordFocusChanged);
    super.dispose();
  }

  void _handlePasswordFocusChanged() {
    if (!widget.passwordFocusNode.hasFocus &&
        widget.passwordController.text.isNotEmpty) {
      _passwordTouched = true;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final showPasswordPolicy = widget.passwordFocusNode.hasFocus ||
        (_passwordTouched &&
            widget.passwordController.text.isNotEmpty &&
            !widget.passwordPolicy.isValid);
    final showPasswordStatus =
        _passwordTouched && widget.passwordController.text.isNotEmpty;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: SectionColumn(
        spacing: 9,
        children: [
          _AuthField(
            key: const ValueKey('signup-username-field'),
            controller: widget.usernameController,
            focusNode: widget.usernameFocusNode,
            icon: Icons.person_outline_rounded,
            label: 'Username',
            helperText: 'Choose the name shown in records and online play.',
            textInputAction: TextInputAction.next,
          ),
          _AuthField(
            key: const ValueKey('signup-email-field'),
            controller: widget.emailController,
            focusNode: widget.emailFocusNode,
            icon: Icons.email_outlined,
            label: 'Email',
            helperText: 'Used for sign in, receipts, and password recovery.',
            textInputAction: TextInputAction.next,
          ),
          _AuthField(
            key: const ValueKey('signup-password-field'),
            controller: widget.passwordController,
            focusNode: widget.passwordFocusNode,
            icon: Icons.lock_outline_rounded,
            label: 'Password',
            helperText: null,
            obscure: !widget.passwordVisible,
            suffix: _SignupPasswordSuffix(
              showStatus: showPasswordStatus,
              valid: widget.passwordPolicy.isValid,
              visible: widget.passwordVisible,
              onVisibilityChanged: widget.onPasswordVisibilityChanged,
            ),
            textInputAction: TextInputAction.next,
          ),
          if (showPasswordPolicy)
            _PasswordPolicyHint(
              key: const ValueKey('signup-password-policy-hint'),
              result: widget.passwordPolicy,
              highlightMissing: _passwordTouched &&
                  widget.passwordController.text.isNotEmpty &&
                  !widget.passwordPolicy.isValid,
            ),
          _SignupAvatarPicker(
            selectedAvatarUrl: widget.selectedAvatarUrl,
            onChanged: widget.onAvatarChanged,
          ),
          _RecaptchaCard(
            verified: widget.recaptchaVerified,
            loading: widget.recaptchaLoading,
            onVerify: widget.onVerifyRecaptcha,
          ),
          _PolicyRow(
            agree: widget.agree,
            onAgree: widget.onAgree,
            onTerms: widget.onTerms,
            onPolicy: widget.onPolicy,
          ),
          PrimaryButton(
            label: widget.loading ? 'Creating account' : 'Create account',
            icon: Icons.person_add_alt_rounded,
            onPressed: widget.loading ? null : widget.onSubmit,
          ),
        ],
      ),
    );
  }
}

class _SignupAvatarPicker extends StatelessWidget {
  const _SignupAvatarPicker({
    required this.selectedAvatarUrl,
    required this.onChanged,
  });

  final String selectedAvatarUrl;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chessnutProfileAvatars.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final avatar = chessnutProfileAvatars[index];
          final selected = avatar == selectedAvatarUrl;
          final name = avatar.split('/').last.replaceAll('.png', '');
          return InkWell(
            key: ValueKey('signup-avatar-$name'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => onChanged(avatar),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 58,
              height: 58,
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(avatar, fit: BoxFit.cover),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PasswordPolicyHint extends StatelessWidget {
  const _PasswordPolicyHint({
    required this.result,
    this.highlightMissing = false,
    super.key,
  });

  final SignupPasswordPolicyResult result;
  final bool highlightMissing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final characterTypesMet = result.characterTypeCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: result.isValid
            ? scheme.primary.withValues(alpha: 0.09)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.isValid
              ? scheme.primary.withValues(alpha: 0.35)
              : highlightMissing
                  ? scheme.error.withValues(alpha: 0.42)
                  : scheme.outlineVariant.withValues(alpha: 0.62),
        ),
      ),
      child: SectionColumn(
        spacing: 8,
        children: [
          Row(
            children: [
              Icon(
                result.isValid
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                size: 17,
                color:
                    result.isValid ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Use at least 8 characters and any 2 character types.',
                  maxLines: 3,
                  overflow: TextOverflow.visible,
                  style: textTheme.bodySmall?.copyWith(
                    color: result.isValid
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              _PasswordRuleChip(
                label: '8+ characters',
                met: result.isLongEnough,
                requiredRule: true,
                highlight: highlightMissing && !result.isLongEnough,
              ),
              const SizedBox(width: 7),
              _CharacterTypeCounter(
                count: characterTypesMet,
                valid: result.hasEnoughCharacterTypes,
                highlight: highlightMissing && !result.hasEnoughCharacterTypes,
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PasswordRuleChip(
                label: 'Uppercase',
                met: result.hasUppercase,
                highlight: highlightMissing &&
                    !result.hasEnoughCharacterTypes &&
                    !result.hasUppercase,
              ),
              _PasswordRuleChip(
                label: 'Lowercase',
                met: result.hasLowercase,
                highlight: highlightMissing &&
                    !result.hasEnoughCharacterTypes &&
                    !result.hasLowercase,
              ),
              _PasswordRuleChip(
                label: 'Number',
                met: result.hasDigit,
                highlight: highlightMissing &&
                    !result.hasEnoughCharacterTypes &&
                    !result.hasDigit,
              ),
              _PasswordRuleChip(
                label: 'Symbol',
                met: result.hasSymbol,
                highlight: highlightMissing &&
                    !result.hasEnoughCharacterTypes &&
                    !result.hasSymbol,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PasswordRuleChip extends StatelessWidget {
  const _PasswordRuleChip({
    required this.label,
    required this.met,
    this.highlight = false,
    this.requiredRule = false,
  });

  final String label;
  final bool met;
  final bool highlight;
  final bool requiredRule;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = met
        ? scheme.primary
        : highlight
            ? scheme.error
            : scheme.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: met
              ? scheme.primary.withValues(alpha: 0.12)
              : highlight
                  ? scheme.error.withValues(alpha: 0.10)
                  : scheme.surface.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: met
                ? scheme.primary.withValues(alpha: 0.4)
                : highlight
                    ? scheme.error.withValues(alpha: 0.50)
                    : scheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              met
                  ? Icons.check_circle_rounded
                  : highlight
                      ? Icons.cancel_rounded
                      : requiredRule
                          ? Icons.radio_button_unchecked_rounded
                          : Icons.circle_outlined,
              size: 14,
              color: foreground,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.visible,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterTypeCounter extends StatelessWidget {
  const _CharacterTypeCounter({
    required this.count,
    required this.valid,
    required this.highlight,
  });

  final int count;
  final bool valid;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = valid
        ? scheme.primary
        : highlight
            ? scheme.error
            : scheme.onSurfaceVariant;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: valid
              ? scheme.primary.withValues(alpha: 0.10)
              : highlight
                  ? scheme.error.withValues(alpha: 0.09)
                  : scheme.surface.withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: valid
                ? scheme.primary.withValues(alpha: 0.36)
                : highlight
                    ? scheme.error.withValues(alpha: 0.48)
                    : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              valid
                  ? Icons.check_circle_rounded
                  : highlight
                      ? Icons.cancel_rounded
                      : Icons.category_outlined,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Choose any 2',
                maxLines: 2,
                overflow: TextOverflow.visible,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            Text(
              '${count.clamp(0, 4)}/2',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignupPasswordSuffix extends StatelessWidget {
  const _SignupPasswordSuffix({
    required this.showStatus,
    required this.valid,
    required this.visible,
    required this.onVisibilityChanged,
  });

  final bool showStatus;
  final bool valid;
  final bool visible;
  final ValueChanged<bool> onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: showStatus ? 92 : 48,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (showStatus) ...[
            _PasswordStatusIcon(valid: valid),
            const SizedBox(width: 2),
          ],
          _PasswordVisibilityButton(
            visible: visible,
            onChanged: onVisibilityChanged,
          ),
        ],
      ),
    );
  }
}

class _PasswordStatusIcon extends StatelessWidget {
  const _PasswordStatusIcon({required this.valid});

  final bool valid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: valid ? 'Password meets the rules' : 'Password needs attention',
      child: Icon(
        valid ? Icons.check_circle_rounded : Icons.cancel_rounded,
        key: ValueKey(
          valid
              ? 'signup-password-status-valid'
              : 'signup-password-status-invalid',
        ),
        color: valid ? scheme.primary : scheme.error,
        size: 20,
      ),
    );
  }
}

class _ForgotForm extends StatelessWidget {
  const _ForgotForm({
    required this.resetEmailController,
    required this.resetEmailFocusNode,
    required this.resetCodeController,
    required this.resetCodeFocusNode,
    required this.resetPasswordController,
    required this.resetPasswordFocusNode,
    required this.resetPasswordConfirmController,
    required this.resetPasswordConfirmFocusNode,
    required this.onBack,
    required this.resetSent,
    required this.sendingCode,
    required this.submitting,
    required this.onSendCode,
    required this.onSubmit,
  });

  final TextEditingController resetEmailController;
  final FocusNode resetEmailFocusNode;
  final TextEditingController resetCodeController;
  final FocusNode resetCodeFocusNode;
  final TextEditingController resetPasswordController;
  final FocusNode resetPasswordFocusNode;
  final TextEditingController resetPasswordConfirmController;
  final FocusNode resetPasswordConfirmFocusNode;
  final VoidCallback onBack;
  final bool resetSent;
  final bool sendingCode;
  final bool submitting;
  final VoidCallback onSendCode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      child: SectionColumn(
        spacing: 9,
        children: [
          _AuthField(
            controller: resetEmailController,
            focusNode: resetEmailFocusNode,
            icon: Icons.email_outlined,
            label: 'Email',
            helperText: 'Enter the email linked to your account.',
            textInputAction: TextInputAction.next,
            onEditingComplete: resetCodeFocusNode.requestFocus,
          ),
          _AuthField(
            controller: resetCodeController,
            focusNode: resetCodeFocusNode,
            icon: Icons.verified_outlined,
            label: 'Verification code',
            helperText: resetSent
                ? 'Code sent. It expires in 5 minutes.'
                : 'Get a verification code by email first.',
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            textInputAction: TextInputAction.next,
            onEditingComplete: resetPasswordFocusNode.requestFocus,
            suffix: SizedBox(
              width: 132,
              child: TextButton(
                onPressed: sendingCode ? null : onSendCode,
                child: Text(sendingCode ? 'Sending' : 'Get code'),
              ),
            ),
          ),
          _AuthField(
            controller: resetPasswordController,
            focusNode: resetPasswordFocusNode,
            icon: Icons.lock_outline_rounded,
            label: 'Password',
            helperText: 'Choose a new password for your Chessnut account.',
            obscure: true,
            textInputAction: TextInputAction.next,
            onEditingComplete: resetPasswordConfirmFocusNode.requestFocus,
          ),
          _AuthField(
            controller: resetPasswordConfirmController,
            focusNode: resetPasswordConfirmFocusNode,
            icon: Icons.lock_reset_outlined,
            label: 'Repeat password',
            helperText: 'Enter the same password again.',
            obscure: true,
            textInputAction: TextInputAction.done,
          ),
          PrimaryButton(
            label: submitting ? 'Resetting password' : 'Reset password',
            icon: Icons.lock_reset_rounded,
            onPressed: submitting ? null : onSubmit,
          ),
          _AuthRow(
            left: TextButton(
              onPressed: onBack,
              child: const Text('Back to sign in'),
            ),
            right: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _RecaptchaCard extends StatelessWidget {
  const _RecaptchaCard({
    required this.verified,
    required this.loading,
    required this.onVerify,
  });

  final bool verified;
  final bool loading;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(12),
      borderRadius: 14,
      tint: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xB7131C2D)
          : const Color(0xFFFFFFFF),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 380;
          final icon = Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (verified ? scheme.secondary : scheme.primary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              loading
                  ? Icons.sync_rounded
                  : verified
                      ? Icons.verified_user_rounded
                      : Icons.shield_outlined,
              color: verified ? scheme.secondary : scheme.primary,
            ),
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Turnstile verification',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                verified
                    ? 'Human verified'
                    : loading
                        ? 'Connecting to Cloudflare Turnstile...'
                        : 'Complete this check to confirm this signup is not automated.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
          final button = OutlinedButton.icon(
            onPressed: verified || loading ? null : onVerify,
            icon: loading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    verified
                        ? Icons.check_circle_outline_rounded
                        : Icons.touch_app_rounded,
                  ),
            label: Text(
              loading
                  ? 'Verifying'
                  : verified
                      ? 'Human verified'
                      : 'Verify I am not a robot',
            ),
          );

          if (compact) {
            return SectionColumn(
              spacing: 10,
              children: [
                Row(
                  children: [
                    icon,
                    const SizedBox(width: 12),
                    Expanded(child: copy),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: button,
                ),
              ],
            );
          }

          return Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(child: copy),
              const SizedBox(width: 10),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    super.key,
    required this.icon,
    required this.label,
    this.controller,
    this.focusNode,
    this.helperText,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onEditingComplete,
  });

  final IconData icon;
  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? helperText;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;

  @override
  Widget build(BuildContext context) {
    final compactLandscape = isCompactLandscapeDevice(context);
    final inputStyle = Theme.of(context).textTheme.bodyMedium;
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onEditingComplete: onEditingComplete,
      style: compactLandscape ? inputStyle?.copyWith(fontSize: 15) : null,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        hintText: label,
        helperText: helperText,
        isDense: compactLandscape,
        contentPadding: compactLandscape
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 11)
            : null,
        suffixIcon: suffix,
      ),
    );
  }
}

class _PasswordVisibilityButton extends StatelessWidget {
  const _PasswordVisibilityButton({
    required this.visible,
    required this.onChanged,
  });

  final bool visible;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: visible ? 'Hide password' : 'Show password',
      onPressed: () => onChanged(!visible),
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
    );
  }
}

class _AuthRow extends StatelessWidget {
  const _AuthRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Flexible(child: Align(alignment: Alignment.centerRight, child: right)),
      ],
    );
  }
}

class _AuthCheck extends StatelessWidget {
  const _AuthCheck({
    required this.value,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: value,
            visualDensity: VisualDensity.compact,
            onChanged: (next) => onChanged(next ?? false),
          ),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.agree,
    required this.onAgree,
    required this.onTerms,
    required this.onPolicy,
  });

  final bool agree;
  final ValueChanged<bool> onAgree;
  final VoidCallback onTerms;
  final VoidCallback onPolicy;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w800,
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          key: const ValueKey('auth-terms-checkbox'),
          value: agree,
          visualDensity: VisualDensity.compact,
          onChanged: (next) => onAgree(next ?? false),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: [
                Text('I agree to', style: textStyle),
                _InlinePolicyButton(
                  label: 'Terms of Use',
                  onPressed: onTerms,
                ),
                Text('and', style: textStyle),
                _InlinePolicyButton(
                  label: 'Privacy Policy',
                  onPressed: onPolicy,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InlinePolicyButton extends StatelessWidget {
  const _InlinePolicyButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.underline,
              decorationColor: scheme.primary.withValues(alpha: 0.65),
            ),
      ),
    );
  }
}

class _AuthBenefitCard extends StatelessWidget {
  const _AuthBenefitCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your board profile travels with you.',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _BenefitLine(
            icon: Icons.history_rounded,
            label: 'Game records and PGNs',
            color: scheme.secondary,
          ),
          _BenefitLine(
            icon: Icons.auto_awesome_rounded,
            label: 'Grandeur credits and analysis history',
            color: scheme.primary,
          ),
          const _BenefitLine(
            icon: Icons.grid_4x4_rounded,
            label: 'Board pairing and LED preferences',
            color: Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }
}

class _BenefitLine extends StatelessWidget {
  const _BenefitLine({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
