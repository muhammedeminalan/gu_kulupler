/// Bildirim kategorisi — NTF-01 süzgeç çipleri (PLAN §9.7; türetilmiş).
///
/// Firestore'a **yazılmaz**: `NotificationType.category` ile türden türetilir.
/// Eşleme `design/extracted/registry.json#notifCat` ile birebirdir; üye
/// adları registry'deki kategori kodlarıdır.
enum NotificationCategory {
  /// Kulüp bildirimleri (başvuru, üyelik, rol, duyuru, şikayet).
  clubs,

  /// Etkinlik bildirimleri (yeni etkinlik, hatırlatıcı, iptal, yedek terfi).
  events,

  /// Sistem bildirimleri.
  system,
}
