import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'admin_view_model.g.dart';

/// ADM-01 "Admin" genel bakış ViewModel'i (PLAN §12 `AdminViewModel`;
/// prototip `Overview`, `screens-admin.js:11–27`).
///
/// Tek okuma turu (ilk açılış, "Yeniden dene", çek-yenile) — hepsi paralel:
///
/// | Bölüm | Kaynak |
/// |---|---|
/// | Aktif kulüp · Toplam kullanıcı · Açık şikayet | `adminRepository.stats()` (dört `count()`; açık şikayet CD-37) |
/// | Askıdaki kulüp · En aktif 5 kulüp | `clubRepository.fetchActiveClubs(forceRefresh: true)` (askıdakiler dahil; etkinler `memberCount ↓`) |
/// | Grafik | `activityRepository.countByWeek` — son 8 hafta, tüm kulüpler (CD-46: 8 `count()`) |
/// | "+x yeni" | aynı metrik, seçili pencere ([AdminRange]; `countByWeek` kovaları toplanır) |
/// | Katılım oranı | `eventRepository.listPublicUpcoming(fromUtc: pencere başı)` → yayındaki, bitmiş etkinliklerin sayaçları |
///
/// Dönem çipi ([selectRange]) yalnızca pencereye bağlı iki değeri yeniden
/// okur; okunamazsa önceki çipe döner. `permissionDenied` alınınca claim
/// sunucudan yenilenir (`SessionViewModel.refreshClaims` — CD-160) ve süper
/// admin hâlâ geçerliyse okuma bir kez yinelenir; claim geri alınmışsa
/// router guard'ı (`S`) sekmeyi kapatır.
///
/// Design: ADM-01
@riverpod
final class AdminViewModel extends _$AdminViewModel
    with ProjectDependencyMixin {
  /// Grafik nokta sayısı (son 8 hafta, CD-46).
  static const int chartWeeks = 8;

  /// "En aktif 5 kulüp" satır sayısı (`slice(0, 5)`).
  static const int topClubCount = 5;

  /// Grafiğin ve "+x yeni"nin saydığı türler (CD-46; MGT-01 ile aynı).
  static const Set<ActivityKind> growthKinds = {
    ActivityKind.memberJoined,
    ActivityKind.applicationApproved,
  };

  /// "30 gün" penceresinin gün sayısı.
  static const int monthWindowDays = 30;

  /// Güz döneminin başladığı ay (1 Eylül).
  static const int fallTermMonth = DateTime.september;

  /// Bahar döneminin başladığı ay (1 Şubat).
  static const int springTermMonth = DateTime.february;

  static const Duration _day = Duration(hours: Duration.hoursPerDay);

  static const Duration _week = Duration(days: DateTime.daysPerWeek);

  /// Tam okuma turu sayacı: eski turun geç gelen sonucu atılır.
  int _epoch = 0;

  /// Pencere okuma sayacı ([selectRange]).
  int _rangeEpoch = 0;

  @override
  AdminState build() {
    unawaited(Future<void>.microtask(_load));
    return const AdminState(isFetching: true);
  }

  /// "Yeniden dene" (`ADM-01.retry`): iskeletle baştan okur.
  Future<void> fetch() async {
    if (!ref.mounted) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _load();
  }

  /// Çek-yenile: içerik kalır, değerler yeniden okunur.
  Future<void> refresh() async {
    if (!ref.mounted || state.isRefreshing) return;
    if (!state.isLoaded) return fetch();
    state = state.copyWith(isRefreshing: true);
    await _load();
  }

  /// Dönem çipi (`ADM-01.range.<id>`): pencereye bağlı değerleri yeniden
  /// okur; okunamazsa önceki çipe döner.
  Future<void> selectRange(AdminRange range) async {
    if (!ref.mounted || range == state.range) return;
    final previous = state.range;
    state = state.copyWith(range: range);
    if (!state.isLoaded) return;
    final epoch = ++_rangeEpoch;
    var result = await _readRange(range, appClock.nowUtc());
    if (!_rangeLive(epoch)) return;
    if (_denied([result]) && await _claimsStillValid()) {
      if (!_rangeLive(epoch)) return;
      result = await _readRange(range, appClock.nowUtc());
      if (!_rangeLive(epoch)) return;
    }
    switch (result) {
      case FirebaseSuccess(data: (final newCount, final attendance)):
        state = state.copyWith(newCount: newCount, attendance: attendance);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Admin dönem verisi okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(range: previous);
    }
  }

  /// [nowUtc] için grafiğin ilk haftasının başı: bugünün (Istanbul) sonundan
  /// 8 hafta geri.
  DateTime chartStart(DateTime nowUtc) =>
      _tomorrowStart(nowUtc).subtract(_week * chartWeeks);

  /// [range] penceresinin başı (Istanbul gün başı, UTC).
  DateTime rangeStart(AdminRange range, DateTime nowUtc) {
    final today = appClock.istanbulStartOfDay(nowUtc);
    switch (range) {
      case AdminRange.days7:
        return today.subtract(_day * (DateTime.daysPerWeek - 1));
      case AdminRange.days30:
        return today.subtract(_day * (monthWindowDays - 1));
      case AdminRange.term:
        // `istanbulDay` → `YYYY-MM-DD` (Istanbul duvar saati).
        final parts = appClock.istanbulDay(nowUtc).split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final (termYear, termMonth) = month >= fallTermMonth
            ? (year, fallTermMonth)
            : month >= springTermMonth
            ? (year, springTermMonth)
            : (year - 1, fallTermMonth);
        // Gün ortası UTC aynı Istanbul gününe düşer; gün başına hizalanır.
        return appClock.istanbulStartOfDay(
          DateTime.utc(termYear, termMonth, 1, Duration.hoursPerDay ~/ 2),
        );
    }
  }

  /// Yarının başı (Istanbul sabit UTC+3, yaz saati yok).
  DateTime _tomorrowStart(DateTime nowUtc) =>
      appClock.istanbulStartOfDay(nowUtc).add(_day);

  // ───────────────────────────────── okuma ──────────────────────────────────

  Future<void> _load({bool claimsRefreshed = false}) async {
    final epoch = ++_epoch;
    final now = appClock.nowUtc();
    final range = state.range;

    final (stats, clubs, chart, ranged) = await (
      adminRepository.stats(),
      clubRepository.fetchActiveClubs(forceRefresh: true),
      activityRepository.countByWeek(
        kinds: growthKinds,
        fromUtc: chartStart(now),
        weeks: chartWeeks,
      ),
      _readRange(range, now),
    ).wait;
    if (!_live(epoch)) return;

    if ((stats, clubs, chart, ranged) case (
      FirebaseSuccess(data: final statsData),
      FirebaseSuccess(data: final clubList),
      FirebaseSuccess(data: final weekly),
      FirebaseSuccess(data: (final newCount, final attendance)),
    )) {
      final active = [
        for (final club in clubList)
          if (club.status == ClubStatus.active) club,
      ]..sort((a, b) => b.memberCount.compareTo(a.memberCount));
      // Kullanıcı bu arada çip değiştirdiyse pencere değerlerini o çipin
      // okuması getirir.
      final sameRange = state.range == range;
      state = state.copyWith(
        stats: statsData,
        suspendedClubCount: clubList.where((c) => c.isSuspended).length,
        topClubs: active.take(topClubCount).toList(growable: false),
        chart: weekly,
        newCount: sameRange ? newCount : null,
        attendance: sameRange ? attendance : null,
        isLoaded: true,
        isFetching: false,
        isRefreshing: false,
        isError: false,
      );
      return;
    }

    final results = [stats, clubs, chart, ranged];
    if (!claimsRefreshed && _denied(results) && await _claimsStillValid()) {
      if (!_live(epoch)) return;
      return _load(claimsRefreshed: true);
    }
    for (final result in results) {
      if (result case FirebaseFailure(:final error, :final message)) {
        AppLogger.warn(
          'Admin genel bakış okunamadı: ${error.name}',
          error: message,
        );
        break;
      }
    }
    if (!_live(epoch)) return;
    // Çek-yenilemede eski içerik kalır; ilk açılışta hata görünümü.
    state = state.copyWith(
      isFetching: false,
      isRefreshing: false,
      isError: !state.isLoaded || state.isFetching,
    );
  }

  /// [range] penceresinin "+x yeni" toplamı ve katılım değerleri.
  Future<FirestoreResult<(int, AdminAttendance)>> _readRange(
    AdminRange range,
    DateTime nowUtc,
  ) async {
    final from = rangeStart(range, nowUtc);
    // Pencereyi örten en az hafta sayısı; bugünden sonraki kovalar boştur,
    // toplam [from, şimdi] aralığının tam sayısıdır.
    final days = _tomorrowStart(nowUtc).difference(from).inDays;
    final weeks = (days + DateTime.daysPerWeek - 1) ~/ DateTime.daysPerWeek;
    final (counts, events) = await (
      activityRepository.countByWeek(
        kinds: growthKinds,
        fromUtc: from,
        weeks: weeks,
      ),
      eventRepository.listPublicUpcoming(fromUtc: from),
    ).wait;
    switch ((counts, events)) {
      case (
        FirebaseSuccess(data: final weekly),
        FirebaseSuccess(data: final list),
      ):
        var eventCount = 0;
        var registered = 0;
        var attended = 0;
        for (final event in list) {
          if (event.status != EventStatus.published ||
              !event.endsAt.isBefore(nowUtc)) {
            continue;
          }
          eventCount++;
          registered += event.goingCount;
          attended += event.attendedCount;
        }
        return FirebaseSuccess((
          weekly.fold<int>(0, (sum, n) => sum + n),
          AdminAttendance(
            eventCount: eventCount,
            registered: registered,
            attended: attended,
          ),
        ));
      case (FirebaseFailure(:final error, :final message, :final detail), _):
      case (_, FirebaseFailure(:final error, :final message, :final detail)):
        return FirebaseFailure(error, message: message, detail: detail);
    }
  }

  bool _denied(List<FirestoreResult<Object?>> results) => results.any(
    (r) => r.errorOrNull == FirestoreError.permissionDenied,
  );

  /// Claim'i sunucudan yeniler (CD-160); süper admin hâlâ geçerli mi?
  Future<bool> _claimsStillValid() async {
    final session = ref.read(sessionViewModelProvider.notifier);
    await session.refreshClaims();
    return ref.mounted && ref.read(sessionViewModelProvider).isSuperAdmin;
  }

  bool _live(int epoch) => ref.mounted && epoch == _epoch;

  bool _rangeLive(int epoch) => ref.mounted && epoch == _rangeEpoch;
}
