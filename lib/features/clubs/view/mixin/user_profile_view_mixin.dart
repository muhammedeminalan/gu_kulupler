import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/clubs/provider/user_profile_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/user_profile_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/user_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/navigation/routes/system_routes.dart';

/// CLB-07 davranışı: gezinme, kullanıcı menüsü ve "kullanıcı yok"
/// yönlendirmesi (prototip `UserProfile`, `screens-clubs.js:151–162`).
///
/// * Geri (`CLB-07.back`) bir önceki rotaya döner; yığın yoksa Kulüpler
///   sekmesinin köküne iner.
/// * "⋮" (`CLB-07.menu`) SHT-27'yi açar: "Engelle" / "Engeli kaldır" →
///   ViewModel (DLG-13, TST-09); "Kullanıcıyı şikayet et" → SHT-10 → DLG-12;
///   "Profili gör" bu ekranın kendisidir (bir şey yapmaz).
/// * Ortak kulüp çipi (`CLB-07.club.<clubId>`) → CLB-03.
/// * Engel bandındaki "Engeli kaldır" (`CLB-07.unblock`) → TST-09.
/// * Yönetici kartı (W-69): "Kopyala" → TST-08, "Rolü değiştir" → SHT-22 →
///   DLG-20, "Üyelikten çıkar" → DLG-19 (çıkarılınca geri döner).
/// * Kullanıcı belgesi yoksa SYS-04'e gidilir.
mixin UserProfileViewMixin on ConsumerState<UserProfileView> {
  /// Ekranın ViewModel sağlayıcısı (kullanıcı + açılış kulübü ailesi).
  UserProfileViewModelProvider get provider =>
      userProfileViewModelProvider(widget.userId, clubId: widget.clubId);

  /// Ekranın ViewModel'i.
  UserProfileViewModel get viewModel => ref.read(provider.notifier);

  FeedbackService get _feedback => ref.read(feedbackServiceProvider);

  @override
  void initState() {
    super.initState();
    // Ekran, kullanıcının yokluğu zaten bilinirken açıldıysa (ViewModel
    // canlıydı).
    if (ref.read(provider).isNotFound) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goNotFound());
    }
  }

  /// `build` içinde çağrılır: kullanıcı belgesi yok çıkarsa SYS-04'e gider.
  void watchNotFound() => ref.listen(
    provider.select((state) => state.isNotFound),
    (_, isNotFound) {
      if (isNotFound) _goNotFound();
    },
  );

  /// Geri (`CLB-07.back`).
  void goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      const ClubsRoute().go(context);
    }
  }

  /// "Yeniden dene" (`CLB-07.retry`).
  Future<void> retry() => viewModel.fetch();

  /// Ortak kulüp çipi (`CLB-07.club.<clubId>`) → CLB-03.
  void openClub(String clubId) => ClubDetailRoute(clubId: clubId).go(context);

  /// Engel bandındaki "Engeli kaldır" (`CLB-07.unblock`).
  void unblock() => unawaited(viewModel.toggleBlock());

  /// Yönetici kartı "Kopyala" (`CLB-07.copyEmail`) → TST-08.
  void copyEmail() => unawaited(viewModel.copyEmail());

  /// Yönetici kartı "Rolü değiştir" (`CLB-07.changeRole`) → SHT-22 → DLG-20.
  void changeRole() => unawaited(viewModel.changeRole());

  /// Yönetici kartı "Üyelikten çıkar" (`CLB-07.remove`) → DLG-19; çıkarıldıysa
  /// önceki sayfaya dönülür (`dialogs.js:35`).
  Future<void> remove() async {
    if (await viewModel.remove() && mounted) goBack();
  }

  /// Üyelik tarihi (`12 Ekim 2026`; yerel ayara göre).
  String formatDate(DateTime instant) => AppDateFormats(
    Locale(context.l10n.localeName),
    ref.read(appClockProvider),
  ).date(instant);

  /// "⋮" (`CLB-07.menu`) → SHT-27; seçilen satırı yürütür.
  Future<void> openMenu() async {
    final state = ref.read(provider);
    final user = state.user;
    if (user == null) return;
    final action = await _feedback.showSheet<UserMenuAction>(
      SheetId.sht27,
      builder: (_) => UserMenuSheet(
        userId: widget.userId,
        userName: user.name,
        isBlocked: state.isBlocked,
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case UserMenuAction.block || UserMenuAction.unblock:
        await viewModel.toggleBlock();
      case UserMenuAction.report:
        await openReport();
      // Bu ekran zaten kullanıcının profilidir.
      case UserMenuAction.viewProfile:
      // Yorum satırları yalnızca SHT-09'dan açılan menüde çizilir (T-20).
      case UserMenuAction.removeComment || UserMenuAction.reportComment:
        break;
    }
  }

  /// "Kullanıcıyı şikayet et" (`SHT-27.report`): SHT-10 → yazım → DLG-12.
  Future<void> openReport() async {
    final report = await _feedback.showSheet<ReportReasonResult>(
      SheetId.sht10,
      builder: (_) => ReportReasonSheet(
        target: viewModel.reportTarget,
        onSubmit: viewModel.submitReport,
      ),
    );
    if (report == null || !mounted) return;
    await viewModel.showReportReceived();
  }

  void _goNotFound() {
    if (mounted) const NotFoundRoute().go(context);
  }
}
