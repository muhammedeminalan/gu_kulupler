/// İzinli e-posta alan adları — `ALLOWED_EMAIL_DOMAINS`'in **tek** kaynağı
/// (D-27, CD-76).
///
/// `AppConstants.allowedEmailDomains` bu listeye delege eder; Security Rules
/// `emailOk()` regex'i [rulesRegex] ile parite testine tabidir
/// (`tool/check_rules_parity.js` RP03). Biçim denetimi (tek `@`, yerel kısım
/// uzunluğu) burada **yapılmaz**: `EmailDomainValidator.isWellFormed`.
abstract final class EmailDomainPolicy {
  /// İzinli alan adları (küçük harf, tam eşleşme; alt alan adı izinli değil).
  static const List<String> allowedDomains = [
    'ogr.gumushane.edu.tr',
    'gumushane.edu.tr',
  ];

  /// [email] adresinin alan adı [allowedDomains] içinde mi?
  ///
  /// Son `@` işaretinden sonraki kısım ASCII küçük harfe çevrilip listeyle
  /// **tam** karşılaştırılır: alt alan adı (`x.gumushane.edu.tr`) ve benzer
  /// alan adı (`evilgumushane.edu.tr`, `gumushane.edu.tr.evil.com`) reddedilir.
  /// Girdi kırpılmaz (baştaki/sondaki boşluğu çağıran temizler); `@` yoksa
  /// sonuç `false`'tur. Yalnızca A–Z küçültülür; ASCII dışı harfler (Türkçe
  /// `İ`/`ı`, benzer görünümlü Unicode harfleri) hiçbir zaman eşleşmez.
  static bool isAllowed(String email) {
    final at = email.lastIndexOf('@');
    if (at < 0) return false;
    return allowedDomains.contains(_asciiLower(email.substring(at + 1)));
  }

  /// Security Rules `emailOk()` içindeki `matches(...)` deseninin değeri:
  /// `.*@(ogr\.gumushane\.edu\.tr|gumushane\.edu\.tr)`.
  ///
  /// [allowedDomains] listesinden üretilir (ikinci kopya yok). Rules kaynak
  /// metninde dizgi literal'i olduğu için ters bölüler çiftlenir (`\\.`);
  /// Rules `matches` tüm dizgiyi eşler.
  static String rulesRegex() =>
      '.*@(${allowedDomains.map(RegExp.escape).join('|')})';

  /// Yalnızca `A`–`Z` aralığını küçültür (yerel ayardan ve Unicode harf
  /// katlamasından bağımsız).
  static String _asciiLower(String value) => String.fromCharCodes(
    value.codeUnits.map(
      (unit) => unit >= _upperA && unit <= _upperZ ? unit + _caseOffset : unit,
    ),
  );

  static const int _upperA = 0x41;
  static const int _upperZ = 0x5A;
  static const int _caseOffset = 0x20;
}
