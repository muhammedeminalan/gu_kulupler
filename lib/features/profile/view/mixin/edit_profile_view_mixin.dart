import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/profile/provider/edit_profile_state.dart';
import 'package:gu_kulupler/features/profile/provider/edit_profile_view_model.dart';
import 'package:gu_kulupler/features/profile/view/edit_profile_view.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/department_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/year_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

/// PRF-02 davranışı: metin denetleyicileri, alt sayfalar, kaydetme, çıkış
/// (prototip `EditProfile`, `screens-profile.js:21–36`).
///
/// * Fotoğraf (`PRF-02.avatar`): SHT-16 kamera / galeri → seçim
///   (`EditProfileViewModel.pickAvatar`; "Fotoğrafı kaldır" sunulmaz —
///   prototip `hasPhoto` vermez).
/// * Bölüm / sınıf: SHT-02 / SHT-03; sayfa kapatılırsa değer değişmez.
/// * "Kaydet" (`PRF-02.save`): başarıda ekran kapanır; kapalı düğmeye dokunma
///   TST-X9.
/// * Geri (`PRF-02.back`) ve sistem geri tuşu: değişiklik varsa DLG-25
///   ("Kaydet" / "Kaydetmeden çık" / "Düzenlemeye devam").
mixin EditProfileViewMixin on UnsavedChangesMixin<EditProfileView> {
  /// `imageTooLarge` metnindeki `{maxMb}` için bayt → MB böleni.
  static const int _bytesPerMb = 1024 * 1024;

  /// Ad alanı.
  late final TextEditingController nameController;

  /// Biyografi alanı.
  late final TextEditingController bioController;

  /// Salt okunur e-posta alanı.
  late final TextEditingController emailController;

  ProviderSubscription<(String, String, String)>? _fieldsSubscription;

  /// Ekranın ViewModel'i.
  EditProfileViewModel get viewModel =>
      ref.read(editProfileViewModelProvider.notifier);

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  bool get isDirty =>
      ref.watch(editProfileViewModelProvider.select((s) => s.isDirty));

  /// DLG-25 "Kaydet": kaydeder; başarıda ekran kapanır.
  @override
  Future<bool> Function()? get onSaveRequested =>
      () async => await viewModel.save() == EditProfileOutcome.saved;

  /// Önceki sayfa; yığın yoksa profil sekmesinin kökü.
  @override
  void leaveScreen() {
    if (context.canPop()) {
      context.pop();
    } else {
      const ProfileRoute().go(context);
    }
  }

  @override
  void initState() {
    super.initState();
    final state = ref.read(editProfileViewModelProvider);
    nameController = TextEditingController(text: state.name);
    bioController = TextEditingController(text: state.bio);
    emailController = TextEditingController(text: state.email);
    // Alanlar ViewModel'den de değişir: e-posta okunur, biyografi sınırda
    // kesilir, kaydetmeden sonra ad kırpılır.
    _fieldsSubscription = ref.listenManual(
      editProfileViewModelProvider.select((s) => (s.name, s.bio, s.email)),
      (_, fields) {
        _show(nameController, fields.$1);
        _show(bioController, fields.$2);
        _show(emailController, fields.$3);
      },
    );
  }

  @override
  void dispose() {
    _fieldsSubscription?.close();
    nameController.dispose();
    bioController.dispose();
    emailController.dispose();
    super.dispose();
  }

  /// Geri (`PRF-02.back`); kaydetme sürerken etkisizdir.
  void onBack() {
    if (ref.read(editProfileViewModelProvider).isSubmitting) return;
    unawaited(confirmLeave());
  }

  /// "Kaydet" (`PRF-02.save`; kapalıyken de → TST-X9).
  Future<void> save() async {
    final outcome = await viewModel.save();
    if (outcome == EditProfileOutcome.saved && mounted) leaveScreen();
  }

  /// "Yeniden dene": form oturumdan yeniden kurulur.
  Future<void> retry() => viewModel.load();

  /// Avatar (`PRF-02.avatar`): SHT-16 → kamera / galeri → seçim.
  Future<void> openPhotoSource() async {
    if (ref.read(editProfileViewModelProvider).isSubmitting) return;
    final choice = await _feedback.showSheet<PhotoSourceChoice>(
      SheetId.sht16,
      builder: (_) => const PhotoSourceSheet(),
    );
    if (!mounted) return;
    final source = switch (choice) {
      PhotoSourceChoice.camera => MediaSource.camera,
      PhotoSourceChoice.gallery => MediaSource.gallery,
      // "Fotoğrafı kaldır" bu ekranda sunulmaz (`hasPhoto` verilmez).
      PhotoSourceChoice.remove || null => null,
    };
    if (source != null) await viewModel.pickAvatar(source);
  }

  /// Bölüm alanı (`PRF-02.department`): SHT-02.
  Future<void> openDepartmentPicker() async {
    final current = ref.read(editProfileViewModelProvider).departmentId;
    final id = await _feedback.showSheet<String>(
      SheetId.sht02,
      builder: (_) => DepartmentPickerSheet(value: current),
    );
    if (id != null && mounted) viewModel.setDepartment(id);
  }

  /// Sınıf alanı (`PRF-02.year`): SHT-03.
  Future<void> openYearPicker() async {
    final current = ref.read(editProfileViewModelProvider).year;
    final year = await _feedback.showSheet<YearLevel>(
      SheetId.sht03,
      builder: (_) => YearPickerSheet(value: current),
    );
    if (year != null && mounted) viewModel.setYear(year);
  }

  /// [field] alanının hata metni; hata yoksa `null`.
  String? errorTextOf(
    EditProfileField field,
    EditProfileState state,
    AppLocalizations l10n,
  ) {
    final error = state.errors[field];
    if (error == null) return null;
    return switch (field) {
      EditProfileField.name => switch (error) {
        FormFieldError.required => l10n.authErrRequired,
        _ => l10n.authErrNameLength(Limits.nameMin, Limits.nameMax),
      },
      EditProfileField.interests => l10n.authSetupMinInterest,
      // Seçici yalnızca iki tür hata üretir: boyut sınırı ya da işlenemeyen
      // görsel.
      EditProfileField.photo =>
        error == FormFieldError.limitExceeded
            ? l10n.imageTooLarge(Limits.imageMaxBytes ~/ _bytesPerMb)
            : l10n.imageInvalidType,
    };
  }

  /// Alana bağlanamayan kaydetme hatasının metni (ağ / yetki hatası toast ile
  /// bildirilir).
  String? submitErrorTextOf(EditProfileState state, AppLocalizations l10n) =>
      state.submitError == EditProfileError.unknown ? l10n.sysErrorTitle : null;

  /// [controller] alanındaki metni [value] yapar (imleç sonda).
  static void _show(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }
}
