import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/profile/provider/edit_profile_state.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/form_validation_mixin.dart';
import 'package:gu_kulupler/product/mixin/permission_prompt_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_ui/gu_ui.dart' show TurkishCaseX;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'edit_profile_view_model.g.dart';

/// "Profili düzenle" ekranının ViewModel'i (PRF-02; PLAN §12.6).
///
/// Form oturumdaki profilden kurulur; e-posta sahibinin gizli hesap
/// belgesinden okunur (D-29). Kaydetme (prototip `save`,
/// `screens-profile.js:25`):
///
/// 1. Değişiklik yoksa TST-X9, hiçbir şey yazılmaz.
/// 2. Doğrulama: ad `Limits.nameMin`–`Limits.nameMax` (kırpılmış), ilgi
///    alanı en az `Limits.interestsMin` (personel hariç). Biyografi girilirken
///    `Limits.bioMax`'ta kesilir.
/// 3. Çevrimdışıysa TST-24 (`WriteGuardMixin`).
/// 4. Yeni fotoğraf varsa `updateAvatar` — değişen profil alanları aynı
///    yazımda `profile` yamasıyla gider (CD-135: parametre PRF-02 içindir);
///    yoksa `updateProfile` yalnızca değişen alanlarla.
/// 5. Başarı: oturum yenilenir (`refreshUser`), yalnızca fotoğraf değiştiyse
///    TST-57, aksi halde TST-21. Hata: form değerleri yerinde kalır (yazım
///    tek adımdır, geri alınacak yerel değişiklik yoktur); ağ → TST-24, yetki
///    → TST-X18, diğerleri günlüğe + form altı hata satırı.
///
/// Görsel seçimi ve izin ön açıklamaları `PermissionPromptMixin`'dedir
/// (DLG-04, DLG-05, TST-32; yeniden kodlama `DeviceImagePickerService`,
/// CD-135(8c)).
@riverpod
final class EditProfileViewModel extends _$EditProfileViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        FormValidationMixin<EditProfileField>,
        PermissionPromptMixin {
  static const Set<StorageError> _networkUploadErrors = {
    StorageError.retryLimitExceeded,
    StorageError.timeout,
  };

  bool _isPicking = false;

  /// Form oturumdaki profilden eşzamanlı kurulur; e-posta ardından okunur.
  @override
  EditProfileState build() {
    final initial = _formOf(ref.read(sessionViewModelProvider).user);
    if (initial.original != null) unawaited(Future.microtask(_loadEmail));
    return initial;
  }

  /// Formu oturumdaki profilden yeniden kurar ve e-postayı okur ("Yeniden
  /// dene"). Profil yoksa hata durumu.
  Future<void> load() async {
    if (state.isSubmitting) return;
    state = _formOf(ref.read(sessionViewModelProvider).user);
    if (state.original != null) await _loadEmail();
  }

  /// Ad değişti (`PRF-02.name`).
  void setName(String value) {
    if (state.isSubmitting || value == state.name) return;
    state = _edited(state.copyWith(name: value), const [
      EditProfileField.name,
    ]);
  }

  /// Bölüm seçildi (SHT-02).
  void setDepartment(String id) {
    if (state.isSubmitting || id == state.departmentId) return;
    state = _edited(state.copyWith(departmentId: id), const []);
  }

  /// Sınıf seçildi (SHT-03).
  void setYear(YearLevel year) {
    if (state.isSubmitting || year == state.year) return;
    state = _edited(state.copyWith(year: year), const []);
  }

  /// Biyografi değişti (`PRF-02.bio`); `Limits.bioMax`'tan uzun metin
  /// kesilir (prototip `v.slice(0, 140)`).
  void setBio(String value) {
    if (state.isSubmitting) return;
    final bio = _truncate(value, Limits.bioMax);
    if (bio == state.bio) return;
    state = _edited(state.copyWith(bio: bio), const []);
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
      const [EditProfileField.interests],
    );
    return true;
  }

  /// Kilitli e-posta alanına dokunuldu (`PRF-02.lockedEmail`): TST-20.
  void onLockedFieldTap() => feedback.showToast(ToastId.tst20);

  /// [source] kaynağından yeni profil fotoğrafı seçtirir (SHT-16 sonrası).
  ///
  /// İzin ön açıklamaları ve kamera reddi (TST-32)
  /// `PermissionPromptMixin.pickImage` içindedir. Vazgeçme durumu
  /// değiştirmez; görsel işlenemezse fotoğraf alanına hata yazılır. Süren
  /// bir seçim ya da kaydetme varken çağrı yok sayılır.
  Future<void> pickAvatar(MediaSource source) async {
    if (_isPicking || state.isSubmitting || state.original == null) return;
    _isPicking = true;
    try {
      final result = await pickImage(source);
      if (!ref.mounted) return;
      switch (result) {
        case ImagePickSuccess(:final image):
          state = _edited(state.copyWith(avatar: image), const [
            EditProfileField.photo,
          ]);
        case ImagePickCancelled() ||
            ImagePickFailure(error: ImagePickError.permissionDenied):
          break;
        case ImagePickFailure(:final error):
          AppLogger.warn('Profil fotoğrafı seçilemedi: ${error.name}');
          state = state.copyWith(
            errors: {
              ...state.errors,
              EditProfileField.photo: error == ImagePickError.tooLarge
                  ? FormFieldError.limitExceeded
                  : FormFieldError.invalidFormat,
            },
          );
      }
    } finally {
      _isPicking = false;
    }
  }

  /// Alanları doğrular ve hatalarını state'e yazar (fotoğraf hatası
  /// korunur); hata yoksa `true`.
  bool validate() {
    final errors = _validationErrors();
    state = state.copyWith(
      errors: {
        EditProfileField.photo: ?state.errors[EditProfileField.photo],
        ...errors,
      },
    );
    return errors.isEmpty;
  }

  /// "Kaydet" (`PRF-02.save`; kapalıyken de çağrılır → TST-X9). Akış sınıf
  /// açıklamasında.
  Future<EditProfileOutcome> save() async {
    final original = state.original;
    if (state.isSubmitting || original == null) {
      return EditProfileOutcome.ignored;
    }
    if (!state.isDirty) {
      feedback.showToast(ToastId.tstX9);
      return EditProfileOutcome.noChanges;
    }
    if (!validate()) return EditProfileOutcome.invalid;
    if (!ensureOnline()) return EditProfileOutcome.offline;

    // Ekran kaydetme sürerken kapanabilir: sonraki adımlar bu kopyayı okur.
    final form = state;
    final uid = original.uid;
    final session = ref.read(sessionViewModelProvider.notifier);
    final patch = _patchOf(form, original);
    state = form.copyWith(isSubmitting: true, clearSubmitError: true);

    final avatar = form.avatar;
    String? avatarPath;
    if (avatar != null) {
      final result = await userRepository.updateAvatar(
        uid,
        bytes: avatar.bytes,
        contentType: avatar.contentType,
        profile: patch.isEmpty ? null : patch,
        onProgress: (fraction) {
          if (ref.mounted) state = state.copyWith(uploadProgress: fraction);
        },
      );
      switch (result) {
        case FirebaseSuccess(:final data):
          avatarPath = data;
        case FirebaseFailure(:final error, :final message):
          return _fail(
            isNetwork:
                _networkUploadErrors.contains(error.storage) ||
                WriteGuardMixin.networkErrors.contains(error.firestore),
            firestore: error.firestore,
            reason: '$error',
            message: message,
          );
      }
    } else {
      final result = await userRepository.updateProfile(uid, patch);
      if (result case FirebaseFailure(:final error, :final message)) {
        return _fail(
          isNetwork: WriteGuardMixin.networkErrors.contains(error),
          firestore: error,
          reason: error.name,
          message: message,
        );
      }
    }

    feedback.showToast(
      avatar != null && patch.isEmpty ? ToastId.tst57 : ToastId.tst21,
    );
    await session.refreshUser();
    if (ref.mounted) {
      state = _formOf(
        _applied(original, patch, avatarPath),
      ).copyWith(email: form.email);
    }
    return EditProfileOutcome.saved;
  }

  EditProfileOutcome _fail({
    required bool isNetwork,
    required FirestoreError? firestore,
    required String reason,
    String? message,
  }) {
    // Yükleme adımının ağ hatası Storage türündedir: TST-24 doğrudan.
    if (isNetwork) feedback.showToast(ToastId.tst24);
    final notified =
        isNetwork || (firestore != null && showWriteFailureToast(firestore));
    if (!notified) {
      AppLogger.warn('Profil kaydedilemedi: $reason', error: message);
    }
    if (ref.mounted) {
      state = state.copyWith(
        isSubmitting: false,
        clearUploadProgress: true,
        submitError: notified ? null : EditProfileError.unknown,
      );
    }
    return EditProfileOutcome.failed;
  }

  Future<void> _loadEmail() async {
    if (!ref.mounted) return;
    final uid = state.original?.uid;
    if (uid == null) return;
    final result = await userRepository.getPrivateAccount(uid);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data?):
        state = state.copyWith(email: data.email);
      case FirebaseSuccess():
        AppLogger.warn('Hesap belgesi yok: e-posta gösterilemiyor');
      case FirebaseFailure(:final error):
        AppLogger.warn('E-posta okunamadı: ${error.name}');
    }
  }

  Map<EditProfileField, FormFieldError> _validationErrors() => validateFields({
    EditProfileField.name: () =>
        fromFieldError(FieldValidators.name(state.trimmedName)),
    if (!state.isStaff)
      EditProfileField.interests: () =>
          state.interests.length < Limits.interestsMin
          ? FormFieldError.required
          : null,
  });

  /// Yalnızca değişen alanları taşıyan yama (`name` + `nameLower` birlikte,
  /// ilgi alanları `StaticTables.interests` sırasıyla).
  static UserProfilePatch _patchOf(EditProfileState form, UserModel original) {
    final name = form.trimmedName;
    final nameChanged = name != original.name;
    final bio = form.trimmedBio;
    final interestsChanged =
        form.interests.length != original.interests.length ||
        !form.interests.containsAll(original.interests);
    return UserProfilePatch(
      name: nameChanged ? name : null,
      nameLower: nameChanged ? name.trLower() : null,
      department: form.departmentId != original.department
          ? form.departmentId
          : null,
      year: form.year != original.year ? form.year : null,
      interests: interestsChanged
          ? [
              for (final interest in StaticTables.interests)
                if (form.interests.contains(interest.id)) interest.id,
            ]
          : null,
      bio: bio != original.bio ? bio : null,
    );
  }

  /// Yazılan değerlerle güncellenmiş profil (yeni form tabanı).
  static UserModel _applied(
    UserModel original,
    UserProfilePatch patch,
    String? avatarPath,
  ) => original.copyWith(
    name: patch.name,
    nameLower: patch.nameLower,
    department: patch.department,
    year: patch.year,
    interests: patch.interests,
    bio: patch.bio,
    avatarPath: avatarPath,
  );

  /// [user] profilinden kurulmuş form; `null` → hata durumu.
  static EditProfileState _formOf(UserModel? user) => user == null
      ? const EditProfileState(isError: true)
      : EditProfileState(
          original: user,
          name: user.name,
          departmentId: user.department,
          year: user.year,
          interests: user.interests.toSet(),
          bio: user.bio,
        );

  /// Düzenleme sonrası ortak güncelleme: [fields] alanlarının hatası ve eski
  /// sunucu hatası silinir.
  EditProfileState _edited(
    EditProfileState next,
    List<EditProfileField> fields,
  ) => next.copyWith(
    clearSubmitError: true,
    errors: {
      for (final entry in next.errors.entries)
        if (!fields.contains(entry.key)) entry.key: entry.value,
    },
  );

  /// [value] metnini en çok [max] UTF-16 birimine keser; vekil çiftini
  /// bölmez.
  static String _truncate(String value, int max) {
    if (value.length <= max) return value;
    var end = max;
    final last = value.codeUnitAt(end - 1);
    // Yüksek vekil (0xD800–0xDBFF) çiftinin yarısı kalmasın.
    if (last >= _highSurrogateMin && last <= _highSurrogateMax) end--;
    return value.substring(0, end);
  }

  static const int _highSurrogateMin = 0xD800;
  static const int _highSurrogateMax = 0xDBFF;
}
