// SYS-01 · Açılış — logo animasyonu (`@keyframes splash`), sürüm satırı,
// zaman aşımı / oturum hatası → SYS-02, cihaz matrisi, aksiyon envanteri
// (0 aksiyon) ve açık + koyu golden. Referans:
// design/reference-shots/screens/SYS-01__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/system/provider/splash_state.dart';
import 'package:gu_kulupler/features/system/provider/splash_view_model.dart';
import 'package:gu_kulupler/features/system/view/error_view.dart';
import 'package:gu_kulupler/features/system/view/splash_view.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/splash_hold.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_session_states.dart';
import '../../../fakes/test_router.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

/// Logoyu saran en yakın geçiş widget'ı (rota geçişleri daha dıştadır).
T _logoTransition<T extends Widget>(WidgetTester tester) => tester.widget<T>(
  find.ancestor(of: find.byType(GuLogo), matching: find.byType(T)).first,
);

double _logoScale(WidgetTester tester) =>
    _logoTransition<ScaleTransition>(tester).scale.value;

double _logoOpacity(WidgetTester tester) =>
    _logoTransition<FadeTransition>(tester).opacity.value;

SplashState _splashState(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(SplashView)),
).read(splashViewModelProvider);

void main() {
  group('SYS-01 · Açılış', () {
    testWidgets('logo (96), ürün adı ve sürüm çizilir', (tester) async {
      await tester.pumpApp(const SplashView());
      await tester.pumpAndSettle();

      expect(tester.widget<GuLogo>(find.byType(GuLogo)).size, 96);
      final title = tester.widget<Text>(find.text(AppConstants.appName));
      expect(
        title.style,
        tester.element(find.byType(SplashView)).gu.text.splashTitle,
      );
      expect(find.text(tester.l10n.sysSplashVersion('1.0.0')), findsOneWidget);
      // Blok ekranın tamamında ortalanır; sürüm alttan 40 dp yukarıda biter.
      expect(tester.getCenter(find.byType(Column)).dx, 195);
      expect(
        tester
            .getBottomLeft(find.text(tester.l10n.sysSplashVersion('1.0.0')))
            .dy,
        844 - GuSizes.splashVersionBottom,
      );
    });

    testWidgets('sürüm okunamadıysa satır çizilmez', (tester) async {
      await tester.pumpApp(
        const SplashView(),
        overrides: [
          splashViewModelProvider.overrideWithBuild(
            (ref, notifier) => const SplashState(),
          ),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text(tester.l10n.sysSplashVersion('')), findsNothing);
      expect(find.text(AppConstants.appName), findsOneWidget);
    });

    testWidgets('sürüm satırı alt güvenli alanın altına inmez', (tester) async {
      await tester.pumpApp(
        const SplashView(),
        viewPadding: const EdgeInsets.only(bottom: 48),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getBottomLeft(find.text(tester.l10n.sysSplashVersion('1.0.0')))
            .dy,
        844 - 48 - GuSpacing.s8,
      );
    });

    testWidgets('logo animasyonu: ölçek .7 → 1.05 (%60) → 1, opaklık 0 → 1; '
        'bitince isAnimationDone', (tester) async {
      await tester.pumpApp(const SplashView());
      expect(_logoScale(tester), GuMotion.splashStartScale);
      expect(_logoOpacity(tester), 0);
      expect(_splashState(tester).isAnimationDone, isFalse);

      // İlk kare animasyonu başlatır (başlangıç anı kaydedilir).
      await tester.pump();
      expect(_splashState(tester).startedAt, isNotNull);

      await tester.pump(GuMotion.splash * GuMotion.splashPeakAt);
      expect(_logoScale(tester), closeTo(GuMotion.splashPeakScale, 1e-9));
      expect(_logoOpacity(tester), closeTo(1, 1e-9));
      expect(_splashState(tester).isAnimationDone, isFalse);

      await tester.pump(GuMotion.splash * (1 - GuMotion.splashPeakAt));
      expect(_logoScale(tester), 1);
      expect(_logoOpacity(tester), 1);

      // Tamamlanma durumu süre dolduktan sonraki karede bildirilir.
      await tester.pump(GuMotion.fast);
      expect(_splashState(tester).isAnimationDone, isTrue);
      expect(_splashState(tester).isTimedOut, isFalse);
    });

    testWidgets('azaltılmış harekette animasyon anında biter', (tester) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const SplashView(),
          ),
        ),
      );
      await tester.pump();
      expect(_logoScale(tester), 1);
      expect(_logoOpacity(tester), 1);
      expect(_splashState(tester).isAnimationDone, isTrue);
    });

    testWidgets('aksiyon envanteri: etkileşimli öğe yok', (tester) async {
      await tester.pumpApp(const SplashView());
      await tester.pumpAndSettle();
      expectActionInventory(tester, 'SYS-01');
    });

    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const SplashView(),
        safeAreas: true,
      );
    });

    testWidgets('golden: açık + koyu', (tester) async {
      for (final theme in kGoldenThemes) {
        await tester.pumpApp(const SplashView(), theme: theme);
        // PNG kod çözümü motor tarafındadır → runAsync.
        final image = tester.widget<Image>(find.byType(Image));
        await tester.runAsync(
          () => precacheImage(image.image, tester.element(find.byType(Image))),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(kPumpAppBoundaryKey),
          matchesGoldenFile(
            goldenUri(goldenPath('SYS-01', theme, const Locale('tr'))),
          ),
        );
      }
    });
  });

  group('SYS-01 · Açılış · yönlendirme', () {
    GoRouter routerOf(WidgetTester tester) => ProviderScope.containerOf(
      tester.element(find.byType(SplashView)),
    ).read(appRouterProvider);

    testWidgets('oturum Limits.splashTimeout içinde çözülmezse SYS-02', (
      tester,
    ) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.unknown,
      );
      expect(app.location, '/splash');

      await tester.pump(
        Limits.splashTimeout - const Duration(seconds: 2),
      );
      await tester.pumpAndSettle();
      expect(app.location, '/splash');

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(app.location, '/error');
      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.byType(SplashView), findsNothing);
    });

    testWidgets('oturum hata verirse SYS-02', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.unknown,
      );
      app.session = app.session.copyWith(isError: true);
      await tester.pumpAndSettle();
      expect(app.location, '/error');
    });

    testWidgets('oturum hatası animasyon bitmeden gelirse SYS-02 animasyonun '
        'ardından açılır', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAppRouter(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => const SessionState(isError: true),
          ),
        ],
      );
      final router = routerOf(tester);
      String location() =>
          router.routerDelegate.currentConfiguration.uri.toString();

      await tester.pump();
      await tester.pump(GuMotion.splash * GuMotion.splashPeakAt);
      expect(location(), '/splash');

      await tester.pumpAndSettle();
      expect(location(), '/error');
    });

    testWidgets('oturum animasyon bitmeden çözülse de açılış en az animasyon '
        'süresi kadar görünür (architecture §4)', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAppRouter(
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => FakeSessionStates.active,
          ),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SplashView)),
      );
      final router = container.read(appRouterProvider);
      String location() =>
          router.routerDelegate.currentConfiguration.uri.toString();
      expect(container.read(splashHoldProvider), isTrue);

      await tester.pump();
      await tester.pump(GuMotion.splash * GuMotion.splashPeakAt);
      expect(location(), '/splash');
      expect(find.byType(SplashView), findsOneWidget);

      await tester.pumpAndSettle();
      expect(container.read(splashHoldProvider), isFalse);
      expect(location(), '/clubs');
      expect(find.byType(SplashView), findsNothing);
    });

    testWidgets('oturum çözülünce router çıkarır; bekleyen zaman aşımı iptal '
        'olur', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.unknown,
      );
      app.session = FakeSessionStates.active;
      await tester.pumpAndSettle();
      expect(app.location, '/clubs');

      await tester.pump(Limits.splashTimeout);
      await tester.pumpAndSettle();
      expect(app.location, '/clubs');
    });
  });
}
