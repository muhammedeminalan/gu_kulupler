/// İzinli e-posta alan adları — `ALLOWED_EMAIL_DOMAINS`'in **tek** kaynağı
/// (D-27, CD-76).
///
/// `AppConstants.allowedEmailDomains` bu listeye delege eder; Security Rules
/// `emailOk()` regex'i [rulesRegex] ile parite testine tabidir
/// (`tool/check_rules_parity.js` RP03). Biçim denetimi (tek `@`, yerel kısım
/// uzunluğu) burada **yapılmaz**: `EmailDomainValidator.isWellFormed`.
///
/// Kalıcı liste ([universityDomains]) ile geçici test listesi
/// ([temporaryTestDomains]) **ayrı** tutulur; tüketiciler yalnızca
/// [allowedDomains], [isAllowed] ve [rulesRegex] kullanır (CD-136).
abstract final class EmailDomainPolicy {
  /// Kalıcı üniversite alan adları (D-27; küçük harf, tam eşleşme; alt alan
  /// adı izinli değil). Tasarım sabiti `ALLOWED_EMAIL_DOMAINS` ile aynıdır.
  static const List<String> universityDomains = [
    'ogr.gumushane.edu.tr',
    'gumushane.edu.tr',
  ];

  /// **GEÇİCİ** — test süresince izinli ek alan adları (kullanıcı talebi
  /// 2026-10-13: öğrenci e-postası geç geliyor; D-27'den geçici sapma,
  /// CD-136).
  ///
  /// Borç **W-61** ile teslimden önce (T-45) boşaltılır; geri alma tek
  /// satırdır: `temporaryTestDomains = []`. Ardından `firebase/firestore.rules`
  /// ve `firebase/storage.rules` regex'inden `gmail\\.com` çıkarılır (RP03
  /// bunu zorlar) ve kurallar gerçek projeye yeniden yüklenir.
  static const List<String> temporaryTestDomains = ['gmail.com'];

  /// İzinli alan adları: [universityDomains] + [temporaryTestDomains]
  /// (küçük harf, tam eşleşme; alt alan adı izinli değil). Üniversite alan
  /// adları her zaman başta ve aynı sıradadır.
  static const List<String> allowedDomains = [
    ...universityDomains,
    ...temporaryTestDomains,
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

  /// Security Rules `emailOk()` içindeki `matches(...)` deseninin değeri.
  /// Kalıcı biçimi `.*@(ogr\.gumushane\.edu\.tr|gumushane\.edu\.tr)`;
  /// [temporaryTestDomains] doluyken sonuna o alan adları eklenir
  /// (GEÇİCİ, W-61: `|gmail\.com`).
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
