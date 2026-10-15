import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/club_settings_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/form_validation_mixin.dart';
import 'package:gu_kulupler/product/mixin/permission_prompt_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'club_settings_view_model.g.dart';

/// MGT-09 "Kulüp ayarları" ekranının ViewModel'i (PLAN §12.6; prototip
/// `S['MGT-09']`, `screens-manage.js:170–188`). Aile `clubId`.
///
/// * **Açılış:** kulüp belgesi okunur (`clubRepository.getClub`), form
///   belgeden kurulur. Okunamayan / silinmiş kulüp → hata durumu.
/// * **Kirli takibi:** her değişiklikten sonra yazılacak yama
///   (`ClubSettingsPatch`, yalnızca değişen alanlar) + seçilmiş logo / kapak
///   yeniden hesaplanır; değer eski haline dönerse form temizlenir.
/// * **Kilitli alanlar:** kulüp adı (`MGT-09.lockedName`) ve kategori
///   (SHT-33'te başka kategori seçimi) TST-20 verir — yönetici değiştiremez
///   (Rules §3.3; ad / kategori süper adminde, ADM-03 — T-39).
/// * **Danışman** salt okunurdur: yazan her dokunuş TST-26 (Q-09).
/// * **Kaydet** iyimser değildir; sırayla (PLAN §12.6): seçilmiş görseller
///   `managementRepository.updateClubMedia` (yeni dosya adı, eski dosya
///   silinmez — D-10) → değişen alanlar `managementRepository
///   .updateClubSettings`. Yarıda kalan yazımda yüklenmiş görsel yeniden
///   yüklenmez. Başarı TST-21; başvuru durumu değiştiyse
///   [AppDurations.applicationsToastDelay] sonra TST-54.
///
/// | İşlem | Koruma | Yazım | Geri bildirim |
/// |---|---|---|---|
/// | [save] | danışman TST-26 · doğrulama · değişiklik yok TST-X9 · çevrimdışı TST-24 | `updateClubMedia` → `updateClubSettings` | TST-21 (+ TST-54) |
///
/// Design: MGT-09
@riverpod
final class ClubSettingsViewModel extends _$ClubSettingsViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        FormValidationMixin<ClubSettingsField>,
        PermissionPromptMixin {
  static const Set<StorageError> _networkUploadErrors = {
    StorageError.retryLimitExceeded,
    StorageError.timeout,
  };

  bool _isPicking = false;

  @override
  ClubSettingsState build(String clubId) {
    ref.listen(sessionViewModelProvider, (_, session) {
      final role = session.roleIn(clubId);
      if (role == state.role) return;
      state = state.copyWith(role: role, clearRole: role == null);
    });
    // Kulüp ilk karede okunmaya başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(load));
    return ClubSettingsState(
      role: ref.read(sessionViewModelProvider).roleIn(clubId),
    );
  }

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// Kulübü okur ve formu belgeden kurar; hata görünümündeki "Yeniden dene"
  /// (`MGT-09.retry`).
  Future<void> load() async {
    if (!ref.mounted) return;
    state = state.copyWith(isLoading: true, isError: false);
    final result = await clubRepository.getClub(clubId);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data) when !data.isDeleted:
        state = _formOf(data, role: state.role);
      case FirebaseSuccess():
        AppLogger.warn('Kulüp ayarları: kulüp silinmiş: $clubId');
        state = state.copyWith(isLoading: false, isError: true);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Kulüp ayarları: kulüp okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isLoading: false, isError: true);
    }
  }

  // ───────────────────────────────── alanlar ────────────────────────────────

  /// Kısa açıklama (`MGT-09.summary`); `Limits.clubSummaryMax`'te kesilir.
  void setSummary(String value) {
    final summary = _clamped(value, Limits.clubSummaryMax);
    if (!_canEdit || summary == state.summary) return;
    _edit(state.copyWith(summary: summary), const [ClubSettingsField.summary]);
  }

  /// Uzun açıklama (`MGT-09.about`); `Limits.clubAboutMax`'te kesilir.
  void setAbout(String value) {
    final about = _clamped(value, Limits.clubAboutMax);
    if (!_canEdit || about == state.about) return;
    _edit(state.copyWith(about: about), const [ClubSettingsField.about]);
  }

  /// İletişim e-postası (`MGT-09.email`).
  void setEmail(String value) {
    if (!_canEdit || value == state.email) return;
    _edit(state.copyWith(email: value), const [ClubSettingsField.email]);
  }

  /// Instagram kullanıcı adı (`MGT-09.instagram`).
  void setInstagram(String value) {
    if (!_canEdit || value == state.instagram) return;
    _edit(
      state.copyWith(instagram: value),
      const [ClubSettingsField.instagram],
    );
  }

  /// Web sitesi (`MGT-09.web`).
  void setWeb(String value) {
    if (!_canEdit || value == state.web) return;
    _edit(state.copyWith(web: value), const [ClubSettingsField.web]);
  }

  /// "Başvurular açık" (`MGT-09.toggle.applicationsOpen`); kaydedilince
  /// durum değiştiyse TST-54.
  void setApplicationsOpen({required bool value}) {
    if (!_canEdit || value == state.applicationsOpen) return;
    _edit(state.copyWith(applicationsOpen: value));
  }

  /// "Yönetim onayı gerekli" (`MGT-09.toggle.approvalRequired`).
  void setApprovalRequired({required bool value}) {
    if (!_canEdit || value == state.approvalRequired) return;
    _edit(state.copyWith(approvalRequired: value));
  }

  /// "Başvuruda not iste" (`MGT-09.toggle.requireNote`).
  void setRequireNote({required bool value}) {
    if (!_canEdit || value == state.requireNote) return;
    _edit(state.copyWith(requireNote: value));
  }

  /// SHT-31 şablonu (`SHT-31.use`): [palette] × [pattern], tohum [seed].
  /// Seçilmiş özel kapak bırakılır; yüklenmiş kapak önizlemeden kalkar ve
  /// kayıtta `coverPath` bırakılır (`ClubSettingsPatch.clearCoverPath`;
  /// dosya silinmez — D-10).
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

  /// Logo (`MGT-09.logo`) → SHT-16 [source]: görsel seçtirir (yeniden
  /// kodlanmış — CD-135); yükleme kaydettedir.
  Future<void> pickLogo(MediaSource source) => _pick(source, isLogo: true);

  /// SHT-31 "Galeriden seç" → SHT-16 [source]: özel kapak seçtirir; yükleme
  /// kaydettedir.
  Future<void> pickCover(MediaSource source) => _pick(source, isLogo: false);

  /// SHT-33 sonucu: kategori yönetici tarafından değiştirilemez (Rules
  /// §3.3) — başka kategori seçilirse TST-20, değer değişmez.
  void selectCategory(String categoryId) {
    final original = state.original;
    if (original == null || categoryId == original.categoryId) return;
    feedback.showToast(ToastId.tst20);
  }

  /// Kilitli kulüp adı (`MGT-09.lockedName`) → TST-20.
  void onLockedNameTap() => feedback.showToast(ToastId.tst20);

  /// Danışman bakışında yazan eyleme dokunuldu → TST-26.
  void onReadOnlyTap() => feedback.showToast(ToastId.tst26);

  /// Kapalı "Kaydet"e dokunuldu: danışman → TST-26, değişiklik yok → TST-X9.
  void onSaveDisabledTap() => feedback.showToast(
    state.isReadOnly ? ToastId.tst26 : ToastId.tstX9,
  );

  /// Yazan / sayfa açan eylemden önce: danışmansa TST-26 ve `false`.
  bool ensureWritable() {
    if (!state.isReadOnly) return true;
    onReadOnlyTap();
    return false;
  }

  // ─────────────────────────────── doğrulama ────────────────────────────────

  /// Alanları doğrular ve hatalarını state'e yazar; hata yoksa `true`.
  bool validate() {
    final errors = _errors();
    state = state.copyWith(errors: errors);
    return errors.isEmpty;
  }

  // ───────────────────────────────── yazım ──────────────────────────────────

  /// "Kaydet" (`MGT-09.save`; DLG-25 "Kaydet").
  Future<ClubSettingsOutcome> save() async {
    final original = state.original;
    if (!ref.mounted || state.isSubmitting || original == null) {
      return ClubSettingsOutcome.ignored;
    }
    if (!ensureWritable()) return ClubSettingsOutcome.blocked;
    if (!validate()) return ClubSettingsOutcome.invalid;
    final uid = ref.read(sessionViewModelProvider).uid;
    if (uid == null) return ClubSettingsOutcome.ignored;

    final patch = _patchOf(state, original);
    final logo = state.pendingLogo;
    final cover = state.pendingCover;
    if (patch.isEmpty && logo == null && cover == null) {
      feedback.showToast(ToastId.tstX9);
      state = state.copyWith(isDirty: false);
      return ClubSettingsOutcome.blocked;
    }
    if (!ensureOnline()) return ClubSettingsOutcome.blocked;

    state = state.copyWith(isSubmitting: true, isSubmitError: false);
    if ((logo != null || cover != null) &&
        !await _uploadMedia(uid, logo: logo, cover: cover)) {
      return ClubSettingsOutcome.failed;
    }
    if (!patch.isEmpty) {
      final result = await managementRepository.updateClubSettings(
        clubId,
        patch,
        actorId: uid,
      );
      if (result case FirebaseFailure(:final error, :final message)) {
        _writeFailed(error, message);
        return ClubSettingsOutcome.failed;
      }
    }
    final applicationsOpen = patch.applicationsOpen;
    if (ref.mounted) {
      final saved = _applied(state.original ?? original, patch);
      state = _formOf(saved, role: state.role).copyWith(
        // Yüklenmiş kapak yerine şablon seçildiyse önizleme şablonda kalır.
        clearCoverPath: state.coverPath == null,
      );
      _refreshPanel();
    }
    feedback.showToast(ToastId.tst21);
    if (applicationsOpen != null) _showApplicationsToastLater(applicationsOpen);
    return ClubSettingsOutcome.saved;
  }

  // ────────────────────────────────── iç ────────────────────────────────────

  /// Form düzenlenebilir mi: kulüp okunmuş, gönderim yok, danışman değil
  /// (danışmanda TST-26).
  bool get _canEdit =>
      ref.mounted &&
      state.original != null &&
      !state.isSubmitting &&
      ensureWritable();

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

  /// Seçilmiş görselleri yükler; başarıda yollar belgeye ve forma işlenir,
  /// seçimler temizlenir (yeniden denemede yeniden yüklenmez).
  Future<bool> _uploadMedia(
    String uid, {
    required PickedImage? logo,
    required PickedImage? cover,
  }) async {
    final result = await managementRepository.updateClubMedia(
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
  /// TST-X18; diğerleri hata bandı.
  void _uploadFailed(MediaUpdateError error, String? message) {
    final storage = error.storage;
    final firestore = error.firestore;
    var shown = true;
    if (_networkUploadErrors.contains(storage) ||
        WriteGuardMixin.networkErrors.contains(firestore)) {
      feedback.showToast(ToastId.tst24);
    } else if (storage == StorageError.unauthorized ||
        firestore == FirestoreError.permissionDenied) {
      feedback.showToast(ToastId.tstX18);
    } else {
      shown = false;
      AppLogger.warn('Kulüp görseli yüklenemedi: $error', error: message);
    }
    if (ref.mounted) {
      state = state.copyWith(isSubmitting: false, isSubmitError: !shown);
    }
  }

  /// Ayar yazım hatası: ağ → TST-24, yetki yok → TST-X18; diğerleri hata
  /// bandı.
  void _writeFailed(FirestoreError error, String? message) {
    final shown = showWriteFailureToast(error);
    if (!shown) {
      AppLogger.warn(
        'Kulüp ayarları yazılamadı: ${error.name}',
        error: message,
      );
    }
    if (ref.mounted) {
      state = state.copyWith(isSubmitting: false, isSubmitError: !shown);
    }
  }

  /// TST-54 TST-21'den sonra gelir (prototip `setTimeout(…, 1200)`); ekran
  /// kapansa da gösterilir — geri bildirim servisi önceden alınır.
  void _showApplicationsToastLater(bool open) {
    final feedback = this.feedback;
    Timer(
      AppDurations.applicationsToastDelay,
      () => feedback.showToast(ToastId.tst54, params: ToastParams(open: open)),
    );
  }

  /// Yaşayan MGT-01 paneli (kulüp adı, başvuru bandı) içerik kalarak
  /// yenilenir.
  void _refreshPanel() {
    final panel = manageViewModelProvider(clubId);
    if (ref.exists(panel)) unawaited(ref.read(panel.notifier).refresh());
  }

  Map<ClubSettingsField, FormFieldError> _errors() {
    final email = state.email.trim();
    final instagram = state.instagram.trim();
    final web = state.web.trim();
    return validateFields({
      ClubSettingsField.summary: () =>
          fromFieldError(FieldValidators.clubSummary(state.summary.trim())),
      ClubSettingsField.about: () =>
          fromFieldError(FieldValidators.clubAbout(state.about.trim())),
      ClubSettingsField.email: () =>
          email.isEmpty || FieldValidators.socialEmail(email) == null
          ? null
          : FormFieldError.invalidEmail,
      ClubSettingsField.instagram: () =>
          instagram.isEmpty || FieldValidators.instagram(instagram) == null
          ? null
          : FormFieldError.invalidFormat,
      ClubSettingsField.web: () =>
          web.isEmpty || FieldValidators.web(web) == null
          ? null
          : FormFieldError.invalidFormat,
    });
  }

  /// Değişiklik sonrası ortak güncelleme: [fields] alanlarının hatası ve eski
  /// gönderim hatası silinir, kirli bayrağı yeniden hesaplanır.
  void _edit(
    ClubSettingsState next, [
    List<ClubSettingsField> fields = const [],
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

  static bool _isDirty(ClubSettingsState form) {
    final original = form.original;
    if (original == null) return false;
    return form.pendingLogo != null ||
        form.pendingCover != null ||
        !_patchOf(form, original).isEmpty;
  }

  /// [club] belgesinden kurulmuş, temiz form.
  static ClubSettingsState _formOf(ClubModel club, {required ClubRole? role}) {
    final social = club.social;
    return ClubSettingsState(
      role: role,
      original: club,
      summary: club.summary,
      about: club.about,
      email: social.email ?? '',
      instagram: social.instagram ?? '',
      web: social.web ?? '',
      applicationsOpen: club.applicationsOpen,
      approvalRequired: club.approvalRequired,
      requireNote: club.requireNote,
      coverPalette: club.palette,
      coverPattern: club.pattern,
      coverSeed: club.coverSeed,
      coverPath: club.coverPath,
      isLoading: false,
    );
  }

  /// [form] ile [original] arasındaki fark: yalnızca değişen alanlar.
  /// Metinler kırpılır; boş iletişim alanı `null` yazılır, Instagram adı
  /// `@` ile başlar (prototip `screens-manage.js:176`).
  static ClubSettingsPatch _patchOf(
    ClubSettingsState form,
    ClubModel original,
  ) {
    final summary = form.summary.trim();
    final about = form.about.trim();
    final social = _socialOf(form);
    return ClubSettingsPatch(
      summary: summary == original.summary.trim() ? null : summary,
      about: about == original.about.trim() ? null : about,
      social: social == _normalized(original.social) ? null : social,
      approvalRequired: form.approvalRequired == original.approvalRequired
          ? null
          : form.approvalRequired,
      applicationsOpen: form.applicationsOpen == original.applicationsOpen
          ? null
          : form.applicationsOpen,
      requireNote: form.requireNote == original.requireNote
          ? null
          : form.requireNote,
      palette: form.coverPalette == original.palette ? null : form.coverPalette,
      pattern: form.coverPattern == original.pattern ? null : form.coverPattern,
      coverSeed: form.coverSeed == original.coverSeed ? null : form.coverSeed,
      // SHT-31 şablonu yüklenmiş kapağın yerine seçildi: `coverPath` bırakılır
      // (dosya silinmez — D-10). Yeni kapak seçildiyse yükleme yolu yazar.
      clearCoverPath:
          original.coverPath != null &&
          form.coverPath == null &&
          form.pendingCover == null,
    );
  }

  static ClubSocialModel _socialOf(ClubSettingsState form) {
    final handle = _orNull(form.instagram);
    return ClubSocialModel(
      email: _orNull(form.email),
      instagram: handle == null || handle.startsWith(_handlePrefix)
          ? handle
          : '$_handlePrefix$handle',
      web: _orNull(form.web),
    );
  }

  /// Belgedeki boş dizgi alanlar "yok" sayılır (fark hesabında).
  static ClubSocialModel _normalized(ClubSocialModel social) => ClubSocialModel(
    email: _orNull(social.email ?? ''),
    instagram: _orNull(social.instagram ?? ''),
    web: _orNull(social.web ?? ''),
  );

  static const String _handlePrefix = '@';

  static String? _orNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// [patch] yazıldıktan sonraki model.
  static ClubModel _applied(ClubModel original, ClubSettingsPatch patch) =>
      original.copyWith(
        summary: patch.summary,
        about: patch.about,
        social: patch.social,
        approvalRequired: patch.approvalRequired,
        applicationsOpen: patch.applicationsOpen,
        requireNote: patch.requireNote,
        palette: patch.palette,
        pattern: patch.pattern,
        coverSeed: patch.coverSeed,
        clearCoverPath: patch.clearCoverPath,
      );

  /// [text] metninin [max] karakterle sınırlı hali; vekil çiftin ortasından
  /// kesilmez.
  static String _clamped(String text, int max) {
    if (text.length <= max) return text;
    final end = _isHighSurrogate(text.codeUnitAt(max - 1)) ? max - 1 : max;
    return text.substring(0, end);
  }

  static bool _isHighSurrogate(int unit) => (unit & 0xFC00) == 0xD800;
}
