// T-11 · AuthStatus: altı değer, architecture §6 sırasıyla (PLAN §12.2).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';

void main() {
  test('T-11 · AuthStatus altı değerdir; `deleted` ayrı değer değildir', () {
    expect(AuthStatus.values.map((status) => status.name), [
      'unknown',
      'signedOut',
      'unverified',
      'profileIncomplete',
      'active',
      'suspended',
    ]);
  });
}
