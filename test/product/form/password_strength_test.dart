// `PasswordStrength` — AUT-02 / SHT-32 ortak şifre gücü (4 ölçüt:
// uzunluk, büyük harf (Türkçe dahil), rakam, harf / rakam dışı karakter).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/product/form/password_strength.dart';

void main() {
  group('PasswordStrength', () {
    test('karşılanan ölçüt sayısı, 0 – max', () {
      expect(PasswordStrength.max, 4);
      expect(PasswordStrength.of(''), 0);
      expect(PasswordStrength.of('abc'), 0);
      expect(PasswordStrength.of('abcdefgh'), 1);
      expect(PasswordStrength.of('Abcdefgh'), 2);
      expect(PasswordStrength.of('Abcdefg1'), 3);
      expect(PasswordStrength.of('Abcdef1!'), 4);
    });

    test(
      'Türkçe büyük harf ve sembol sayılır; harf / rakam sembol değildir',
      () {
        expect(PasswordStrength.hasUppercase('şifreİ'), isTrue);
        expect(PasswordStrength.hasUppercase('şifreı'), isFalse);
        expect(PasswordStrength.hasSymbol('ğüşöç123'), isFalse);
        expect(PasswordStrength.hasSymbol('abc def'), isTrue);
        expect(PasswordStrength.hasMinLength('çok-uzun'), isTrue);
      },
    );
  });
}
