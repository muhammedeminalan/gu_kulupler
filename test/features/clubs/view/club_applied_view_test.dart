// CLB-04 · İsteğin kulüp yönetimine iletildi — içerik (TR / EN), başvuru
// kartı (not alıntısı, gönderim anı), bildirim kartı, durumlar (okunuyor,
// okunamadı, kulüp yok), 4 + 1 aksiyon ve sonuçları (CLB-03, CLB-01, Profil
// sekmesi, DLG-03 → TST-19), cihaz matrisi, aksiyon envanteri, açık + koyu
// golden. Referans: design/reference-shots/screens/CLB-04__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_state.dart';
import 'package:gu_kulupler/features/clubs/view/club_applied_view.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/service/permission_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import 'club_application_test_support.dart';

final Key _close = GuKey.action('CLB-04.close');
final Key _browse = GuKey.action('CLB-04.browse');
final Key _myApplications = GuKey.action('CLB-04.myApplications');
final Key _enable = GuKey.action('CLB-04.enableNotifications');
final Key _retry = GuKey.action('CLB-04.retry');

const String _location = '/clubs/$kClubId/applied';

const ClubAppliedView _view = ClubAppliedView(clubId: kClubId);

/// Not yok, bildirim izni var: yalnızca başvuru kartı.
final ClubApplicationState _plainState = ClubApplicationState(
  club: kClub,
  membership: kPending,
);

Future<void> _pump(
  WidgetTester tester,
  ClubApplicationState state, {
  Locale locale = const Locale('tr'),
  EdgeInsets viewPadding = EdgeInsets.zero,
}) async {
  await tester.pumpApp(
    _view,
    locale: locale,
    viewPadding: viewPadding,
    overrides: stateOverride(state),
  );
  // Onay işaretinin çizimi biter.
  await tester.pumpAndSettle();
}

GuButton _button(WidgetTester tester, Key key) =>
    tester.widget<GuButton>(find.byKey(key));

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

/// Açık + koyu tam ekran golden'ı; onay işaretinin çizimi bittikten sonra
/// yakalanır.
Future<void> _golden(
  WidgetTester tester,
  String name,
  ClubApplicationState state, {
  List<Locale> locales = const [Locale('tr')],
}) async {
  for (final locale in locales) {
    for (final theme in kGoldenThemes) {
      await tester.pumpApp(
        _view,
        locale: locale,
        theme: theme,
        overrides: stateOverride(state),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(kPumpAppBoundaryKey),
        matchesGoldenFile(goldenUri(goldenPath(name, theme, locale))),
      );
    }
  }
}

