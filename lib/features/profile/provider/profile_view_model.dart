import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/profile/provider/profile_state.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/permission_prompt_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_view_model.g.dart';

/// PRF-01 "Profil" ekranının ViewModel'i (PLAN §12.6; prototip
/// `S['PRF-01']`, `screens-profile.js:6–15`).
///
/// * Kullanıcı, süper admin claim'i ve üyelikler oturumdan canlı gelir
///   (`SessionState`); açılışta iki okuma yapılır: aktif üyeliklerin kulüp
///   belgeleri (`clubRepository.getClubs`, tek toplu sorgu) ve katılım
///   kayıtları (`rsvpRepository.listMine` → `attended` sayısı). Bekleyen
///   başvuru sayısı oturumdan sayılır (ek okuma yok).
/// * Oturumda yeni bir aktif üyelik belirirse yalnızca eksik kulüp
///   belgeleri okunur.
/// * Profil fotoğrafı (`PRF-01.avatar` → SHT-16): seçim
///   `PermissionPromptMixin.pickImage`; yazım `userRepository.updateAvatar`
///   (profil tamamlanmış — yamasız, W-57) → TST-57 → oturum yenilenir.
///   Seçilen görsel yazım sürerken iyimser gösterilir; hata → eski görsel.
/// * Sheet açma ve gezinme view'dadır; toast'lar buradan.
///
/// | İşlem | Sonuç | Geri bildirim |
/// |---|---|---|
/// | [fetch] / [refresh] | okunamadı | hata görünümü / içerik kalır |
/// | [changeAvatar] | yazıldı | TST-57 |
/// | | çevrimdışı / ağ · yetki yok | TST-24 · TST-X18 |
/// | | izin reddi | TST-32 (`pickImage`) |
///
/// Design: PRF-01
@riverpod
final class ProfileViewModel extends _$ProfileViewModel
    with ProjectDependencyMixin, WriteGuardMixin, PermissionPromptMixin {
  /// Yükleme adımının bağlantı hataları (→ TST-24).
  static const Set<StorageError> _networkUploadErrors = {
    StorageError.retryLimitExceeded,
    StorageError.timeout,
  };

  bool _isLoading = false;
  bool _isLoadingClubs = false;

  /// Belgesi istenmiş kulüpler (okunamayan / silinmiş kulüp oturum her
  /// değiştiğinde yeniden istenmez).
  final Set<String> _requestedClubIds = {};

  /// Son yüklenen fotoğrafın Storage yolu: oturumdaki `avatarPath` bu yola
  /// dönene kadar yerel önizleme kalır (adres çözülürken baş harfler
  /// görünmez).
  String? _previewPath;

  @override
  ProfileState build() {
    ref.listen(sessionViewModelProvider, (previous, session) {
      if (previous?.user != session.user ||
          previous?.isSuperAdmin != session.isSuperAdmin ||
          previous?.memberships != session.memberships) {
        _syncSession(session);
      }
    });
    // İlk okuma ilk karede başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    final session = ref.read(sessionViewModelProvider);
    return ProfileState(
      user: session.user,
      isSuperAdmin: session.isSuperAdmin,
      memberships: session.memberships.values.toList(growable: false),
      isFetching: true,
    );
  }

  String? get _uid =>
      ref.mounted ? ref.read(sessionViewModelProvider).uid : null;

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// Yeniden okur — hata görünümündeki "Yeniden dene". Süren okuma varken
  /// gelen çağrı yok sayılır.
  Future<void> fetch() async {
    if (!ref.mounted || _isLoading) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _load();
  }

  /// Çek-yenile: iskelet göstermeden okur; okunamazsa içerik kalır.
  Future<void> refresh() async {
    if (!ref.mounted || _isLoading || state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true);
    await _load();
  }

  // ─────────────────────────────── fotoğraf ─────────────────────────────────

  /// SHT-16'da seçilen [source] kaynağından profil fotoğrafını değiştirir.
  /// Süren bir yazım varken ya da seçimden vazgeçilirse etkisizdir.
  Future<void> changeAvatar(MediaSource source) async {
    final uid = _uid;
    if (uid == null || state.isUpdatingAvatar) return;
    final picked = await pickImage(source);
    if (!ref.mounted) return;
    final PickedImage image;
    switch (picked) {
      case ImagePickSuccess(image: final value):
        image = value;
      case ImagePickCancelled() ||
          ImagePickFailure(error: ImagePickError.permissionDenied):
        return;
      case ImagePickFailure(:final error):
        // Boyut / tür hatasının PRF-01'de toast karşılığı yok (TST kataloğu).
        AppLogger.warn('Profil fotoğrafı seçilemedi: ${error.name}');
        return;
    }
    if (!ensureOnline()) return;
    state = state.copyWith(avatarPreview: image.bytes, isUpdatingAvatar: true);
    final session = ref.read(sessionViewModelProvider.notifier);
    final result = await userRepository.updateAvatar(
      uid,
      bytes: image.bytes,
      contentType: image.contentType,
    );
    switch (result) {
      case FirebaseSuccess(:final data):
        _previewPath = data;
        feedback.showToast(ToastId.tst57);
        if (ref.mounted) state = state.copyWith(isUpdatingAvatar: false);
        await session.refreshUser();
        if (ref.mounted) _syncSession(ref.read(sessionViewModelProvider));
      case FirebaseFailure(:final error, :final message):
        _showAvatarFailure(error, message);
        if (ref.mounted) {
          state = state.copyWith(
            clearAvatarPreview: true,
            isUpdatingAvatar: false,
          );
        }
    }
  }

  // ────────────────────────────────── iç ────────────────────────────────────

  void _showAvatarFailure(MediaUpdateError error, String? message) {
    final storage = error.storage;
    final firestore = error.firestore;
    if (storage != null && _networkUploadErrors.contains(storage)) {
      feedback.showToast(ToastId.tst24);
      return;
    }
    if (firestore != null && showWriteFailureToast(firestore)) return;
    AppLogger.warn('Profil fotoğrafı yazılamadı: $error', error: message);
  }

  static List<String> _activeClubIds(Iterable<MembershipModel> memberships) => [
    for (final membership in memberships)
      if (membership.isActiveMember) membership.clubId,
  ];

  /// Oturumdaki değişikliği state'e yansıtır; yeni aktif üyeliğin kulübü
  /// okunmamışsa okur.
  void _syncSession(SessionState session) {
    if (!ref.mounted) return;
    final memberships = session.memberships.values.toList(growable: false);
    final keepsPreview =
        state.isUpdatingAvatar ||
        (_previewPath != null && session.user?.avatarPath == _previewPath);
    state = state.copyWith(
      user: session.user,
      isSuperAdmin: session.isSuperAdmin,
      memberships: memberships,
      clearAvatarPreview: !keepsPreview,
    );
    if (!keepsPreview) _previewPath = null;
    _fillMissingClubs();
  }

  /// Okunmuş içerikte belgesi olmayan aktif üyelik kulüplerini okur.
  void _fillMissingClubs() {
    if (_isLoading || state.isFetching || state.isError) return;
    final missing = [
      for (final id in _activeClubIds(state.memberships))
        if (!_requestedClubIds.contains(id)) id,
    ];
    if (missing.isNotEmpty) unawaited(_loadClubs(missing));
  }

  /// Oturumda sonradan beliren kulüplerin belgeleri; okunamazsa satırlar
  /// bir sonraki yenilemeye kalır.
  Future<void> _loadClubs(List<String> clubIds) async {
    if (_isLoadingClubs) return;
    _isLoadingClubs = true;
    _requestedClubIds.addAll(clubIds);
    try {
      final result = await clubRepository.getClubs(clubIds);
      if (!ref.mounted) return;
      switch (result) {
        case FirebaseSuccess(:final data):
          state = state.copyWith(
            clubs: {...state.clubs, for (final club in data) club.id: club},
          );
        case FirebaseFailure(:final error, :final message):
          _requestedClubIds.removeAll(clubIds);
          AppLogger.warn('Kulüpler okunamadı: ${error.name}', error: message);
      }
    } finally {
      _isLoadingClubs = false;
    }
  }

  /// Kulüp belgelerini ve katılım kayıtlarını okur.
  Future<void> _load() async {
    if (!ref.mounted || _isLoading) return;
    final uid = _uid;
    if (uid == null) {
      state = state.copyWith(isFetching: false, isRefreshing: false);
      return;
    }
    _isLoading = true;
    try {
      final clubIds = _activeClubIds(state.memberships);
      _requestedClubIds
        ..clear()
        ..addAll(clubIds);
      final clubsFuture = clubRepository.getClubs(
        clubIds,
        forceRefresh: state.isRefreshing,
      );
      // Yalnızca "katıldı" kayıtları sayılır (T-44 · D3-02).
      final rsvpsFuture = rsvpRepository.listMine(
        uid,
        statuses: {RsvpStatus.attended},
      );
      final clubs = await clubsFuture;
      final rsvps = await rsvpsFuture;
      if (!ref.mounted) return;
      switch ((clubs, rsvps)) {
        case (
          FirebaseSuccess(data: final clubList),
          FirebaseSuccess(data: final rsvpList),
        ):
          state = state.copyWith(
            clubs: {for (final club in clubList) club.id: club},
            attendedCount: rsvpList
                .where((r) => !r.isDeleted && r.status == RsvpStatus.attended)
                .length,
            isFetching: false,
            isRefreshing: false,
            isError: false,
          );
        case (FirebaseFailure(:final error, :final message), _) ||
            (_, FirebaseFailure(:final error, :final message)):
          AppLogger.warn('Profil okunamadı: ${error.name}', error: message);
          state = state.copyWith(
            isFetching: false,
            isRefreshing: false,
            // Çek-yenile hatası içeriği silmez.
            isError: !state.isRefreshing || state.isError,
          );
      }
    } finally {
      _isLoading = false;
    }
    // Okuma sürerken oturuma eklenen üyelikler.
    if (ref.mounted) _fillMissingClubs();
  }
}
