class SignupPasswordPolicyResult {
  const SignupPasswordPolicyResult({
    required this.isLongEnough,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSymbol,
  });

  final bool isLongEnough;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSymbol;

  int get characterTypeCount => [
        hasUppercase,
        hasLowercase,
        hasDigit,
        hasSymbol,
      ].where((value) => value).length;

  bool get hasEnoughCharacterTypes => characterTypeCount >= 2;

  bool get isValid => isLongEnough && hasEnoughCharacterTypes;
}

class SignupPasswordPolicy {
  const SignupPasswordPolicy._();

  static const message =
      'Use 8+ characters and at least two types: uppercase, lowercase, number, or symbol.';

  static SignupPasswordPolicyResult evaluate(String password) {
    final normalized = password.trim();
    return SignupPasswordPolicyResult(
      isLongEnough: normalized.length >= 8,
      hasUppercase: RegExp(r'[A-Z]').hasMatch(normalized),
      hasLowercase: RegExp(r'[a-z]').hasMatch(normalized),
      hasDigit: RegExp(r'[0-9]').hasMatch(normalized),
      hasSymbol: RegExp(r'[^A-Za-z0-9]').hasMatch(normalized),
    );
  }
}
