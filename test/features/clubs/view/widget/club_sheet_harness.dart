// CLB-03 sheet testlerinin ortak düzeneği (SHT-05, SHT-06, SHT-07): gerçek
// `AppFeedbackService` + go_router gezgini. Feature sheet'leri rotayı
// `context.pop` ile kapatır (HC12b: `Navigator.` yalnızca overlay
// çerçevelerinde), bu yüzden ağaçta `GoRouter` bulunur. Overlay gerçekten
// çizilir (scrim, geçiş, çerçeve); sonuç `showSheet`'in döndürdüğü değerdir.
//
//   final h = ClubSheetHarness<ClubMenuAction>(
//     SheetId.sht06,
//     (_) => const ClubMenuSheet(clubId: 'c01', clubName: 'Kulüp'),
//     session: FakeSessionStates.activeMember('c01'),
//   );
//   await h.pump(tester);        // GetIt sıfırlanır, sahteler kaydedilir
//   h.clubs.put('c01');          // sahteler `pump` SONRASI hazırlanır
//   await h.open(tester);
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../fakes/fake_auth_service.dart';
import '../../../../fakes/fake_club_repository.dart';
import '../../../../fakes/fake_connectivity_service.dart';
import '../../../../fakes/fake_feedback_service.dart';
import '../../../../fakes/fake_membership_repository.dart';
import '../../../../fakes/fake_session_states.dart';
import '../../../../fakes/fake_settings_repository.dart';
import '../../../../helpers/fake_app_clock.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/pump_app.dart';

/// Düzenekteki yasal metin sayfasının (AUT-06 yer tutucusu) anahtarı.
const Key kHarnessLegalKey = ValueKey<String>('harness.legal');

/// [id] sayfasını gerçek servis ve go_router üzerinden açan test düzeneği.
///
/// Gezgin bir `ShellRoute` içindedir: kabuk, uygulama kökündeki gibi
/// (`GuApp.builder`) kök metin stilini verir; sayfa bu gezgine itilir.
class ClubSheetHarness<T> {
  ClubSheetHarness(
    this.id,
    this.builder, {
    this.session = FakeSessionStates.active,
    this.overrides = const [],
  });

  /// Açılan sayfanın kimliği.
  final SheetId id;

  /// Sayfa içeriği (`GuSheetFrame` döndürür).
  WidgetBuilder builder;

  /// Oturum (`sessionViewModelProvider` başlangıç durumu).
  final SessionState session;

  /// Ek sağlayıcı ezmeleri.
  final List<Override> overrides;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final GuToastController controller = GuToastController();
  late final AppFeedbackService service = AppFeedbackService(
    navigatorKey: navigatorKey,
    toastController: controller,
  );
  late final GoRouter router = GoRouter(
    routes: [
      ShellRoute(
        navigatorKey: navigatorKey,
        builder: (context, _, child) =>
            DefaultTextStyle(style: context.gu.text.bodyM, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: SizedBox.expand()),
          ),
          GoRoute(
            path: '/legal/:tip',
            builder: (_, state) => Scaffold(
              key: kHarnessLegalKey,
              body: Text(state.pathParameters['tip'] ?? ''),
            ),
          ),
        ],
      ),
    ],
  );

  static const Object _pending = Object();
  Object? _result = _pending;
  bool _disposeRegistered = false;

  /// Son açılan sayfa kapandı mı?
  bool get isClosed => !identical(_result, _pending);

  /// Son açılan sayfanın sonucu; kapanmadıysa hata.
  T? get result {
    if (!isClosed) throw StateError('${id.designId} henüz kapanmadı.');
    return _result as T?;
  }

  // `pump`'ın kaydettiği sahteler.
  FakeFeedbackService get feedback =>
      GetIt.I<FeedbackService>() as FakeFeedbackService;
  FakeClubRepository get clubs =>
      GetIt.I<ClubRepository>() as FakeClubRepository;
  FakeMembershipRepository get memberships =>
      GetIt.I<MembershipRepository>() as FakeMembershipRepository;
  FakeSettingsRepository get settings =>
      GetIt.I<SettingsRepository>() as FakeSettingsRepository;
  FakeConnectivityService get connectivity =>
      GetIt.I<ConnectivityService>() as FakeConnectivityService;
  FakeAuthService get auth => GetIt.I<AuthService>() as FakeAuthService;
  FakeAppClock get clock => GetIt.I<AppClock>() as FakeAppClock;

  /// Boş bir sayfa üstünde gezgini çizer (GetIt sıfırlanır; sahteler bundan
  /// sonra hazırlanır).
  Future<void> pump(
    WidgetTester tester, {
    Locale locale = const Locale('tr'),
    ThemeMode theme = ThemeMode.light,
    Size size = const Size(390, 844),
    double textScale = 1.0,
    EdgeInsets viewPadding = EdgeInsets.zero,
    double keyboardInset = 0,
  }) async {
    if (!_disposeRegistered) {
      _disposeRegistered = true;
      addTearDown(controller.dispose);
      addTearDown(router.dispose);
    }
    await tester.pumpAppRouter(
      routerOf: (_) => router,
      locale: locale,
      theme: theme,
      size: size,
      textScale: textScale,
      viewPadding: viewPadding,
      keyboardInset: keyboardInset,
      overrides: [
        sessionViewModelProvider.overrideWithBuild((_, _) => session),
        ...overrides,
      ],
    );
  }

  /// Sayfayı açar ve giriş geçişini bitirir. İçerikte sonsuz animasyon
  /// (meşgul düğme) varsa [settle] `false` verilir: yalnızca geçiş süresi
  /// kadar ilerlenir.
  Future<void> open(WidgetTester tester, {bool settle = true}) async {
    _result = _pending;
    unawaited(
      service
          .showSheet<T>(id, builder: builder)
          .then((value) => _result = value),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(GuMotion.sheetEnter);
    }
  }

  /// Geri tuşu: gezgin en üstteki rotaya (sayfaya) kapanmasını sorar.
  Future<void> back(WidgetTester tester) async {
    await navigatorKey.currentState!.maybePop();
    await tester.pumpAndSettle();
  }

  /// Açık sayfanın tam ekran golden'ı (scrim dahil):
  /// `test/goldens/<name>__<tema>__tr.png`.
  Future<void> expectGolden(
    WidgetTester tester,
    String name,
    ThemeMode theme,
  ) => expectLater(
    find.byKey(kPumpAppBoundaryKey),
    matchesGoldenFile(goldenUri(goldenPath(name, theme, const Locale('tr')))),
  );
}
