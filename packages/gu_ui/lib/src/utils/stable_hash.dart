/// Kararlı (platformdan ve çalıştırmadan bağımsız) hash — CD-94, D-16 tek
/// kopya. Dart `String.hashCode` sürümler / platformlar arasında sabit
/// değildir; tohumdan renk (`GuAvatar`) ve kalıcı kimlik
/// (`LocalReminderService.notificationId`, T-23) için bu sınıf kullanılır.
abstract final class GuStableHash {
  /// FNV-1a 32 bit başlangıç değeri (`core.js:418` `2166136261`).
  static const int _offsetBasis = 0x811C9DC5;

  /// FNV asalının (`16777619` = `0x01000193`) alt 24 biti; üst kısım `1 << 24`
  /// ayrı toplanır.
  static const int _primeLow = 0x193;

  /// Asalın üst kısmı: `x << 24` (32 bitte yalnız `x`'in alt baytı kalır).
  static const int _primeShift = 24;

  static const int _byteMask = 0xFF;
  static const int _mask32 = 0xFFFFFFFF;

  /// FNV-1a 32 bit — prototip `hashStr` (`core.js:418`) birebir: UTF-16 kod
  /// birimi (`charCodeAt` = [String.codeUnits]) üzerinde `h ^= c;
  /// h = Math.imul(h, 16777619)`, sonuç işaretsiz (`>>> 0`).
  ///
  /// `fnv1a32('') == 2166136261`, `fnv1a32('a') == 3826002220`,
  /// `fnv1a32('av:u001') == 3469349974`.
  ///
  /// Çarpım iki parçada yapılır (`x × 16777619 = (x << 24) + x × 0x193`);
  /// ara değer 2^53'ü aşmaz, sonuç JS sayı modelinde de aynıdır.
  static int fnv1a32(String input) {
    var hash = _offsetBasis;
    for (final unit in input.codeUnits) {
      final x = (hash ^ unit) & _mask32;
      hash = (((x & _byteMask) << _primeShift) + x * _primeLow) & _mask32;
    }
    return hash;
  }
}
