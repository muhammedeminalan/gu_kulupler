import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/share_sheet.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/manage/activity_lookups.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'manage_view_model.g.dart';

/// MGT-01 "Yönetim paneli" ViewModel'i (PLAN §12.6; prototip `Panel`,
/// `screens-manage.js:16–31`). Kulüp başına ayrı örnek (family `clubId`).
///
/// Tek okuma turu (ilk açılış, "Yeniden dene", çek-yenile) — hepsi paralel:
///
/// | Bölüm | Kaynak |
/// |---|---|
/// | Toplam üye | `clubs/{c}.memberCount` (sayaç; yeniden sayılmaz) |
/// | "+x bu ay", grafik | `activity` üyelik kategorisi, son 8 hafta: `member_joined` + `application_approved`, haftalık istemcide toplanır (CD-46) |
/// | Bekleyen başvuru | `listPending` toplamı |
/// | Yaklaşan etkinlik, önizleme, yoklama hedefi | `listClubEvents(includeDrafts)` (başlangıç ↓) şimdiye kadar |
/// | Bu ay duyuru | `listForManagement`, son 30 gün, `type == announcement` |
/// | Bugünkü duyuru hakkı | `announcementCounters` (`getToday`) |
/// | Son hareketler | `listActivity` ilk sayfa (tanınmayan tür süzülür, ilk 5) + adlar (`getUsers`, `getEvents`) |
/// | "Henüz üyen yok" | `listActiveMembers(role: member, limit 1)` |
///
/// Sayfalı kaynaklar en çok [maxPages] sayfa okunur (pencere dışına düşen
/// ilk kayıtta durulur). Bir okuma başarısızsa ilk açılışta hata görünümü;
/// çek-yenilemede eski içerik kalır.
///
/// Danışman (Q-09) yazamaz: yazan hızlı eylemler [ensureWritable] ile
/// TST-26 verir.
///
/// Design: MGT-01
@riverpod
final class ManageViewModel extends _$ManageViewModel
    with ProjectDependencyMixin, ExternalLinkMixin {
  /// "Yaklaşan etkinlikler" önizlemesindeki kart sayısı (`slice(0, 2)`).
  static const int upcomingPreviewCount = 2;

  /// "Son hareketler" satır sayısı (`slice(0, 5)`).
  static const int recentPreviewCount = 5;

  /// Grafik nokta sayısı (son 8 hafta, CD-46).
  static const int chartWeeks = 8;

  /// "Bu ay" penceresinin gün sayısı (prototip `monthAgo = now − 30 gün`,
  /// `actions.js:73`).
  static const int monthWindowDays = 30;

  /// "Bu ay" penceresi.
  static const Duration monthWindow = Duration(days: monthWindowDays);

  /// Sayfalı kaynakların okunan en çok sayfa sayısı.
  static const int maxPages = 10;

  /// Grafiğin saydığı türler (CD-46).
  static const Set<ActivityKind> growthKinds = {
    ActivityKind.memberJoined,
    ActivityKind.applicationApproved,
  };

  static const Duration _week = Duration(days: DateTime.daysPerWeek);

  static const Duration _day = Duration(hours: Duration.hoursPerDay);

  /// Okuma turu sayacı: eski turun geç gelen sonucu atılır.
  int _epoch = 0;

  @override
  ManageState build(String clubId) {
    ref.listen(sessionViewModelProvider, (_, session) {
      final access = session.accessTo(clubId);
      final role = session.roleIn(clubId);
      if (access == state.access && role == state.role) return;
      state = state.copyWith(
        access: access,
        role: role,
        clearRole: role == null,
      );
    });
    unawaited(Future<void>.microtask(_load));
    final session = ref.read(sessionViewModelProvider);
    return ManageState(
      access: session.accessTo(clubId),
      role: session.roleIn(clubId),
      isFetching: true,
    );
  }

  /// "Yeniden dene" (`MGT-01.retry`): iskeletle baştan okur.
  Future<void> fetch() async {
    if (!ref.mounted) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _load();
  }

  /// Çek-yenile: içerik kalır, değerler yeniden okunur.
  Future<void> refresh() async {
    if (!ref.mounted || state.isRefreshing) return;
    if (state.club == null) return fetch();
    state = state.copyWith(isRefreshing: true);
    await _load();
  }

  /// Danışman bakışında yazan eyleme dokunuldu → TST-26.
  void onReadOnlyTap() => feedback.showToast(ToastId.tst26);

  /// Yazan eylemden önce: danışmansa TST-26 ve `false`.
  bool ensureWritable() {
    if (!state.isReadOnly) return true;
    onReadOnlyTap();
    return false;
  }

  /// "Yoklama al" (`MGT-01.quick.attendance`) hedefi; yoksa TST-X12 ve
  /// `null`.
  String? nextAttendanceEventId() {
    final id = state.attendanceEventId;
    if (id == null) feedback.showToast(ToastId.tstX12);
    return id;
  }

  /// Kulübün paylaşım bağlantısı ("Henüz üyen yok" → SHT-15).
  String shareUrl() => '${AppConstants.shareBaseUrl}${AppPaths.clubs}/$clubId';

  /// SHT-15'te seçilen yol: kopyala → TST-35; WhatsApp / e-posta → DLG-32;
  /// "Diğer…" → sistem paylaşım sayfası (CLB-03 ile aynı).
  Future<void> share(ShareChoice choice) async {
    final club = state.club;
    if (club == null) return;
    final url = shareUrl();
    switch (choice) {
      case ShareChoice.copyLink:
        if (await shareService.copyText(url)) {
          feedback.showToast(ToastId.tst35);
        }
      case ShareChoice.whatsapp:
        await openExternalLink(ShareLinks.whatsApp(url));
      case ShareChoice.email:
        await openExternalLink(ShareLinks.email(club.name));
      case ShareChoice.other:
        await shareService.shareText(url, subject: club.name);
    }
  }

  /// [nowUtc] için grafiğin ilk haftasının başı: bugünün (Istanbul) sonundan
  /// 8 hafta geri.
  DateTime chartStart(DateTime nowUtc) =>
      _chartEnd(nowUtc).subtract(_week * chartWeeks);

  /// Grafiğin bitişi: yarının başı (Istanbul sabit UTC+3, yaz saati yok).
  DateTime _chartEnd(DateTime nowUtc) =>
      appClock.istanbulStartOfDay(nowUtc).add(_day);

  // ───────────────────────────────── okuma ──────────────────────────────────

  Future<void> _load() async {
    final epoch = ++_epoch;
    final now = appClock.nowUtc();
    final chartFrom = chartStart(now);
    final monthFrom = now.subtract(monthWindow);

    final (
      club,
      pending,
      events,
      recent,
      growth,
      posts,
      counter,
      members,
    ) = await (
      clubRepository.getClub(clubId),
      _collect(
        (page) => membershipRepository.listPending(clubId, page),
      ),
      _collect(
        (page) => eventRepository.listClubEvents(
          clubId,
          page,
          includeDrafts: true,
        ),
        stopAt: (e) =>
            e.status == EventStatus.published && !e.startsAt.isAfter(now),
      ),
      activityRepository.listActivity(
        clubId,
        const PageRequest(limit: recentPreviewCount * 2),
      ),
      _collect(
        (page) => activityRepository.listActivity(
          clubId,
          page,
          category: ActivityCategory.membership,
        ),
        stopAt: (a) => (a.createdAt ?? now).isBefore(chartFrom),
      ),
      _collect(
        (page) => postRepository.listForManagement(clubId, page),
        stopAt: (p) => (p.createdAt ?? now).isBefore(monthFrom),
      ),
      announcementCounterRepository.getToday(clubId),
      membershipRepository.listActiveMembers(
        clubId,
        const PageRequest(limit: 1),
        role: ClubRole.member,
      ),
    ).wait;
    if (!_live(epoch)) return;

    if ((
          club,
          pending,
          events,
          recent,
          growth,
          posts,
          counter,
          members,
        )
        case (
          FirebaseSuccess(data: final clubDoc),
          FirebaseSuccess(data: final pendingList),
          FirebaseSuccess(data: final eventList),
          FirebaseSuccess(data: final recentPage),
          FirebaseSuccess(data: final growthList),
          FirebaseSuccess(data: final postList),
          FirebaseSuccess(data: final counterDoc),
          FirebaseSuccess(data: final memberPage),
        )) {
      final upcoming = [
        for (final e in eventList)
          if (e.status == EventStatus.published && e.startsAt.isAfter(now)) e,
      ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
      final lastStarted = eventList.where(
        (e) => e.status == EventStatus.published && !e.startsAt.isAfter(now),
      );
      final recentItems = [
        for (final a in recentPage.items)
          if (a.kind != ActivityKind.unknown) a,
      ].take(recentPreviewCount).toList(growable: false);
      final chart = _weekly(growthList, chartFrom, now);
      final joinedThisMonth = growthList.where((a) {
        final at = a.createdAt ?? now;
        return growthKinds.contains(a.kind) && !at.isBefore(monthFrom);
      }).length;
      final announcements = postList.where((p) {
        final at = p.createdAt ?? now;
        return p.type == PostType.announcement && !at.isBefore(monthFrom);
      }).length;
      final lookups = await _resolve(recentItems, eventList);
      if (!_live(epoch)) return;

      state = state.copyWith(
        club: clubDoc,
        kpis: MgtKpis(
          memberCount: clubDoc.memberCount,
          joinedThisMonth: joinedThisMonth,
          pendingCount: pendingList.length,
          upcomingEventCount: upcoming.length,
          announcementCount: announcements,
        ),
        chart: chart,
        announcementsToday: counterDoc?.count ?? 0,
        upcomingEvents: upcoming
            .take(upcomingPreviewCount)
            .toList(growable: false),
        attendanceEventId: upcoming.isNotEmpty
            ? upcoming.first.id
            : lastStarted.firstOrNull?.id,
        clearAttendanceEventId: upcoming.isEmpty && lastStarted.isEmpty,
        recentActivity: recentItems,
        lookups: lookups,
        hasMembers: memberPage.items.isNotEmpty,
        isFetching: false,
        isRefreshing: false,
        isError: false,
      );
      return;
    }

    for (final result in [
      club,
      pending,
      events,
      recent,
      growth,
      posts,
      counter,
      members,
    ]) {
      if (result case FirebaseFailure(:final error, :final message)) {
        AppLogger.warn(
          'Yönetim paneli okunamadı: ${error.name}',
          error: message,
        );
        break;
      }
    }
    // Çek-yenilemede eski içerik kalır; ilk açılışta hata görünümü.
    state = state.copyWith(
      isFetching: false,
      isRefreshing: false,
      isError: state.club == null || state.isFetching,
    );
  }

  bool _live(int epoch) => ref.mounted && epoch == _epoch;

  /// [items] kayıtlarını [from]'dan başlayan 8 haftalık kovalara sayar
  /// (yalnızca [growthKinds]); boş hafta 0.
  List<int> _weekly(List<ActivityModel> items, DateTime from, DateTime now) {
    final counts = List<int>.filled(chartWeeks, 0);
    for (final a in items) {
      if (!growthKinds.contains(a.kind)) continue;
      final at = a.createdAt ?? now;
      if (at.isBefore(from)) continue;
      final index = at.difference(from).inMicroseconds ~/ _week.inMicroseconds;
      counts[index.clamp(0, chartWeeks - 1)]++;
    }
    return counts;
  }

  /// [fetch] sayfalarını sırayla okur; [stopAt] `true` dönen ilk öğede
  /// (öğe dahil) ya da [maxPages] sayfada durur.
  Future<FirestoreResult<List<T>>> _collect<T>(
    Future<FirestoreResult<PageResult<T>>> Function(PageRequest page) fetch, {
    bool Function(T item)? stopAt,
  }) async {
    final out = <T>[];
    PageCursor? after;
    for (var i = 0; i < maxPages; i++) {
      final result = await fetch(PageRequest(after: after));
      switch (result) {
        case FirebaseFailure(:final error, :final message, :final detail):
          return FirebaseFailure(error, message: message, detail: detail);
        case FirebaseSuccess(:final data):
          for (final item in data.items) {
            out.add(item);
            if (stopAt != null && stopAt(item)) return FirebaseSuccess(out);
          }
          if (!data.hasMore) return FirebaseSuccess(out);
          after = data.next;
      }
    }
    return FirebaseSuccess(out);
  }

  /// [items] satırlarının adları: eylemci + hedef kullanıcı (`getUsers`),
  /// etkinlik başlığı ([known] içinden, yoksa `getEvents`). Bulunamayan
  /// kimlikler `missing`; okunamayan kaynak boş ad bırakır.
  Future<ActivityLookups> _resolve(
    List<ActivityModel> items,
    List<EventModel> known,
  ) async {
    final userIds = <String>{};
    final eventIds = <String>{};
    for (final a in items) {
      if (a.actorId.isNotEmpty) userIds.add(a.actorId);
      final target = a.refs.userId;
      if (target != null && target.isNotEmpty) userIds.add(target);
      final event = a.refs.eventId;
      if (event != null && event.isNotEmpty) eventIds.add(event);
    }
    final titles = <String, String>{
      for (final e in known)
        if (eventIds.contains(e.id)) e.id: e.title,
    };
    final unknownEvents = eventIds.difference(titles.keys.toSet()).toList();
    final (users, events) = await (
      userRepository.getUsers(userIds.toList()),
      eventRepository.getEvents(unknownEvents),
    ).wait;
    final missing = <String>{};
    final byId = <String, UserModel>{};
    switch (users) {
      case FirebaseSuccess(:final data):
        for (final user in data) {
          byId[user.uid] = user;
        }
        missing.addAll(userIds.where((id) => !byId.containsKey(id)));
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Faaliyet adları okunamadı: ${error.name}',
          error: message,
        );
    }
    switch (events) {
      case FirebaseSuccess(:final data):
        for (final event in data) {
          titles[event.id] = event.title;
        }
        missing.addAll(unknownEvents.where((id) => !titles.containsKey(id)));
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Faaliyet etkinlikleri okunamadı: ${error.name}',
          error: message,
        );
    }
    return ActivityLookups(users: byId, eventTitles: titles, missing: missing);
  }
}
