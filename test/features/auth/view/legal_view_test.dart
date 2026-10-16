// AUT-06 · Yasal metinler — çubuk, üç sekme (KVKK / Gizlilik / Koşullar),
// 7 bölüm çipi, metin; 11 envanter aksiyonu (`AUT-06.back`, `.tab.<tip>` ×3,
// `.jump.<n>` ×7) ve sonuçları, kayıt formundan açılışta onay çubuğu
// (`AUT-06.accept`), cihaz matrisi, açık + koyu golden. Referans:
// design/reference-shots/screens/AUT-06__*.webp; prototip
// `screens-auth.js:152–160`. Rota guard'sızdır ve `push` ile açılır.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/features/auth/provider/register_view_model.dart';
import 'package:gu_kulupler/features/auth/view/legal_view.dart';
import 'package:gu_kulupler/features/auth/view/widget/legal_document.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/navigation/routes/auth_routes.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_session_states.dart';
import '../../../fakes/test_router.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

final Key _back = GuKey.action('AUT-06.back');
final Key _accept = GuKey.action('AUT-06.accept');

Key _tab(LegalTab tab) => GuKey.action('AUT-06.tab.${tab.name}');

Key _jump(int number) => GuKey.action('AUT-06.jump.$number');

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

/// [tab] metninin kaydırma görünümü (sekme başına ayrı).
Finder _scrollView(LegalTab tab) =>
    find.byKey(PageStorageKey<String>('legal-${tab.name}'));

ScrollPosition _position(WidgetTester tester, LegalTab tab) => tester
    .state<ScrollableState>(
      find.descendant(
        of: _scrollView(tab),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

/// Numaralı bölüm başlığı metni ("1. Veri sorumlusu").
String _heading(AppLocalizations l10n, LegalTab tab, int number) =>
    l10n.legalSectionHeading(
      number,
      LegalDocument.of(l10n, tab).sections[number - 1].heading,
    );

/// [number] numaralı bölümün metin içindeki kutusu.
Rect _sectionRect(WidgetTester tester, int number) =>
    tester.getRect(find.byType(LegalSection).at(number - 1));

Future<void> _tapJump(WidgetTester tester, int number) async {
  // Çip şeridi yatay kayar: çip önce görünür alana alınır.
  await tester.ensureVisible(find.byKey(_jump(number)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(_jump(number)));
  await tester.pumpAndSettle();
}

/// Ekranı `/host` üstüne `push` ile açan router (uygulamadaki açılış biçimi);
/// `/clubs` dönülecek sayfa yokken varılan ana sayfadır.
Future<({GoRouter router, Future<bool?> result})> _pumpPushed(
  WidgetTester tester, {
  bool showAccept = false,
}) async {
  GoRouter? router;
  await tester.pumpAppRouter(
    routerOf: (_) => router ??= GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (context, state) => const TestPage('/host'),
        ),
        GoRoute(
          path: '/clubs',
          builder: (context, state) => const TestPage('/clubs'),
        ),
        GoRoute(
          path: '/legal/:tip',
          builder: (context, state) => LegalView(
            tip: LegalTab.values.byName(state.pathParameters['tip']!),
            showAccept: showAccept,
          ),
        ),
      ],
    ),
  );
  addTearDown(() => router?.dispose());
  await tester.pumpAndSettle();
  final result = router!.push<bool>('/legal/kvkk');
  await tester.pumpAndSettle();
  return (router: router!, result: result);
}

