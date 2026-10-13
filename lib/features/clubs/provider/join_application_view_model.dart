import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/join_application_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/form_validation_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'join_application_view_model.g.dart';

/// SHT-05 "Katılma başvurusu" formunun ViewModel'i (kulüp başına bir örnek;
/// prototip `SHEETS['SHT-05']`, `sheets.js:27–32`).
///
/// * Kulübü açılışta okur ([fetch]); üyelik belgesi oturumdan canlı gelir
///   (`SessionState.memberships`).
/// * [submit] notu doğrular (`club.requireNote` ise zorunlu, en çok
///   `Limits.applicationNoteMax`), çevrimdışı kapısından geçer ve başvuruyu
///   yazar: onay isteyen kulüpte `membershipRepository.apply` (not
///   `private/contact` belgesine gider — CD-137), onaysız kulüpte
///   `joinInstant`. Onaysız kulüpte eski kaydı (`rejected` / `removed` /
///   `cancelled`) olan kullanıcı yine `apply` ile yönetici onayına gider.
/// * Reddedilen yollar: kulüp başvuru almıyor → TST-X1; yeniden başvuru
///   bekleme süresi → TST-X4 (`{date}`); çevrimdışı / ağ hatası → TST-24;
///   diğer sunucu hataları `submitError` olarak formda gösterilir.
/// * Başarı bildirimi ve gezinme çağırandadır: sheet sonuçla kapanır
///   ([JoinApplicationOutcome.applied] → CLB-04,
///   [JoinApplicationOutcome.joined] → TST-34).
@riverpod
final class JoinApplicationViewModel extends _$JoinApplicationViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        FormValidationMixin<JoinApplicationField> {
  static const Set<FirestoreError> _networkErrors = {
    FirestoreError.offline,
    FirestoreError.unavailable,
    FirestoreError.timeout,
  };

  /// UTF-16 üst vekil aralığı (U+D800–U+DBFF).
  static const int _highSurrogateStart = 0xD800;
  static const int _highSurrogateEnd = 0xDBFF;

  bool _isLoading = false;

  @override
  JoinApplicationState build(String clubId) {
    ref.listen(sessionViewModelProvider, (_, session) {
      final membership = session.memberships[clubId];
      if (membership == state.membership) return;
      state = state.copyWith(
        membership: membership,
        clearMembership: membership == null,
      );
    });
    // Kulüp ilk karede okunmaya başlar; sheet ayrıca çağırmaz.
    unawaited(Future<void>.microtask(fetch));
    return JoinApplicationState(
      membership: ref.read(sessionViewModelProvider).memberships[clubId],
      isFetching: true,
    );
  }

  /// [value] metnini `Limits.applicationNoteMax` UTF-16 birimine keser
  /// (`sheets.js:31` `v.slice(0, 300)`); yarım vekil çift (emoji) bırakmaz.
  static String clampNote(String value) {
    const max = Limits.applicationNoteMax;
    if (value.length <= max) return value;
    final unit = value.codeUnitAt(max - 1);
    final splitsPair = unit >= _highSurrogateStart && unit <= _highSurrogateEnd;
    return value.substring(0, splitsPair ? max - 1 : max);
  }

  /// Kulübü okur (`clubRepository.getClub`). Silinmiş kulüp ve okuma hatası
  /// `isError` olur; "Yeniden dene" yine bunu çağırır. Süren okuma varken
  /// gelen çağrı yok sayılır.
  Future<void> fetch() async {
    if (!ref.mounted || _isLoading) return;
    _isLoading = true;
    state = state.copyWith(isFetching: true, isError: false);
    final result = await clubRepository.getClub(clubId);
    _isLoading = false;
    if (!ref.mounted) return;
    state = switch (result) {
      FirebaseSuccess(:final data) => state.copyWith(
        club: data,
        isFetching: false,
      ),
      FirebaseFailure() => state.copyWith(isFetching: false, isError: true),
    };
  }

  /// Not değişti: sınıra kesilir ([clampNote]), alan ve sunucu hatası
  /// silinir. Süren gönderim kendi notunu taşır; o sırada yazılan metin
  /// yalnızca formda kalır (alan ile state ayrışmaz).
  void setNote(String value) {
    final note = clampNote(value);
    if (note == state.note &&
        state.errors.isEmpty &&
        state.submitError == null) {
      return;
    }
    state = state.copyWith(
      note: note,
      errors: const {},
      clearSubmitError: true,
    );
  }

  /// Notu doğrular ve hataları state'e yazar; geçerliyse `true`.
  bool validate() {
    final errors = validateFields({
      JoinApplicationField.note: () => fromFieldError(
        FieldValidators.applicationNote(
          state.note.trim(),
          requireNote: state.requireNote,
        ),
      ),
    });
    state = state.copyWith(errors: errors);
    return errors.isEmpty;
  }

