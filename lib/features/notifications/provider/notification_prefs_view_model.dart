import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/notifications/provider/notification_prefs_state.dart';
import 'package:gu_kulupler/features/notifications/provider/notifications_view_model.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/format/time_of_day_value.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_kulupler/product/mixin/permission_prompt_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notification_prefs_view_model.g.dart';

/// NTF-02 "Bildirim tercihleri" ViewModel'i (PLAN §12.6; prototip
/// `NotifPrefs`, `screens-events.js:109–120`).
///
/// * [fetch] tercihleri (`settingsRepository.getSettings`), aktif üyeliklerin
///   kulüplerini (`clubRepository.getClubs`) ve sistem bildirim iznini
///   (`permissionService.isGranted`) birlikte okur.
/// * Her değişiklik **anında** ve **iyimser** kaydedilir: değer önce state'e
///   yazılır, sonra tek alanlı `UserSettingsPatch` gider. Başarı → TST-19;
///   ret → alan son kaydedilen değere döner (ağ TST-24, yetki TST-X18, diğer
///   günlük). Çevrimdışıyken hiçbir şey değişmez (TST-24).
/// * Aynı alana art arda dokunuş sıraya girer: süren yazım bitince state'teki
///   son değer bir kez daha yazılır (son dokunuş kazanır). Yazım sürerken
///   ekrandan çıkılsa da ViewModel yazım bitene kadar yaşar.
/// * `eventReminders` / `reminderTime` kaydı başarılıysa yerel hatırlatıcılar
///   baştan kurulur (`SessionViewModel.rescheduleReminders`, W-85). Sessiz
///   saat Mod C'de yalnızca kaydedilir; listeyi ve hatırlatıcıyı etkilemez
///   (CD-43, CD-148).
/// * Tür anahtarı kaydı başarılıysa NTF-01 tercih süzgeci yenilenir
///   (`NotificationsViewModel.refresh`, canlıysa).
@riverpod
final class NotificationPrefsViewModel extends _$NotificationPrefsViewModel
    with ProjectDependencyMixin, WriteGuardMixin, PermissionPromptMixin {
  /// Sunucunun bildiği son tercihler (geri alma hedefi).
  UserSettingsModel _saved = const UserSettingsModel();

  /// Yazımı süren alanlar (aynı alana ikinci yazıcı açılmaz).
  final Set<NotificationPrefField> _writing = {};

  bool _isLoading = false;

  @override
  NotificationPrefsState build() {
    // İlk okuma ilk karede başlar; ekran ayrıca çağırmaz.
    unawaited(Future<void>.microtask(fetch));
    return const NotificationPrefsState(isFetching: true);
  }

  String? get _uid =>
      ref.mounted ? ref.read(sessionViewModelProvider).uid : null;

  /// İlk okuma ve "Yeniden dene" (`NTF-02.retry`). Süren okuma varken gelen
  /// çağrı yok sayılır.
  Future<void> fetch() async {
    if (!ref.mounted || _isLoading) return;
    final session = ref.read(sessionViewModelProvider);
    final uid = session.uid;
    if (uid == null) {
      state = state.copyWith(isFetching: false, isError: true);
      return;
    }
    _isLoading = true;
    state = state.copyWith(isFetching: true, isError: false);
    final clubIds = _activeClubIds(session);
    final (settings, clubs, granted) = await (
      settingsRepository.getSettings(uid),
      _fetchClubs(clubIds),
      permissionService.isGranted(Permission.notification),
    ).wait;
    _isLoading = false;
    if (!ref.mounted) return;
    switch ((settings, clubs)) {
      case (FirebaseSuccess(:final data), FirebaseSuccess(data: final list)):
        _saved = data;
        final order = {for (final (i, id) in clubIds.indexed) id: i};
        state = state.copyWith(
          settings: data,
          clubs: [...list]
            ..sort((a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0)),
          permissionGranted: granted,
          showManagement: _managesAnyClub(session),
          isFetching: false,
        );
      case (FirebaseFailure(:final error, :final message), _) ||
          (_, FirebaseFailure(:final error, :final message)):
        AppLogger.warn(
          'Bildirim tercihleri okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isFetching: false, isError: true);
    }
  }

  /// SHT-07 kapandıktan sonra kulüp kayıtlarını (`settings.clubs`) yeniden
  /// okur ("Özelleştir" / "Sessize alındı" alt satırı). Genel tercihlere
  /// dokunmaz; hata yalnızca günlüğe yazılır.
  Future<void> refreshClubPrefs() async {
    final uid = _uid;
    if (uid == null || !state.isLoaded) return;
    final result = await settingsRepository.getSettings(uid);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        _saved = _saved.copyWith(clubs: data.clubs);
        state = state.copyWith(
          settings: state.settings.copyWith(clubs: data.clubs),
        );
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Kulüp bildirim tercihleri yenilenemedi: ${error.name}',
          error: message,
        );
    }
  }

  /// Açık / kapalı anahtar ([NotificationPrefField.typeToggles] ve
  /// [NotificationPrefField.quiet]).
  Future<void> toggle(NotificationPrefField field, {required bool value}) {
    assert(
      field != NotificationPrefField.reminderTime &&
          field != NotificationPrefField.quietRange,
      'toggle: $field açık / kapalı alan değil',
    );
    if (!state.isLoaded || state.isOn(field) == value) return Future.value();
    return _change(field, _withSwitch(state.settings, field, value: value));
  }

  /// "Sessiz saatler" anahtarı (`NTF-02.quiet`).
  Future<void> setQuiet({required bool value}) =>
      toggle(NotificationPrefField.quiet, value: value);

  /// Hatırlatma zamanı (`NTF-02.reminderTime.1h` / `.1d`). Yalnızca
  /// [ReminderOption.oneHour] ve [ReminderOption.oneDay] geçerlidir (CD-34);
  /// diğerleri yok sayılır.
  Future<void> setReminderTime(ReminderOption option) {
    if (option != ReminderOption.oneHour && option != ReminderOption.oneDay) {
      return Future.value();
    }
    if (!state.isLoaded || state.settings.reminderTime == option) {
      return Future.value();
    }
    return _change(
      NotificationPrefField.reminderTime,
      state.settings.copyWith(reminderTime: option),
    );
  }

  /// Sessiz saat aralığı (SHT-29 sonucu). Gece yarısını aşan aralık geçerlidir
  /// (22:00–08:00); başlangıç ile bitiş aynıysa aralık boştur, yazılmaz ve
  /// `false` döner. İki uç tek yamada gider.
  Future<bool> setQuietRange(TimeOfDayValue from, TimeOfDayValue to) async {
    if (!isValidQuietRange(from, to)) return false;
    if (!state.isLoaded) return false;
    if (state.quietFrom == from && state.quietTo == to) return true;
    await _change(
      NotificationPrefField.quietRange,
      state.settings.copyWith(quietFrom: from.hhmm, quietTo: to.hhmm),
    );
    return true;
  }

  /// Sessiz saat aralığı geçerli mi? Uçlar farklı olmalı; [from] > [to]
  /// gece yarısını aşan aralıktır.
  static bool isValidQuietRange(TimeOfDayValue from, TimeOfDayValue to) =>
      from != to;

  /// "İzni aç" (`NTF-02.permission`; prototip DLG-03).
  ///
  /// * İzin zaten varsa yalnızca durum güncellenir.
  /// * Sistem bir daha sormuyorsa (`needsSettings`) uygulamanın sistem
  ///   ayarları açılır; dönüşte [refreshPermission].
  /// * Aksi halde DLG-03 → sistem izni (`askNotificationPermission`; verilirse
  ///   TST-19). "Bir kez" bayrağı sonuçtan bağımsız işaretlenir.
  Future<void> enablePermission() async {
    if (!ref.mounted) return;
    final status = await permissionService.status(Permission.notification);
    if (!ref.mounted) return;
    if (status.isUsable) {
      state = state.copyWith(permissionGranted: true);
      return;
    }
    if (status.needsSettings) {
      if (!await permissionService.openAppSettings()) {
        AppLogger.info('Bildirim izni için sistem ayarları açılamadı');
      }
      return;
    }
    await askNotificationPermission();
    if (!ref.mounted) return;
    unawaited(
      ref
          .read(appPreferencesViewModelProvider.notifier)
          .markNotificationPermissionAsked(),
    );
    await refreshPermission();
  }

  /// Sistem bildirim iznini yeniden okur (uygulama ön plana dönünce).
  Future<void> refreshPermission() async {
    if (!ref.mounted) return;
    final granted = await permissionService.isGranted(Permission.notification);
    if (!ref.mounted || state.permissionGranted == granted) return;
    state = state.copyWith(permissionGranted: granted);
  }

  // ──────────────────────────────── yazma ───────────────────────────────────

  Future<void> _change(
    NotificationPrefField field,
    UserSettingsModel next,
  ) async {
    if (!ref.mounted) return;
    if (!ensureOnline()) return;
    state = state.copyWith(
      settings: next,
      savingKeys: {...state.savingKeys, field},
    );
    // Süren yazım bitince son değeri kendisi gönderir.
    if (_writing.contains(field)) return;
    await _flush(field);
  }

  Future<void> _flush(NotificationPrefField field) async {
    final uid = _uid;
    if (uid == null) {
      _revert(field);
      return;
    }
    _writing.add(field);
    // Ekran kapansa da yazım sonucu (geri alma / hatırlatıcı) işlenir.
    final link = ref.keepAlive();
    try {
      while (true) {
        final sending = state.settings;
        final result = await settingsRepository.updateSettings(
          uid,
          _patchOf(field, sending),
        );
        if (!ref.mounted) return;
        switch (result) {
          case FirebaseSuccess():
            _saved = _copyField(field, into: _saved, from: sending);
            // Yazım sürerken yeni dokunuş geldiyse son değer de gönderilir.
            if (_patchOf(field, state.settings) != _patchOf(field, sending)) {
              continue;
            }
            state = state.copyWith(
              savingKeys: {...state.savingKeys}..remove(field),
            );
            feedback.showToast(ToastId.tst19);
            _afterSave(field);
            return;
          case FirebaseFailure(:final error, :final message):
            if (!showWriteFailureToast(error)) {
              AppLogger.warn(
                'Bildirim tercihi yazılamadı (${field.name}): ${error.name}',
                error: message,
              );
            }
            _revert(field);
            return;
        }
      }
    } finally {
      _writing.remove(field);
      link.close();
    }
  }

  /// [field] alanını son kaydedilen değere döndürür.
  void _revert(NotificationPrefField field) {
    if (!ref.mounted) return;
    state = state.copyWith(
      settings: _copyField(field, into: state.settings, from: _saved),
      savingKeys: {...state.savingKeys}..remove(field),
    );
  }

  void _afterSave(NotificationPrefField field) {
    if (field.affectsReminders) {
      unawaited(
        ref.read(sessionViewModelProvider.notifier).rescheduleReminders(),
      );
    }
    if (field.affectsInbox && ref.exists(notificationsViewModelProvider)) {
      unawaited(ref.read(notificationsViewModelProvider.notifier).refresh());
    }
  }

  // ─────────────────────────────── yardımcılar ──────────────────────────────

  Future<FirestoreResult<List<ClubModel>>> _fetchClubs(List<String> ids) =>
      ids.isEmpty
      ? Future.value(const FirebaseSuccess(<ClubModel>[]))
      : clubRepository.getClubs(ids);

  /// Aktif üyeliklerin kulüpleri, başvuru sırasıyla (prototip `myClubs`:
  /// demo verideki üyelik sırası).
  static List<String> _activeClubIds(SessionState session) {
    final active = [
      for (final membership in session.memberships.values)
        if (membership.status == MembershipStatus.active) membership,
    ];
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    active.sort((a, b) {
      final byDate = (a.appliedAt ?? epoch).compareTo(b.appliedAt ?? epoch);
      return byDate != 0 ? byDate : a.clubId.compareTo(b.clubId);
    });
    return [for (final membership in active) membership.clubId];
  }

  static bool _managesAnyClub(SessionState session) =>
      session.memberships.keys.any((clubId) {
        final role = session.roleIn(clubId);
        return role == ClubRole.board || role == ClubRole.president;
      });

  static UserSettingsModel _withSwitch(
    UserSettingsModel settings,
    NotificationPrefField field, {
    required bool value,
  }) => switch (field) {
    NotificationPrefField.announcements => settings.copyWith(
      announcements: value,
    ),
    NotificationPrefField.eventReminders => settings.copyWith(
      eventReminders: value,
    ),
    NotificationPrefField.newEvents => settings.copyWith(newEvents: value),
    NotificationPrefField.applicationResults => settings.copyWith(
      applicationResults: value,
    ),
    NotificationPrefField.management => settings.copyWith(management: value),
    NotificationPrefField.system => settings.copyWith(system: value),
    NotificationPrefField.quiet => settings.copyWith(quiet: value),
    NotificationPrefField.reminderTime ||
    NotificationPrefField.quietRange => settings,
  };

  /// [field] alanının [settings]'teki değerini taşıyan tek alanlı yama.
  static UserSettingsPatch _patchOf(
    NotificationPrefField field,
    UserSettingsModel settings,
  ) => switch (field) {
    NotificationPrefField.announcements => UserSettingsPatch(
      announcements: settings.announcements,
    ),
    NotificationPrefField.eventReminders => UserSettingsPatch(
      eventReminders: settings.eventReminders,
    ),
    NotificationPrefField.newEvents => UserSettingsPatch(
      newEvents: settings.newEvents,
    ),
    NotificationPrefField.applicationResults => UserSettingsPatch(
      applicationResults: settings.applicationResults,
    ),
    NotificationPrefField.management => UserSettingsPatch(
      management: settings.management,
    ),
    NotificationPrefField.system => UserSettingsPatch(system: settings.system),
    NotificationPrefField.reminderTime => UserSettingsPatch(
      reminderTime: settings.reminderTime,
    ),
    NotificationPrefField.quiet => UserSettingsPatch(quiet: settings.quiet),
    NotificationPrefField.quietRange => UserSettingsPatch(
      quietFrom: settings.quietFrom,
      quietTo: settings.quietTo,
    ),
  };

  /// [into]'nun [field] alanı [from]'dakiyle değiştirilmiş kopyası.
  static UserSettingsModel _copyField(
    NotificationPrefField field, {
    required UserSettingsModel into,
    required UserSettingsModel from,
  }) => switch (field) {
    NotificationPrefField.reminderTime => into.copyWith(
      reminderTime: from.reminderTime,
    ),
    NotificationPrefField.quietRange => into.copyWith(
      quietFrom: from.quietFrom,
      quietTo: from.quietTo,
    ),
    _ => _withSwitch(
      into,
      field,
      value: NotificationPrefsState(settings: from).isOn(field),
    ),
  };
}
