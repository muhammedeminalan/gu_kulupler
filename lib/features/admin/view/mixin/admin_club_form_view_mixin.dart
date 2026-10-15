import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/features/admin/provider/admin_club_form_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_club_form_view_model.dart';
import 'package:gu_kulupler/features/admin/view/admin_club_form_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/category_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/cover_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/president_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';

/// ADM-03 davranışı: kapat (DLG-25), seçici sayfalar (SHT-33 / SHT-16 /
/// SHT-31 / SHT-25) ve kaydet (prototip `S['ADM-03']`,
/// `screens-admin.js:43–46`).
///
/// * **Kapat** (`ADM-03.close`) ve sistem geri tuşu: değişiklik varsa DLG-25
///   — "Kaydetmeden çık" çıkar, "Düzenlemeye devam" kalır (prototip DLG-25'i
///   "Kaydet"siz açar). Gönderim sürerken etkisizdir.
/// * **Kategori** → SHT-33; **logo** → SHT-16 → seçici; **kapak** → SHT-31:
///   şablon ya da "Galeriden seç" (SHT-16).
/// * **Başkan ata** → SHT-25 atama kipi (adaylar `presidentCandidates`).
/// * **Kaydet** başarılıysa ADM-02'ye dönülür (`AdminClubsRoute`, `go`;
///   prototip `popTo('ADM-02')`).
mixin AdminClubFormViewMixin on UnsavedChangesMixin<AdminClubFormView> {
  /// Ekranın ViewModel sağlayıcısı (kulüp ailesi; yeni kulüpte `null`).
  AdminClubFormViewModelProvider get provider =>
      adminClubFormViewModelProvider(widget.clubId);

  /// Ekranın ViewModel'i.
  AdminClubFormViewModel get viewModel => ref.read(provider.notifier);

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  AdminClubFormState get _state => ref.read(provider);

  @override
  bool get isDirty => ref.watch(provider.select((state) => state.isDirty));

  /// Önceki sayfa; yığın yoksa ADM-02.
  @override
  void leaveScreen() {
    if (context.canPop()) {
      context.pop();
    } else {
      const AdminClubsRoute().go(context);
    }
  }

  /// Kapat (`ADM-03.close`); gönderim sürerken etkisizdir.
  void onClose() {
    if (_state.isSubmitting) return;
    unawaited(confirmLeave());
  }

  /// "Yeniden dene" (`ADM-03.retry`): kulüp yeniden okunur.
  Future<void> retry() => viewModel.load();

  /// "Oluştur" / "Kaydet" (`ADM-03.save`); başarıda ADM-02.
  Future<void> save() async {
    final outcome = await viewModel.save();
    if (!mounted) return;
    if (outcome == AdminClubFormOutcome.created ||
        outcome == AdminClubFormOutcome.saved) {
      const AdminClubsRoute().go(context);
    }
  }

  /// Kategori (`ADM-03.category`) → SHT-33.
  Future<void> openCategory() async {
    if (_state.isSubmitting) return;
    final categoryId = await _feedback.showSheet<String>(
      SheetId.sht33,
      builder: (_) => CategoryPickerSheet(selected: _state.categoryId),
    );
    if (categoryId != null && mounted) viewModel.setCategory(categoryId);
  }

  /// Logo (`ADM-03.logo`) → SHT-16 → seçici.
  Future<void> openLogo() async {
    if (_state.isSubmitting) return;
    final source = await _pickSource();
    if (source != null && mounted) await viewModel.pickLogo(source);
  }

  /// Kapak (`ADM-03.cover`) → SHT-31: şablon ya da özel kapak kaynağı.
  Future<void> openCover() async {
    if (_state.isSubmitting) return;
    final state = _state;
    final result = await _feedback.showSheet<CoverPickerResult>(
      SheetId.sht31,
      builder: (_) => CoverPickerContent(
        palette: state.coverPalette,
        pattern: state.coverPattern,
        seed: state.coverSeed,
        icon: CoverMapper.icon(state.iconName),
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

  /// "Başkan ata" (`ADM-03.assignPresident`) → SHT-25 atama kipi.
  Future<void> assignPresident() async {
    if (_state.isSubmitting) return;
    final users = await viewModel.presidentCandidates();
    if (users == null || !mounted) return;
    final userId = await _feedback.showSheet<String>(
      SheetId.sht25,
      builder: (_) => PresidentPickerSheet(
        mode: PresidentPickerMode.assign,
        candidates: [for (final u in users) PresidentCandidate.fromUser(u)],
      ),
    );
    if (userId == null || !mounted) return;
    for (final user in users) {
      if (user.uid == userId) viewModel.setPresident(user);
    }
  }

  Future<MediaSource?> _pickSource() async {
    final choice = await _feedback.showSheet<PhotoSourceChoice>(
      SheetId.sht16,
      builder: (_) => const PhotoSourceSheet(),
    );
    return switch (choice) {
      PhotoSourceChoice.camera => MediaSource.camera,
      PhotoSourceChoice.gallery => MediaSource.gallery,
      // "Fotoğrafı kaldır" sunulmaz (`hasPhoto` verilmez; logo silinmez).
      PhotoSourceChoice.remove || null => null,
    };
  }
}
