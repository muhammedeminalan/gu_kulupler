/// Bellek içi okuma önbelleğinin süre ve boyut sınırları (T-44 · D3-01).
///
/// İş kuralı sınırı değil, istemci önbellek politikasıdır: PLAN §9.8 tablosu
/// (`Limits`) kilitli olduğu için ayrı tutulur. Yalnızca nadir değişen,
/// her doğrulanmış kullanıcıya açık belgeler önbelleğe alınır (kulüp listesi,
/// kulüp belgesi, başka kullanıcının herkese açık profili); üyelik, yetki,
/// sayaç belgeleri, bildirim, katılım ve yönetim okumaları **alınmaz**.
abstract final class CachePolicy {
  /// Kulüp belgesi ve etkin kulüp listesinin bellekte geçerli kalma süresi.
  static const Duration clubTtl = Duration(minutes: 5);

  /// Bellekte tutulan en çok kulüp belgesi (en eski kullanılan atılır).
  static const int clubMax = 200;

  /// Başka kullanıcının herkese açık profilinin (`users/{uid}`) geçerli
  /// kalma süresi.
  static const Duration userTtl = Duration(minutes: 10);

  /// Bellekte tutulan en çok kullanıcı profili (en eski kullanılan atılır).
  static const int userMax = 500;
}
