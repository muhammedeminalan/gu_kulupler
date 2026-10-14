import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/club_applied_view.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/routes/shell_route.dart';
import 'package:gu_kulupler/product/navigation/routes/system_routes.dart';

/// CLB-04 davranışı: kapatma, gezinme, bildirim izni ve "kulüp yok"
/// yönlendirmesi (prototip `Applied`, `screens-clubs.js:115–121`).
///
/// * Kapat (`CLB-04.close`) kulüp sayfasına döner (`popTo('CLB-03')`).
/// * "Diğer kulüplere göz at" (`CLB-04.browse`) Kulüpler sekmesinin köküne
///   iner (`resetTo('CLB-01')`).
/// * "Başvurularım" (`CLB-04.myApplications`) Profil sekmesinde PRF-03
///   bekleyenler sekmesini açar (Q-20: sekmeler arası bağlantı
///   `AppNavigator.openInTab`).
/// * "Aç" (`CLB-04.enableNotifications`) DLG-03 ön açıklamasını açar; izin
///   ve TST-19 ViewModel'dedir.
/// * Kulüp yok / silinmişse SYS-04'e gidilir.
mixin ClubAppliedViewMixin on ConsumerState<ClubAppliedView> {
  /// Ekranın ViewModel'i.
  ClubApplicationViewModel get viewModel =>
      ref.read(clubApplicationViewModelProvider(widget.clubId).notifier);

  @override
  void initState() {
    super.initState();
    // Ekran, kulübün yokluğu zaten bilinirken açıldıysa (ViewModel canlıydı).
    if (ref.read(clubApplicationViewModelProvider(widget.clubId)).isNotFound) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goNotFound());
    }
  }

  /// `build` içinde çağrılır: kulüp yok / silinmiş çıkarsa SYS-04'e gider.
  void watchNotFound() => ref.listen(
    clubApplicationViewModelProvider(
      widget.clubId,
    ).select((state) => state.isNotFound),
    (_, isNotFound) {
      if (isNotFound) _goNotFound();
    },
  );

  /// Kapat (`CLB-04.close`) → CLB-03.
  void close() => ClubDetailRoute(clubId: widget.clubId).go(context);

  /// "Diğer kulüplere göz at" (`CLB-04.browse`) → CLB-01.
  void browse() => const ClubsRoute().go(context);

  /// "Başvurularım" (`CLB-04.myApplications`) → PRF-03 "Kulüplerim"in
  /// bekleyenler sekmesi (`/profile/clubs?tab=pending`; W-65).
  void openMyApplications() => AppNavigator.openInTab(
    context,
    GuTab.profile,
    const MyClubsRoute(tab: MyClubsTab.pending).location,
  );

  /// "Aç" (`CLB-04.enableNotifications`) → DLG-03.
  void enableNotifications() => unawaited(viewModel.enableNotifications());

  /// Hata bandındaki "Yeniden dene" (`CLB-04.retry`).
  void retry() => unawaited(viewModel.fetch());

  void _goNotFound() {
    if (mounted) const NotFoundRoute().go(context);
  }
}
