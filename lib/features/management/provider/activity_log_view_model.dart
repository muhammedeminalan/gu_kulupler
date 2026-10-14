import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/features/management/provider/activity_log_state.dart';
import 'package:gu_kulupler/product/manage/activity_lookups.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'activity_log_view_model.g.dart';

/// MGT-10 "Faaliyet geçmişi" ekranının ViewModel'i (PLAN §12.6; prototip
/// `S['MGT-10']`, `screens-manage.js:190–196`).
///
/// * Açılışta kulüp (başlık) ve günlüğün ilk sayfası birlikte okunur
///   (`activityRepository.listActivity`, 20 + imleç, en yeni üstte); kalan
///   sayfalar [loadMore] ile gelir.
/// * Tür grubu çipi ([setCategory]) sorguda uygulanır (`kind in [...]`,
///   `ActivityCategory.kinds`): liste baştan, iskeletle okunur.
/// * Satır metinlerinin adları her sayfada eksik kimlikler için toplu okunur
///   (`userRepository.getUsers`, `eventRepository.getEvents`); sayfa adlarıyla
///   birlikte listeye girer (ad boşken satır çizilmez). Bulunamayan hedef
///   [ActivityLookups.missing] olur ("Silinmiş kullanıcı" / "İçerik
///   kaldırıldı"); ad okuması başarısızsa liste yine gösterilir.
/// * Tanınmayan tür ([ActivityKind.unknown]) listelenmez (kategori yok,
///   metin yok).
/// * Ekran salt okumadır: yazım yoktur (danışman da aynı listeyi görür,
///   bandı view çizer). Gezinme view'dadır ([targetOf] hedefi verir).
///
/// | İşlem | Sonuç | Geri bildirim |
/// |---|---|---|
/// | açılış / [fetch] / [setCategory] | okunamadı | hata görünümü ("Yeniden dene") |
/// | [refresh] | okunamadı | içerik kalır; içerik yoksa hata görünümü |
/// | [loadMore] | okunamadı | liste olduğu gibi kalır (yeniden kaydırınca dener) |
///
/// Design: MGT-10
@riverpod
final class ActivityLogViewModel extends _$ActivityLogViewModel
    with ProjectDependencyMixin {
  /// İçeriğin kuşağı: her tam okumada artar; eski kuşağın sonucu yazılmaz.
  int _generation = 0;

  @override
  ActivityLogState build(String clubId) {
    // İlk sayfa ilk karede okunmaya başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    return const ActivityLogState(isFetching: true);
  }

  /// "Yeniden dene" (`MGT-10.retry`): listeyi iskeletle baştan okur.
  Future<void> fetch() async {
    if (!ref.mounted) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _load();
  }

  /// Çek-yenile: listeyi iskelet göstermeden baştan okur. Okunamazsa var
  /// olan içerik kalır; içerik yoksa hata görünümü.
  Future<void> refresh() async {
    if (!ref.mounted || state.isRefreshing || state.isFetching) return;
    state = state.copyWith(isRefreshing: true);
    await _load();
  }

  /// Tür grubu çipi (`MGT-10.filter.<id>`; `null` → "Tümü"): liste
  /// iskeletle, yeni süzgeçle baştan okunur (süren okumalar düşer).
  Future<void> setCategory(ActivityCategory? category) async {
    if (!ref.mounted || category == state.category) return;
    state = state.copyWith(
      category: category,
      clearCategory: category == null,
      entries: const [],
      sections: const [],
      clearCursor: true,
      isFetching: true,
      isLoadingMore: false,
      isRefreshing: false,
      isError: false,
    );
    await _load(withClub: state.club == null);
  }

  /// Sonraki sayfa (liste sonuna yaklaşınca). Okunamazsa liste olduğu gibi
  /// kalır; imleç korunur.
  Future<void> loadMore() async {
    final cursor = state.cursor;
    if (!ref.mounted ||
        cursor == null ||
        !state.wantsMore ||
        state.isRefreshing) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true);
    final result = await activityRepository.listActivity(
      clubId,
      PageRequest(after: cursor),
      category: state.category,
    );
    if (!_live(generation)) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        final known = {for (final entry in state.entries) entry.id};
        final fresh = [
          for (final entry in _visible(data.items))
            if (known.add(entry.id)) entry,
        ];
        final lookups = await _resolve(fresh);
        if (!_live(generation)) return;
        _emit(
          state.copyWith(
            lookups: state.lookups.merge(lookups),
            cursor: data.next,
            clearCursor: data.next == null,
            isLoadingMore: false,
          ),
          [...state.entries, ...fresh],
        );
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Faaliyetlerin sonraki sayfası okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isLoadingMore: false);
    }
  }

  /// [entry] satırına dokunmanın hedefi — prototip `ActivityRow.go`
  /// (`screens-manage.js:37`) sırası: etkinlik → gönderi → başvurular →
  /// hedef kullanıcı → kulüp ayarları. Bulunamayan etkinlik / kullanıcı
  /// hedefi [ActivityLogTargetKind.none] olur.
  ActivityLogTarget targetOf(ActivityModel entry) {
    final refs = entry.refs;
    final missing = state.lookups.missing;
    final eventId = refs.eventId;
    if (eventId != null) {
      return missing.contains(eventId)
          ? const ActivityLogTarget(ActivityLogTargetKind.none)
          : ActivityLogTarget(ActivityLogTargetKind.event, eventId);
    }
    final postId = refs.postId;
    if (postId != null) {
      return ActivityLogTarget(ActivityLogTargetKind.post, postId);
    }
    if (_applicationKinds.contains(entry.kind)) {
      return const ActivityLogTarget(ActivityLogTargetKind.applications);
    }
    final userId = refs.userId;
    if (userId != null) {
      return missing.contains(userId)
          ? const ActivityLogTarget(ActivityLogTargetKind.none)
          : ActivityLogTarget(ActivityLogTargetKind.profile, userId);
    }
    return const ActivityLogTarget(ActivityLogTargetKind.settings);
  }

  /// Başvuru türleri (prototip `a.kind.startsWith('application')`).
  static const Set<ActivityKind> _applicationKinds = {
    ActivityKind.applicationReceived,
    ActivityKind.applicationApproved,
    ActivityKind.applicationRejected,
  };

  bool _live(int generation) => ref.mounted && generation == _generation;

  /// Kulübü ([withClub]) ve seçili süzgeçle ilk sayfayı okur, adlarını
  /// çözer ve yüklemeyi / yenilemeyi bitirir.
  Future<void> _load({bool withClub = true}) async {
    if (!ref.mounted) return;
    final generation = ++_generation;
    final clubRead = withClub
        ? clubRepository.getClub(clubId)
        : Future<FirestoreResult<ClubModel>?>.value();
    final (club, page) = await (
      clubRead,
      activityRepository.listActivity(
        clubId,
        const PageRequest(),
        category: state.category,
      ),
    ).wait;
    if (!_live(generation)) return;
    if (club case FirebaseFailure(:final error)) {
      AppLogger.warn('Faaliyet geçmişi: kulüp okunamadı: ${error.name}');
    }
    final clubModel = club?.dataOrNull;
    switch (page) {
      case FirebaseSuccess(:final data):
        final entries = _visible(data.items);
        final lookups = await _resolve(entries);
        if (!_live(generation)) return;
        _emit(
          state.copyWith(
            club: clubModel,
            lookups: state.lookups.merge(lookups),
            cursor: data.next,
            clearCursor: data.next == null,
            isFetching: false,
            isRefreshing: false,
            isLoadingMore: false,
            isError: false,
          ),
          entries,
        );
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Faaliyet geçmişi okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(
          club: clubModel,
          isFetching: false,
          isRefreshing: false,
          isLoadingMore: false,
          isError: state.entries.isEmpty,
        );
    }
  }

  /// [entries] kayıtlarının metin adlarından henüz okunmamış olanları okur
  /// (eylemci + hedef kullanıcı, etkinlik). Okunamayan grup boş kalır.
  Future<ActivityLookups> _resolve(List<ActivityModel> entries) async {
    final known = state.lookups;
    final userIds = <String>{};
    final eventIds = <String>{};
    void want(String? id, Set<String> into) {
      if (id == null || id.isEmpty || known.isResolved(id)) return;
      into.add(id);
    }

    for (final entry in entries) {
      want(entry.actorId, userIds);
      want(entry.refs.userId, userIds);
      want(entry.refs.eventId, eventIds);
    }
    if (userIds.isEmpty && eventIds.isEmpty) return const ActivityLookups();
    final (users, events) = await (
      userRepository.getUsers(userIds.toList()),
      eventRepository.getEvents(eventIds.toList()),
    ).wait;
    final missing = <String>{};
    final userById = <String, UserModel>{};
    switch (users) {
      case FirebaseSuccess(:final data):
        for (final user in data) {
          userById[user.uid] = user;
        }
        missing.addAll(userIds.where((id) => !userById.containsKey(id)));
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Faaliyet: kullanıcılar okunamadı: ${error.name}',
          error: message,
        );
    }
    final titles = <String, String>{};
    switch (events) {
      case FirebaseSuccess(:final data):
        for (final event in data) {
          titles[event.id] = event.title;
        }
        missing.addAll(eventIds.where((id) => !titles.containsKey(id)));
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Faaliyet: etkinlikler okunamadı: ${error.name}',
          error: message,
        );
    }
    return ActivityLookups(
      users: userById,
      eventTitles: titles,
      missing: missing,
    );
  }

  /// [next] durumunu [entries] listesi ve onun gün gruplarıyla yazar.
  void _emit(ActivityLogState next, List<ActivityModel> entries) {
    if (!ref.mounted) return;
    state = next.copyWith(entries: entries, sections: _group(entries));
  }

  /// Tanınan türler (tanınmayan tür listelenmez).
  static List<ActivityModel> _visible(List<ActivityModel> items) => [
    for (final entry in items)
      if (entry.kind != ActivityKind.unknown) entry,
  ];

  /// [entries]'i Istanbul günlerine ayırır; grupların ve satırların sırası
  /// listenin sırasıdır (prototip `dayKey` grupları).
  List<ActivityDaySection> _group(List<ActivityModel> entries) {
    final now = appClock.nowUtc();
    final byDay = <DateTime, List<ActivityModel>>{};
    for (final entry in entries) {
      final day = appClock.istanbulStartOfDay(entry.createdAt ?? now);
      (byDay[day] ??= []).add(entry);
    }
    return [
      for (final MapEntry(key: day, value: items) in byDay.entries)
        ActivityDaySection(day: day, items: items),
    ];
  }
}
