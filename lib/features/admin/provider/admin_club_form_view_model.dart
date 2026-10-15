import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_club_form_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_clubs_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_president_candidates_mixin.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/form_validation_mixin.dart';
import 'package:gu_kulupler/product/mixin/permission_prompt_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_ui/gu_ui.dart' show TurkishCaseX;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'admin_club_form_view_model.g.dart';

/// ADM-03 "Kulüp oluştur / düzenle" ekranının ViewModel'i (PLAN §12.6;
/// prototip `S['ADM-03']`, `screens-admin.js:39–56`). Aile `clubId`
/// (`AdminClubEditRoute`); `null` → yeni kulüp (`AdminClubFormRoute`).
///
/// * **Açılış (düzenleme):** kulüp (`clubRepository.getClub`) ve başkanın
///   kullanıcı belgesi (`userRepository.getUser`) okunur. Okunamayan /
///   silinmiş kulüp → hata durumu. Askıdaki kulüp de düzenlenir.
/// * **Ad benzersizliği (CD-63):** ön sorgu yok — `createClub` /
///   `updateClubIdentity` `nameLower` eşitlik sorgusunu kendisi koşar;
///   `alreadyExists` → ad alanında "Bu adda bir kulüp zaten var"
///   ([AdminClubFormState.isNameTaken]; yarış kabul).
/// * **İkon:** prototipteki gibi kategoriden türer
///   ([AdminClubFormState.iconName]); ayrı ikon seçici tasarımda yok.
/// * **Başkan:** SHT-25 atama kipi adayları [presidentCandidates]
///   (`AdminPresidentCandidatesMixin`, ADM-02 ile ortak);
///   oluşturmada `createClub(president…)`, düzenlemede değiştiyse kayıtta
///   `assignPresident` (üyelik + `presidentId` aynı işlemde — T-37).
/// * **Danışman (K-A):** ad + unvan `AdvisorInput` ile yazılır; hesap
///   bağlama yalnızca `tool/admin/set_advisor.js`. Bağlı hesap
///   (`advisor.userId`) varken "Kaldır" ([unlinkAdvisor]) her durumda
///   sunulur; kayıtta önce `setAdvisor(active: false)` bağı ayırır (W-101 a,
///   bayat bağ dahil).
/// * **Görseller:** seçilen logo / kapak kayıtta
///   `adminRepository.updateClubMedia` ile yüklenir (yeni kulüpte
///   oluşturmadan sonra). Yarıda kalan yazım yeniden denenince yapılan adım
///   tekrarlanmaz (oluşturulmuş kulüp, ayrılmış bağ, yüklenmiş görsel).
/// * `permissionDenied` → claim sunucudan yenilenir (CD-160); okuma, süper
///   admin hâlâ geçerliyse bir kez yinelenir.
///
/// | İşlem | Koruma | Yazım | Geri bildirim |
/// |---|---|---|---|
/// | [save] (yeni) | doğrulama · çevrimdışı TST-24 | `createClub` → `updateClubMedia` | TST-33 |
/// | [save] (düzenle) | doğrulama · değişiklik yok TST-X9 · çevrimdışı TST-24 | `setAdvisor(false)` → `updateClubMedia` → `updateClubIdentity` → `assignPresident` | TST-21 |
///
/// Design: ADM-03
@riverpod
final class AdminClubFormViewModel extends _$AdminClubFormViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        FormValidationMixin<AdminClubField>,
        PermissionPromptMixin,
        AdminPresidentCandidatesMixin {
  static const Set<StorageError> _networkUploadErrors = {
    StorageError.retryLimitExceeded,
    StorageError.timeout,
  };

  bool _isPicking = false;

  @override
  AdminClubFormState build(String? clubId) {
    if (clubId == null) return const AdminClubFormState();
    // Kulüp ilk karede okunmaya başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(load));
    return const AdminClubFormState(isLoading: true);
  }

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// Düzenlenen kulübü okur ve formu belgeden kurar; hata görünümündeki
  /// "Yeniden dene" (`ADM-03.retry`). Yeni kulüpte etkisizdir.
  Future<void> load() async {
    final id = clubId;
    if (id == null || !ref.mounted) return;
    state = state.copyWith(isLoading: true, isError: false);
    var result = await clubRepository.getClub(id);
    if (result.errorOrNull == FirestoreError.permissionDenied &&
        await _claimsStillValid()) {
      result = await clubRepository.getClub(id);
    }
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data) when !data.isDeleted:
        final president = await _userOf(data.presidentId);
        if (!ref.mounted) return;
        state = AdminClubFormState.of(data, president: president);
      case FirebaseSuccess():
        AppLogger.warn('Kulüp formu: kulüp silinmiş: $id');
        state = state.copyWith(isLoading: false, isError: true);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Kulüp formu: kulüp okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isLoading: false, isError: true);
    }
  }

  /// SHT-25 "Başkan ata" adayları ([readPresidentCandidates]): seçili
  /// başkan ve bağlı danışman hariç. Okunamazsa toast (TST-24 / TST-X18) ve
  /// `null`.
  Future<List<UserModel>?> presidentCandidates() async {
    if (!ref.mounted || state.isSubmitting) return null;
    final result = await readPresidentCandidates(
      excluded: {state.presidentUserId, state.linkedAdvisorId},
    );
    if (!ref.mounted) return null;
    switch (result) {
      case FirebaseSuccess(:final data):
        return data;
      case FirebaseFailure(:final error, :final message):
        _deniedRefresh(error);
        if (!showWriteFailureToast(error)) {
          AppLogger.warn(
            'Başkan adayları okunamadı: ${error.name}',
            error: message,
          );
          feedback.showToast(ToastId.tstX18);
        }
        return null;
    }
  }

  // ───────────────────────────────── alanlar ────────────────────────────────

  /// Kulüp adı (`ADM-03.name`); `Limits.clubNameMax`'te kesilir. Ad
  /// değişince çakışma uyarısı kalkar.
  void setName(String value) {
    final name = _clamped(value, Limits.clubNameMax);
    if (!_canEdit || name == state.name) return;
    _edit(state.copyWith(name: name, isNameTaken: false), const [
      AdminClubField.name,
    ]);
  }

  /// SHT-33 sonucu (`ADM-03.category`).
  void setCategory(String categoryId) {
    if (!_canEdit || categoryId == state.categoryId) return;
    _edit(state.copyWith(categoryId: categoryId), const [
      AdminClubField.category,
    ]);
  }

  /// Kısa açıklama (`ADM-03.summary`); `Limits.clubSummaryMax`'te kesilir.
  void setSummary(String value) {
    final summary = _clamped(value, Limits.clubSummaryMax);
    if (!_canEdit || summary == state.summary) return;
    _edit(state.copyWith(summary: summary), const [AdminClubField.summary]);
  }

  /// Uzun açıklama (`ADM-03.about`); `Limits.clubAboutMax`'te kesilir.
  void setAbout(String value) {
    final about = _clamped(value, Limits.clubAboutMax);
    if (!_canEdit || about == state.about) return;
    _edit(state.copyWith(about: about), const [AdminClubField.about]);
  }

  /// Danışman adı (`ADM-03.advisorName`); `Limits.nameMax`'te kesilir.
  void setAdvisorName(String value) {
    final name = _clamped(value, Limits.nameMax);
    if (!_canEdit || name == state.advisorName) return;
    _edit(state.copyWith(advisorName: name), const [
      AdminClubField.advisorName,
    ]);
  }

  /// Danışman unvanı (`ADM-03.advisorTitle`); `Limits.nameMax`'te kesilir.
  void setAdvisorTitle(String value) {
    final title = _clamped(value, Limits.nameMax);
    if (!_canEdit || title == state.advisorTitle) return;
    _edit(state.copyWith(advisorTitle: title), const [
      AdminClubField.advisorName,
    ]);
  }

  /// "Başvurular açık" (`ADM-03.toggle.applicationsOpen`).
  void setApplicationsOpen({required bool value}) {
    if (!_canEdit || value == state.applicationsOpen) return;
    _edit(state.copyWith(applicationsOpen: value));
  }

  /// "Yönetim onayı gerekli" (`ADM-03.toggle.approvalRequired`).
  void setApprovalRequired({required bool value}) {
    if (!_canEdit || value == state.approvalRequired) return;
    _edit(state.copyWith(approvalRequired: value));
  }

  /// SHT-31 şablonu (`SHT-31.use`): [palette] × [pattern], tohum [seed].
  /// Seçilmiş özel kapak bırakılır; yüklenmiş kapak önizlemeden kalkar ve
  /// kayıtta `coverPath` bırakılır (`ClubIdentityPatch.clearCoverPath`;
  /// dosya silinmez — D-10; W-102).
  void setCoverTemplate(ClubPalette palette, ClubPattern pattern, String seed) {
    if (!_canEdit) return;
    _edit(
      state.copyWith(
        coverPalette: palette,
        coverPattern: pattern,
        coverSeed: seed,
        clearCoverPath: true,
        clearPendingCover: true,
      ),
    );
  }

  /// Logo (`ADM-03.logo`) → SHT-16 [source]; yükleme kaydettedir.
  Future<void> pickLogo(MediaSource source) => _pick(source, isLogo: true);

  /// SHT-31 "Galeriden seç" → SHT-16 [source]; yükleme kaydettedir.
  Future<void> pickCover(MediaSource source) => _pick(source, isLogo: false);

  /// SHT-25 seçimi: [user] başkan olur (kayıtta yazılır).
  void setPresident(UserModel user) {
    if (!_canEdit || user.uid == state.presidentUserId) return;
    _edit(state.copyWith(presidentUserId: user.uid, president: user), const [
      AdminClubField.president,
    ]);
  }

  /// Başkan kartındaki "Kaldır" (`ADM-03.removePresident`): seçim kalkar,
  /// kayıt yeni başkan ister.
  void removePresident() {
    if (!_canEdit || state.presidentUserId == null) return;
    _edit(state.copyWith(clearPresident: true));
  }

  /// Bağlı danışman hesabındaki "Kaldır" (`ADM-03.unlinkAdvisor`, W-101 a):
  /// kayıtta `setAdvisor(active: false)` bağı ayırır; ad / unvan kalır.
  void unlinkAdvisor() {
    if (!_canEdit || state.linkedAdvisorId == null) return;
    _edit(state.copyWith(advisorUnlinked: true), const [
      AdminClubField.advisorName,
    ]);
  }

  // ─────────────────────────────── doğrulama ────────────────────────────────

  /// Alanları doğrular ve hatalarını state'e yazar; hata yoksa `true`.
  bool validate() {
    final errors = _errors();
    state = state.copyWith(errors: errors);
    return errors.isEmpty;
  }

  // ───────────────────────────────── yazım ──────────────────────────────────

  /// "Oluştur" / "Kaydet" (`ADM-03.save`).
  Future<AdminClubFormOutcome> save() async {
    if (!ref.mounted ||
        state.isSubmitting ||
        state.isLoading ||
        state.isError) {
      return AdminClubFormOutcome.ignored;
    }
    if (!validate()) return AdminClubFormOutcome.invalid;
    final uid = ref.read(sessionViewModelProvider).uid;
    if (uid == null) return AdminClubFormOutcome.ignored;
    final original = state.original;
    if (original != null && !_isDirty(state)) {
      feedback.showToast(ToastId.tstX9);
      state = state.copyWith(isDirty: false);
      return AdminClubFormOutcome.blocked;
    }
    if (!ensureOnline()) return AdminClubFormOutcome.blocked;
    state = state.copyWith(isSubmitting: true, isSubmitError: false);
    return original == null ? _create(uid) : _update(uid, original);
  }

  // ────────────────────────────────── iç ────────────────────────────────────

  Future<AdminClubFormOutcome> _create(String uid) async {
    var clubId = state.createdClubId;
    if (clubId == null) {
      final president = state.president;
      final presidentId = state.presidentUserId;
      if (president == null || presidentId == null) {
        state = state.copyWith(isSubmitting: false);
        return AdminClubFormOutcome.invalid;
      }
      final email = await _emailOf(presidentId);
      if (!ref.mounted) return AdminClubFormOutcome.ignored;
      // Okuma hatası `_emailOf`'ta bildirildi (toast / hata bandı).
      if (email == null) return AdminClubFormOutcome.failed;
      final result = await adminRepository.createClub(
        _createInput(state),
        presidentUserId: presidentId,
        presidentUser: president,
        presidentEmail: email,
        advisor: _advisorInput(state),
      );
      switch (result) {
        case FirebaseSuccess(:final data):
          clubId = data.id;
          if (ref.mounted) state = state.copyWith(createdClubId: clubId);
        case FirebaseFailure(error: FirestoreError.alreadyExists):
          _nameTaken();
          return AdminClubFormOutcome.invalid;
        case FirebaseFailure(:final error, :final message):
          _writeFailed(error, message);
          return AdminClubFormOutcome.failed;
      }
    }
    if (!await _uploadPending(clubId, uid)) return AdminClubFormOutcome.failed;
    feedback.showToast(ToastId.tst33);
    if (ref.mounted) {
      state = state.copyWith(isSubmitting: false, isDirty: false);
      _refreshList();
    }
    return AdminClubFormOutcome.created;
  }

  Future<AdminClubFormOutcome> _update(String uid, ClubModel original) async {
    final clubId = original.id;
    final advisorId = original.advisor?.userId;
    if (state.advisorUnlinked && advisorId != null) {
      final result = await adminRepository.setAdvisor(
        clubId: clubId,
        userId: advisorId,
        active: false,
      );
      if (result case FirebaseFailure(:final error, :final message)) {
        _writeFailed(error, message);
        return AdminClubFormOutcome.failed;
      }
      if (ref.mounted) {
        state = state.copyWith(
          original: original.copyWith(
            advisor: original.advisor?.copyWith(clearUserId: true),
          ),
          advisorUnlinked: false,
        );
      }
    }
    if (!await _uploadPending(clubId, uid)) return AdminClubFormOutcome.failed;

    final current = state.original ?? original;
    final patch = _patchOf(state, current);
    if (!patch.isEmpty) {
      final result = await adminRepository.updateClubIdentity(clubId, patch);
      switch (result) {
        case FirebaseSuccess():
          if (ref.mounted) {
            state = state.copyWith(original: _applied(current, patch));
          }
        case FirebaseFailure(error: FirestoreError.alreadyExists):
          _nameTaken();
          return AdminClubFormOutcome.invalid;
        case FirebaseFailure(:final error, :final message):
          _writeFailed(error, message);
          return AdminClubFormOutcome.failed;
      }
    }

    final toUserId = state.presidentUserId;
    final saved = state.original ?? current;
    if (toUserId != null && toUserId != saved.presidentId) {
      final result = await adminRepository.assignPresident(
        clubId: clubId,
        toUserId: toUserId,
        actorId: uid,
      );
      if (result case FirebaseFailure(:final error, :final message)) {
        _writeFailed(error, message);
        return AdminClubFormOutcome.failed;
      }
      if (ref.mounted) {
        state = state.copyWith(original: saved.copyWith(presidentId: toUserId));
      }
    }

    feedback.showToast(ToastId.tst21);
    if (ref.mounted) {
      state = state.copyWith(isSubmitting: false, isDirty: false);
      _refreshList();
    }
    return AdminClubFormOutcome.saved;
  }

  /// Seçilmiş görselleri [clubId] kulübüne yükler; başarıda yollar forma
  /// işlenir, seçimler temizlenir (yeniden denemede yeniden yüklenmez).
  Future<bool> _uploadPending(String clubId, String uid) async {
    final logo = state.pendingLogo;
    final cover = state.pendingCover;
    if (logo == null && cover == null) return true;
    final result = await adminRepository.updateClubMedia(
      clubId,
      uploaderId: uid,
      logo: _uploadOf(logo),
      cover: _uploadOf(cover),
    );
    switch (result) {
      case FirebaseSuccess(:final data):
        if (ref.mounted) {
          final original = state.original;
          state = state.copyWith(
            original: original?.copyWith(
              logoPath: data.logoPath,
              coverPath: data.coverPath,
            ),
            coverPath: data.coverPath,
            clearPendingLogo: logo != null,
            clearPendingCover: cover != null,
          );
        }
        return true;
      case FirebaseFailure(:final error, :final message):
        _uploadFailed(error, message);
        return false;
    }
  }

  static ClubMediaUpload? _uploadOf(PickedImage? image) => image == null
      ? null
      : ClubMediaUpload(bytes: image.bytes, contentType: image.contentType);

  /// Görsel yükleme hatası: bağlantı → TST-24, Storage / Rules reddi →
  /// TST-X18 (+ claim yenileme); diğerleri hata bandı.
  void _uploadFailed(MediaUpdateError error, String? message) {
    final storage = error.storage;
    final firestore = error.firestore;
    var shown = true;
    if (_networkUploadErrors.contains(storage) ||
        WriteGuardMixin.networkErrors.contains(firestore)) {
      feedback.showToast(ToastId.tst24);
    } else if (storage == StorageError.unauthorized ||
        firestore == FirestoreError.permissionDenied) {
      unawaited(_refreshClaims());
      feedback.showToast(ToastId.tstX18);
    } else {
      shown = false;
      AppLogger.warn('Kulüp görseli yüklenemedi: $error', error: message);
    }
    if (ref.mounted) {
      state = state.copyWith(isSubmitting: false, isSubmitError: !shown);
    }
  }

  /// Yazım hatası: ağ → TST-24, yetki yok → TST-X18 (+ claim yenileme —
  /// CD-160); diğerleri hata bandı.
  void _writeFailed(FirestoreError error, String? message) {
    _deniedRefresh(error);
    final shown = showWriteFailureToast(error);
    if (!shown) {
      AppLogger.warn('Kulüp formu yazılamadı: ${error.name}', error: message);
    }
    if (ref.mounted) {
      state = state.copyWith(isSubmitting: false, isSubmitError: !shown);
    }
  }

  /// Yaşayan ADM-02 listesi içerik kalarak yenilenir: dönüş `go` ile aynı
  /// sayfaya olduğundan ekran yeniden kurulmaz.
  void _refreshList() {
    if (ref.exists(adminClubsViewModelProvider)) {
      unawaited(ref.read(adminClubsViewModelProvider.notifier).refresh());
    }
  }

  void _nameTaken() {
    if (!ref.mounted) return;
    state = state.copyWith(isSubmitting: false, isNameTaken: true);
  }

  void _deniedRefresh(FirestoreError error) {
    if (error == FirestoreError.permissionDenied) {
      unawaited(_refreshClaims());
    }
  }

  Future<void> _refreshClaims() =>
      ref.read(sessionViewModelProvider.notifier).refreshClaims();

  /// Claim'i sunucudan yeniler (CD-160); süper admin hâlâ geçerli mi?
  Future<bool> _claimsStillValid() async {
    await _refreshClaims();
    return ref.mounted && ref.read(sessionViewModelProvider).isSuperAdmin;
  }

  Future<UserModel?> _userOf(String uid) async {
    final result = await userRepository.getUser(uid);
    return switch (result) {
      FirebaseSuccess(:final data) => data,
      FirebaseFailure(:final error) => _logMissing('başkan', error),
    };
  }

  /// Başkanın hesap e-postası (`private/contact`); okunamazsa `null`
  /// (hesap belgesi yoksa boş dizgi).
  Future<String?> _emailOf(String uid) async {
    final result = await userRepository.getPrivateAccount(uid);
    switch (result) {
      case FirebaseSuccess(:final data):
        return data?.email ?? '';
      case FirebaseFailure(:final error, :final message):
        _writeFailed(error, message);
        return null;
    }
  }

  static UserModel? _logMissing(String what, FirestoreError error) {
    AppLogger.warn('Kulüp formu: $what okunamadı: ${error.name}');
    return null;
  }

  /// Form düzenlenebilir mi: okuma bitti, gönderim yok.
  bool get _canEdit =>
      ref.mounted && !state.isLoading && !state.isError && !state.isSubmitting;

  Future<void> _pick(MediaSource source, {required bool isLogo}) async {
    if (_isPicking || !_canEdit) return;
    _isPicking = true;
    try {
      final result = await pickImage(source);
      if (!ref.mounted) return;
      switch (result) {
        case ImagePickSuccess(:final image):
          _edit(
            isLogo
                ? state.copyWith(pendingLogo: image)
                : state.copyWith(pendingCover: image),
          );
        case ImagePickCancelled():
          break;
        case ImagePickFailure(:final error):
          // İzin reddinin toastını (TST-32) seçici gösterdi; diğerleri günlük.
          AppLogger.warn(
            'Kulüp ${isLogo ? 'logosu' : 'kapağı'} seçilemedi: ${error.name}',
          );
      }
    } finally {
      _isPicking = false;
    }
  }

  Map<AdminClubField, FormFieldError> _errors() {
    final name = state.name.trim();
    final advisorName = state.advisorName.trim();
    final advisorRequired =
        state.advisorTitle.trim().isNotEmpty || state.linkedAdvisorId != null;
    return validateFields({
      AdminClubField.name: () => name.isEmpty
          ? FormFieldError.required
          : fromFieldError(FieldValidators.clubNameLower(name.trLower())),
      AdminClubField.category: () =>
          state.categoryId == null ? FormFieldError.required : null,
      AdminClubField.summary: () =>
          fromFieldError(FieldValidators.clubSummary(state.summary.trim())),
      AdminClubField.about: () =>
          fromFieldError(FieldValidators.clubAbout(state.about.trim())),
      AdminClubField.president: () =>
          state.presidentUserId == null ? FormFieldError.required : null,
      AdminClubField.advisorName: () => advisorName.isEmpty
          ? (advisorRequired ? FormFieldError.required : null)
          : fromFieldError(FieldValidators.name(advisorName)),
    });
  }

  /// Değişiklik sonrası ortak güncelleme: [fields] alanlarının hatası ve eski
  /// gönderim hatası silinir, kirli bayrağı yeniden hesaplanır.
  void _edit(
    AdminClubFormState next, [
    List<AdminClubField> fields = const [],
  ]) {
    final edited = next.copyWith(
      isSubmitError: false,
      errors: {
        for (final entry in next.errors.entries)
          if (!fields.contains(entry.key)) entry.key: entry.value,
      },
    );
    state = edited.copyWith(isDirty: _isDirty(edited));
  }

  /// Formda kaydedilecek bir şey var mı: yeni kulüpte boş formdan, düzenlemede
  /// belgeden fark.
  static bool _isDirty(AdminClubFormState form) {
    if (form.pendingLogo != null || form.pendingCover != null) return true;
    final original = form.original;
    if (original == null) {
      const blank = AdminClubFormState();
      return form.name.trim().isNotEmpty ||
          form.categoryId != null ||
          form.summary.trim().isNotEmpty ||
          form.about.trim().isNotEmpty ||
          form.presidentUserId != null ||
          form.advisorName.trim().isNotEmpty ||
          form.advisorTitle.trim().isNotEmpty ||
          form.applicationsOpen != blank.applicationsOpen ||
          form.approvalRequired != blank.approvalRequired ||
          form.coverPalette != blank.coverPalette ||
          form.coverPattern != blank.coverPattern ||
          form.coverSeed != blank.coverSeed;
    }
    return form.advisorUnlinked ||
        form.presidentUserId != original.presidentId ||
        !_patchOf(form, original).isEmpty;
  }

  /// Yeni kulübün girdisi (kuruluş yılı bu yıl — tasarımda alan yok).
  ClubCreateInput _createInput(AdminClubFormState form) {
    final name = form.name.trim();
    final seed = form.coverSeed;
    return ClubCreateInput(
      name: name,
      nameLower: name.trLower(),
      categoryId: form.categoryId ?? '',
      iconName: form.iconName,
      founded: Limits.foundedMax(appClock),
      palette: form.coverPalette,
      pattern: form.coverPattern,
      coverSeed: seed.isEmpty ? null : seed,
      summary: form.summary.trim(),
      about: form.about.trim(),
      applicationsOpen: form.applicationsOpen,
      approvalRequired: form.approvalRequired,
    );
  }

  /// Formdaki danışman; ad boşsa `null` (K-A).
  static AdvisorInput? _advisorInput(AdminClubFormState form) {
    final name = form.advisorName.trim();
    if (name.isEmpty) return null;
    return AdvisorInput(name: name, title: form.advisorTitle.trim());
  }

  /// [form] ile [original] arasındaki fark: yalnızca değişen alanlar
  /// (başkan ayrı yazılır — `assignPresident`).
  static ClubIdentityPatch _patchOf(
    AdminClubFormState form,
    ClubModel original,
  ) {
    final name = form.name.trim();
    final summary = form.summary.trim();
    final about = form.about.trim();
    final nameChanged = name != original.name;
    final categoryChanged = form.categoryId != original.categoryId;
    final iconName = form.iconName;
    final advisor = _advisorInput(form);
    final before = original.advisor;
    final advisorChanged = advisor == null
        ? before != null
        : before == null ||
              advisor.name != before.name.trim() ||
              advisor.title != before.title.trim();
    final seed = form.coverSeed;
    return ClubIdentityPatch(
      name: nameChanged ? name : null,
      nameLower: nameChanged ? name.trLower() : null,
      categoryId: categoryChanged ? form.categoryId : null,
      iconName: iconName == original.iconName ? null : iconName,
      summary: summary == original.summary.trim() ? null : summary,
      about: about == original.about.trim() ? null : about,
      palette: form.coverPalette == original.palette ? null : form.coverPalette,
      pattern: form.coverPattern == original.pattern ? null : form.coverPattern,
      coverSeed: seed.isEmpty || seed == original.coverSeed ? null : seed,
      applicationsOpen: form.applicationsOpen == original.applicationsOpen
          ? null
          : form.applicationsOpen,
      approvalRequired: form.approvalRequired == original.approvalRequired
          ? null
          : form.approvalRequired,
      advisor: advisorChanged ? advisor : null,
      clearAdvisor: advisorChanged && advisor == null && before != null,
      // SHT-31 şablonu yüklenmiş kapağın yerine seçildi: `coverPath` bırakılır
      // (dosya silinmez — D-10). Yeni kapak seçildiyse yükleme yolu yazar.
      clearCoverPath:
          original.coverPath != null &&
          form.coverPath == null &&
          form.pendingCover == null,
    );
  }

  /// [patch] yazıldıktan sonraki model.
  static ClubModel _applied(ClubModel original, ClubIdentityPatch patch) {
    final advisor = patch.advisor;
    final before = original.advisor;
    return original.copyWith(
      name: patch.name,
      nameLower: patch.nameLower,
      categoryId: patch.categoryId,
      iconName: patch.iconName,
      summary: patch.summary,
      about: patch.about,
      palette: patch.palette,
      pattern: patch.pattern,
      coverSeed: patch.coverSeed,
      applicationsOpen: patch.applicationsOpen,
      approvalRequired: patch.approvalRequired,
      advisor: advisor == null
          ? null
          : ClubAdvisorModel(
              name: advisor.name,
              title: advisor.title,
              userId: before?.userId,
            ),
      clearAdvisor: patch.clearAdvisor,
      clearCoverPath: patch.clearCoverPath,
    );
  }

  /// [text] metninin [max] karakterle sınırlı hali; vekil çiftin ortasından
  /// kesilmez.
  static String _clamped(String text, int max) {
    if (text.length <= max) return text;
    final end = _isHighSurrogate(text.codeUnitAt(max - 1)) ? max - 1 : max;
    return text.substring(0, end);
  }

  static bool _isHighSurrogate(int unit) => (unit & 0xFC00) == 0xD800;
}