String _locationOf(GoRouter router) =>
    router.routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  group('AUT-06 · Yasal metinler', () {
    testWidgets('çubuk, üç sekme, 7 çip, başlık, güncelleme satırı ve 7 '
        'bölüm — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        await tester.pumpApp(
          const LegalView(tip: LegalTab.kvkk),
          locale: locale,
        );
        final l10n = tester.l10n;

        // Çubuk: geri + "Yasal metinler".
        final bar = tester.widget<GuAppBar>(find.byType(GuAppBar));
        expect(bar.title, l10n.legalTitle);
        expect(bar.backSemanticLabel, l10n.a11yBack);
        expect(bar.closeIcon, isFalse);
        expect(find.byKey(_back), findsOneWidget);

        // Sekmeler: KVKK · Gizlilik · Koşullar; ilki seçili.
        final tabs = tester.widget<GuTabs>(find.byType(GuTabs));
        expect(
          [for (final tab in tabs.tabs) tab.id],
          [
            'kvkk',
            'gizlilik',
            'kosullar',
          ],
        );
        expect(
          [for (final tab in tabs.tabs) tab.label],
          [
            l10n.legalKvkkShort,
            l10n.legalGizlilikShort,
            l10n.legalKosullarShort,
          ],
        );
        expect(tabs.value, 'kvkk');
        expect(tabs.sticky, isFalse);

        // Çipler: numaralı 7 başlık, hiçbiri seçili değil.
        final chips = tester.widgetList<GuChip>(find.byType(GuChip)).toList();
        expect(chips, hasLength(LegalDocument.sectionCount));
        for (var n = 1; n <= LegalDocument.sectionCount; n++) {
          expect(chips[n - 1].label, _heading(l10n, LegalTab.kvkk, n));
          expect(chips[n - 1].selected, isFalse);
        }
        expect(chips.first.label, startsWith('1. '));

        // Metin: başlık, güncelleme satırı, 7 bölüm (başlık + gövde).
        expect(find.text(l10n.legalKvkkTitle), findsOneWidget);
        expect(find.text(l10n.legalUpdated), findsOneWidget);
        final sections = tester
            .widgetList<LegalSection>(find.byType(LegalSection))
            .toList();
        expect(sections, hasLength(LegalDocument.sectionCount));
        expect(sections.first.heading, _heading(l10n, LegalTab.kvkk, 1));
        expect(
          sections.first.body,
          l10n.legalKvkkB1(AppConstants.appName, AppConstants.supportEmail),
        );
        expect(sections.last.heading, _heading(l10n, LegalTab.kvkk, 7));
        expect(
          sections.last.body,
          l10n.legalKvkkB7(AppConstants.supportEmail, AppConstants.webHost),
        );

        // Onay çubuğu yalnızca kayıt formundan açılışta.
        expect(find.byType(GuStickyCta), findsNothing);
        expect(find.byKey(_accept), findsNothing);
      }
      await expectA11yGuidelines(tester);
    });

    testWidgets('ilk sekme rota parametresidir (`/legal/:tip`)', (
      tester,
    ) async {
      for (final tab in LegalTab.values) {
        await tester.pumpApp(LegalView(tip: tab));
        final l10n = tester.l10n;
        expect(tester.widget<GuTabs>(find.byType(GuTabs)).value, tab.name);
        expect(find.text(LegalDocument.of(l10n, tab).title), findsOneWidget);
        expect(_scrollView(tab), findsOneWidget);
      }
    });

    testWidgets('her sekmenin metni kendi ARB anahtarlarından gelir; '
        'gizlilik metni ürün adını sabitten alır — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final l10n = tester.l10nFor(locale);
        final kvkk = LegalDocument.of(l10n, LegalTab.kvkk);
        final gizlilik = LegalDocument.of(l10n, LegalTab.gizlilik);
        final kosullar = LegalDocument.of(l10n, LegalTab.kosullar);

        expect(kvkk.title, l10n.legalKvkkTitle);
        expect(gizlilik.title, l10n.legalGizlilikTitle);
        expect(kosullar.title, l10n.legalKosullarTitle);
        expect(
          [for (final section in kvkk.sections) section.heading],
          [
            l10n.legalKvkkH1,
            l10n.legalKvkkH2,
            l10n.legalKvkkH3,
            l10n.legalKvkkH4,
            l10n.legalKvkkH5,
            l10n.legalKvkkH6,
            l10n.legalKvkkH7,
          ],
        );
        expect(
          [for (final section in kvkk.sections) section.body],
          [
            l10n.legalKvkkB1(AppConstants.appName, AppConstants.supportEmail),
            l10n.legalKvkkB2,
            l10n.legalKvkkB3,
            l10n.legalKvkkB4,
            l10n.legalKvkkB5(AppConstants.supportEmail),
            l10n.legalKvkkB6,
            l10n.legalKvkkB7(AppConstants.supportEmail, AppConstants.webHost),
          ],
        );
        expect(
          [for (final section in gizlilik.sections) section.heading],
          [
            l10n.legalGizlilikH1,
            l10n.legalGizlilikH2,
            l10n.legalGizlilikH3,
            l10n.legalGizlilikH4,
            l10n.legalGizlilikH5,
            l10n.legalGizlilikH6,
            l10n.legalGizlilikH7,
          ],
        );
        expect(
          [for (final section in gizlilik.sections) section.body],
          [
            l10n.legalGizlilikB1(AppConstants.appName),
            l10n.legalGizlilikB2,
            l10n.legalGizlilikB3,
            l10n.legalGizlilikB4,
            l10n.legalGizlilikB5,
            l10n.legalGizlilikB6,
            l10n.legalGizlilikB7(AppConstants.webHost),
          ],
        );
        expect(gizlilik.sections.first.body, contains(AppConstants.appName));
        // Web sayfasıyla eşit içerik (K-96): veri sorumlusu ve e-posta,
        // sonda tam metin adresi (dile göre yol), resmî uygulama değil.
        final privacyPath = locale == _tr ? 'gizlilik' : 'privacy';
        expect(kvkk.sections.first.body, contains('Muhammed Emin Alan'));
        expect(kvkk.sections.first.body, contains(AppConstants.supportEmail));
        expect(kvkk.sections[4].body, contains(AppConstants.supportEmail));
        for (final document in [kvkk, gizlilik]) {
          expect(
            document.sections.last.body,
            endsWith('${AppConstants.webHost}/$privacyPath'),
          );
        }
        for (final body in [
          for (final section in [...kvkk.sections, ...gizlilik.sections])
            section.body,
        ]) {
          expect(body.toLowerCase(), isNot(contains('kampüs')));
          expect(body.toLowerCase(), isNot(contains('campus')));
          expect(body, isNot(contains('gumushane.edu.tr')));
          expect(body, isNot(contains('1 yıl')));
          expect(body, isNot(contains('1 year')));
        }
        expect(
          [for (final section in kosullar.sections) section.heading],
          [
            l10n.legalKosullarH1,
            l10n.legalKosullarH2,
            l10n.legalKosullarH3,
            l10n.legalKosullarH4,
            l10n.legalKosullarH5,
            l10n.legalKosullarH6,
            l10n.legalKosullarH7,
          ],
        );
        expect(
          [for (final section in kosullar.sections) section.body],
          [
            l10n.legalKosullarB1,
            l10n.legalKosullarB2,
            l10n.legalKosullarB3,
            l10n.legalKosullarB4,
            l10n.legalKosullarB5,
            l10n.legalKosullarB6,
            l10n.legalKosullarB7,
          ],
        );
        for (final document in [kvkk, gizlilik, kosullar]) {
          expect(document.sections, hasLength(LegalDocument.sectionCount));
        }
        for (final tab in LegalTab.values) {
          expect(
            LegalDocument.shortTitleOf(l10n, tab),
            LegalDocument.of(l10n, tab).shortTitle,
          );
        }
      }
    });

    testWidgets('yerleşim: çipler sekmelerin 3 px altında, metin dolgusu '
        '0 / 16 / 16, bölüm aralığı 16; alt boşluk gerçek güvenli alan + 8', (
      tester,
    ) async {
      const safe = EdgeInsets.only(top: 47, bottom: 34);
      await tester.pumpApp(
        const LegalView(tip: LegalTab.kvkk),
        viewPadding: safe,
      );
      const size = Size(390, 844);
      final l10n = tester.l10n;

      // Çubuk gerçek üst güvenli alanın altında, 56 px.
      final tabs = tester.getRect(find.byType(GuTabs));
      expect(tabs.top, safe.top + 56);

      // Çip şeridi: sekmelerin hemen altında, üst / alt 3, sol 16.
      final strip = tester.getRect(find.byType(GuHorizontalList));
      final firstChip = tester.getRect(find.byType(GuChip).first);
      expect(strip.top, tabs.bottom);
      expect(firstChip.top, strip.top + 3);
      expect(firstChip.left, 16);
      expect(strip.bottom, firstChip.bottom + 3);

      // Metin: şeridin hemen altında başlar (üst dolgu yok), yatay 16.
      final scroll = tester.getRect(_scrollView(LegalTab.kvkk));
      final title = tester.getRect(find.text(l10n.legalKvkkTitle));
      final updated = tester.getRect(find.text(l10n.legalUpdated));
      expect(scroll.top, strip.bottom);
      expect(scroll.bottom, size.height);
      expect(title.top, scroll.top);
      expect(title.left, 16);
      expect(updated.top, title.bottom + 16);
      expect(_sectionRect(tester, 1).top, updated.bottom + 16);
      expect(_sectionRect(tester, 1).left, 16);
      expect(_sectionRect(tester, 1).right, size.width - 16);
      expect(_sectionRect(tester, 2).top, _sectionRect(tester, 1).bottom + 16);

      // Sona kaydırınca son bölümün altında 16 + alt güvenli alan + 8 kalır.
      final position = _position(tester, LegalTab.kvkk);
      expect(position.maxScrollExtent, greaterThan(0));
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(
        _sectionRect(tester, LegalDocument.sectionCount).bottom,
        size.height - (16 + safe.bottom + 8),
      );
    });

    testWidgets('aksiyon envanteri: AUT-06.back / .tab.* / .jump.1–7', (
      tester,
    ) async {
      await tester.pumpApp(const LegalView(tip: LegalTab.kvkk));
      expectActionInventory(tester, 'AUT-06');
    });

    testWidgets('cihaz matrisi: taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const LegalView(tip: LegalTab.kvkk),
        safeAreas: true,
      );
    });

    testWidgets('cihaz matrisi: taşma yok (onay çubuğuyla, en uzun sekme '
        'adları)', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const LegalView(tip: LegalTab.kosullar, showAccept: true),
        safeAreas: true,
      );
    });

    testWidgets('golden: açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'AUT-06',
        const LegalView(tip: LegalTab.kvkk),
      );
    });
  });

  group('AUT-06 · Yasal metinler · aksiyonlar', () {
    testWidgets('AUT-06.tab.*: sekme değişince başlık, çipler ve metin '
        'değişir', (tester) async {
      await tester.pumpApp(const LegalView(tip: LegalTab.kvkk));
      final l10n = tester.l10n;

      for (final tab in [
        LegalTab.gizlilik,
        LegalTab.kosullar,
        LegalTab.kvkk,
      ]) {
        await tester.tap(find.byKey(_tab(tab)));
        await tester.pumpAndSettle();
        final document = LegalDocument.of(l10n, tab);
        expect(tester.widget<GuTabs>(find.byType(GuTabs)).value, tab.name);
        expect(find.text(document.title), findsOneWidget);
        expect(
          tester.widget<GuChip>(find.byKey(_jump(1))).label,
          _heading(l10n, tab, 1),
        );
        expect(
          tester.widget<LegalSection>(find.byType(LegalSection).last).body,
          document.sections.last.body,
        );
        // Diğer metinlerin başlığı görünmez.
        for (final other in LegalTab.values.where((item) => item != tab)) {
          expect(
            find.text(LegalDocument.of(l10n, other).title),
            findsNothing,
          );
        }
      }
      // Seçili sekmeye yeniden dokunmak bir şey değiştirmez.
      await tester.tap(find.byKey(_tab(LegalTab.kvkk)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.legalKvkkTitle), findsOneWidget);
    });

    testWidgets('AUT-06.jump.<n>: metin o bölüme kayar (bölüm görünen alanın '
        'başına; son bölümlerde kaydırma sonuna)', (tester) async {
      await tester.pumpApp(
        const LegalView(tip: LegalTab.kvkk),
        size: const Size(390, 500),
      );
      final position = _position(tester, LegalTab.kvkk);
      final viewportTop = tester.getRect(_scrollView(LegalTab.kvkk)).top;
      expect(position.pixels, 0);

      // Ulaşılabilen bölümler görünen alanın başına oturur.
      for (final number in [4, 2, 1]) {
        await _tapJump(tester, number);
        expect(
          _sectionRect(tester, number).top,
          closeTo(viewportTop, 0.5),
          reason: 'bölüm $number',
        );
      }
      // 1. bölümde başlık ve güncelleme satırı yukarıda kalır.
      expect(position.pixels, greaterThan(0));

      // Son bölüm: içerik biter, kaydırma sonda durur.
      await _tapJump(tester, 7);
      expect(position.pixels, position.maxScrollExtent);
      expect(
        _sectionRect(tester, 7).top,
        greaterThan(viewportTop),
      );
    });

    testWidgets('AUT-06.jump.<n>: hareket azaltılmışsa animasyonsuz atlar', (
      tester,
    ) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const LegalView(tip: LegalTab.kvkk),
          ),
        ),
        size: const Size(390, 500),
      );
      final viewportTop = tester.getRect(_scrollView(LegalTab.kvkk)).top;
      await tester.tap(find.byKey(_jump(2)));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(_sectionRect(tester, 2).top, closeTo(viewportTop, 0.5));
    });

    testWidgets('her sekme kendi kaydırma konumunu korur; yeni sekme baştan '
        'başlar', (tester) async {
      await tester.pumpApp(
        const LegalView(tip: LegalTab.kvkk),
        size: const Size(390, 500),
      );
      await _tapJump(tester, 3);
      final kvkkOffset = _position(tester, LegalTab.kvkk).pixels;
      expect(kvkkOffset, greaterThan(0));

      await tester.tap(find.byKey(_tab(LegalTab.gizlilik)));
      await tester.pumpAndSettle();
      expect(_position(tester, LegalTab.gizlilik).pixels, 0);

      await tester.tap(find.byKey(_tab(LegalTab.kvkk)));
      await tester.pumpAndSettle();
      expect(_position(tester, LegalTab.kvkk).pixels, kvkkOffset);
    });

    testWidgets('AUT-06.back: açan ekrana döner (push ile açılış)', (
      tester,
    ) async {
      final pushed = await _pumpPushed(tester);
      expect(find.byType(LegalView), findsOneWidget);
      expect(_locationOf(pushed.router), '/legal/kvkk');

      await tester.tap(find.byKey(_back));
      await tester.pumpAndSettle();

      expect(find.byType(LegalView), findsNothing);
      expect(_locationOf(pushed.router), '/host');
      // Geri, sonuç taşımaz (onay değildir).
      expect(await pushed.result, isNull);
    });

    testWidgets('AUT-06.back: dönülecek sayfa yoksa ana sayfa', (
      tester,
    ) async {
      GoRouter? router;
      await tester.pumpAppRouter(
        routerOf: (_) => router ??= GoRouter(
          initialLocation: '/legal/gizlilik',
          routes: [
            GoRoute(
              path: '/clubs',
              builder: (context, state) => const TestPage('/clubs'),
            ),
            GoRoute(
              path: '/legal/:tip',
              builder: (context, state) => LegalView(
                tip: LegalTab.values.byName(state.pathParameters['tip']!),
              ),
            ),
          ],
        ),
      );
      addTearDown(() => router?.dispose());
      await tester.pumpAndSettle();
      expect(
        tester.widget<GuTabs>(find.byType(GuTabs)).value,
        LegalTab.gizlilik.name,
      );

      await tester.tap(find.byKey(_back));
      await tester.pumpAndSettle();
      expect(_locationOf(router!), '/clubs');
      expect(find.byType(LegalView), findsNothing);
    });

    testWidgets('yol parametresi değişirse sekme de değişir; onay, dönülecek '
        'sayfa yokken de ekrandan çıkarır', (tester) async {
      GoRouter? router;
      await tester.pumpAppRouter(
        routerOf: (_) => router ??= GoRouter(
          initialLocation: '/legal/kvkk',
          routes: [
            GoRoute(
              path: '/clubs',
              builder: (context, state) => const TestPage('/clubs'),
            ),
            GoRoute(
              path: '/legal/:tip',
              builder: (context, state) => LegalView(
                tip: LegalTab.values.byName(state.pathParameters['tip']!),
                showAccept: true,
              ),
            ),
          ],
        ),
      );
      addTearDown(() => router?.dispose());
      await tester.pumpAndSettle();
      final l10n = tester.l10n;
      expect(find.text(l10n.legalKvkkTitle), findsOneWidget);

      router!.go('/legal/kosullar');
      await tester.pumpAndSettle();
      expect(
        tester.widget<GuTabs>(find.byType(GuTabs)).value,
        LegalTab.kosullar.name,
      );
      expect(find.text(l10n.legalKosullarTitle), findsOneWidget);
      expect(find.text(l10n.legalKvkkTitle), findsNothing);

      await tester.tap(find.byKey(_accept));
      await tester.pumpAndSettle();
      expect(_locationOf(router!), '/clubs');
    });

    testWidgets('AUT-06.accept: yalnızca showAccept ile görünür; "Okudum, '
        'anladım" açan ekrana `true` ile döner — TR ve EN metin', (
      tester,
    ) async {
      for (final locale in [_tr, _en]) {
        await tester.pumpApp(
          const LegalView(tip: LegalTab.kvkk, showAccept: true),
          locale: locale,
        );
        final accept = tester.widget<GuButton>(find.byKey(_accept));
        expect(accept.label, tester.l10n.legalAccept);
        expect(accept.variant, GuButtonVariant.primary);
        expect(accept.full, isTrue);
        expect(
          find.descendant(
            of: find.byType(GuStickyCta),
            matching: find.byKey(_accept),
          ),
          findsOneWidget,
        );
      }

      final pushed = await _pumpPushed(tester, showAccept: true);
      await tester.tap(find.byKey(_accept));
      await tester.pumpAndSettle();
      expect(_locationOf(pushed.router), '/host');
      expect(await pushed.result, isTrue);
    });

    testWidgets('AUT-06.accept: açık kayıt formu varsa onay kutusunu '
        'işaretler; yoksa (doğrudan bağlantı) form oluşturulmaz', (
      tester,
    ) async {
      ProviderContainer container() => ProviderScope.containerOf(
        tester.element(find.byType(LegalView)),
      );

      // Kayıt formu açık (yığında): onay işaretlenir.
      var pushed = await _pumpPushed(tester, showAccept: true);
      final form = container().listen(registerViewModelProvider, (_, _) {});
      addTearDown(form.close);
      expect(form.read().acceptedLegal, isFalse);
      await tester.tap(find.byKey(_accept));
      await tester.pumpAndSettle();
      expect(form.read().acceptedLegal, isTrue);
      expect(await pushed.result, isTrue);
      form.close();

      // Kayıt formu yok: ViewModel kurulmaz, ekran yine kapanır.
      pushed = await _pumpPushed(tester, showAccept: true);
      final scope = container();
      expect(scope.exists(registerViewModelProvider), isFalse);
      await tester.tap(find.byKey(_accept));
      await tester.pumpAndSettle();
      expect(scope.exists(registerViewModelProvider), isFalse);
      expect(await pushed.result, isTrue);
    });

    testWidgets('onay çubuğu alt güvenli alanı kendisi kaplar: metnin alt '
        'boşluğu 16 + 8', (tester) async {
      const safe = EdgeInsets.only(bottom: 34);
      await tester.pumpApp(
        const LegalView(tip: LegalTab.kvkk, showAccept: true),
        viewPadding: safe,
      );
      final cta = tester.getRect(find.byType(GuStickyCta));
      expect(cta.bottom, 844);
      final position = _position(tester, LegalTab.kvkk)
        ..jumpTo(_position(tester, LegalTab.kvkk).maxScrollExtent);
      await tester.pump();
      expect(position.pixels, position.maxScrollExtent);
      expect(
        _sectionRect(tester, LegalDocument.sectionCount).bottom,
        cta.top - (16 + 8),
      );
    });

    testWidgets('gerçek rota: guard’sızdır — oturum yokken de açılır, sekme '
        'yol parametresinden gelir', (tester) async {
      final app = await TestRouter.pump(
        tester,
        session: FakeSessionStates.signedOut,
        location: '/legal/kosullar',
      );
      expect(app.location, '/legal/kosullar');
      expect(
        tester.widget<LegalView>(find.byType(LegalView)).tip,
        LegalTab.kosullar,
      );
      expect(
        tester.widget<LegalView>(find.byType(LegalView)).showAccept,
        isFalse,
      );
      expect(find.text(tester.l10n.legalKosullarTitle), findsOneWidget);
    });

    testWidgets('gerçek rota: `LegalRoute(...).push` ile açılır, geri açan '
        'ekrana döner', (tester) async {
      final app = await TestRouter.pump(tester, location: '/clubs');
      final context = tester.element(find.byType(Navigator).first);
      unawaited(const LegalRoute(tip: LegalTab.gizlilik).push<void>(context));
      await tester.pumpAndSettle();
      expect(find.byType(LegalView), findsOneWidget);
      expect(find.text(tester.l10n.legalGizlilikTitle), findsOneWidget);

      await tester.tap(find.byKey(_back));
      await tester.pumpAndSettle();
      expect(find.byType(LegalView), findsNothing);
      expect(app.location, '/clubs');
    });
  });
}
