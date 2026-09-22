import 'package:flutter_test/flutter_test.dart';

import 'package:chessnut_flutter_export/services/password_policy.dart';

void main() {
  test(
      'signup password policy requires length and at least two character types',
      () {
    expect(SignupPasswordPolicy.evaluate('Abcdef12').isValid, isTrue);
    expect(SignupPasswordPolicy.evaluate('abcdefgh1').isValid, isTrue);
    expect(SignupPasswordPolicy.evaluate('ABCDEFGH1').isValid, isTrue);
    expect(SignupPasswordPolicy.evaluate('!!!!!!!!a').isValid, isTrue);

    expect(SignupPasswordPolicy.evaluate('Abc123!').isValid, isFalse);
    expect(SignupPasswordPolicy.evaluate('abcdefgh').isValid, isFalse);
    expect(SignupPasswordPolicy.evaluate('12345678').isValid, isFalse);
  });
}