void main() {
  setUpAll(initDateFormats);

  group('CLB-04 · İsteğin iletildi · içerik', () {
    for (final locale in DeviceMatrix.locales) {
      testWidgets('içerik (${locale.languageCode}): onay işareti, başlık, '
          'başvuru kartı, bildirim kartı, iki düğme', (tester) async {
        await _pump(tester, kPendingState, locale: locale);
        final l10n = tester.l10n;
        final gu = tester.element(find.byType(ClubAppliedView)).gu;

        // Çubuk: başlıksız, kapat.
        final bar = tester.widget<GuAppBar>(find.byType(GuAppBar));
        expect(bar.title, isNull);
        expect(bar.closeIcon, isTrue);
        expect(find.byKey(_close), findsOneWidget);
        expect(find.bySemanticsLabel(l10n.a11yClose), findsOneWidget);

        // Onay işareti 110 + başlık + açıklama (ortalı).
        final check = tester.widget<GuSuccessCheck>(
          find.byType(GuSuccessCheck),
        );
        expect(check.size, 110);
        expect(check.semanticLabel, l10n.commonSuccess);
        final title = tester.widget<Text>(find.text(l10n.appliedTitle));
        expect(title.style, gu.text.titleL);
        expect(title.textAlign, TextAlign.center);
        final description = tester.widget<Text>(find.text(l10n.appliedDesc));
        expect(description.style?.color, gu.colors.textSecondary);
        expect(description.style?.fontSize, gu.text.bodyM.fontSize);
        expect(description.textAlign, TextAlign.center);

        // Başvuru kartı: amblem + ad + gönderim anı + not alıntısı.
        final emblem = tester.widget<GuEmblem>(find.byType(GuEmblem));
        expect(emblem.icon, GuIcons.music);
        expect(emblem.size, GuEmblemSize.sm);
        expect(
          tester.widget<Text>(find.text(kClub.name)).style,
          gu.text.titleS,
        );
        final sentAt = locale.languageCode == 'tr'
            ? '6 Eki Sal, 19:08'
            : 'Tue 6 Oct, 19:08';
        expect(
          tester.widget<Text>(find.text(l10n.appliedSentAt(sentAt))).style,
          gu.text.caption,
        );
        final quote = tester.widget<Text>(find.text('“$kNote”'));
        expect(quote.style?.fontStyle, FontStyle.italic);
        expect(quote.style?.color, gu.colors.textSecondary);
        expect(quote.style?.fontSize, gu.text.bodyS.fontSize);
        final applicationCard = tester.widget<GuCard>(
          find.ancestor(
            of: find.text(kClub.name),
            matching: find.byType(GuCard),
          ),
        );
        expect(applicationCard.onTap, isNull);
        expect(applicationCard.muted, isFalse);
        expect(applicationCard.padding, GuCard.bodyPadding);

        // Bildirim kartı: zil + metin + "Aç".
        final promptCard = tester.widget<GuCard>(
          find.ancestor(of: find.byKey(_enable), matching: find.byType(GuCard)),
        );
        expect(promptCard.muted, isTrue);
        final bell = tester.widget<GuIcon>(
          find.descendant(
            of: find.ancestor(
              of: find.byKey(_enable),
              matching: find.byType(GuCard),
            ),
            matching: find.byWidgetPredicate(
              (widget) => widget is GuIcon && widget.icon == GuIcons.bellRing,
            ),
          ),
        );
        expect(bell.size, 22);
        expect(bell.color, gu.colors.brandPrimaryText);
        expect(
          tester.widget<Text>(find.text(l10n.appliedEnableNotif)).style,
          gu.text.bodyS,
        );
        final enable = _button(tester, _enable);
        expect(enable.label, l10n.commonOpen);
        expect(enable.variant, GuButtonVariant.tonal);
        expect(enable.size, GuButtonSize.sm);

        // Düğmeler.
        final browse = _button(tester, _browse);
        expect(browse.label, l10n.appliedBrowse);
        expect(browse.variant, GuButtonVariant.primary);
        expect(browse.size, GuButtonSize.lg);
        expect(browse.full, isTrue);
        final mine = _button(tester, _myApplications);
        expect(mine.label, l10n.appliedMyApplications);
        expect(mine.variant, GuButtonVariant.text);
        expect(mine.full, isFalse);

        expect(find.byType(GuBanner), findsNothing);
        expect(find.byType(GuSkeletonList), findsNothing);
        await expectA11yGuidelines(tester);
      });
    }

    testWidgets('not yoksa alıntı, izin varsa bildirim kartı çizilmez', (
      tester,
    ) async {
      await _pump(tester, _plainState);
      expect(find.textContaining('“'), findsNothing);
      expect(find.byKey(_enable), findsNothing);
      expect(find.text(tester.l10n.appliedEnableNotif), findsNothing);
      expect(find.byType(GuCard), findsOneWidget);

      // Yalnızca boşluktan oluşan not da alıntı sayılmaz.
      await _pump(tester, _plainState.copyWith(savedNote: '  \n'));
      expect(find.textContaining('“'), findsNothing);
    });

    testWidgets('üyelik henüz oturuma gelmediyse gönderim anı "şimdi"dir', (
      tester,
    ) async {
      await _pump(tester, ClubApplicationState(club: kClub));
      // Sahte saat: 12 Ekim 2026 Pazartesi 19:30 (Istanbul).
      expect(
        find.text(tester.l10n.appliedSentAt('12 Eki Pzt, 19:30')),
        findsOneWidget,
      );
    });

    testWidgets('yerleşim: yatay 16, üst 16, aralık 16; düğmeler 56 · 44; '
        'alt güvenli alan + 8', (tester) async {
      const safe = EdgeInsets.only(top: 47, bottom: 34);
      await _pump(tester, kPendingState, viewPadding: safe);
      final l10n = tester.l10n;

      final bar = tester.getRect(find.byType(GuAppBar));
      final check = tester.getRect(find.byType(GuSuccessCheck));
      final title = tester.getRect(find.text(l10n.appliedTitle));
      final description = tester.getRect(find.text(l10n.appliedDesc));
      final card = tester.getRect(
        find.ancestor(of: find.text(kClub.name), matching: find.byType(GuCard)),
      );
      final prompt = tester.getRect(
        find.ancestor(of: find.byKey(_enable), matching: find.byType(GuCard)),
      );
      final browse = tester.getRect(find.byKey(_browse));
      final mine = tester.getRect(find.byKey(_myApplications));

      expect(check.top, bar.bottom + 16);
      expect(check.size, const Size.square(110));
      expect(check.center.dx, 195);
      expect(title.top, check.bottom + 16);
      expect(description.top, title.bottom + 16);
      expect(card.top, description.bottom + 16);
      expect(card.left, 16);
      expect(card.right, 390 - 16);
      expect(prompt.top, card.bottom + 16);
      expect(prompt.left, 16);
      expect(prompt.right, 390 - 16);
      expect(browse.top, prompt.bottom + 16);
      expect(browse.width, 358);
      expect(browse.height, 56);
      expect(mine.top, browse.bottom + 16);
      expect(mine.height, 44);
      expect(mine.center.dx, 195);

      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        scroll.padding,
        const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 34 + 8),
      );
    });
  });

  group('CLB-04 · İsteğin iletildi · durumlar', () {
    testWidgets('okunuyor: başarı mesajı ve düğmeler durur, kart iskelettir', (
      tester,
    ) async {
      await _pump(tester, kLoadingState);
      final l10n = tester.l10n;
      expect(find.text(l10n.appliedTitle), findsOneWidget);
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.commonLoading), findsOneWidget);
      expect(find.byType(GuEmblem), findsNothing);
      expect(find.byType(GuBanner), findsNothing);
      expect(find.byKey(_browse), findsOneWidget);
      expect(find.byKey(_myApplications), findsOneWidget);
    });

    testWidgets('okunamadı: kartın yerinde "Yeniden dene"li hata bandı', (
      tester,
    ) async {
      await _pump(tester, kErrorState);
      final l10n = tester.l10n;
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.danger);
      expect(banner.text, l10n.sysErrorDesc);
      expect(banner.actionLabel, l10n.commonRetry);
      expect(banner.actionKey, _retry);
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.byType(GuEmblem), findsNothing);
      expect(find.byType(GuSkeletonList), findsNothing);
      // Onay mesajı ve düğmeler veriden bağımsızdır.
      expect(find.text(l10n.appliedTitle), findsOneWidget);
      expect(find.byKey(_browse), findsOneWidget);
    });

    testWidgets('hata, eldeki kulüpten önce gelir', (tester) async {
      await _pump(tester, kPendingState.copyWith(isError: true));
      expect(find.byType(GuBanner), findsOneWidget);
      expect(find.byType(GuEmblem), findsNothing);
    });
  });

  group('CLB-04 · İsteğin iletildi · envanter ve matris', () {
    testWidgets('aksiyon envanteri: 4 aksiyon', (tester) async {
      await _pump(tester, kPendingState);
      expectActionInventory(tester, 'CLB-04');
    });

    testWidgets('aksiyon envanteri: bildirim izni varken "Aç" yok', (
      tester,
    ) async {
      await _pump(tester, _plainState);
      expectActionInventory(
        tester,
        'CLB-04',
        extraExempt: const {'CLB-04.enableNotifications'},
      );
    });

    testWidgets('aksiyon envanteri: okunuyor / okunamadı', (tester) async {
      for (final state in [kLoadingState, kErrorState]) {
        await _pump(tester, state);
        expectActionInventory(
          tester,
          'CLB-04',
          extraExempt: const {'CLB-04.enableNotifications'},
        );
      }
    });

    testWidgets('cihaz matrisi: taşma yok (güvenli alanlar)', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: stateOverride(kPendingState),
        safeAreas: true,
      );
    });

    testWidgets('cihaz matrisi: uzun kulüp adı + 300 karakterlik not', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: stateOverride(
          kPendingState.copyWith(
            club: kClub.copyWith(
              name:
                  'Uluslararası Öğrenci Değişim Programları ve Kültürlerarası '
                  'Etkileşim Topluluğu',
            ),
            savedNote: 'Uzun bir başvuru notu. ' * 13,
          ),
        ),
      );
    });

    testWidgets('cihaz matrisi: okunuyor ve okunamadı', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: stateOverride(kLoadingState),
      );
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: stateOverride(kErrorState),
      );
    });
  });

  group('CLB-04 · İsteğin iletildi · aksiyonlar', () {
    testWidgets('kulüp ve not gerçek okumadan gelir; izin yoksa bildirim '
        'kartı görünür', (tester) async {
      await pumpClubRoute(tester, _location, membership: kPending);
      expect(find.byType(ClubAppliedView), findsOneWidget);
      expect(find.text(kClub.name), findsOneWidget);
      expect(find.text('“$kNote”'), findsOneWidget);
      expect(find.byKey(_enable), findsOneWidget);
    });

    testWidgets('bildirim izni verilmişse kart görünmez', (tester) async {
      await pumpClubRoute(
        tester,
        _location,
        membership: kPending,
        seed: () => permissionsFake().results[Permission.notification] =
            PermissionStatus.granted,
      );
      expect(find.byKey(_enable), findsNothing);
    });

    testWidgets('kapat → kulüp sayfası (CLB-03)', (tester) async {
      final router = await pumpClubRoute(
        tester,
        _location,
        membership: kPending,
      );
      await _tap(tester, _close);
      expect(locationOf(router), '/clubs/$kClubId');
      expect(feedbackFake().calls, isEmpty);
    });

    testWidgets('"Diğer kulüplere göz at" → Kulüpler kökü (CLB-01)', (
      tester,
    ) async {
      final router = await pumpClubRoute(
        tester,
        _location,
        membership: kPending,
      );
      await _tap(tester, _browse);
      expect(locationOf(router), '/clubs');
    });

    testWidgets('"Başvurularım" → PRF-03 bekleyenler sekmesi (W-65)', (
      tester,
    ) async {
      final router = await pumpClubRoute(
        tester,
        _location,
        membership: kPending,
      );
      await _tap(tester, _myApplications);
      expect(locationOf(router), '/profile/clubs?tab=pending');
    });

    testWidgets('"Aç" → DLG-03 "İzin ver" → TST-19, kart kalkar', (
      tester,
    ) async {
      await pumpClubRoute(tester, _location, membership: kPending);
      feedbackFake().nextDialogResult = true;

      await _tap(tester, _enable);

      expect(feedbackFake().dialogs, [DialogId.dlg03]);
      expect(permissionsFake().requested, [Permission.notification]);
      expect(feedbackFake().toasts, [ToastId.tst19]);
      expect(find.byKey(_enable), findsNothing);
      expect(find.text(tester.l10n.appliedEnableNotif), findsNothing);
    });

    testWidgets('"Aç" → DLG-03 "Şimdi değil": kart kalır, izin istenmez', (
      tester,
    ) async {
      await pumpClubRoute(tester, _location, membership: kPending);
      feedbackFake().nextDialogResult = false;
      await _tap(tester, _enable);
      expect(feedbackFake().dialogs, [DialogId.dlg03]);
      expect(permissionsFake().requested, isEmpty);
      expect(feedbackFake().toasts, isEmpty);
      expect(find.byKey(_enable), findsOneWidget);
    });

    testWidgets('kulüp yok / silinmiş → SYS-04', (tester) async {
      final router = await pumpClubRoute(
        tester,
        _location,
        withClub: false,
        membership: kPending,
      );
      expect(locationOf(router), '/not-found');
    });

    testWidgets('kulübün yokluğu bilinirken açılırsa da SYS-04', (
      tester,
    ) async {
      final router = await pumpClubRoute(
        tester,
        _location,
        overrides: stateOverride(const ClubApplicationState(isNotFound: true)),
      );
      expect(locationOf(router), '/not-found');
    });

    testWidgets('okunamadı → "Yeniden dene" başvuru kartını getirir', (
      tester,
    ) async {
      await pumpClubRoute(
        tester,
        _location,
        membership: kPending,
        seed: () => clubsFake().failNext(FirestoreError.unavailable),
      );
      expect(find.byType(GuBanner), findsOneWidget);

      await _tap(tester, _retry);
      expect(find.byType(GuBanner), findsNothing);
      expect(find.text(kClub.name), findsOneWidget);
      expect(find.text('“$kNote”'), findsOneWidget);
    });

    testWidgets('başvuru oturuma sonradan gelirse not yeniden okunur', (
      tester,
    ) async {
      // Ekran, üyelik akışı yetişmeden açıldı: oturumda üyelik yok.
      await pumpClubRoute(tester, _location);
      expect(find.textContaining('“'), findsNothing);

      membershipsFake().put(kPending, email: kEmail, note: kNote);
      setSession(tester, sessionWith(kPending));
      await tester.pumpAndSettle();

      expect(find.text('“$kNote”'), findsOneWidget);
      expect(
        find.text(tester.l10n.appliedSentAt('6 Eki Sal, 19:08')),
        findsOneWidget,
      );
    });
  });

  group('CLB-04 · İsteğin iletildi · golden', () {
    testWidgets('golden: açık + koyu, TR + EN (çizim bitmiş)', (tester) async {
      await _golden(
        tester,
        'CLB-04',
        kPendingState,
        locales: DeviceMatrix.locales,
      );
    });

    testWidgets('golden: notsuz, bildirim izni var', (tester) async {
      await _golden(tester, 'CLB-04__plain', _plainState);
    });

    testWidgets('golden: okunuyor', (tester) async {
      await _golden(tester, 'CLB-04__loading', kLoadingState);
    });

    testWidgets('golden: okunamadı', (tester) async {
      await _golden(tester, 'CLB-04__error', kErrorState);
    });
  });
}
