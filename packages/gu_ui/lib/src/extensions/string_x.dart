import 'dart:ui' show Locale;

/// Bir ya da daha çok boşluk karakteri (JS `/\s+/`, core.js:422).
final RegExp _whitespace = RegExp(r'\s+');

/// Türkçe büyük/küçük harf dönüşümleri (CD-11; PLAN §7.0, §7.10).
///
/// Dart'ın `toUpperCase()` / `toLowerCase()` çağrıları yerelden bağımsızdır:
/// `'i'.toUpperCase() == 'I'`, `'I'.toLowerCase() == 'i'`. Türkçede noktalı ve
/// noktasız i ayrı harflerdir (`i ↔ İ`, `ı ↔ I`); bu uzantı JS
/// `toLocaleUpperCase('tr')` / `toLocaleLowerCase('tr')` davranışını verir.
extension TurkishCaseX on String {
  /// Türkçe büyük harf: önce `i → İ`, `ı → I`, sonra `toUpperCase()`.
  ///
  /// `'istanbul'.trUpper() == 'İSTANBUL'`, `'ığdır'.trUpper() == 'IĞDIR'`.
  String trUpper() => replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

  /// Türkçe küçük harf: önce `I → ı`, `İ → i`, sonra `toLowerCase()`.
  ///
  /// `'ISPARTA'.trLower() == 'ısparta'`, `'İSTANBUL'.trLower() == 'istanbul'`.
  String trLower() => replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  /// Yerele göre büyük harf (CSS `text-transform: uppercase` karşılığı:
  /// `overline`, `dateBadgeMonth`). `languageCode == 'tr'` → [trUpper],
  /// aksi hâlde `toUpperCase()`.
  String upperFor(Locale locale) =>
      locale.languageCode == 'tr' ? trUpper() : toUpperCase();

  /// Avatar baş harfleri — core.js:422 `initials` birebir.
  ///
  /// Boşluklara bölünür; parça yoksa `'?'`; tek parça → ilk harf; çok parça →
  /// ilk ve son parçanın ilk harfi. Sonuç Türkçe büyük harfe çevrilir
  /// (`toLocaleUpperCase('tr')` → [trUpper]). `'Ayşe Demir'.initials == 'AD'`.
  String get initials {
    final parts = trim()
        .split(_whitespace)
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].trUpper();
    return '${parts.first[0]}${parts.last[0]}'.trUpper();
  }
}