  /// Başvuruyu gönderir. [formatDate] TST-X4'ün `{date}` metnini üretir
  /// (yerel ayara göre biçimleme view'dadır).
  ///
  /// Sıra: bekleme süresi → doğrulama → çevrimdışı kapısı → yazım. Sonuçlar
  /// [JoinApplicationOutcome]'da.
  Future<JoinApplicationOutcome> submit({
    required String Function(DateTime retryAfter) formatDate,
  }) async {
    if (state.club == null || state.isSubmitting) {
      return JoinApplicationOutcome.ignored;
    }
    final retryAfter = state.retryAfter;
    if (retryAfter != null && state.isWaiting(appClock.nowUtc())) {
      _showCooldown(formatDate(retryAfter));
      return JoinApplicationOutcome.cooldown;
    }
    if (!validate()) return JoinApplicationOutcome.invalid;
    if (!ensureOnline()) return JoinApplicationOutcome.offline;

    final applicant = ref.read(sessionViewModelProvider).user;
    final email = authRepository.currentUser?.email;
    if (applicant == null || email == null) {
      AppLogger.warn('Başvuru gönderilemedi: oturumda profil / e-posta yok');
      state = state.copyWith(submitError: SubmitError.unknown);
      return JoinApplicationOutcome.failed;
    }

    final note = state.note.trim();
    final instant = state.isInstant;
    state = state.copyWith(
      isSubmitting: true,
      errors: const {},
      clearSubmitError: true,
    );

    Future<FirestoreResult<MembershipModel>> apply() =>
        membershipRepository.apply(
          clubId: clubId,
          applicant: applicant,
          email: email,
          note: note,
        );

    var result = instant
        ? await membershipRepository.joinInstant(
            clubId: clubId,
            applicant: applicant,
            email: email,
          )
        : await apply();
    // Oturumdaki üyelik eskiyse sunucu söyler: eski kaydı olan kullanıcı
    // onaysız kulüpte de başvuruyla girer.
    if (instant &&
        _ruleCodeOf(result) == FirestoreRuleCode.reapplyNeedsReview) {
      result = await apply();
    }
    if (!ref.mounted) {
      return result.isSuccess
          ? _successOf(result.dataOrNull)
          : JoinApplicationOutcome.failed;
    }

    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(isSubmitting: false);
        return _successOf(data);
      case FirebaseFailure(:final error, :final message, :final detail):
        return _fail(error, message, detail, formatDate);
    }
  }

  static JoinApplicationOutcome _successOf(MembershipModel? membership) =>
      membership?.status == MembershipStatus.active
      ? JoinApplicationOutcome.joined
      : JoinApplicationOutcome.applied;

  static FirestoreRuleCode? _ruleCodeOf(
    FirestoreResult<MembershipModel> result,
  ) => switch (result) {
    FirebaseFailure(
      error: FirestoreError.ruleViolation,
      detail: FirestoreFailureDetail(:final code),
    ) =>
      code,
    _ => null,
  };

  JoinApplicationOutcome _fail(
    FirestoreError error,
    String? message,
    Object? detail,
    String Function(DateTime retryAfter) formatDate,
  ) {
    final rule =
        error == FirestoreError.ruleViolation &&
            detail is FirestoreFailureDetail
        ? detail
        : null;
    if (rule?.code == FirestoreRuleCode.applicationsClosed) {
      feedback.showToast(ToastId.tstX1);
      state = state.copyWith(isSubmitting: false);
      return JoinApplicationOutcome.closed;
    }
    if (rule?.code == FirestoreRuleCode.retryCooldown) {
      final until = rule?.retryAfter ?? state.retryAfter;
      if (until != null) _showCooldown(formatDate(until));
      state = state.copyWith(isSubmitting: false);
      return JoinApplicationOutcome.cooldown;
    }
    if (_networkErrors.contains(error)) {
      feedback.showToast(ToastId.tst24);
      state = state.copyWith(isSubmitting: false);
      return JoinApplicationOutcome.offline;
    }
    if (error == FirestoreError.invalidArgument) {
      // Kulüp bu arada not zorunluluğu getirmiş olabilir.
      state = state.copyWith(
        isSubmitting: false,
        errors: {
          JoinApplicationField.note: state.note.trim().isEmpty
              ? FormFieldError.required
              : FormFieldError.tooLong,
        },
      );
      return JoinApplicationOutcome.invalid;
    }
    AppLogger.warn('Başvuru gönderilemedi: ${error.name}', error: message);
    state = state.copyWith(
      isSubmitting: false,
      submitError: switch (error) {
        FirestoreError.permissionDenied ||
        FirestoreError.unauthenticated => SubmitError.permission,
        FirestoreError.conflict ||
        FirestoreError.alreadyExists => SubmitError.conflict,
        _ => SubmitError.unknown,
      },
    );
    return JoinApplicationOutcome.failed;
  }

  void _showCooldown(String date) =>
      feedback.showToast(ToastId.tstX4, params: ToastParams(date: date));
}
