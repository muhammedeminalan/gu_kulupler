import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/profile/provider/profile_view_model.dart';
import 'package:gu_kulupler/features/profile/view/profile_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/managed_club_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/club_category_request.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_ui/gu_ui.dart';

/// PRF-01 davranışı: başa kaydırma, fotoğraf kaynağı (SHT-16), yönetim
/// paneli seçimi (SHT-18) ve gezinme.
///
/// * Etkin sekmeye yeniden dokunma (`scrollTopRequestProvider`, PLAN §13.2)
///   içeriği başa kaydırır.
/// * Profil dalındaki hedefler (PRF-02, PRF-03, PRF-04) ve başka sekmenin
///   ekranları (EVT-04, CLB-03, CLB-01) `go` ile açılır: başka sekmenin
///   ekranı o sekmenin yığınında kurulur, Profil yığını değişmez (Q-20 = A,
///   navigation.md §4).
mixin ProfileViewMixin on ConsumerState<ProfileView> {
  /// İçeriğin kaydırma denetleyicisi.
  final ScrollController scrollController = ScrollController();

  ProviderSubscription<int>? _scrollTopSubscription;

  /// Ekranın ViewModel'i.
  ProfileViewModel get viewModel => ref.read(profileViewModelProvider.notifier);

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  Duration get _scrollDuration =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : GuMotion.base;

  @override
  void initState() {
    super.initState();
    _scrollTopSubscription = ref.listenManual(
      scrollTopRequestProvider(GuTab.profile),
      (_, _) => scrollToTop(),
    );
  }

  @override
  void dispose() {
    _scrollTopSubscription?.close();
    scrollController.dispose();
    super.dispose();
  }

  /// İçeriği başa kaydırır.
  void scrollToTop() {
    if (!scrollController.hasClients) return;
    unawaited(
      scrollController.animateTo(
        0,
        duration: _scrollDuration,
        curve: GuMotion.easeStandard,
      ),
    );
  }

  /// Çek-yenile.
  Future<void> refresh() => viewModel.refresh();

  /// Hata görünümündeki "Yeniden dene" (`PRF-01.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Avatar (`PRF-01.avatar`): SHT-16 → kamera / galeri → yükleme. Prototip
  /// PRF-01'de "Fotoğrafı kaldır" sunmaz (`hasPhoto` verilmez).
  Future<void> changePhoto() async {
    final choice = await _feedback.showSheet<PhotoSourceChoice>(
      SheetId.sht16,
      builder: (_) => const PhotoSourceSheet(),
    );
    if (!mounted) return;
    final source = switch (choice) {
      PhotoSourceChoice.camera => MediaSource.camera,
      PhotoSourceChoice.gallery => MediaSource.gallery,
      PhotoSourceChoice.remove || null => null,
    };
    if (source != null) await viewModel.changeAvatar(source);
  }

  /// "Profili düzenle" (`PRF-01.edit`) → PRF-02.
  void openEdit() => const EditProfileRoute().go(context);

  /// "Kulüp" kartı (`PRF-01.stat.clubs`) ve "Tümü" (`PRF-01.allClubs`) →
  /// PRF-03.
  void openMyClubs() => const MyClubsRoute().go(context);

  /// "Bekleyen başvuru" kartı (`PRF-01.stat.pending`) → PRF-03 bekleyenler.
  void openPending() => const MyClubsRoute(tab: MyClubsTab.pending).go(context);

  /// "Biletlerim" (`PRF-01.tickets`) → EVT-04 (Etkinlikler sekmesi).
  void openMyEvents() => const MyEventsRoute().go(context);

  /// "Katıldığım etkinlik" kartı (`PRF-01.stat.events`) → EVT-04 "Geçmiş"
  /// sekmesi (prototip `{tab:'past'}`, `screens-profile.js:12`).
  void openPastEvents() =>
      const MyEventsRoute(tab: MyEventsTab.past).go(context);

  /// "Kaydedilenler" (`PRF-01.saved`) → PRF-04.
  void openSaved() => const SavedRoute().go(context);

  /// Ayarlar (`PRF-01.settings`, `PRF-01.settingsRow`) → SET-01.
  void openSettings() => const SettingsRoute().go(context);

  /// Kulüp satırı (`PRF-01.club.<id>`) → CLB-03 (Kulüpler sekmesi).
  void openClub(String clubId) => ClubDetailRoute(clubId: clubId).go(context);

  /// Yönetilen kulüp satırı (`PRF-01.managed.<id>`) → MGT-01.
  void openManaged(String clubId) => ManageRoute(clubId: clubId).go(context);

  /// "Yönetim paneli" (`PRF-01.managedAll`; prototip `flows.openManage`):
  /// birden çok yönetilen kulüpte SHT-18 (varsayılan davranışı seçilen
  /// kulübün MGT-01'idir — W-26); tek kulüpte doğrudan MGT-01.
  Future<void> openManagePanel() async {
    final managed = ref.read(profileViewModelProvider).managedClubs;
    if (managed.isEmpty) return;
    if (managed.length > 1) {
      await _feedback.showSheet<String>(
        SheetId.sht18,
        builder: (_) => const ManagedClubPickerSheet(),
      );
      return;
    }
    openManaged(managed.single.club.id);
  }

  /// "Etkinlikleri keşfet" (`PRF-01.discover`, kulüp yokken) → CLB-01.
  void discoverClubs() => const ClubsRoute().go(context);

  /// İlgi alanı çipi (`PRF-01.interest.<id>`) → CLB-01, süzgeç ilgi
  /// alanının kategorisine çevrilmiş olarak (`clubCategoryRequestProvider`;
  /// prototip `clubFilters.categories = [cat]`, `screens-profile.js:16`).
  void openInterest(String interestId) {
    for (final interest in StaticTables.interests) {
      if (interest.id != interestId) continue;
      ref
          .read(clubCategoryRequestProvider.notifier)
          .request(interest.categoryId);
      break;
    }
    const ClubsRoute().go(context);
  }
}
