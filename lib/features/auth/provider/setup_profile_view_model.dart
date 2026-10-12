import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/auth/provider/setup_profile_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/form_validation_mixin.dart';
import 'package:gu_kulupler/product/mixin/permission_prompt_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_ui/gu_ui.dart' show TurkishCaseX;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'setup_profile_view_model.g.dart';

/// Profil tamamlama ekranının ViewModel'i (AUT-05; PLAN §12.5).
///
/// Üç adımı (fotoğraf → eğitim bilgisi → ilgi alanları) tutar, doğrular ve
/// profili yazar. Yazım sırası Rules sözleşmesine bağlıdır (W-56, W-57):
///
/// 1. Profil belgesi yoksa `createProfile` — e-posta kimlik jetonundaki
///    adrestir, ad kimlik hesabının görünen adıdır (CD-134); çağrı yeniden
///    denemeye karşı güvenlidir.
/// 2. Bölüm + sınıf + ilgi alanları + `profileComplete: true` tek yamada
///    (`updateProfile`).
/// 3. Fotoğraf seçildiyse `updateAvatar` — profil artık tamamlandığından tek
///    başına çağrılabilir. Yükleme başarısız olsa da profil tamamlanmış
///    sayılır (fotoğraf sonradan PRF-02'den eklenir).
/// 4. `SessionViewModel.refreshUser()` → oturum `active` olur; ekranı router
///    değiştirir (bu sınıf gezinmez).
///
/// Ad bu ekranda sorulmaz; izin ön açıklamaları ve görsel seçimi
/// `PermissionPromptMixin` üzerindendir (DLG-04, DLG-05, TST-32).
@riverpod
final class SetupProfileViewModel extends _$SetupProfileViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        FormValidationMixin<SetupProfileField>,
        PermissionPromptMixin {
  static const Set<FirestoreError> _networkErrors = {
    FirestoreError.offline,
    FirestoreError.unavailable,
    FirestoreError.timeout,
  };

  static const Set<StorageError> _networkUploadErrors = {
    StorageError.retryLimitExceeded,
    StorageError.timeout,
  };

  bool _isPicking = false;

  /// Kimlik alanları ekran açılırken bir kez okunur: profil belgesi varsa
  /// (yarım kalmış kurulum) ondan, yoksa kimlik hesabından.
  @override
  SetupProfileState build() {
    final account = authRepository.currentUser;
    final profile = ref.read(sessionViewModelProvider).user;
    return SetupProfileState(
      name: profile?.name ?? _nameOf(account),
      avatarSeed: profile?.avatarSeed ?? account?.uid ?? '',
      isStaff: profile?.staff ?? false,
    );
  }

  /// [step] adımını gösterir; alan hataları ve eski sunucu hatası silinir
  /// (`screens-auth.js:139`, `:147`). Doğrulama yapmaz — ileri geçiş [next]
  /// ile yapılır.
  void setStep(SetupStep step) {
    if (state.isSubmitting || step == state.step) return;
    state = state.copyWith(
      step: step,
      errors: const {},
      clearSubmitError: true,
    );
  }

  /// "Geri": önceki adım; ilk adımda etkisizdir.
  void back() {
    final index = state.step.index;
    if (index > 0) setStep(SetupStep.values[index - 1]);
  }

  /// "Şimdilik atla": fotoğraf adımını geçer (`screens-auth.js:143`). Seçilmiş
  /// fotoğraf varsa korunur.
  void skipPhoto() => setStep(SetupStep.info);

  /// Bölüm seçildi (SHT-02).
  void setDepartment(String id) {
    if (state.isSubmitting || id == state.departmentId) return;
    state = _edited(state.copyWith(departmentId: id), const [
      SetupProfileField.department,
    ]);
  }

  /// Sınıf seçildi (SHT-03).
  void setYear(YearLevel year) {
    if (state.isSubmitting || year == state.year) return;
    state = _edited(state.copyWith(year: year), const [SetupProfileField.year]);
  }

  /// [id] ilgi alanını seçer / seçimi kaldırır ve seçimin değişip
  /// değişmediğini döndürür. `Limits.interestsMax` dolmuşken yeni seçim
  /// yapılmaz: TST-04 gösterilir ve `false` döner.
  bool toggleInterest(String id) {
    if (state.isSubmitting) return false;
    final selected = state.interests;
    final isSelected = selected.contains(id);
    if (!isSelected && !state.canAddInterest) {
      feedback.showToast(ToastId.tst04);
      return false;
    }
    state = _edited(
      state.copyWith(
        interests: isSelected ? selected.difference({id}) : {...selected, id},
      ),
      const [SetupProfileField.interests],
    );
    return true;
  }

  /// [source] kaynağından profil fotoğrafı seçtirir (SHT-16 sonrası).
  ///
  /// Kamera için DLG-04 + sistem izni, galeri için DLG-05 ön açıklaması
  /// `PermissionPromptMixin.pickImage` içindedir; kamera reddinde TST-32
  /// ("Ayarlara git") orada gösterilir. Vazgeçme durumu değiştirmez; görsel
  /// işlenemezse fotoğraf alanına hata yazılır. Süren bir seçim ya da
  /// gönderim varken çağrı yok sayılır.
  Future<void> pickAvatar(MediaSource source) async {
    if (_isPicking || state.isSubmitting) return;
    _isPicking = true;
    try {
      final result = await pickImage(source);
      if (!ref.mounted) return;
      switch (result) {
        case ImagePickSuccess(:final image):
          state = _edited(state.copyWith(avatar: image), const [
            SetupProfileField.photo,
          ]);
        case ImagePickCancelled() ||
            ImagePickFailure(error: ImagePickError.permissionDenied):
          break;
        case ImagePickFailure(:final error):
          AppLogger.warn('Profil fotoğrafı seçilemedi: ${error.name}');
          state = state.copyWith(
            errors: {
              ...state.errors,
              SetupProfileField.photo: error == ImagePickError.tooLarge
                  ? FormFieldError.limitExceeded
                  : FormFieldError.invalidFormat,
            },
          );
      }
    } finally {
      _isPicking = false;
    }
  }

  /// Görünen adımı doğrular ve alan hatalarını state'e yazar; hata yoksa
  /// `true`.
  ///
  /// Kurallar: eğitim adımında bölüm ve (personel değilse) sınıf zorunlu;
  /// ilgi alanları adımında (personel değilse) en az `Limits.interestsMin`
  /// seçim. Fotoğraf adımı isteğe bağlıdır.
  bool validate() {
    final errors = _errorsOf(state.step);
    state = state.copyWith(errors: errors);
    return errors.isEmpty;
  }

  /// Birincil düğme ("Devam" / "Tamamla"): adımı doğrular ve sonraki adıma
  /// geçer; son adımda profili gönderir ([submit]).
  Future<SetupProfileOutcome> next() async {
    if (state.isSubmitting) return SetupProfileOutcome.ignored;
    if (state.step.isLast) return submit();
    if (!validate()) return SetupProfileOutcome.invalid;
    setStep(SetupStep.values[state.step.index + 1]);
    return SetupProfileOutcome.advanced;
  }

  /// Profili yazar ve oturumu yeniler (sıra sınıf açıklamasında).
  ///
  /// Tüm adımlar yeniden doğrulanır; eksik alan varsa o adıma dönülür. Süren
  /// gönderim varken gelen çağrı yok sayılır. Çevrimdışı ve ağ hatasında
  /// TST-24; başarıda TST-05 (fotoğraf yüklendiyse önce TST-57) gösterilir ve
  /// [SetupProfileState.isSubmitting] `true` kalır (ekran yönlendirmeyle
  /// kapanır).
  Future<SetupProfileOutcome> submit() async {
    if (state.isSubmitting) return SetupProfileOutcome.ignored;
    for (final step in SetupStep.values) {
      final errors = _errorsOf(step);
      if (errors.isEmpty) continue;
      state = state.copyWith(step: step, errors: errors);
      return SetupProfileOutcome.invalid;
    }
    if (!ensureOnline()) return SetupProfileOutcome.offline;

    final account = authRepository.currentUser;
    final email = account?.email;
    if (account == null || email == null) {
      AppLogger.warn('Profil tamamlanamadı: oturumda kimlik / e-posta yok');
      state = state.copyWith(submitError: SetupProfileError.unknown);
      return SetupProfileOutcome.failed;
    }

    // Ekran gönderim sürerken kapanabilir: sonraki adımlar bu kopyayı okur.
    final form = state;
    final uid = account.uid;
    final session = ref.read(sessionViewModelProvider.notifier);
    final hasProfile = ref.read(sessionViewModelProvider).user != null;
    state = form.copyWith(
      isSubmitting: true,
      errors: const {},
      clearSubmitError: true,
    );

    if (!hasProfile) {
      final created = await userRepository.createProfile(
        uid: uid,
        email: email,
        name: form.name,
        nameLower: form.name.trLower(),
        avatarSeed: form.avatarSeed,
      );
      if (created case FirebaseFailure(:final error, :final message)) {
        return _fail(error, message);
      }
    }

    // İlgi alanlarını taşıyan yama fotoğraf yazımından önce gider (W-57).
    final patched = await userRepository.updateProfile(
      uid,
      UserProfilePatch(
        department: form.departmentId,
        year: form.isStaff ? null : form.year,
        interests: [
          for (final interest in StaticTables.interests)
            if (form.interests.contains(interest.id)) interest.id,
        ],
        profileComplete: true,
      ),
    );
    if (patched case FirebaseFailure(:final error, :final message)) {
      return _fail(error, message);
    }

    final avatar = form.avatar;
    final uploadLostConnection =
        avatar != null && await _uploadAvatar(uid, avatar);

    await session.refreshUser();
    if (ref.mounted &&
        ref.read(sessionViewModelProvider).status != AuthStatus.active) {
      // Profil yazıldı ama oturum yenilenemedi: yeniden deneme güvenlidir.
      state = state.copyWith(
        isSubmitting: false,
        clearUploadProgress: true,
        submitError: SetupProfileError.unknown,
      );
      return SetupProfileOutcome.failed;
    }
    // Aynı anda tek toast: bağlantı koptuğu için yüklenemeyen fotoğraf
    // karşılamadan önce gelir.
    if (uploadLostConnection) {
      feedback.showToast(ToastId.tst24);
    } else {
      feedback.showToast(
        ToastId.tst05,
        params: ToastParams(name: form.firstName),
      );
    }
    return SetupProfileOutcome.success;
  }

  /// Fotoğrafı yükler ve `avatarPath` alanını yazar; başarıda TST-57.
  ///
  /// Hata gönderimi durdurmaz (profil tamamlandı). Dönüş: yükleme bağlantı
  /// koptuğu için mi başarısız oldu (çağıran TST-24 gösterir)?
  Future<bool> _uploadAvatar(String uid, PickedImage avatar) async {
    final result = await userRepository.updateAvatar(
      uid,
      bytes: avatar.bytes,
      contentType: avatar.contentType,
      onProgress: (fraction) {
        if (ref.mounted) state = state.copyWith(uploadProgress: fraction);
      },
    );
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(ToastId.tst57);
        return false;
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn('Profil fotoğrafı yüklenemedi: $error', error: message);
        return _networkUploadErrors.contains(error.storage) ||
            _networkErrors.contains(error.firestore);
    }
  }

  SetupProfileOutcome _fail(FirestoreError error, String? message) {
    final isNetwork = _networkErrors.contains(error);
    if (isNetwork) {
      feedback.showToast(ToastId.tst24);
    } else {
      AppLogger.warn('Profil tamamlanamadı: ${error.name}', error: message);
    }
    // Oturum olayı ekranı kapatmış olabilir; kapanmış state'e yazılmaz.
    if (ref.mounted) {
      state = state.copyWith(
        isSubmitting: false,
        clearUploadProgress: true,
        submitError: isNetwork
            ? SetupProfileError.network
            : SetupProfileError.unknown,
      );
    }
    return SetupProfileOutcome.failed;
  }

  Map<SetupProfileField, FormFieldError> _errorsOf(SetupStep step) =>
      switch (step) {
        SetupStep.photo => const {},
        SetupStep.info => validateFields({
          SetupProfileField.department: () =>
              state.departmentId == null ? FormFieldError.required : null,
          if (!state.isStaff)
            SetupProfileField.year: () =>
                state.year == null ? FormFieldError.required : null,
        }),
        SetupStep.interests => validateFields({
          if (!state.isStaff)
            SetupProfileField.interests: () =>
                state.interests.length < Limits.interestsMin
                ? FormFieldError.required
                : null,
        }),
      };

  /// Düzenleme sonrası ortak güncelleme: form kirlenir, [fields] alanlarının
  /// hatası ve eski sunucu hatası silinir.
  SetupProfileState _edited(
    SetupProfileState next,
    List<SetupProfileField> fields,
  ) => next.copyWith(
    isDirty: true,
    clearSubmitError: true,
    errors: {
      for (final entry in next.errors.entries)
        if (!fields.contains(entry.key)) entry.key: entry.value,
    },
  );

  /// Kimlik hesabından ad: görünen ad, yoksa e-postanın yerel kısmı (CD-134).
  /// Boş görünen ad yok sayılır: `createProfile` boş adı kabul etmez.
  static String _nameOf(AuthUserInfo? account) {
    final displayName = account?.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) return displayName;
    return account?.email?.split('@').first.trim() ?? '';
  }
}
