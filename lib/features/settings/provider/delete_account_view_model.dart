import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/settings/provider/delete_account_state.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/manage_member_actions_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_account_view_model.g.dart';

/// SET-03 Hesabı sil ekranının ViewModel'i (PLAN §12.6; prototip
/// `DeleteAccount`, `screens-profile.js:80–92`; domain-model §11; sözleşme
/// `docs/plans/T-29.md` §4).
///
/// **Adımlar:** 1 uyarı + başkanlık engeli ([load] → `precheck`; başkansa
/// [next] TST-X10 ile ilerlemez) · 2 ayrılma nedeni (isteğe bağlı,
/// saklanmaz) · 3 şifre + "SİL" ([confirm]).
///
/// **Başkanlık devri (W-34):** 1. adımdaki her kulübün "Devret"i
/// ([transfer]) SHT-25 (kulübün aktif üyeleri) → DLG-21 ("DEVRET") → M11 →
/// TST-49 akışını bu ekranda açar (`ManageMemberActionsMixin`); devirden
/// sonra ön denetim yeniden koşar, engel kalmadıysa "Devam" ilerler.
///
/// **[confirm] dizisi (§4 f):** doğrulama (eksikse TST-X11) → çevrimdışı
/// kapısı (TST-24) → `AuthRepository.reauthenticate` (yanlış şifre → alan
/// hatası; hiçbir şey yazılmamıştır) → `precheck` **yeniden** (yükleme ile
/// onay arası yarış; başkansa TST-X10 + 1. adım) → `markDeleted` (dönüşü
/// olmayan nokta; düşerse hiçbir şey değişmemiştir, yeniden denenebilir) →
/// `resumeCleanup` (her parçada [DeleteAccountState.progress]; hatası akışı
/// **durdurmaz** — kalan temizlik bir sonraki girişte oturum çözümünde sürer,
/// §4 b) → yerel hatırlatıcılar iptal → `SessionViewModel.signOut` → router
/// AUT-01'e taşır + TST-22. Oturum kapatılamazsa oturum yeniden çözülür:
/// silinmiş hesap orada kapatılır (giriş engeli).
///
/// Design: SET-03
@riverpod
final class DeleteAccountViewModel extends _$DeleteAccountViewModel
    with ProjectDependencyMixin, WriteGuardMixin, ManageMemberActionsMixin {
  @override
  DeleteAccountState build() {
    unawaited(Future<void>.microtask(load));
    return const DeleteAccountState();
  }

  String? get _uid =>
      ref.mounted ? ref.read(sessionViewModelProvider).uid : null;

  /// Başkanlık ön denetimi (`AccountDeletionRepository.precheck`) ve başkanı
  /// olunan kulüplerin adları. Kulüp adları okunamazsa kimlik gösterilir.
  Future<void> load() async {
    final uid = _uid;
    if (uid == null) return;
    state = state.copyWith(isChecking: true, isCheckError: false);
    final result = await accountDeletionRepository.precheck(uid);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'SET-03 ön denetimi okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isChecking: false, isCheckError: true);
      case FirebaseSuccess(data: DeletionReady()):
        state = state.copyWith(
          isChecking: false,
          presidentOfClubIds: const [],
          clubNames: const {},
        );
      case FirebaseSuccess(data: DeletionBlockedByPresidency(:final clubIds)):
        await _applyPresidency(clubIds);
    }
  }

  Future<void> _applyPresidency(List<String> clubIds) async {
    final clubs = await clubRepository.getClubs(clubIds);
    if (!ref.mounted) return;
    if (clubs case FirebaseFailure(:final error)) {
      AppLogger.warn('SET-03 kulüp adları okunamadı: ${error.name}');
    }
    state = state.copyWith(
      isChecking: false,
      isCheckError: false,
      presidentOfClubIds: clubIds,
      clubNames: {
        for (final club in clubs.dataOrNull ?? const <ClubModel>[])
          club.id: club.name,
      },
    );
  }

  @override
  SessionState? get memberSession =>
      ref.mounted ? ref.read(sessionViewModelProvider) : null;

  /// "Devret" (`SET-03.transfer.<clubId>`, W-34): SHT-25 → DLG-21 → M11 →
  /// TST-49. Devredildiyse `true`; başkanlık engeli yeniden denetlenir.
  /// Gönderim sürerken etkisizdir.
  Future<bool> transfer(String clubId) async {
    if (state.isSubmitting) return false;
    return transferPresidency(clubId);
  }

  @override
  void onPresidencyTransferred(
    String clubId, {
    required String fromUserId,
    required String toUserId,
  }) {
    if (ref.mounted) unawaited(load());
  }

  /// "Devam" (`SET-03.next`): sonraki adıma geçer ve `true` döner. 1. adımda
  /// başkanlık engeli varsa TST-X10 gösterir; ön denetim sürerken ya da
  /// okunamadıysa (yeniden dener) ilerlemez.
  bool next() {
    if (state.isSubmitting) return false;
    switch (state.step) {
      case DeleteStep.warning:
        if (state.isChecking) return false;
        if (state.isCheckError) {
          unawaited(load());
          return false;
        }
        if (state.isPresident) {
          feedback.showToast(ToastId.tstX10);
          return false;
        }
        state = state.copyWith(step: DeleteStep.reason);
        return true;
      case DeleteStep.reason:
        state = state.copyWith(step: DeleteStep.confirm);
        return true;
      case DeleteStep.confirm:
        return false;
    }
  }

  /// Geri (`SET-03.back`): önceki adıma döner ve `true` döner; 1. adımda
  /// `false` (ekran kapanır). Gönderim sürerken etkisizdir (`true`).
  bool back() {
    if (state.isSubmitting) return true;
    switch (state.step) {
      case DeleteStep.warning:
        return false;
      case DeleteStep.reason:
        state = state.copyWith(step: DeleteStep.warning);
      case DeleteStep.confirm:
        state = state.copyWith(step: DeleteStep.reason, clearSubmitError: true);
    }
    return true;
  }

  /// Neden seçildi (`SET-03.reason.<neden>`).
  void setReason(DeleteReason reason) => state = state.copyWith(reason: reason);

  /// Neden metni (`SET-03.reasonText`), [DeleteAccountState.reasonTextMax]
  /// karakterde kesilir.
  void setReasonText(String value) => state = state.copyWith(
    reasonText: value.length > DeleteAccountState.reasonTextMax
        ? value.substring(0, DeleteAccountState.reasonTextMax)
        : value,
  );

  /// Şifre (`SET-03.password`); şifre hatası temizlenir.
  void setPassword(String value) {
    if (value == state.password) return;
    state = state.copyWith(password: value, clearSubmitError: true);
  }

  /// Onay sözcüğü (`SET-03.confirmWord`).
  void setConfirmWord(String value) {
    if (value == state.confirmWord) return;
    state = state.copyWith(confirmWord: value);
  }

  /// Form onaylanabilir mi ([DeleteAccountState.canConfirm]); değilse
  /// TST-X11 gösterir ve `false` döner. [expectedWord] ARB
  /// `set03ConfirmWord`'dür.
  bool validate(String expectedWord) {
    if (state.canConfirm(expectedWord)) return true;
    feedback.showToast(ToastId.tstX11);
    return false;
  }

  /// "Hesabımı kalıcı olarak sil" (`SET-03.confirm`) — sınıf belgesindeki
  /// dizi.
  Future<DeleteOutcome> confirm(String expectedWord) async {
    final uid = _uid;
    if (uid == null || state.isSubmitting) return DeleteOutcome.ignored;
    if (!validate(expectedWord)) return DeleteOutcome.ignored;
    // Oturum `markDeleted`'dan sonra ekran kapansa da kapatılır: kalıcı
    // ViewModel baştan alınır (`ref` kapanınca okunamaz).
    final session = ref.read(sessionViewModelProvider.notifier);
    if (!ensureOnline()) {
      state = state.copyWith(submitError: DeleteError.network);
      return DeleteOutcome.failed;
    }
    state = state.copyWith(
      isSubmitting: true,
      clearSubmitError: true,
      clearProgress: true,
    );

    final reauth = await authRepository.reauthenticate(
      password: state.password,
    );
    if (!ref.mounted) return DeleteOutcome.failed;
    if (reauth case FirebaseFailure(:final error, :final message)) {
      return _failed(_authError(error, message));
    }

    switch (await accountDeletionRepository.precheck(uid)) {
      case FirebaseFailure(:final error):
        if (!ref.mounted) return DeleteOutcome.failed;
        return _failed(_dataError(error, 'ön denetim'));
      case FirebaseSuccess(data: DeletionBlockedByPresidency(:final clubIds)):
        if (!ref.mounted) return DeleteOutcome.failed;
        state = state.copyWith(
          step: DeleteStep.warning,
          isSubmitting: false,
          submitError: DeleteError.isPresident,
        );
        feedback.showToast(ToastId.tstX10);
        await _applyPresidency(clubIds);
        return DeleteOutcome.blockedByPresidency;
      case FirebaseSuccess(data: DeletionReady()):
        break;
    }
    if (!ref.mounted) return DeleteOutcome.failed;

    final marked = await accountDeletionRepository.markDeleted(uid);
    if (marked case FirebaseFailure(:final error)) {
      if (!ref.mounted) return DeleteOutcome.failed;
      return _failed(_dataError(error, 'markDeleted'));
    }

    // Dönüşü olmayan nokta geçildi: buradan sonra ekran kapansa da dizi
    // sürer, oturum kapanır.
    final cleanup = await accountDeletionRepository.resumeCleanup(
      uid,
      onProgress: (progress) {
        if (ref.mounted) state = state.copyWith(progress: progress);
      },
    );
    if (cleanup case FirebaseFailure(:final error, :final message)) {
      AppLogger.warn(
        'Hesap silme temizliği yarıda kaldı (sonraki girişte sürer): '
        '${error.name}',
        error: message,
      );
    }
    await localReminderService.cancelAll();
    await _closeSession(session);
    return DeleteOutcome.deleted;
  }

  /// Oturumu kapatır ve TST-22 gösterir; kapatılamazsa oturum yeniden
  /// çözülür (silinmiş hesap `SessionViewModel` içinde kapatılır).
  Future<void> _closeSession(SessionViewModel session) async {
    final signedOut = await session.signOut();
    if (signedOut) {
      feedback.showToast(ToastId.tst22);
      return;
    }
    await session.refreshUser();
  }

  DeleteOutcome _failed(DeleteError error) {
    state = state.copyWith(isSubmitting: false, submitError: error);
    if (error == DeleteError.network) feedback.showToast(ToastId.tst24);
    return DeleteOutcome.failed;
  }

  DeleteError _authError(AuthError error, String? message) => switch (error) {
    AuthError.invalidCredentials => DeleteError.wrongPassword,
    AuthError.tooManyRequests ||
    AuthError.lockedOut => DeleteError.tooManyRequests,
    AuthError.network => DeleteError.network,
    AuthError.invalidEmail ||
    AuthError.userDisabled ||
    AuthError.emailAlreadyInUse ||
    AuthError.weakPassword ||
    AuthError.requiresRecentLogin ||
    AuthError.sessionExpired ||
    AuthError.invalidActionCode ||
    AuthError.operationNotAllowed ||
    AuthError.unknown ||
    AuthError.domainNotAllowed ||
    AuthError.resendCooldown ||
    AuthError.emailNotVerified => _logged(
      DeleteError.unknown,
      'yeniden doğrulama: ${error.name}',
      message,
    ),
  };

  DeleteError _dataError(FirestoreError error, String step) =>
      WriteGuardMixin.networkErrors.contains(error)
      ? DeleteError.network
      : _logged(DeleteError.unknown, '$step: ${error.name}', null);

  static DeleteError _logged(DeleteError result, String what, String? detail) {
    AppLogger.warn('Hesap silinemedi — $what', error: detail);
    return result;
  }
}
