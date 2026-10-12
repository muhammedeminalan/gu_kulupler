import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/auth/provider/setup_profile_state.dart';
import 'package:gu_kulupler/features/auth/provider/setup_profile_view_model.dart';
import 'package:gu_kulupler/features/auth/view/setup_profile_view.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/department_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/year_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

/// AUT-05 davranışı: alt sayfalar, kapatma ve hata metni eşlemesi.
///
/// * Fotoğraf: SHT-16 kaynağı sorar; seçim `SetupProfileViewModel.pickAvatar`
///   ile sürer (izin ön açıklamaları ve seçici orada).
/// * Bölüm / sınıf: SHT-02 / SHT-03 seçimi ViewModel'e yazılır; sayfa
///   kapatılırsa değer değişmez.
/// * Kapat (`AUT-05.close`) ve sistem geri tuşu: seçim yapıldıysa DLG-25
///   sorulur. Bu ekrandan çıkmak oturumu kapatmaktır
///   (`screens-auth.js:141`): "Kaydetmeden çık" ve seçim yokken kapat
///   oturumu kapatır; giriş ekranına router yönlendirir.
/// * Profil tamamlanınca burada gezinme **yapılmaz**: oturum `active` olur,
///   router kabuğa yönlendirir.
mixin SetupProfileViewMixin on UnsavedChangesMixin<SetupProfileView> {
  /// `imageTooLarge` metnindeki `{maxMb}` için bayt → MB böleni.
  static const int _bytesPerMb = 1024 * 1024;

  /// Ekranın ViewModel'i.
  SetupProfileViewModel get viewModel =>
      ref.read(setupProfileViewModelProvider.notifier);

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  bool get isDirty => ref.watch(setupProfileViewModelProvider).isDirty;

  /// Ekrandan çıkış = oturumu kapatma; yönlendirme router'dadır.
  @override
  void leaveScreen() =>
      unawaited(ref.read(sessionViewModelProvider.notifier).signOut());

  /// Kapat düğmesi; gönderim sürerken etkisizdir.
  void onClose() {
    if (ref.read(setupProfileViewModelProvider).isSubmitting) return;
    unawaited(confirmLeave());
  }

  /// "Fotoğraf ekle": SHT-16 → kamera / galeri → seçim.
  Future<void> openPhotoSource() async {
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

  /// Bölüm alanı: SHT-02.
  Future<void> openDepartmentPicker() async {
    final current = ref.read(setupProfileViewModelProvider).departmentId;
    final id = await _feedback.showSheet<String>(
      SheetId.sht02,
      builder: (_) => DepartmentPickerSheet(value: current),
    );
    if (id != null && mounted) viewModel.setDepartment(id);
  }

  /// Sınıf alanı: SHT-03.
  Future<void> openYearPicker() async {
    final current = ref.read(setupProfileViewModelProvider).year;
    final year = await _feedback.showSheet<YearLevel>(
      SheetId.sht03,
      builder: (_) => YearPickerSheet(value: current),
    );
    if (year != null && mounted) viewModel.setYear(year);
  }

  /// [field] alanının hata metni; hata yoksa `null`.
  String? errorTextOf(
    SetupProfileField field,
    SetupProfileState state,
    AppLocalizations l10n,
  ) {
    final error = state.errors[field];
    if (error == null) return null;
    return switch (field) {
      SetupProfileField.department ||
      SetupProfileField.year => l10n.authErrRequired,
      SetupProfileField.interests => l10n.authSetupMinInterest,
      // Seçici yalnızca iki tür hata üretir: boyut sınırı ya da işlenemeyen
      // (JPG / PNG / WebP'ye çevrilemeyen) görsel.
      SetupProfileField.photo =>
        error == FormFieldError.limitExceeded
            ? l10n.imageTooLarge(Limits.imageMaxBytes ~/ _bytesPerMb)
            : l10n.imageInvalidType,
    };
  }

  /// Alana bağlanamayan gönderim hatasının metni (ağ hatası TST-24 ile
  /// bildirilir).
  String? submitErrorTextOf(SetupProfileState state, AppLocalizations l10n) =>
      state.submitError == SetupProfileError.unknown
      ? l10n.sysErrorTitle
      : null;
}
