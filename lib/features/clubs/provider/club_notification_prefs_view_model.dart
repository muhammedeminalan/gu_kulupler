import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_notification_prefs_state.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'club_notification_prefs_view_model.g.dart';

/// SHT-07 "Kulüp bildirimleri" ViewModel'i (kulüp başına bir örnek; prototip
/// `SHEETS['SHT-07']`, `sheets.js:37–38`).
///
/// * [load] kullanıcının ayarlar belgesinden kulübün kaydını okur
///   (`settings/{uid}.clubs[clubId]`; kayıt yoksa hepsi açık).
/// * [toggle] iyimserdir: değer önce state'e yazılır, sonra
///   `settingsRepository.updateClubSettings` çağrılır. Başarı → TST-38;
///   hata → son kaydedilen değere dönülür (ağ hatasında TST-24, diğerlerinde
///   `isError`). Çevrimdışıyken hiçbir şey değişmez (TST-24).
/// * "Tümünü sessize al" açılınca üç tür de kapanır, kapatılınca üçü de
///   açılır. Sessizdeyken diğer anahtarlara dokunmak yalnızca TST-X16
///   gösterir.
/// * Art arda dokunuşlar sıraya girer: süren yazım bitince state'teki son
///   değer bir kez daha yazılır (yarış yok, son dokunuş kazanır).
@riverpod
final class ClubNotificationPrefsViewModel
    extends _$ClubNotificationPrefsViewModel
    with ProjectDependencyMixin, WriteGuardMixin {
  static const Set<FirestoreError> _networkErrors = {
    FirestoreError.offline,
    FirestoreError.unavailable,
    FirestoreError.timeout,
  };

  /// Sunucunun bildiği son değer (geri alma hedefi).
  ClubNotificationPrefsModel _saved = const ClubNotificationPrefsModel();
  bool _isLoading = false;
  bool _isWriting = false;

  @override
  ClubNotificationPrefsState build(String clubId) {
    // Tercihler ilk karede okunmaya başlar; sheet ayrıca çağırmaz.
    unawaited(Future<void>.microtask(load));
    return const ClubNotificationPrefsState();
  }

  /// Ayarlar belgesini okur. Hata `isError` olur ("Yeniden dene" yine bunu
  /// çağırır); süren okuma varken gelen çağrı yok sayılır.
  Future<void> load() async {
    if (!ref.mounted || _isLoading) return;
    final uid = ref.read(sessionViewModelProvider).uid;
    if (uid == null) {
      state = state.copyWith(isError: true);
      return;
    }
    _isLoading = true;
    state = state.copyWith(isError: false);
    final result = await settingsRepository.getSettings(uid);
    _isLoading = false;
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        _saved = data.clubs[clubId] ?? const ClubNotificationPrefsModel();
        state = state.copyWith(prefs: _saved, isLoaded: true);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Kulüp bildirim tercihleri okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isError: true);
    }
  }

  /// [key] anahtarını [value] yapar (iyimser; sınıf açıklamasındaki kurallar).
  Future<void> toggle(ClubPrefKey key, {required bool value}) async {
    if (!state.isLoaded) return;
    if (state.isLocked(key)) {
      feedback.showToast(ToastId.tstX16);
      return;
    }
    final next = _apply(state.prefs, key, value);
    if (next == state.prefs) return;
    if (!ensureOnline()) return;
    state = state.copyWith(prefs: next, isSaving: true, isError: false);
    // Süren yazım bitince son değeri kendisi gönderir.
    if (_isWriting) return;
    await _flush();
  }

  static ClubNotificationPrefsModel _apply(
    ClubNotificationPrefsModel prefs,
    ClubPrefKey key,
    bool value,
  ) => switch (key) {
    ClubPrefKey.announcements => prefs.copyWith(announcements: value),
    ClubPrefKey.events => prefs.copyWith(events: value),
    ClubPrefKey.posts => prefs.copyWith(posts: value),
    // `sheets.js:38`: sessize alınca üç tür kapanır, açılınca üçü de açılır.
    ClubPrefKey.muted => ClubNotificationPrefsModel(
      announcements: !value,
      events: !value,
      posts: !value,
      muted: value,
    ),
  };

  Future<void> _flush() async {
    final uid = ref.read(sessionViewModelProvider).uid;
    if (uid == null) {
      state = state.copyWith(prefs: _saved, isSaving: false, isError: true);
      return;
    }
    _isWriting = true;
    try {
      while (true) {
        final sending = state.prefs;
        final result = await settingsRepository.updateClubSettings(
          uid,
          clubId,
          sending,
        );
        if (!ref.mounted) return;
        switch (result) {
          case FirebaseSuccess():
            _saved = sending;
            // Yazım sürerken yeni dokunuş geldiyse son değer de gönderilir.
            if (state.prefs != sending) continue;
            state = state.copyWith(isSaving: false);
            feedback.showToast(ToastId.tst38);
            return;
          case FirebaseFailure(:final error, :final message):
            final isNetwork = _networkErrors.contains(error);
            if (isNetwork) {
              feedback.showToast(ToastId.tst24);
            } else {
              AppLogger.warn(
                'Kulüp bildirim tercihleri yazılamadı: ${error.name}',
                error: message,
              );
            }
            state = state.copyWith(
              prefs: _saved,
              isSaving: false,
              isError: !isNetwork,
            );
            return;
        }
      }
    } finally {
      _isWriting = false;
    }
  }
}
