import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_kulupler/product/mixin/form_validation_mixin.dart';
import 'package:gu_kulupler/product/mixin/membership_dialogs_mixin.dart';
import 'package:gu_kulupler/product/mixin/permission_prompt_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'club_application_view_model.g.dart';

/// CLB-04 "İsteğin iletildi" ve CLB-05 "Başvuru durumu" ekranlarının ortak
/// ViewModel'i (kulüp başına bir örnek; PLAN §12.6, prototip
/// `screens-clubs.js:114–138`).
///
/// * Kulübü, başvuru notunu (`memberships/{id}/private/contact` — CD-137) ve
///   bildirim iznini açılışta okur ([fetch]). Üyelik belgesi oturumdan canlı
///   gelir (`SessionState.memberships`): yönetici karar verince ekran
///   kendiliğinden güncellenir.
/// * Yazan her işlem çevrimdışı kapısından geçer (TST-24). Gezinme view'dadır.
///
/// | İşlem | Sonuç | Geri bildirim |
/// |---|---|---|
/// | [saveNote] | not `private/contact`'a yazıldı | TST-07 |
/// | | kulüp not istiyor, not boş | alan hatası |
/// | [cancel] | DLG-07 onayı → `pending → cancelled` | TST-40 (view kulübe döner) |
/// | [reapply] | kulüp başvuru almıyor | TST-X1 |
/// | | bekleme süresi dolmadı | TST-X4 `{date}` |
/// | | onay gerekli / eski kayıt | [ReapplyOutcome.openSheet] (SHT-05) |
/// | | onaysız kulüp | anında katılım → TST-34 ("Kulübe git") |
/// | [enableNotifications] | DLG-03 → sistem izni | TST-19, kart kalkar |
/// | hepsi | çevrimdışı / ağ | TST-24 |
/// | | yetki yok | TST-X18 |
/// | | diğer | `submitError` (ekran içi hata satırı) |
///
/// Design: CLB-04, CLB-05
@riverpod
final class ClubApplicationViewModel extends _$ClubApplicationViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        FormValidationMixin<ApplicationField>,
        MembershipDialogsMixin,
        PermissionPromptMixin {
  static const Set<FirestoreError> _networkErrors = {
    FirestoreError.offline,
    FirestoreError.unavailable,
    FirestoreError.timeout,
  };

  /// Onaysız kulüpte de yönetici onayına giden önceki durumlar (rules-spec
  /// §3.4 M3 / M4): bu kullanıcılar anında katılamaz, başvuru formuna gider.
  static const Set<MembershipStatus> _reviewStatuses = {
    MembershipStatus.rejected,
    MembershipStatus.removed,
    MembershipStatus.cancelled,
  };

  /// Okuma sırası: yavaş kalan eski okuma yenisinin sonucunu ezmez.
  int _epoch = 0;

  /// DLG-07 açık mı? Onay beklenirken gelen ikinci iptal yok sayılır.
  bool _isConfirming = false;

  @override
  ClubApplicationState build(String clubId) {
    ref.listen(sessionViewModelProvider, (_, session) {
      final membership = session.memberships[clubId];
      if (membership != state.membership) _onMembershipChanged(membership);
    });
    // Okuma ilk karede başlar; ekranlar ayrıca çağırmaz.
    unawaited(Future<void>.microtask(fetch));
    return ClubApplicationState(
      membership: ref.read(sessionViewModelProvider).memberships[clubId],
      isFetching: true,
    );
  }

  String? get _uid => ref.read(sessionViewModelProvider).uid;

  /// Kulübü, başvuru notunu ve bildirim iznini okur; "Yeniden dene" yine
  /// bunu çağırır.
  ///
  /// Kulüp yoksa / silinmişse `isNotFound` (→ SYS-04); kulüp ya da not
  /// okunamazsa `isError`. Kullanıcı notu düzenlemeye başladıysa taslağı
  /// korunur.
  Future<void> fetch() async {
    if (!ref.mounted) return;
    final epoch = ++_epoch;
    state = state.copyWith(isFetching: true, isError: false, isNotFound: false);
    final uid = _uid;
    if (uid == null) {
      state = state.copyWith(isFetching: false, isError: true);
      return;
    }
    final (clubResult, contactResult, granted) = await (
      clubRepository.getClub(clubId),
      membershipRepository.readContact(clubId, uid),
      permissionService.isGranted(Permission.notification),
    ).wait;
    if (!ref.mounted || epoch != _epoch) return;

    switch ((clubResult, contactResult)) {
      case (
        FirebaseFailure(
          error: FirestoreError.notFound || FirestoreError.invalidArgument,
        ),
        _,
      ):
        state = state.copyWith(isFetching: false, isNotFound: true);
      case (FirebaseFailure(:final error, :final message), _) ||
          (_, FirebaseFailure(:final error, :final message)):
        AppLogger.warn('Başvuru okunamadı: ${error.name}', error: message);
        state = state.copyWith(isFetching: false, isError: true);
      case (
        FirebaseSuccess(data: final club),
        FirebaseSuccess(data: final contact),
      ):
        final saved = contact?.note ?? '';
        state = state.copyWith(
          club: club,
          savedNote: saved,
          note: state.isDirty ? state.note : saved,
          showNotificationPrompt: !granted,
          isFetching: false,
        );
    }
  }

  /// Not alanı değişti (`CLB-05.note`): alan ve sunucu hatası silinir. Not
  /// kaydedilirken yok sayılır.
  void setNote(String value) {
    if (state.isSaving) return;
    if (value == state.note &&
        state.errors.isEmpty &&
        state.submitError == null) {
      return;
    }
    state = state.copyWith(
      note: value,
      errors: const {},
      clearSubmitError: true,
    );
  }

  /// Notu doğrular (`club.requireNote` ise zorunlu, en çok
  /// `Limits.applicationNoteMax`) ve hataları state'e yazar; geçerliyse
  /// `true`.
  bool validate() {
    final errors = validateFields({
      ApplicationField.note: () => fromFieldError(
        FieldValidators.applicationNote(
          state.note.trim(),
          requireNote: state.club?.requireNote ?? false,
        ),
      ),
    });
    state = state.copyWith(errors: errors);
    return errors.isEmpty;
  }

  /// "Kaydet" (`CLB-05.saveNote`): bekleyen başvurunun notunu günceller →
  /// TST-07.
  ///
  /// Sıra: süren yazım, değişmemiş ya da sınırı aşan not → yok say (düğme
  /// kapalıdır); doğrulama; çevrimdışı
  /// kapısı (TST-24); `membershipRepository.updateApplicationNote` (yalnızca
  /// `private/contact.note` yazılır — CD-137). Başvuru bu arada karara
  /// bağlandıysa (`conflict`) not yazılmaz; ekran canlı üyelikle güncellenir.
  Future<void> saveNote() async {
    final uid = _uid;
    if (uid == null || state.club == null || state.isBusy) return;
    if (!state.canSaveNote) return;
    if (!validate()) return;
    if (!ensureOnline()) return;

    final note = state.note.trim();
    state = state.copyWith(isSaving: true, clearSubmitError: true);
    final result = await membershipRepository.updateApplicationNote(
      clubId: clubId,
      userId: uid,
      note: note,
    );
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess():
        state = state.copyWith(isSaving: false, savedNote: note);
        feedback.showToast(ToastId.tst07);
      case FirebaseFailure(error: FirestoreError.invalidArgument):
        // Kulüp bu arada not zorunluluğu getirmiş olabilir.
        state = state.copyWith(
          isSaving: false,
          errors: {
            ApplicationField.note: note.isEmpty
                ? FormFieldError.required
                : FormFieldError.tooLong,
          },
        );
      case FirebaseFailure(:final error, :final message):
        state = state.copyWith(isSaving: false);
        _onWriteFailure(error, 'Başvuru notu kaydedilemedi', message);
    }
  }

  /// "İsteği iptal et" (`CLB-05.cancel`): DLG-07 onayı → başvuru geri çekilir
  /// (`pending → cancelled`) → TST-40. İptal edildiyse `true` (view kulüp
  /// sayfasına döner).
  ///
  /// Sıra: süren yazım / açık onay → yok say; DLG-07; çevrimdışı kapısı
  /// (TST-24);
  /// `membershipRepository.cancelApplication`. Başvuru bu arada karara
  /// bağlandıysa (`conflict`) hiçbir şey yazılmaz; ekran canlı üyelikle
  /// güncellenir.
  Future<bool> cancel() async {
    final uid = _uid;
    final club = state.club;
    if (uid == null || club == null || state.isBusy) return false;
    if (state.phase != ApplicationPhase.pending || _isConfirming) return false;
    _isConfirming = true;
    final confirmed = await confirmCancelApplication(clubName: club.name);
    _isConfirming = false;
    if (!confirmed || !ref.mounted || state.isBusy) return false;
    if (!ensureOnline()) return false;

    state = state.copyWith(isCancelling: true, clearSubmitError: true);
    final result = await membershipRepository.cancelApplication(
      clubId: clubId,
      userId: uid,
    );
    if (!ref.mounted) return result.isSuccess;
    state = state.copyWith(isCancelling: false);
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(ToastId.tst40);
        return true;
      case FirebaseFailure(:final error, :final message):
        _onWriteFailure(error, 'Başvuru iptal edilemedi', message);
        return false;
    }
  }

  /// "Tekrar başvur" / "Katıl" (`CLB-05.reapply`) — prototip `startJoin`
  /// (`cards.js:11–18`). Düğme devre dışı görünürken de çağrılır: neden
  /// başvurulamadığını toast söyler. [formatDate] TST-X4'ün `{date}` metnini
  /// üretir (yerel ayara göre biçimleme view'dadır).
  ///
  /// Sıra: kulüp başvuru almıyor → TST-X1; bekleme süresi → TST-X4; onay
  /// gerekli ya da eski kayıt (`rejected` / `removed` / `cancelled`) →
  /// [ReapplyOutcome.openSheet]; onaysız kulüp → çevrimdışı kapısı →
  /// `membershipRepository.joinInstant` → TST-34 ([onOpenClub] toastın
  /// "Kulübe git" eylemidir; gezinme view'dadır).
  Future<ReapplyOutcome> reapply({
    required String Function(DateTime retryAfter) formatDate,
    required VoidCallback onOpenClub,
  }) async {
    final club = state.club;
    if (club == null || state.isBusy) return ReapplyOutcome.failed;
    if (club.isSuspended || !club.applicationsOpen) {
      feedback.showToast(ToastId.tstX1);
      return ReapplyOutcome.blocked;
    }
    final retryAfter = state.retryAfter;
    if (retryAfter != null && !state.canReapplyAt(appClock.nowUtc())) {
      _showCooldown(formatDate(retryAfter));
      return ReapplyOutcome.blocked;
    }
    if (club.approvalRequired ||
        _reviewStatuses.contains(state.membership?.status)) {
      return ReapplyOutcome.openSheet;
    }
    if (!ensureOnline()) return ReapplyOutcome.failed;

    final applicant = ref.read(sessionViewModelProvider).user;
    final email = authRepository.currentUser?.email;
    if (applicant == null || email == null) {
      AppLogger.warn('Kulübe katılınamadı: oturumda profil / e-posta yok');
      state = state.copyWith(submitError: SubmitError.unknown);
      return ReapplyOutcome.failed;
    }

    state = state.copyWith(isJoining: true, clearSubmitError: true);
    final result = await membershipRepository.joinInstant(
      clubId: clubId,
      applicant: applicant,
      email: email,
    );
    if (!ref.mounted) {
      return result.isSuccess ? ReapplyOutcome.joined : ReapplyOutcome.failed;
    }
    state = state.copyWith(isJoining: false);
    switch (result) {
      case FirebaseSuccess():
        showJoined(onOpenClub: onOpenClub);
        return ReapplyOutcome.joined;
      case FirebaseFailure(
        error: FirestoreError.ruleViolation,
        detail: FirestoreFailureDetail(:final code, retryAfter: final until),
      ):
        return _onJoinRule(code, until ?? retryAfter, formatDate);
      case FirebaseFailure(error: FirestoreError.conflict):
        // Kulüp bu arada onaya geçti ya da üyelik değişti: kulüp yeniden
        // okunur, sonraki dokunuş güncel yola gider.
        unawaited(fetch());
        return ReapplyOutcome.failed;
      case FirebaseFailure(:final error, :final message):
        _onWriteFailure(error, 'Kulübe katılınamadı', message);
        return ReapplyOutcome.failed;
    }
  }

  /// TST-34 "Kulübe katıldın!" + "Kulübe git" (`actions.js:209`). Anında
  /// katılımdan ([reapply]) ve SHT-05 katılımla kapandığında view'dan
  /// çağrılır.
  void showJoined({required VoidCallback onOpenClub}) =>
      feedback.showToast(ToastId.tst34, onAction: onOpenClub);

  /// "Aç" (`CLB-04.enableNotifications`): DLG-03 ön açıklaması → sistem
  /// bildirim izni. İzin verilirse TST-19 gösterilir ve kart kalkar; "Şimdi
  /// değil" ya da ret kartı yerinde bırakır. Sonuç ne olursa olsun "bir kez"
  /// bayrağı işaretlenir (kabuk ayrıca sormaz).
  Future<void> enableNotifications() async {
    final granted = await askNotificationPermission();
    if (!ref.mounted) return;
    unawaited(
      ref
          .read(appPreferencesViewModelProvider.notifier)
          .markNotificationPermissionAsked(),
    );
    if (granted) state = state.copyWith(showNotificationPrompt: false);
  }

  /// [now] anında yeniden başvuruya kalan süre; bekleme yoksa `null`.
  Duration? remainingUntilRetry(DateTime now) => state.remainingUntilRetry(now);

  /// Oturumdaki üyelik değişti (başvuru, karar, iptal). Yeni bir başvuru
  /// açıldıysa (`pending`'e geçiş) not `private/contact`'ta değişmiştir:
  /// yeniden okunur.
  void _onMembershipChanged(MembershipModel? next) {
    final previous = state.membership;
    state = state.copyWith(membership: next, clearMembership: next == null);
    if (next?.status == MembershipStatus.pending &&
        previous?.status != MembershipStatus.pending) {
      unawaited(_reloadNote());
    }
  }

  /// Notu sessizce yeniden okur (iskelet yok); okunamazsa eldeki not kalır.
  Future<void> _reloadNote() async {
    final uid = _uid;
    if (uid == null) return;
    final result = await membershipRepository.readContact(clubId, uid);
    if (!ref.mounted) return;
    if (result case FirebaseSuccess(:final data)) {
      final saved = data?.note ?? '';
      state = state.copyWith(
        savedNote: saved,
        note: state.isDirty ? state.note : saved,
      );
    }
  }

  ReapplyOutcome _onJoinRule(
    FirestoreRuleCode code,
    DateTime? retryAfter,
    String Function(DateTime retryAfter) formatDate,
  ) {
    switch (code) {
      case FirestoreRuleCode.applicationsClosed:
        feedback.showToast(ToastId.tstX1);
        return ReapplyOutcome.blocked;
      case FirestoreRuleCode.retryCooldown:
        if (retryAfter != null) _showCooldown(formatDate(retryAfter));
        return ReapplyOutcome.blocked;
      case FirestoreRuleCode.reapplyNeedsReview:
        // Oturumdaki üyelik eskiydi: eski kaydı olan kullanıcı formla girer.
        return ReapplyOutcome.openSheet;
      case FirestoreRuleCode.capacityFull ||
          FirestoreRuleCode.registrationClosed ||
          FirestoreRuleCode.eventEnded ||
          FirestoreRuleCode.announcementLimit ||
          FirestoreRuleCode.presidentCannotLeave ||
          FirestoreRuleCode.presidentCannotBeRemoved ||
          FirestoreRuleCode.eventHasRegistrations ||
          FirestoreRuleCode.attendanceWindowClosed ||
          FirestoreRuleCode.notMember ||
          FirestoreRuleCode.reportLimit:
        // Üyelik geçişlerinde üretilmeyen kurallar.
        AppLogger.warn('Kulübe katılınamadı: ${code.name}');
        state = state.copyWith(submitError: SubmitError.unknown);
        return ReapplyOutcome.failed;
    }
  }

  /// Yazım hatalarının ortak eşlemesi: ağ → TST-24; yetki → TST-X18; kulüp
  /// yok → SYS-04; başvuru bu arada değişti (`conflict`) → sessiz (canlı
  /// üyelik ekranı günceller); diğer → `submitError`.
  void _onWriteFailure(FirestoreError error, String what, String? message) {
    if (_networkErrors.contains(error)) {
      feedback.showToast(ToastId.tst24);
      return;
    }
    switch (error) {
      case FirestoreError.permissionDenied || FirestoreError.unauthenticated:
        feedback.showToast(ToastId.tstX18);
      case FirestoreError.notFound:
        state = state.copyWith(isNotFound: true);
      case FirestoreError.conflict:
        AppLogger.warn('$what: başvuru bu arada değişti');
        state = state.copyWith(submitError: SubmitError.conflict);
      case FirestoreError.alreadyExists ||
          FirestoreError.aborted ||
          FirestoreError.unavailable ||
          FirestoreError.invalidArgument ||
          FirestoreError.failedPrecondition ||
          FirestoreError.resourceExhausted ||
          FirestoreError.cancelled ||
          FirestoreError.unknown ||
          FirestoreError.timeout ||
          FirestoreError.parse ||
          FirestoreError.offline ||
          FirestoreError.ruleViolation:
        AppLogger.warn('$what: ${error.name}', error: message);
        state = state.copyWith(submitError: SubmitError.unknown);
    }
  }

  /// TST-X4 "{date} tarihine kadar tekrar başvuramazsın."
  void _showCooldown(String date) =>
      feedback.showToast(ToastId.tstX4, params: ToastParams(date: date));
}
