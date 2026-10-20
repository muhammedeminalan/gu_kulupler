import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_state.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_kulupler/product/mixin/permission_prompt_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/navigation/notification_navigator.dart';
import 'package:gu_kulupler/product/notification/notification_lookups.dart';
import 'package:gu_kulupler/product/notification/unread_notification_clubs.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notifications_view_model.g.dart';

/// NTF-01 "Bildirimler" + sekme rozetinin ViewModel'i (PLAN §12.6, §15.9).
///
/// * **keepAlive** (PLAN §12.1): rozet sekme çubuğunda her zaman görünür
///   (kabuk dinler); oturum kullanıcısı değişince (giriş / çıkış) yeniden
///   kurulur, eski abonelik kapanır.
/// * **Canlı veri** (PLAN §10.6 #2): `notificationRepository.watchInbox(uid)`;
///   tercihler bir kez okunur (`settingsRepository.getSettings`;
///   [reloadSettings] NTF-02 kaydından sonra). Görünür liste: tanınmayan tür
///   düşer → okuyan taraf tercih süzgeci (`NotificationPreferenceFilter`,
///   T-25) → engellenen başvuranın `application_received` bildirimi düşer
///   (domain-model §2.13 istemci süzgeci).
/// * Metin adları (kulüp / etkinlik / gönderi / başvuran) her anlık
///   görüntüde eksik kimlikler için toplu okunur (`getClubs`, `getEvents`,
///   `getUsers`, `getPost`); bulunamayan hedef [NotificationLookups.missing]
///   olur ("İçerik kaldırıldı"). İlk görüntü adlar gelene dek iskelettir.
/// * Okunmamış kulüp kümesi (W-68) [UnreadNotificationClubs]'a yazılır.
/// * TST-55: oturum başladıktan sonra düşen, görünür ve okunmamış yeni
///   bildirim [NotificationsState.incoming] olur (bandı kabuk gösterir).
/// * Yazımlar iyimserdir (önce yerel, hata → eski liste + toast; ağ →
///   TST-24, yetki → TST-X18). Okunmadıya döndürme yolu yoktur
///   (`NotificationRepository.markRead`).
///
/// Design: NTF-01
@Riverpod(keepAlive: true)
final class NotificationsViewModel extends _$NotificationsViewModel
    with ProjectDependencyMixin, WriteGuardMixin, PermissionPromptMixin {
  StreamSubscription<FirestoreResult<List<NotificationModel>>>? _subscription;

  /// Okuması süren ad kimlikleri (aynı kimlik iki kez istenmez).
  final Set<String> _inFlight = <String>{};

  /// Bu oturumda görülmüş bildirim kimlikleri (geri alınan bildirim TST-55
  /// sayılmaz).
  final Set<String> _seen = <String>{};

  /// Kurulum sayacı: eski kurulumun geç gelen sonuçları atılır.
  int _epoch = 0;

  /// [type] türünü kapatan tercih yaması ("Bu türü kapat",
  /// `NTF-01.menu.<id>.mute`; prototip `cards.js:157`). Zorunlu (`force`)
  /// türlerin tercihi yoktur → `null` (öğe gösterilmez).
  static UserSettingsPatch? mutePatchOf(NotificationType type) =>
      switch (type) {
        NotificationType.announcement => const UserSettingsPatch(
          announcements: false,
        ),
        NotificationType.eventReminder => const UserSettingsPatch(
          eventReminders: false,
        ),
        NotificationType.eventNew => const UserSettingsPatch(newEvents: false),
        NotificationType.postNew => const UserSettingsPatch(newPosts: false),
        NotificationType.commentNew => const UserSettingsPatch(
          newComments: false,
        ),
        NotificationType.applicationApproved ||
        NotificationType.applicationRejected => const UserSettingsPatch(
          applicationResults: false,
        ),
        NotificationType.applicationReceived => const UserSettingsPatch(
          management: false,
        ),
        NotificationType.system => const UserSettingsPatch(system: false),
        _ => null,
      };

  @override
  NotificationsState build() {
    final uid = ref.watch(sessionViewModelProvider.select((s) => s.uid));
    ref
      ..onDispose(_cancel)
      ..listen(
        sessionViewModelProvider.select((s) => s.blockedUserIds),
        (_, _) => _emit(state),
      );
    final epoch = ++_epoch;
    _inFlight.clear();
    _seen.clear();
    if (uid == null) {
      return NotificationsState(sessionStartedAt: appClock.nowUtc());
    }
    unawaited(Future<void>.microtask(() => _start(uid, epoch)));
    return NotificationsState(
      sessionStartedAt: appClock.nowUtc(),
      isFetching: true,
    );
  }

  String? get _uid =>
      ref.mounted ? ref.read(sessionViewModelProvider).uid : null;

  bool _live(int epoch) => ref.mounted && epoch == _epoch;

  /// Filtre çipi (`NTF-01.filter.<name>`).
  void setFilter(NotificationFilter filter) {
    if (!ref.mounted || state.filter == filter) return;
    _emit(state.copyWith(filter: filter));
  }

  /// Çek-yenile / "Yeniden dene" (`NTF-01.refresh`, `NTF-01.retry`):
  /// tercihleri ve izni yeniden okur, akışı yeniden dinler (liste zaten
  /// canlı).
  Future<void> refresh() async {
    final uid = _uid;
    if (uid == null) return;
    state = state.copyWith(isError: false, isFetching: state.raw.isEmpty);
    await _start(uid, _epoch);
  }

  /// Tercihleri yeniden okur ve listeyi yeniden süzer (NTF-02 kaydından
  /// sonra; akış yeniden kurulmaz).
  Future<void> reloadSettings() async {
    final uid = _uid;
    if (uid == null) return;
    final result = await settingsRepository.getSettings(uid);
    if (!ref.mounted) return;
    if (result case FirebaseSuccess(:final data)) {
      _emit(state.copyWith(settings: data));
    }
  }

  /// İzin bandının görünürlüğünü sistem izninden yeniler (ekran açılışı).
  Future<void> checkPermission() async {
    final granted = await permissionService.isGranted(Permission.notification);
    if (!ref.mounted) return;
    state = state.copyWith(
      showPermissionBanner: !granted && !state.isBannerDismissed,
    );
  }

  /// [id] bildirimini okundu işaretler (iyimser; sağa kaydırma, menü).
  Future<void> markRead(String id) async {
    final notification = _find(id);
    if (notification == null || notification.read) return;
    if (!ensureOnline()) return;
    _setRead({id}, read: true);
    final result = await notificationRepository.markRead(id);
    if (!ref.mounted) return;
    if (result case FirebaseFailure(:final error, :final message)) {
      _setRead({id}, read: false);
      _onWriteFailure(error, 'Bildirim okundu işaretlenemedi', message);
    }
  }

  /// "Tümünü okundu say" (`NTF-01.markAllRead`, TST-18): görünür (tercih
  /// süzgecinden geçmiş, filtreden bağımsız) okunmamışlar tek çağrıda.
  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null || state.isMarkingAll) return;
    final unread = [
      for (final n in _visible(state))
        if (!n.read) n.id,
    ];
    if (unread.isEmpty) {
      feedback.showToast(ToastId.tst18);
      return;
    }
    if (!ensureOnline()) return;
    final ids = unread.toSet();
    state = state.copyWith(isMarkingAll: true);
    _setRead(ids, read: true);
    final result = await notificationRepository.markAllRead(uid, unread);
    if (!ref.mounted) return;
    state = state.copyWith(isMarkingAll: false);
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(ToastId.tst18);
      case FirebaseFailure(:final error, :final message):
        _setRead(ids, read: false);
        _onWriteFailure(error, 'Bildirimler okundu işaretlenemedi', message);
    }
  }

  /// Kaydırarak sil (`NTF-01.swipe.<id>`, menü) → TST-16 "Geri al".
  Future<void> softDelete(String id) async {
    final uid = _uid;
    final notification = _find(id);
    if (uid == null || notification == null) return;
    if (!ensureOnline()) return;
    _emit(state.copyWith(raw: _without(id), pendingUndo: notification));
    final result = await notificationRepository.softDeleteNotification(
      id,
      actorId: uid,
    );
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(
          ToastId.tst16,
          onAction: () => unawaited(undoDelete()),
        );
      case FirebaseFailure(:final error, :final message):
        _emit(
          state.copyWith(
            raw: _withRestored(notification),
            clearPendingUndo: state.pendingUndo?.id == id,
          ),
        );
        _onWriteFailure(error, 'Bildirim silinemedi', message);
    }
  }

  /// TST-16 "Geri al" → `restoreNotification`.
  Future<void> undoDelete() async {
    final notification = state.pendingUndo;
    if (!ref.mounted || notification == null) return;
    if (!ensureOnline()) return;
    _emit(
      state.copyWith(raw: _withRestored(notification), clearPendingUndo: true),
    );
    final result = await notificationRepository.restoreNotification(
      notification.id,
    );
    if (!ref.mounted) return;
    if (result case FirebaseFailure(:final error, :final message)) {
      _emit(state.copyWith(raw: _without(notification.id)));
      _onWriteFailure(error, 'Bildirim geri alınamadı', message);
    }
  }

  /// "Bu türü kapat" (`NTF-01.menu.<id>.mute`): türün genel tercihi kapanır
  /// (iyimser) → TST-19; hatırlatıcı tercihi değiştiyse yerel planlar
  /// yeniden kurulur (CD-148).
  Future<void> muteType(NotificationModel notification) async {
    final uid = _uid;
    final settings = state.settings;
    final patch = mutePatchOf(notification.type);
    if (uid == null || settings == null || patch == null) return;
    if (!ensureOnline()) return;
    _emit(state.copyWith(settings: _patched(settings, patch)));
    final result = await settingsRepository.updateSettings(uid, patch);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(ToastId.tst19);
        if (patch.eventReminders != null) {
          unawaited(
            ref.read(sessionViewModelProvider.notifier).rescheduleReminders(),
          );
        }
      case FirebaseFailure(:final error, :final message):
        _emit(state.copyWith(settings: settings));
        _onWriteFailure(error, 'Tercih kaydedilemedi', message);
    }
  }

  /// Satıra dokunma (`NTF-01.item.<id>`): satır yerelde okundu görünür,
  /// okundu yazımı ve hedef `NotificationNavigator.open`'dadır (PLAN §15.8
  /// adım 1–5).
  Future<void> open(NotificationModel notification) async {
    if (!ref.mounted) return;
    if (!notification.read) _setRead({notification.id}, read: true);
    await ref.read(notificationNavigatorProvider).open(notification);
  }

  /// İzin bandı "Aç" (`NTF-01.enable`) → DLG-03 → sistem izni
  /// (`permissionService.requestNotifications`) → TST-19; verilirse band
  /// kalkar. "Bir kez sor" bayrağı her durumda işaretlenir.
  Future<void> requestPermission() async {
    final granted = await askNotificationPermission();
    if (!ref.mounted) return;
    unawaited(
      ref
          .read(appPreferencesViewModelProvider.notifier)
          .markNotificationPermissionAsked(),
    );
    if (granted) state = state.copyWith(showPermissionBanner: false);
  }

  /// İzin bandı kapat (`NTF-01.dismissBanner`): oturum boyunca dönmez.
  void dismissPermissionBanner() {
    if (!ref.mounted) return;
    state = state.copyWith(
      showPermissionBanner: false,
      isBannerDismissed: true,
    );
  }

  /// TST-55 bandı gösterildi: [NotificationsState.incoming] temizlenir.
  void consumeIncoming() {
    if (!ref.mounted || state.incoming == null) return;
    state = state.copyWith(clearIncoming: true);
  }

  // ───────────────────────────────── okuma ──────────────────────────────────

  Future<void> _start(String uid, int epoch) async {
    if (!_live(epoch)) return;
    _cancel();
    final (settings, granted) = await (
      settingsRepository.getSettings(uid),
      permissionService.isGranted(Permission.notification),
    ).wait;
    if (!_live(epoch)) return;
    switch (settings) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(settings: data);
      case FirebaseFailure(:final error, :final message):
        // Tercih okunamazsa süzgeç uygulanmaz (her şey görünür).
        AppLogger.warn(
          'Bildirim tercihleri okunamadı: ${error.name}',
          error: message,
        );
    }
    state = state.copyWith(
      showPermissionBanner: !granted && !state.isBannerDismissed,
    );
    _subscription = notificationRepository
        .watchInbox(uid)
        .listen((result) => _onInbox(result, epoch));
  }

  void _onInbox(FirestoreResult<List<NotificationModel>> result, int epoch) {
    if (!_live(epoch)) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        final first = state.isFetching && state.raw.isEmpty && _seen.isEmpty;
        final arrival = first ? null : _arrival(data);
        _seen.addAll(data.map((n) => n.id));
        _emit(state.copyWith(raw: data, isError: false, incoming: arrival));
        unawaited(_resolve(data, epoch));
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn('Bildirimler okunamadı: ${error.name}', error: message);
        state = state.copyWith(isFetching: false, isError: true);
    }
  }

  /// [next] anlık görüntüsünde ilk kez görülen, oturumdan sonra yazılmış,
  /// görünür ve okunmamış en yeni bildirim (TST-55); yoksa `null`.
  NotificationModel? _arrival(List<NotificationModel> next) {
    final threshold = state.sessionStartedAt;
    final candidates = [
      for (final n in next)
        if (!_seen.contains(n.id) &&
            !n.read &&
            (n.createdAt?.isAfter(threshold) ?? false))
          n,
    ];
    if (candidates.isEmpty) return null;
    final visible = _visibleOf(candidates, state.settings);
    return visible.isEmpty ? null : visible.first;
  }

  /// [items] bildirimlerinin metin adlarından eksik olanları okur; bitince
  /// ilk görüntünün iskeleti kalkar.
  Future<void> _resolve(List<NotificationModel> items, int epoch) async {
    final lookups = state.lookups;
    final clubIds = <String>{};
    final eventIds = <String>{};
    final postIds = <String>{};
    final userIds = <String>{};
    void want(String? id, Set<String> into) {
      if (id == null || id.isEmpty) return;
      if (lookups.isResolved(id) || _inFlight.contains(id)) return;
      into.add(id);
    }

    for (final n in items) {
      final refs = n.refs;
      want(refs.clubId, clubIds);
      want(refs.eventId, eventIds);
      want(refs.postId, postIds);
      want(refs.applicantId, userIds);
    }
    final all = {...clubIds, ...eventIds, ...postIds, ...userIds};
    if (all.isEmpty) {
      if (_live(epoch) && state.isFetching) {
        state = state.copyWith(isFetching: false);
      }
      return;
    }
    _inFlight.addAll(all);
    final (clubs, events, users, posts) = await (
      clubRepository.getClubs(clubIds.toList()),
      eventRepository.getEvents(eventIds.toList()),
      userRepository.getUsers(userIds.toList()),
      Future.wait([for (final id in postIds) postRepository.getPost(id)]),
    ).wait;
    _inFlight.removeAll(all);
    if (!_live(epoch)) return;

    final missing = <String>{};
    final clubNames = <String, String>{};
    if (clubs case FirebaseSuccess(:final data)) {
      for (final club in data) {
        clubNames[club.id] = club.name;
      }
      missing.addAll(clubIds.where((id) => !clubNames.containsKey(id)));
    }
    final eventById = <String, EventModel>{};
    if (events case FirebaseSuccess(:final data)) {
      for (final event in data) {
        eventById[event.id] = event;
      }
      missing.addAll(eventIds.where((id) => !eventById.containsKey(id)));
    }
    final userNames = <String, String>{};
    if (users case FirebaseSuccess(:final data)) {
      for (final user in data) {
        userNames[user.uid] = user.name;
      }
      missing.addAll(userIds.where((id) => !userNames.containsKey(id)));
    }
    final postTitles = <String, String>{};
    final postList = postIds.toList();
    for (var i = 0; i < postList.length; i++) {
      switch (posts[i]) {
        case FirebaseSuccess(:final data):
          postTitles[postList[i]] = NotificationLookups.postTitleOf(data);
        case FirebaseFailure(
          error: FirestoreError.notFound || FirestoreError.permissionDenied,
        ):
          missing.add(postList[i]);
        case FirebaseFailure():
          break;
      }
    }
    state = state.copyWith(
      lookups: state.lookups.merge(
        NotificationLookups(
          clubNames: clubNames,
          events: eventById,
          postTitles: postTitles,
          userNames: userNames,
          missing: missing,
        ),
      ),
      isFetching: false,
    );
  }

  // ───────────────────────────── türetilmiş alanlar ─────────────────────────

  /// [next]'in türetilmiş alanlarını hesaplayıp durumu yazar ve okunmamış
  /// kulüp kümesini yayınlar.
  void _emit(NotificationsState next) {
    if (!ref.mounted) return;
    final visible = _visible(next);
    final items = [
      for (final n in visible)
        if (_matches(next.filter, n)) n,
    ];
    state = next.copyWith(
      items: items,
      sections: _group(items),
      unreadCount: visible.where((n) => !n.read).length,
    );
    ref.read(unreadNotificationClubsProvider.notifier).set({
      for (final n in visible)
        if (!n.read && n.refs.clubId != null) n.refs.clubId!,
    });
    _syncBadge(state.unreadCount);
  }

  /// Son yazılan uygulama simgesi rozeti (H-25); aynı değer tekrar yazılmaz.
  int? _badge;

  /// Okundu / silindi / yeni bildirim değişimini simge rozetine yansıtır.
  void _syncBadge(int count) {
    if (count == _badge) return;
    _badge = count;
    unawaited(messagingService.setBadge(count));
  }

  /// [s] durumunda görünür bildirimler (filtreden önce).
  List<NotificationModel> _visible(NotificationsState s) =>
      _visibleOf(s.raw, s.settings);

  List<NotificationModel> _visibleOf(
    List<NotificationModel> raw,
    UserSettingsModel? settings,
  ) {
    final blocked = ref.read(sessionViewModelProvider).blockedUserIds;
    final allowed = settings == null
        ? raw
        : NotificationPreferenceFilter.apply(settings, raw);
    return [
      for (final n in allowed)
        if (n.type != NotificationType.unknown &&
            !(n.type == NotificationType.applicationReceived &&
                blocked.contains(n.refs.applicantId)))
          n,
    ];
  }

  static bool _matches(
    NotificationFilter filter,
    NotificationModel n,
  ) => switch (filter) {
    NotificationFilter.all => true,
    NotificationFilter.clubs => n.type.category == NotificationCategory.clubs,
    NotificationFilter.events => n.type.category == NotificationCategory.events,
    NotificationFilter.system => n.type.category == NotificationCategory.system,
    NotificationFilter.unread => !n.read,
  };

  List<NotificationSection> _group(List<NotificationModel> items) {
    final now = appClock.nowUtc();
    // Istanbul sabit UTC+3 (yaz saati yok): önceki günlerin başlangıcı aynı
    // UTC saatinde, takvim günü kadar geridedir.
    final today = appClock.istanbulStartOfDay(now);
    DateTime daysBefore(int days) => DateTime.utc(
      today.year,
      today.month,
      today.day - days,
      today.hour,
      today.minute,
    );
    final yesterday = daysBefore(1);
    final weekStart = daysBefore(DateTime.daysPerWeek);
    final byDay = <NotificationDay, List<NotificationModel>>{};
    for (final n in items) {
      final at = n.createdAt ?? now;
      final day = !at.isBefore(today)
          ? NotificationDay.today
          : !at.isBefore(yesterday)
          ? NotificationDay.yesterday
          : !at.isBefore(weekStart)
          ? NotificationDay.week
          : NotificationDay.earlier;
      (byDay[day] ??= []).add(n);
    }
    return [
      for (final day in NotificationDay.values)
        if (byDay[day] case final list?)
          NotificationSection(day: day, items: list),
    ];
  }

  // ─────────────────────────────── yardımcılar ──────────────────────────────

  NotificationModel? _find(String id) {
    for (final n in state.raw) {
      if (n.id == id) return n;
    }
    return null;
  }

  void _setRead(Set<String> ids, {required bool read}) => _emit(
    state.copyWith(
      raw: [
        for (final n in state.raw)
          ids.contains(n.id) ? n.copyWith(read: read) : n,
      ],
    ),
  );

  List<NotificationModel> _without(String id) => [
    for (final n in state.raw)
      if (n.id != id) n,
  ];

  /// [notification] yeniden eklenmiş, en yeni üstte sıralı liste.
  List<NotificationModel> _withRestored(NotificationModel notification) {
    final now = appClock.nowUtc();
    return [..._without(notification.id), notification]..sort(
      (a, b) => (b.createdAt ?? now).compareTo(a.createdAt ?? now),
    );
  }

  static UserSettingsModel _patched(
    UserSettingsModel settings,
    UserSettingsPatch patch,
  ) => settings.copyWith(
    announcements: patch.announcements,
    eventReminders: patch.eventReminders,
    newEvents: patch.newEvents,
    newPosts: patch.newPosts,
    newComments: patch.newComments,
    applicationResults: patch.applicationResults,
    management: patch.management,
    system: patch.system,
  );

  void _onWriteFailure(FirestoreError error, String what, String? message) {
    if (showWriteFailureToast(error)) return;
    AppLogger.warn('$what: ${error.name}', error: message);
  }

  void _cancel() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}
