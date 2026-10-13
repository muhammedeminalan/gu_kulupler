import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/counter_model.dart';

/// Günlük bildirimli duyuru sayacı —
/// `announcementCounters/{clubId}_{yyyyMMdd}` (PLAN §10.4; rules-spec §3.16,
/// domain-model §7).
///
/// Bir kulüp bir Istanbul gününde en çok `Limits.announcementDailyLimit`
/// bildirimli duyuru yayınlar. Sayaç tek başına yazılmaz: yalnızca duyuru
/// yayınıyla **aynı işlemde** bir artar (`PostRepository.create`); bu yüzden
/// yazma üyesi bu arayüzde değildir (uygulama sınıfı gönderi işlemine ekler).
/// Belge silinmez ve sıfırlanmaz; yeni gün yeni belgedir. Okuma kulüp
/// yönetimine (yönetici, danışman, süper admin) açıktır.
///
/// **Gün sınırı (CD-129):** gün anahtarını istemci cihaz saatinden, Security
/// Rules sunucu saatinden hesaplar ve eşitlik toleranssızdır. Cihaz saati
/// Istanbul gün sınırına `Limits.clockSkewTolerance` içindeyken hangi günün
/// geçerli olduğu istemcide bilinemez; o pencerede **komşu gün** de hesaba
/// katılır ([adjacentDayInstant]).
abstract interface class AnnouncementCounterRepository {
  /// [clubId] kulübünün bugünkü (Istanbul günü, cihaz saati) sayacı; belge
  /// yoksa başarı `null` (o gün hiç bildirimli duyuru yok).
  ///
  /// Cihaz saati gün sınırı penceresindeyse ([adjacentDayInstant] `null`
  /// değil) komşu günün belgesi de okunur ve **sayısı büyük olan** döner
  /// (eşitlikte bugünkü): gösterilen kalan hak, Security Rules'ın
  /// reddedebileceği bir hakkı vaat etmez.
  Future<FirestoreResult<CounterModel?>> getToday(String clubId);

  /// [clubId] kulübünün bugün kalan bildirimli duyuru hakkı:
  /// `Limits.announcementDailyLimit − count` ([getToday] ile aynı belge;
  /// belge yoksa hakkın tamamı). Sonuç negatif olmaz.
  Future<FirestoreResult<int>> remainingToday(String clubId);

  /// [nowUtc] Istanbul gün sınırına `Limits.clockSkewTolerance` içindeyse
  /// **komşu günün** içinde kalan bir an; değilse `null`.
  ///
  /// Gün başladıktan sonraki tolerans süresince komşu gün dündür; gün
  /// bitmeden önceki tolerans süresince yarındır. Dönen an yalnızca
  /// [AppClock.istanbulDayKey] / [AppClock.istanbulDay] hesabına verilir.
  /// Saf fonksiyondur ([clock] yalnızca gün hesabı için kullanılır, saati
  /// okunmaz).
  static DateTime? adjacentDayInstant(AppClock clock, DateTime nowUtc) {
    final today = clock.istanbulDayKey(nowUtc);
    final before = nowUtc.subtract(Limits.clockSkewTolerance);
    if (clock.istanbulDayKey(before) != today) return before;
    final after = nowUtc.add(Limits.clockSkewTolerance);
    if (clock.istanbulDayKey(after) != today) return after;
    return null;
  }

  /// [nowUtc] gün sınırı penceresindeyse komşu günün sayaç anahtarı
  /// (`yyyyMMdd`); değilse `null` ([adjacentDayInstant]).
  ///
  /// `PostRepository.create`, cihaz gününün anahtarıyla yazım
  /// [FirestoreError.permissionDenied] alırsa işlemi **bir kez** bu anahtarla
  /// yeniden dener.
  static String? adjacentDayKey(AppClock clock, DateTime nowUtc) {
    final instant = adjacentDayInstant(clock, nowUtc);
    return instant == null ? null : clock.istanbulDayKey(instant);
  }
}
