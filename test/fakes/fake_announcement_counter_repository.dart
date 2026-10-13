// `AnnouncementCounterRepository` fake'i (PLAN §16.3): günlük bildirimli
// duyuru sayaçlarını bellekte tutar.
//
//   final counters = FakeAnnouncementCounterRepository(clock)
//     ..counts[counters.keyOf('c01')] = 2;        // günün hakkı dolu
//   expect((await counters.remainingToday('c01')).dataOrNull, 0);
//
// Gerçek repository gibi: "bugün" verilen saatin Istanbul günüdür; sayaç
// belgesi yoksa `getToday` başarı `null`, `remainingToday` günlük sınırdır;
// gün sınırı penceresinde (CD-129) komşu günün sayacı da okunur ve sayısı
// büyük olan döner. Sayacı `FakePostRepository.create` artırır ([tryBump]):
// `registerDefaultFakes` iki fake'e aynı örneği verir.
import 'dart:math' as math;

import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

final class FakeAnnouncementCounterRepository extends FakeBase
    implements AnnouncementCounterRepository {
  /// "Bugün" [_clock] saatinin Istanbul günüdür.
  FakeAnnouncementCounterRepository(this._clock);

  final AppClock _clock;

  /// `announcementCounters/{clubId}_{yyyyMMdd}` sayaçları (anahtar = belge
  /// kimliği). Test ön veriyi buraya yazar; bugünün anahtarı [keyOf].
  final Map<String, int> counts = <String, int>{};

  /// [clubId] kulübünün bugünkü sayaç belgesinin kimliği.
  String keyOf(String clubId) => FirestoreIds.announcementCounter(
    clubId,
    _clock.istanbulDayKey(_clock.nowUtc()),
  );

  /// [clubId] kulübünün bugünkü sayacını bir artırır; günün hakkı dolmuşsa
  /// hiçbir şey yazmaz ve `false` döner (`FakePostRepository.create`
  /// bildirimli duyuruda çağırır — gerçek yayın işlemindeki sayaç artışı).
  bool tryBump(String clubId) {
    final key = keyOf(clubId);
    final count = counts[key] ?? 0;
    if (count >= Limits.announcementDailyLimit) return false;
    counts[key] = count + 1;
    return true;
  }

  @override
  Future<FirestoreResult<CounterModel?>> getToday(String clubId) async {
    record('getToday', [clubId]);
    if (_rejected<CounterModel?>(clubId) case final failure?) return failure;
    return FirebaseSuccess(_today(clubId));
  }

  @override
  Future<FirestoreResult<int>> remainingToday(String clubId) async {
    record('remainingToday', [clubId]);
    if (_rejected<int>(clubId) case final failure?) return failure;
    return FirebaseSuccess(
      math.max(0, _today(clubId)?.remaining ?? Limits.announcementDailyLimit),
    );
  }

  /// Bugünün sayacı; gün sınırı penceresinde komşu günle karşılaştırılır
  /// (sayısı büyük olan, eşitlikte cihaz günü). Belge yoksa `null`.
  CounterModel? _today(String clubId) {
    final now = _clock.nowUtc();
    final today = _counter(clubId, now);
    final adjacent = AnnouncementCounterRepository.adjacentDayInstant(
      _clock,
      now,
    );
    if (adjacent == null) return today;
    final other = _counter(clubId, adjacent);
    return (other?.count ?? 0) > (today?.count ?? 0) ? other : today;
  }

  CounterModel? _counter(String clubId, DateTime instant) {
    final count =
        counts[FirestoreIds.announcementCounter(
          clubId,
          _clock.istanbulDayKey(instant),
        )];
    return count == null
        ? null
        : CounterModel(
            clubId: clubId,
            day: _clock.istanbulDay(instant),
            count: count,
          );
  }

  /// Bekleyen hata ya da geçersiz kimlik varsa başarısızlık; yoksa `null`.
  FirestoreResult<T>? _rejected<T>(String clubId) {
    final failure = switch (takeFailure()) {
      null => null,
      final FirestoreError error => error,
      _ => FirestoreError.unknown,
    };
    if (failure != null) return FirebaseFailure(failure);
    if (!RepositoryHelpers.isValidId(clubId)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    return null;
  }
}
