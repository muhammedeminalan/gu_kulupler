// SYS-02 · Hata — metinler, 3 aksiyon (`SYS-02.back`, `.retry`, `.home`) ve
// sonuçları, cihaz matrisi, aksiyon envanteri, açık + koyu golden. Referans:
// design/reference-shots/screens/SYS-02__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/system/view/error_view.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_auth_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fakes/test_router.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

final Key _back = GuKey.action('SYS-02.back');
final Key _retry = GuKey.action('SYS-02.retry');
final Key _home = GuKey.action('SYS-02.home');

FakeAuthService _auth() => GetIt.I<AuthService>() as FakeAuthService;

void main() {
  group('SYS-02 · Hata', () {
    testWidgets('illüstrasyon, başlık, açıklama ve iki düğme çizilir', (
      tester,
    ) async {
      await tester.pumpApp(const ErrorView());
      final l10n = tester.l10n;
      expect(find.byType(GuErrorState), findsOneWidget);
      expect(
        tester.widget<GuIllustration>(find.byType(GuIllustration)).illustration,
        GuIllustrations.error,
      );
      expect(find.text(l10n.sysErrorTitle), findsOneWidget);
      expect(find.text(l10n.sysErrorDesc), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(_retry),
          matching: find.text(l10n.commonRetry),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_home),
          matching: find.text(l10n.sysErrorHome),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(l10n.a11yBack), findsOneWidget);
      // Çubuk başlıksızdır; gövde çubuğun altındaki alanda ortalanır.
      final body = tester.getRect(find.byType(GuErrorState));
      expect(body.center.dx, 195);
      expect(body.top, greaterThan(GuSizes.appBarMinHeight));
    });

    testWidgets('aksiyon envanteri: SYS-02.back / .retry / .home', (
      tester,
    ) async {
      await tester.pumpApp(const ErrorView());
      expectActionInventory(tester, 'SYS-02');
    });

    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(tester, (_) => const ErrorView(), safeAreas: true);
    });

    testWidgets('golden: açık + koyu', (tester) async {
      await goldenForThemes(tester, 'SYS-02', const ErrorView());
    });

    test('retryLocation: geçerli uygulama yolu, değilse ana sayfa', () {
      expect(const ErrorView().retryLocation, '/clubs');
      expect(const ErrorView(from: '/profile').retryLocation, '/profile');
      expect(
        const ErrorView(from: '/clubs/c01?tab=posts').retryLocation,
        '/clubs/c01?tab=posts',
      );
      for (final invalid in [
        'http://example.com',
        '//example.com/clubs',
        '/login',
        '/error',
        'clubs',
        '',
      ]) {
        expect(
          ErrorView(from: invalid).retryLocation,
          '/clubs',
          reason: invalid,
        );
      }
    });
  });

  group('SYS-02 · Hata · aksiyonlar', () {
    testWidgets('SYS-02.retry: oturum yeniden çözülür ve from yoluna gidilir', (
      tester,
    ) async {
      final app = await TestRouter.pump(
        tester,
        location: '/error?from=%2Fprofile',
      );
      _auth().currentUser = const AuthUserInfo(
        uid: FakeSessionStates.uid,
        email: 'mehmet@ogr.gumushane.edu.tr',
        emailVerified: true,
      );

      await tester.tap(find.byKey(_retry));
      await tester.pumpAndSettle();
      expect(_auth().callsTo('idTokenClaims'), hasLength(1));
      expect(app.location, '/profile');
      expect(find.byType(ErrorView), findsNothing);
    });

    testWidgets('SYS-02.retry: from yoksa ana sayfa', (tester) async {
      final app = await TestRouter.pump(tester, location: '/error');
      _auth().currentUser = const AuthUserInfo(
        uid: FakeSessionStates.uid,
        email: 'mehmet@ogr.gumushane.edu.tr',
        emailVerified: true,
      );
      await tester.tap(find.byKey(_retry));
      await tester.pumpAndSettle();
      expect(app.location, '/clubs');
    });

    testWidgets('SYS-02.retry: oturum yoksa nereye gidileceğine router karar '
        'verir (tanıtım)', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.unknown,
        location: '/error?from=%2Fprofile',
      );
      expect(app.location, '/error?from=%2Fprofile');

      await tester.tap(find.byKey(_retry));
      await tester.pumpAndSettle();
      expect(app.location, '/onboarding');
    });

    testWidgets('SYS-02.home ve SYS-02.back: ana sayfa', (tester) async {
      for (final key in [_home, _back]) {
        final app = await TestRouter.pump(tester, location: '/error');
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        expect(app.location, '/clubs', reason: '$key');
        expect(_auth().callsTo('idTokenClaims'), isEmpty);
      }
    });
  });
}
