import 'package:gu_data/gu_data.dart';

/// Şifre gücü — karşılanan ölçüt sayısı, 0 – [max]: uzunluk
/// (`Limits.passwordMinLength`), büyük harf (Türkçe harfler dahil), rakam ve
/// harf / rakam dışı karakter (prototip `screens-auth.js:82` AUT-02 ve
/// `sheets.js:150` SHT-32 aynı dört ölçütü sayar).
///
/// Güç yalnızca göstergedir (`PasswordStrengthBar`); geçerlilik kuralı
/// `Limits.passwordPattern`'dir (`FormValidationMixin.passwordError`).
abstract final class PasswordStrength {
  /// Güç üst sınırı (göstergedeki dilim sayısı).
  static const int max = 4;

  static final RegExp _uppercase = RegExp(r'\p{Lu}', unicode: true);
  static final RegExp _digit = RegExp(r'\d');
  static final RegExp _symbol = RegExp(r'[^\p{L}\p{N}]', unicode: true);

  /// Ölçüt: en az `Limits.passwordMinLength` karakter.
  static bool hasMinLength(String password) =>
      password.runes.length >= Limits.passwordMinLength;

  /// Ölçüt: en az bir büyük harf.
  static bool hasUppercase(String password) => _uppercase.hasMatch(password);

  /// Ölçüt: en az bir rakam.
  static bool hasDigit(String password) => _digit.hasMatch(password);

  /// Ölçüt: en az bir harf / rakam dışı karakter.
  static bool hasSymbol(String password) => _symbol.hasMatch(password);

  /// [password] şifresinin gücü, 0 – [max].
  static int of(String password) => [
    hasMinLength(password),
    hasUppercase(password),
    hasDigit(password),
    hasSymbol(password),
  ].where((met) => met).length;
}
