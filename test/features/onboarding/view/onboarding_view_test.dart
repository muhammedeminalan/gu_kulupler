// ONB-01 · Karşılama — üç slayt (Keşfet / Katıl / Takip et), dil düğmesi,
// "Atla", sayfa noktaları, "İleri" → "Başla"; 4 envanter aksiyonu
// (`ONB-01.lang`, `.next`, `.skip`, `.swipe`) + son slayttaki `.start`,
// sonuçları, cihaz matrisi, açık + koyu golden. Referans:
// design/reference-shots/screens/ONB-01__*.webp; prototip
// `screens-auth.js:44–51`.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/onboarding/provider/onboarding_state.dart';
import 'package:gu_kulupler/features/onboarding/provider/onboarding_view_model.dart';
import 'package:gu_kulupler/features/onboarding/view/onboarding_view.dart';
import 'package:gu_kulupler/features/onboarding/view/widget/onboarding_slide.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/menu_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/widget/system/language_menu_button.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fakes/test_router.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../onboarding_test_support.dart';

final Key _lang = GuKey.action('ONB-01.lang');
final Key _skip = GuKey.action('ONB-01.skip');
final Key _swipe = GuKey.action('ONB-01.swipe');
final Key _next = GuKey.action('ONB-01.next');
final Key _start = GuKey.action('ONB-01.start');

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

/// Ekranı son slaytta açan sağlayıcı değişikliği.
final Override _onLastSlide = onboardingViewModelProvider.overrideWithBuild(
  (ref, notifier) =>
      const OnboardingState(pageIndex: OnboardingState.pageCount - 1),
);

int _dotIndex(WidgetTester tester) =>
    tester.widget<GuPageDots>(find.byType(GuPageDots)).index;

FakeAppPreferencesStore _store() =>
    GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;

/// Ekranı `/onboarding`'de, girişi yer tutucu sayfayla çizen router: ekranın
/// kendi gezinmesi (`LoginRoute().go`) uygulamanın yönlendirmesinden
/// bağımsız doğrulanır.
Future<GoRouter> _pumpWithRouter(
  WidgetTester tester, {
  bool lastSlide = false,
}) async {
  GoRouter? router;
  await tester.pumpAppRouter(
    overrides: [if (lastSlide) _onLastSlide],
    routerOf: (_) => router ??= GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingView(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const TestPage('/login'),
        ),
      ],
    ),
  );
  addTearDown(() => router?.dispose());
  await tester.pumpAndSettle();
  return router!;
}

