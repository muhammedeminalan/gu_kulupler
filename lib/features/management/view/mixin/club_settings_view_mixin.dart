import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/features/management/provider/club_settings_state.dart';
import 'package:gu_kulupler/features/management/provider/club_settings_view_model.dart';
import 'package:gu_kulupler/features/management/view/club_settings_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/category_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/cover_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';

/// MGT-09 davranışı: geri (DLG-25), kulüp değiştirme, seçici sayfalar
/// (SHT-16 / SHT-31 / SHT-33) ve kaydet (prototip `S['MGT-09']`,
/// `screens-manage.js:174–177`).
///
/// * **Geri** (`MGT-09.back`) ve sistem geri tuşu: değişiklik varsa DLG-25 —
///   "Kaydet" kaydeder (başarıda çıkar), "Kaydetmeden çık" çıkar. Gönderim
///   sürerken geri etkisizdir.
/// * **Logo** (`MGT-09.logo`) → SHT-16 kaynak → seçici (yeniden kodlama —
///   CD-135) → önizleme; yükleme kaydettedir.
/// * **Kapak** (`MGT-09.cover`) → SHT-31: şablon ya da "Galeriden seç"
///   (SHT-16).
/// * **Kategori** (`MGT-09.category`) → SHT-33; başka kategori TST-20.
/// * Danışman bakışında logo / kapak / kategori TST-26 verir, sayfa açılmaz.
/// * **Kaydet** (`MGT-09.save`): ekranda kalınır (prototip).
/// * Kulüp değiştir (`MGT-09.switchClub`, birden çok kulüp yönetende) →
///   SHT-18 → seçilen kulübün MGT-01'i (prototip SHT-18 varsayılanı).
mixin ClubSettingsViewMixin on UnsavedChangesMixin<ClubSettingsView> {
  /// Ekranın ViewModel sağlayıcısı (kulüp ailesi).
  ClubSettingsViewModelProvider get provider =>
      clubSettingsViewModelProvider(widget.clubId);

  /// Ekranın ViewModel'i.
  ClubSettingsViewModel get viewModel => ref.read(provider.notifier);

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  ClubSettingsState get _state => ref.read(provider);

  @override
  bool get isDirty => ref.watch(provider.select((state) => state.isDirty));

  /// DLG-25 "Kaydet" = kaydet; başarıda ekran kapanır.
  @override
  Future<bool> Function()? get onSaveRequested => _saveForLeave;

  Future<bool> _saveForLeave() async =>
      await viewModel.save() == ClubSettingsOutcome.saved;

  /// Önceki sayfa; yığın yoksa kulübün yönetim paneli (MGT-01).
  @override
  void leaveScreen() {
    if (context.canPop()) {
      context.pop();
    } else {
      ManageRoute(clubId: widget.clubId).go(context);
    }
  }

  /// Geri (`MGT-09.back`); gönderim sürerken etkisizdir.
  void onBack() {
    if (_state.isSubmitting) return;
    unawaited(confirmLeave());
  }

  /// "Yeniden dene" (`MGT-09.retry`): kulüp yeniden okunur.
  Future<void> retry() => viewModel.load();

  /// "Kaydet" (`MGT-09.save`).
  Future<void> save() async {
    await viewModel.save();
  }

  /// Kulüp değiştir (`MGT-09.switchClub`) → SHT-18 → seçilen kulübün
  /// yönetim paneli (MGT-01).
  Future<void> switchClub() async {
    await _feedback.showSheet<String>(
      SheetId.sht18,
      builder: (_) => ManagedClubPickerSheet(
        selectedClubId: widget.clubId,
        onSelect: _openPanel,
      ),
    );
  }

  void _openPanel(String clubId) {
    if (!mounted) return;
    ManageRoute(clubId: clubId).go(context);
  }

  /// Logo (`MGT-09.logo`) → SHT-16 → seçici.
  Future<void> openLogo() async {
    if (_state.isSubmitting || !viewModel.ensureWritable()) return;
    final choice = await _feedback.showSheet<PhotoSourceChoice>(
      SheetId.sht16,
      builder: (_) => const PhotoSourceSheet(),
    );
    if (!mounted) return;
    final source = switch (choice) {
      PhotoSourceChoice.camera => MediaSource.camera,
      PhotoSourceChoice.gallery => MediaSource.gallery,
      // "Fotoğrafı kaldır" sunulmaz (`hasPhoto` verilmez; logo silinmez).
      PhotoSourceChoice.remove || null => null,
    };
    if (source != null) await viewModel.pickLogo(source);
  }

  /// Kapak (`MGT-09.cover`) → SHT-31: şablon ya da özel kapak kaynağı.
  Future<void> openCover() async {
    if (_state.isSubmitting || !viewModel.ensureWritable()) return;
    final state = _state;
    final club = state.original;
    final result = await _feedback.showSheet<CoverPickerResult>(
      SheetId.sht31,
      builder: (_) => CoverPickerContent(
        palette: state.coverPalette,
        pattern: state.coverPattern,
        seed: state.coverSeed,
        icon: club == null ? null : CoverMapper.icon(club.iconName),
      ),
    );
    if (!mounted) return;
    switch (result) {
      case CoverTemplatePicked(:final palette, :final pattern, :final seed):
        viewModel.setCoverTemplate(palette, pattern, seed);
      case CoverUploadPicked(:final source):
        await viewModel.pickCover(source);
      case null:
        break;
    }
  }

  /// Kategori (`MGT-09.category`) → SHT-33.
  Future<void> openCategory() async {
    if (_state.isSubmitting || !viewModel.ensureWritable()) return;
    final categoryId = await _feedback.showSheet<String>(
      SheetId.sht33,
      builder: (_) =>
          CategoryPickerSheet(selected: _state.original?.categoryId),
    );
    if (categoryId != null && mounted) viewModel.selectCategory(categoryId);
  }
}
