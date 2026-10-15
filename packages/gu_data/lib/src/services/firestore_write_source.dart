/// Belge yazımı gözlemcisi: yazılan belgenin tam yolunu (`clubs/c01`) alır.
typedef FirestoreWriteListener = void Function(String path);

/// Yazımlarını yol olarak duyuran Firestore servisi (T-44 · D3-01).
///
/// Bellek içi okuma önbelleği (`RepositoryReadCaches`) kendi yazımını bununla
/// **eşzamanlı** geçersiz kılar: hangi repository yazarsa yazsın (yönetim,
/// süper admin, üyelik sayacı) aynı servisten geçtiği için tek kanca yeter.
/// `FirestoreService` arayüzünden ayrıdır: yalnızca gerçek servis ve onu
/// saran test çiftleri uygular; uygulamayan servis önbelleği TTL ile
/// yaşatır.
///
/// Duyurulan yazımlar: `add`, `set`, `update`, batch'siz `softDelete` /
/// `restore` (yazım başlarken ve sunucu onayında), `commitBatch` ve
/// `runTransaction` içindeki `set` / `update` (commit başarısında). Aynı yol
/// birden çok kez duyurulabilir; dinleyici idempotent olmalıdır.
// ignore: one_member_abstracts — bilinçli tek üyeli yetenek arayüzü.
abstract interface class FirestoreWriteSource {
  /// [listener] her yazımın belge yolunu alır. Dinleyici fırlatmamalıdır.
  void addWriteListener(FirestoreWriteListener listener);
}