String _locationOf(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  group('ONB-01 · Karşılama', () {
    testWidgets('ilk slayt: dil düğmesi, Atla, 200 px illüstrasyon, başlık, '
        'açıklama, noktalar, İleri — TR ve EN', (tester) async {
      for (final (locale, code) in [(_tr, 'TR'), (_en, 'EN')]) {
        await tester.pumpApp(const OnboardingView(), locale: locale);
        await tester.pump();
        final l10n = tester.l10n;

        // Üst satır: solda dil (oksuz), sağda "Atla" (metin / küçük).
        final lang = tester.widget<LanguageMenuButton>(find.byKey(_lang));
        expect(lang.chevron, isFalse);
        expect(find.text(code), findsOneWidget);
        final skip = tester.widget<GuButton>(find.byKey(_skip));
        expect(skip.label, l10n.onbSkip);
        expect(skip.variant, GuButtonVariant.text);
        expect(skip.size, GuButtonSize.sm);
        expect(
          tester.getCenter(find.byKey(_lang)).dx,
          lessThan(tester.getCenter(find.byKey(_skip)).dx),
        );

        // Slayt: Keşfet.
        final illustration = tester.widget<GuIllustration>(
          find.byType(GuIllustration),
        );
        expect(illustration.illustration, GuIllustrations.onbDiscover);
        expect(illustration.size, 200);
        expect(find.text(l10n.onbDiscoverTitle), findsOneWidget);
        expect(find.text(l10n.onbDiscoverDesc), findsOneWidget);

        // Alt blok: 3 nokta (ilki etkin) + "İleri →" (büyük, tam genişlik).
        final dots = tester.widget<GuPageDots>(find.byType(GuPageDots));
        expect(dots.count, 3);
        expect(dots.index, 0);
        final next = tester.widget<GuButton>(find.byKey(_next));
        expect(next.label, l10n.onbNext);
        expect(next.variant, GuButtonVariant.primary);
        expect(next.size, GuButtonSize.lg);
        expect(next.full, isTrue);
        expect(next.iconTrailing, GuIcons.arrowRight);
        expect(find.byKey(_start), findsNothing);
      }
    });

    testWidgets('slaytlar sırasıyla Keşfet, Katıl, Takip et; sayı state ile '
        'aynı', (tester) async {
      await tester.pumpApp(const OnboardingView());
      final l10n = tester.l10n;
      final slides = OnboardingView.slidesOf(l10n);
      expect(slides, hasLength(OnboardingState.pageCount));
      expect(
        [for (final slide in slides) slide.illustration],
        [
          GuIllustrations.onbDiscover,
          GuIllustrations.onbJoin,
          GuIllustrations.onbFollow,
        ],
      );
      expect(
        [for (final slide in slides) slide.title],
        [l10n.onbDiscoverTitle, l10n.onbJoinTitle, l10n.onbFollowTitle],
      );
      expect(
        [for (final slide in slides) slide.desc],
        [l10n.onbDiscoverDesc, l10n.onbJoinDesc, l10n.onbFollowDesc],
      );
    });

    testWidgets('yerleşim: üst satır dolgusu 4 / 8 / 16, slayt dolgusu 32, '
        'alt blok 24 + alt 16; güvenli alanlar gerçek inset', (tester) async {
      const safe = EdgeInsets.only(top: 47, bottom: 34);
      await tester.pumpApp(const OnboardingView(), viewPadding: safe);
      await tester.pump();
      const size = Size(390, 844);

      final lang = tester.getRect(
        find.descendant(
          of: find.byKey(_lang),
          matching: find.byType(GuButton),
        ),
      );
      final skip = tester.getRect(find.byKey(_skip));
      expect(lang.left, 16);
      expect(skip.right, size.width - 8);
      // Satır "Atla"nın boyundadır (metin düğmesi 44); dil düğmesi (40)
      // satırda dikeyde ortalanır.
      expect(skip.top, safe.top + 4);
      expect(skip.height, 44);
      expect(lang.height, 40);
      expect(lang.center.dy, skip.center.dy);

      final next = tester.getRect(find.byKey(_next));
      expect(next.left, 24);
      expect(next.right, size.width - 24);
      expect(next.height, 56);
      expect(next.bottom, size.height - safe.bottom - 16);
      // Noktalar düğmenin 16 üstünde.
      expect(tester.getRect(find.byType(GuPageDots)).bottom, next.top - 16);

      // Slayt içeriği yatayda 32 dolgulu, şerit alanında dikeyde ortalı.
      final track = tester.getRect(find.byKey(_swipe));
      final title = tester.getRect(
        find.text(tester.l10n.onbDiscoverTitle),
      );
      final desc = tester.getRect(find.text(tester.l10n.onbDiscoverDesc));
      final art = tester.getRect(find.byType(GuIllustration));
      expect(desc.left, greaterThanOrEqualTo(32));
      expect(desc.right, lessThanOrEqualTo(size.width - 32));
      expect(art.center.dx, size.width / 2);
      expect(title.top, art.bottom + 16);
      expect(desc.top, title.bottom + 16);
      expect(
        (art.top - track.top) - (track.bottom - desc.bottom),
        closeTo(0, 1),
      );
    });

    testWidgets('aksiyon envanteri: ONB-01.lang / .next / .skip / .swipe', (
      tester,
    ) async {
      await tester.pumpApp(const OnboardingView());
      expectActionInventory(tester, 'ONB-01');
    });

    testWidgets('cihaz matrisi: taşma yok (ilk slayt)', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const OnboardingView(),
        safeAreas: true,
      );
    });

    testWidgets('cihaz matrisi: taşma yok (son slayt, "Başla")', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const OnboardingView(),
        overrides: [_onLastSlide],
        safeAreas: true,
      );
    });

    testWidgets('küçük ekran + büyük yazı: slayt kendi içinde kayar', (
      tester,
    ) async {
      await tester.pumpApp(
        const OnboardingView(),
        size: const Size(320, 480),
        textScale: 1.6,
        locale: _en,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(OnboardingSlide).first,
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('golden: açık + koyu', (tester) async {
      await goldenForThemes(tester, 'ONB-01', const OnboardingView());
    });
  });

  group('ONB-01 · Karşılama · aksiyonlar', () {
    testWidgets('ONB-01.next: sıradaki slayta geçer, noktalar ilerler; son '
        'slaytta düğme "Başla" olur', (tester) async {
      await tester.pumpApp(const OnboardingView());
      final l10n = tester.l10n;

      await tester.tap(find.byKey(_next));
      await tester.pump();
      // Nokta ve düğme hemen güncellenir; şerit yumuşak kayar.
      expect(_dotIndex(tester), 1);
      await tester.pumpAndSettle();
      expect(find.text(l10n.onbJoinTitle), findsOneWidget);
      expect(find.text(l10n.onbJoinDesc), findsOneWidget);
      expect(find.text(l10n.onbDiscoverTitle), findsNothing);
      expect(find.byKey(_next), findsOneWidget);

      await tester.tap(find.byKey(_next));
      await tester.pumpAndSettle();
      expect(_dotIndex(tester), 2);
      expect(find.text(l10n.onbFollowTitle), findsOneWidget);
      expect(
        tester.widget<GuIllustration>(find.byType(GuIllustration)).illustration,
        GuIllustrations.onbFollow,
      );
      // Son slayt: "İleri" yerine oksuz "Başla".
      expect(find.byKey(_next), findsNothing);
      final start = tester.widget<GuButton>(find.byKey(_start));
      expect(start.label, l10n.onbStart);
      expect(start.size, GuButtonSize.lg);
      expect(start.full, isTrue);
      expect(start.iconTrailing, isNull);
    });

    testWidgets('ONB-01.next: hareket azaltılmışsa geçiş animasyonsuzdur', (
      tester,
    ) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const OnboardingView(),
          ),
        ),
      );
      await tester.tap(find.byKey(_next));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text(tester.l10n.onbJoinTitle), findsOneWidget);
      expect(find.text(tester.l10n.onbDiscoverTitle), findsNothing);
      expect(_dotIndex(tester), 1);
    });

    testWidgets('ONB-01.swipe: kaydırma slaytı ve noktaları değiştirir; geri '
        'kaydırınca "İleri" döner', (tester) async {
      await tester.pumpApp(const OnboardingView());
      final l10n = tester.l10n;

      await tester.fling(find.byKey(_swipe), const Offset(-300, 0), 1200);
      await tester.pumpAndSettle();
      expect(_dotIndex(tester), 1);
      expect(find.text(l10n.onbJoinTitle), findsOneWidget);

      await tester.fling(find.byKey(_swipe), const Offset(-300, 0), 1200);
      await tester.pumpAndSettle();
      expect(_dotIndex(tester), 2);
      expect(find.byKey(_start), findsOneWidget);

      // Son slayttan ileri kaydırılamaz.
      await tester.fling(find.byKey(_swipe), const Offset(-300, 0), 1200);
      await tester.pumpAndSettle();
      expect(_dotIndex(tester), 2);

      await tester.fling(find.byKey(_swipe), const Offset(300, 0), 1200);
      await tester.pumpAndSettle();
      expect(_dotIndex(tester), 1);
      expect(find.byKey(_next), findsOneWidget);
      expect(find.byKey(_start), findsNothing);
    });

    testWidgets('ONB-01.lang: SHT-01 açılır menü biçiminde açılır', (
      tester,
    ) async {
      await tester.pumpApp(const OnboardingView());
      final feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
      expect(feedback.menus, isEmpty);

      await tester.tap(find.byKey(_lang));
      await tester.pump();
      expect(feedback.menus, [MenuId.sht01]);
      expect(feedback.sheets, isEmpty);
      // Tanıtım bitmez.
      expect(_store().callsTo('setOnboardingSeen'), isEmpty);
    });

    testWidgets('ONB-01.skip: tanıtım bayrağı yazılır ve girişe geçilir', (
      tester,
    ) async {
      final router = await _pumpWithRouter(tester);
      expect(_locationOf(router), '/onboarding');

      await tester.tap(find.byKey(_skip));
      await tester.pumpAndSettle();

      expect(_store().onboardingSeen, isTrue);
      expect(_store().callsTo('setOnboardingSeen'), hasLength(1));
      expect(_locationOf(router), '/login');
      expect(find.byType(OnboardingView), findsNothing);
    });

    testWidgets('ONB-01.start (son slayt): tanıtım bayrağı yazılır ve girişe '
        'geçilir', (tester) async {
      final router = await _pumpWithRouter(tester, lastSlide: true);
      expect(find.text(tester.l10n.onbFollowTitle), findsOneWidget);
      expect(find.byKey(_next), findsNothing);

      await tester.tap(find.byKey(_start));
      await tester.pumpAndSettle();

      expect(_store().onboardingSeen, isTrue);
      expect(_store().callsTo('setOnboardingSeen'), hasLength(1));
      expect(_locationOf(router), '/login');
    });

    testWidgets('çift dokunma: yazım sürerken ikinci "Atla" yok sayılır — tek '
        'yazım, tek geçiş', (tester) async {
      final router = await _pumpWithRouter(tester);
      final store = await ControlledPreferencesStore.install();
      store.gate = Completer<void>();

      await tester.tap(find.byKey(_skip));
      await tester.pump();
      await tester.tap(find.byKey(_skip));
      await tester.pump();
      // Yazım bekliyor: tek çağrı, ekran yerinde.
      expect(store.onboardingWrites, 1);
      expect(_locationOf(router), '/onboarding');

      store.gate!.complete();
      await tester.pumpAndSettle();
      expect(store.onboardingWrites, 1);
      expect(store.onboardingSeen, isTrue);
      expect(_locationOf(router), '/login');
    });

    testWidgets('gerçek rota ağacı: ilk açılışta /onboarding; "Atla" sonrası '
        'oturum bayrağı yükselir ve router girişe yönlendirir (R2 → R3)', (
      tester,
    ) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.signedOutFirstRun,
        location: '/clubs',
      );
      expect(app.location, '/onboarding');
      expect(find.byType(OnboardingView), findsOneWidget);

      await tester.tap(find.byKey(_skip));
      await tester.pumpAndSettle();

      expect(app.session.onboardingSeen, isTrue);
      expect(app.location, startsWith('/login'));
      expect(find.byType(OnboardingView), findsNothing);
      // Geri dönülemez: tanıtım yalnızca ilk açılışta görünür.
      await app.go('/onboarding');
      expect(app.location, startsWith('/login'));
      expect(
        app.container.read(sessionViewModelProvider).onboardingSeen,
        isTrue,
      );
    });
  });
}
