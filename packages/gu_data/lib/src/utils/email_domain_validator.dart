import 'package:gu_data/src/constants/email_domain_policy.dart';

/// E-posta biçim ve alan adı denetimi (PLAN §9.1, §10.3; D-27, CD-76).
///
/// İki bağımsız soru yanıtlar:
/// - [isWellFormed]: adres biçimce geçerli mi? (alan adı kısıtı **yok** —
///   `clubs.social.email` gibi serbest adresler için de kullanılır.)
/// - [isAllowedDomain]: alan adı üniversite listesinde mi? İzinli alan adı
///   listesi burada **tutulmaz**; `EmailDomainPolicy` tek kaynaktır.
///
/// Kayıt/giriş e-postası için ikisi birlikte aranır: `EmailDomainPolicy`
/// yalnızca son `@` sonrasına baktığından `@gumushane.edu.tr` ya da
/// `a@b@gumushane.edu.tr` gibi bozuk adresleri tek başına reddetmez.
///
/// Girdi kırpılmaz ve küçültülmez; baştaki/sondaki boşluğu çağıran temizler.
abstract final class EmailDomainValidator {
  /// [email] biçimce geçerli bir adres mi?
  ///
  /// Kurallar:
  /// - tam olarak bir `@`;
  /// - yerel kısım 1–64 karakter, yalnızca yazdırılabilir ASCII (boşluk,
  ///   denetim karakteri ve ASCII dışı harf yok — `emailLower` ASCII
  ///   küçültmeyle üretilir, Türkçe harf beklenmez);
  /// - alan adı `[a-z0-9.-]` karakterlerinden (ASCII büyük harf de kabul
  ///   edilir; karşılaştırma `EmailDomainPolicy` gibi harf duyarsızdır), en
  ///   az bir nokta içerir; her etiket doludur ve tire ile başlamaz/bitmez
  ///   (`a@.com`, `a@x..y`, `a@x.`, `a@-x.com` geçersiz).
  static bool isWellFormed(String email) {
    final at = email.indexOf(_at);
    if (at < 0 || at != email.lastIndexOf(_at)) return false;
    return _isLocalPart(email.substring(0, at)) &&
        _isDomain(email.substring(at + 1));
  }

  /// [email] adresinin alan adı izinli listede mi?
  /// (`EmailDomainPolicy.isAllowed`'a delege eder; biçime bakmaz.)
  static bool isAllowedDomain(String email) =>
      EmailDomainPolicy.isAllowed(email);

  static bool _isLocalPart(String local) {
    if (local.isEmpty || local.length > _localPartMaxLength) return false;
    return local.codeUnits.every(
      (unit) => unit >= _firstPrintable && unit <= _lastPrintable,
    );
  }

  static bool _isDomain(String domain) {
    final labels = domain.split(_dot);
    if (labels.length < _minLabelCount) return false;
    return labels.every(_isLabel);
  }

  static bool _isLabel(String label) {
    if (label.isEmpty) return false;
    final units = label.codeUnits;
    if (units.first == _hyphen || units.last == _hyphen) return false;
    return units.every((unit) => unit == _hyphen || _isAsciiAlphanumeric(unit));
  }

  static bool _isAsciiAlphanumeric(int unit) =>
      (unit >= _digit0 && unit <= _digit9) ||
      (unit >= _upperA && unit <= _upperZ) ||
      (unit >= _lowerA && unit <= _lowerZ);

  static const String _at = '@';
  static const String _dot = '.';

  /// RFC 5321 §4.5.3.1.1 yerel kısım üst sınırı.
  static const int _localPartMaxLength = 64;

  /// "En az bir nokta" = en az iki etiket.
  static const int _minLabelCount = 2;

  /// `!` — boşluktan sonraki ilk yazdırılabilir ASCII karakteri.
  static const int _firstPrintable = 0x21;

  /// `~` — son yazdırılabilir ASCII karakteri.
  static const int _lastPrintable = 0x7E;
  static const int _hyphen = 0x2D;
  static const int _digit0 = 0x30;
  static const int _digit9 = 0x39;
  static const int _upperA = 0x41;
  static const int _upperZ = 0x5A;
  static const int _lowerA = 0x61;
  static const int _lowerZ = 0x7A;
}
