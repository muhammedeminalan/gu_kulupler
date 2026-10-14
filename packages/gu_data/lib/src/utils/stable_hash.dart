/// Çalıştırmalar ve platformlar arası kararlı 32 bit FNV-1a özeti (PLAN
/// §10.2, §15.6; CD-09).
///
/// `LocalReminderService.notificationId(rsvpId)` bildirim kimliğini buradan
/// türetir: aynı katılım kaydı her açılışta aynı kimliği alır, böylece
/// yeniden planlama eski planı ezer, iptal doğru planı bulur. `String.hashCode`
/// kullanılmaz (çalıştırmadan çalıştırmaya değişebilir).
///
/// Kimlikler ASCII'dir (`[A-Za-z0-9_-]`): her UTF-16 kod biriminin alt 8 biti
/// bayt olarak işlenir; ASCII girdide sonuç FNV-1a başvuru değerleriyle
/// aynıdır.
int fnv1a32(String input) {
  var hash = _offsetBasis;
  for (final unit in input.codeUnits) {
    hash ^= unit & _byteMask;
    hash = (hash * _prime) & _uint32Mask;
  }
  return hash;
}

/// FNV-1a 32 bit başlangıç değeri.
const int _offsetBasis = 0x811c9dc5;

/// FNV 32 bit asal çarpanı.
const int _prime = 0x01000193;

/// 32 bit işaretsiz aralık maskesi.
const int _uint32Mask = 0xffffffff;

/// Tek bayt maskesi.
const int _byteMask = 0xff;
