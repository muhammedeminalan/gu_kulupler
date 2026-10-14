import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/feed/provider/compose_state.dart';
import 'package:gu_kulupler/features/feed/provider/compose_view_model.dart';
import 'package:gu_kulupler/features/feed/view/compose_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_ui/gu_ui.dart';

/// FED-03 davranışı: kapatma (DLG-25), menü, görsel ekleme (SHT-16), kulüp
/// değiştirme (SHT-18), yayın sonrası gezinme (prototip `Compose`,
/// `screens-clubs.js:181–215`).
///
/// * **Kapat** (`FED-03.close`) ve sistem geri tuşu: değişiklik varsa DLG-25
///   — "Kaydet" taslağı cihaza yazar (TST-13) ve çıkar; "Kaydetmeden çık"
///   çıkar (cihazdaki eski taslak durur); düzenlemede "Kaydet" çizilmez
///   (taslak yalnızca yeni gönderide). Gönderim sürerken kapat etkisizdir.
/// * **"⋮"** (`FED-03.menu`): "Taslak kaydet" (yalnızca yeni gönderi) ·
///   "Önizle" / "Düzenlemeye dön" · "Temizle".
/// * **"Görsel ekle"** (`FED-03.addImage`): sınır dolmuşsa TST-X5; değilse
///   SHT-16 → kamera / galeri → seçim (`ComposeViewModel.addImage`).
/// * **Kulüp adı** (`FED-03.switchClub`): SHT-18 → seçilen kulübün yazı
///   ekranı.
/// * **"Yayınla" / "Kaydet"** (`FED-03.publish`): başarıda kulübün
///   "Gönderiler" sekmesine dönülür; TST-14 "Görüntüle" FED-02'yi açar (toast
///   ekran kapandıktan sonra da durur — gezinme router üzerindendir).
mixin ComposeViewMixin on UnsavedChangesMixin<ComposeView> {
  /// Ekranın ViewModel sağlayıcısı (kulüp + düzenlenen gönderi ailesi).
  ComposeViewModelProvider get provider => composeViewModelProvider(
    clubId: widget.clubId,
    editPostId: widget.editPostId,
  );

  /// Ekranın ViewModel'i.
  ComposeViewModel get viewModel => ref.read(provider.notifier);

  /// Düzenleme kipi mi (`?edit=`)?
  bool get isEditing => widget.editPostId != null;

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  bool get isDirty => ref.watch(provider.select((state) => state.isDirty));

  /// DLG-25 "Kaydet" = taslağı kaydet; düzenlemede taslak yoktur.
  @override
  Future<bool> Function()? get onSaveRequested =>
      isEditing ? null : viewModel.saveDraft;

  /// Önceki sayfa; yığın yoksa kulübün "Gönderiler" sekmesi. Düzenlemede
  /// her zaman sekmeye gidilir: `pop` sorguyu (`?edit=`) üst sayfanın
  /// konumunda bırakır (düzenleme zaten yalnızca akıştan / FED-02'den, `go`
  /// ile açılır — altındaki sayfa kulübün sayfasıdır).
  @override
  void leaveScreen() {
    if (!isEditing && context.canPop()) {
      context.pop();
    } else {
      _goToFeed();
    }
  }

  /// Kapat (`FED-03.close`); gönderim sürerken etkisizdir.
  void onClose() {
    if (ref.read(provider).isSubmitting) return;
    unawaited(confirmLeave());
  }

  /// "Yeniden dene" (`FED-03.retry`): düzenlenecek gönderi yeniden okunur.
  Future<void> retry() => viewModel.loadForEdit();

  /// "⋮" (`FED-03.menu`): taslak / önizleme / temizle.
  Future<void> openMenu() async {
    final l10n = context.l10n;
    final state = ref.read(provider);
    await _feedback.showMenu<void>(
      scrimKey: GuKey.action('FED-03.scrim'),
      items: [
        if (!isEditing)
          GuPopMenuItem(
            key: GuKey.action('FED-03.saveDraft'),
            label: l10n.composeSaveDraft,
            icon: GuIcons.fileText,
            onTap: () => unawaited(viewModel.saveDraft()),
          ),
        GuPopMenuItem(
          key: GuKey.action('FED-03.preview'),
          label: state.isPreview ? l10n.composeEdit : l10n.composePreview,
          icon: GuIcons.eye,
          onTap: viewModel.togglePreview,
        ),
        if (!state.isPollLocked)
          GuPopMenuItem(
            key: GuKey.action('FED-03.clear'),
            label: l10n.composeClear,
            icon: GuIcons.trash2,
            danger: true,
            onTap: viewModel.clear,
          ),
      ],
    );
  }

  /// "Görsel ekle" (`FED-03.addImage`): TST-X5 ya da SHT-16 → seçim.
  Future<void> addImage() async {
    if (!viewModel.ensureCanAddImage()) return;
    final remaining = Limits.postImagesMax - ref.read(provider).images.length;
    final choice = await _feedback.showSheet<PhotoSourceChoice>(
      SheetId.sht16,
      builder: (_) => PhotoSourceSheet(maxImages: remaining),
    );
    if (!mounted) return;
    final source = switch (choice) {
      PhotoSourceChoice.camera => MediaSource.camera,
      PhotoSourceChoice.gallery => MediaSource.gallery,
      // "Fotoğrafı kaldır" bu ekranda sunulmaz (`hasPhoto` verilmez).
      PhotoSourceChoice.remove || null => null,
    };
    if (source != null) await viewModel.addImage(source);
  }

  /// Kulüp adı (`FED-03.switchClub`): SHT-18 → seçilen kulübün yazı ekranı
  /// (prototip `nav.replace('FED-03', {clubId})`).
  Future<void> switchClub() async {
    final current = widget.clubId;
    final clubId = await _feedback.showSheet<String>(
      SheetId.sht18,
      builder: (_) => ManagedClubPickerSheet(selectedClubId: current),
    );
    if (!mounted || clubId == null || clubId == current) return;
    ComposeRoute(clubId: clubId).go(context);
  }

  /// Kapalı "Yayınla" dokunuşu: eksik alanların hatası gösterilir.
  void showErrors() => viewModel.validate();

  /// "Yayınla" / "Kaydet" (`FED-03.publish`).
  Future<void> publish() async {
    // TST-14 "Görüntüle" ekran kapandıktan sonra gelir: bağlam yerine router.
    final router = GoRouter.of(context);
    final clubId = widget.clubId;
    final outcome = await viewModel.publish(
      onView: (postId) => router.go(
        PostDetailRoute(clubId: clubId, postId: postId).location,
      ),
    );
    if (!mounted || outcome != ComposeOutcome.published) return;
    _goToFeed();
  }

  void _goToFeed() => ClubDetailRoute(
    clubId: widget.clubId,
    tab: ClubDetailTab.posts,
  ).go(context);
}
