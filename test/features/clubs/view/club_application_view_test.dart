// CLB-05 · Başvuru durumu — içerik (TR / EN), evreler (beklemede, reddedildi
// / çıkarıldı, onaylandı, başvuru yok), durumlar (okunuyor, okunamadı, kulüp
// yok, çevrimdışı yazma), 5 + 2 aksiyon ve sonuçları (TST-07, DLG-07 →
// TST-40, SHT-05 → CLB-04, TST-34, TST-X1, TST-X4, TST-24), canlı üyelik,
// cihaz matrisi, aksiyon envanteri, açık + koyu golden.
// Referans: design/reference-shots/screens/CLB-05__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_state.dart';
import 'package:gu_kulupler/features/clubs/provider/join_application_state.dart';
import 'package:gu_kulupler/features/clubs/view/club_application_view.dart';
import 'package:gu_kulupler/features/clubs/view/widget/application_status_card.dart';
import 'package:gu_kulupler/features/clubs/view/widget/join_application_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/register_fakes.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import 'club_application_test_support.dart';

final Key _back = GuKey.action('CLB-05.back');
final Key _openClub = GuKey.action('CLB-05.openClub');
final Key _noteField = GuKey.action('CLB-05.note');
final Key _save = GuKey.action('CLB-05.saveNote');
final Key _cancel = GuKey.action('CLB-05.cancel');
final Key _reapply = GuKey.action('CLB-05.reapply');
final Key _retry = GuKey.action('CLB-05.retry');

const String _location = '/clubs/$kClubId/application';
const String _clubLocation = '/clubs/$kClubId';

/// Yalnızca bekleyen başvuruda çizilen aksiyonlar.
const Set<String> _pendingOnly = {
  'CLB-05.note',
  'CLB-05.saveNote',
  'CLB-05.cancel',
};

const ClubApplicationView _view = ClubApplicationView(clubId: kClubId);

Future<void> _pump(
  WidgetTester tester,
  ClubApplicationState state, {
  Locale locale = const Locale('tr'),
  ThemeMode theme = ThemeMode.light,
  EdgeInsets viewPadding = EdgeInsets.zero,
}) => tester.pumpApp(
  _view,
  locale: locale,
  theme: theme,
  viewPadding: viewPadding,
  overrides: stateOverride(state),
);

GuButton _button(WidgetTester tester, Key key) =>
    tester.widget<GuButton>(find.byKey(key));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

List<GuTimelineItem> _steps(WidgetTester tester) =>
    tester.widget<GuTimeline>(find.byType(GuTimeline)).items;

FakeAppClock _clock() => GetIt.I<AppClock>() as FakeAppClock;

void main() {
  setUpAll(initDateFormats);

  group('CLB-05 · Başvuru durumu · içerik', () {
    for (final locale in DeviceMatrix.locales) {
      testWidgets('beklemede (${locale.languageCode}): kart, zaman çizelgesi, '
          'not, "Kaydet", "İsteği iptal et"', (tester) async {
        await _pump(tester, kPendingState, locale: locale);
        final l10n = tester.l10n;
        final gu = tester.element(find.byType(ClubApplicationView)).gu;

        // Çubuk: geri + başlık.
        final bar = tester.widget<GuAppBar>(find.byType(GuAppBar));
        expect(bar.title, l10n.applicationTitle);
        expect(bar.closeIcon, isFalse);
        expect(find.byKey(_back), findsOneWidget);
        expect(find.bySemanticsLabel(l10n.a11yBack), findsOneWidget);

        // Kulüp kartı: amblem + ad + kategori + "Beklemede" rozeti.
        final card = tester.widget<GuCard>(find.byKey(_openClub));
        expect(card.onTap, isNotNull);
        expect(card.semanticLabel, kClub.name);
        expect(card.padding, GuInsets.h16v12);
        final emblem = tester.widget<GuEmblem>(find.byType(GuEmblem));
        expect(emblem.icon, GuIcons.music);
        expect(emblem.size, GuEmblemSize.sm);
        expect(
          tester.widget<Text>(find.text(kClub.name)).style,
          gu.text.titleS,
        );
        expect(
          tester.widget<Text>(find.text(l10n.catK04)).style,
          gu.text.caption,
        );
        final badge = tester.widget<GuStatusBadge>(find.byType(GuStatusBadge));
        expect(badge.kind, GuStatusBadgeKind.pending);
        expect(badge.label, l10n.statusPending);

        // Zaman çizelgesi: gönderildi (tarih) · inceleniyor · sonuç.
        final steps = _steps(tester);
        expect(steps.map((step) => step.title), [
          l10n.applicationStepSent,
          l10n.applicationStepReview,
          l10n.applicationStepResult,
        ]);
        expect(steps.map((step) => step.state), [
          GuTimelineDotState.done,
          GuTimelineDotState.active,
          GuTimelineDotState.pending,
        ]);
        expect(
          steps[0].caption,
          locale.languageCode == 'tr' ? '6 Eki Sal, 19:08' : 'Tue 6 Oct, 19:08',
        );
        expect(steps[1].caption, l10n.applicationReviewing);
        expect(steps[2].caption, l10n.applicationWaitingResult);

        // Not alanı: çok satırlı, 300 karakter, sayaçlı; mevcut notla dolu.
        final input = tester.widget<GuInput>(find.byType(GuInput));
        expect(input.label, l10n.applicationYourNote);
        expect(input.multiline, isTrue);
        expect(input.maxLength, Limits.applicationNoteMax);
        expect(input.showCounter, isTrue);
        expect(input.errorText, isNull);
        expect(input.controller!.text, kNote);
        expect(find.text(kNote), findsOneWidget);

        // "Kaydet": tonal, tam genişlik, not değişene kadar kapalı.
        final save = _button(tester, _save);
        expect(save.label, l10n.commonSave);
        expect(save.variant, GuButtonVariant.tonal);
        expect(save.full, isTrue);
        expect(save.disabled, isTrue);
        expect(save.loading, isFalse);

        // "İsteği iptal et": tehlike çerçeveli, tam genişlik.
        final cancel = _button(tester, _cancel);
        expect(cancel.label, l10n.applicationCancel);
        expect(cancel.variant, GuButtonVariant.dangerOutline);
        expect(cancel.full, isTrue);
        expect(cancel.loading, isFalse);

        // Diğer evrelerin öğeleri yok.
        expect(find.byKey(_reapply), findsNothing);
        expect(find.byType(GuBanner), findsNothing);
        expect(find.byType(GuErrorState), findsNothing);
        expect(find.byType(GuSkeletonList), findsNothing);
        expect(find.text(l10n.sysErrorTitle), findsNothing);
      });
    }

    testWidgets('reddedildi, bekleme sürüyor: neden kartı, tarih rozeti + '
        'kalan gün, kapalı "Tekrar başvur", bekleme notu', (tester) async {
      await _pump(tester, kRejectedWaitingState);
      final l10n = tester.l10n;
      final gu = tester.element(find.byType(ClubApplicationView)).gu;

      final status = tester.widget<GuStatusBadge>(find.byType(GuStatusBadge));
      expect(status.kind, GuStatusBadgeKind.rejected);
      expect(status.label, l10n.statusRejected);
      final steps = _steps(tester);
      expect(steps.map((step) => step.state), [
        GuTimelineDotState.done,
        GuTimelineDotState.done,
        GuTimelineDotState.danger,
      ]);
      // Karar anı: sahte saatten 3 gün önce (9 Ekim 2026 19:30 Istanbul).
      expect(steps[1].caption, '9 Eki Cum, 19:30');
      expect(steps[2].caption, l10n.statusRejected);

      // Neden kartı: üst başlık (büyük harf) + neden + yöneticinin notu.
      final overline = tester.widget<Text>(find.text('NEDEN'));
      expect(overline.style, gu.text.overline);
      expect(
        tester.widget<Text>(find.text(l10n.rejectReasonQuota)).style,
        gu.text.bodyM,
      );
      final note = tester.widget<Text>(
        find.text('Bu dönem kontenjanımız doldu; bahar döneminde bekleriz.'),
      );
      expect(note.style?.color, gu.colors.textSecondary);
      final reasonCard = tester.widget<GuCard>(
        find.ancestor(of: find.text('NEDEN'), matching: find.byType(GuCard)),
      );
      expect(reasonCard.muted, isTrue);
      expect(reasonCard.onTap, isNull);

      // Rozet: bekleme tarihi (16 Ekim 2026) + kalan gün (yukarı yuvarlanır).
      final badge = tester.widget<GuBadge>(
        find.byWidgetPredicate(
          (widget) => widget is GuBadge && widget.icon == GuIcons.hourglass,
        ),
      );
      expect(badge.kind, GuBadgeKind.pending);
      expect(badge.label, l10n.applicationRetryAt('16 Ekim 2026'));
      expect(find.text(l10n.timeInDays(4)), findsOneWidget);

      final reapply = _button(tester, _reapply);
      expect(reapply.label, l10n.applicationReapply);
      expect(reapply.variant, GuButtonVariant.primary);
      expect(reapply.full, isTrue);
      expect(reapply.disabled, isTrue);
      expect(reapply.onDisabledPressed, isNotNull);
      expect(find.text(l10n.applicationRetryNote), findsOneWidget);

      // Bekleyen başvurunun öğeleri yok.
      expect(find.byType(GuInput), findsNothing);
      expect(find.byKey(_save), findsNothing);
      expect(find.byKey(_cancel), findsNothing);
    });

    testWidgets('reddedildi, bekleme dolmuş: "Tekrar başvurabilirsin" rozeti, '
        'açık düğme; neden yoksa kart çizilmez', (tester) async {
      await _pump(
        tester,
        kRejectedOpenState.copyWith(
          membership: rejectedMembership(reason: null),
        ),
      );
      final l10n = tester.l10n;

      final badge = tester.widget<GuBadge>(
        find.byWidgetPredicate(
          (widget) => widget is GuBadge && widget.icon == GuIcons.hourglass,
        ),
      );
      expect(badge.kind, GuBadgeKind.success);
      expect(badge.label, l10n.applicationCanReapply);
      expect(_button(tester, _reapply).disabled, isFalse);
      expect(find.text(l10n.applicationRetryNote), findsNothing);
      expect(find.text('NEDEN'), findsNothing);
      expect(find.byType(GuCountdown), findsNothing);
    });

    testWidgets('reddedildi, kulüp başvuru almıyor: düğme kapalı görünür', (
      tester,
    ) async {
      await _pump(
        tester,
        kRejectedOpenState.copyWith(
          club: kClub.copyWith(applicationsOpen: false),
        ),
      );
      expect(_button(tester, _reapply).disabled, isTrue);
      expect(
        find.text(tester.l10n.applicationCanReapply),
        findsOneWidget,
      );
    });

    testWidgets('bekleme dolunca rozet ve düğme kendiliğinden açılır', (
      tester,
    ) async {
      await _pump(tester, kRejectedWaitingState);
      final l10n = tester.l10n;
      expect(_button(tester, _reapply).disabled, isTrue);

      _clock().set(kRetryAfter.add(const Duration(seconds: 1)));
      await tester.pump(GuMotion.countdownTick);

      expect(_button(tester, _reapply).disabled, isFalse);
      expect(find.text(l10n.applicationCanReapply), findsOneWidget);
      expect(find.text(l10n.applicationRetryNote), findsNothing);
    });

    testWidgets('çıkarıldı: "Çıkarıldı" rozeti, neden "Diğer"', (tester) async {
      await _pump(
        tester,
        ClubApplicationState(
          club: kClub,
          membership: rejectedMembership(
            status: MembershipStatus.removed,
            reason: RejectReason.other,
            retryAfter: kRetryAfter,
          ),
        ),
      );
      final l10n = tester.l10n;
      final status = tester.widget<GuStatusBadge>(find.byType(GuStatusBadge));
      expect(status.kind, GuStatusBadgeKind.removed);
      expect(status.label, l10n.statusRemoved);
      expect(_steps(tester).last.state, GuTimelineDotState.danger);
      expect(_steps(tester).last.caption, l10n.statusRemoved);
      expect(find.text(l10n.rejectReasonOther), findsOneWidget);
      expect(find.byKey(_reapply), findsOneWidget);
    });

    testWidgets('onaylandı: başarı bandı + "Kulübe git"', (tester) async {
      await _pump(tester, kApprovedState);
      final l10n = tester.l10n;

      final status = tester.widget<GuStatusBadge>(find.byType(GuStatusBadge));
      expect(status.kind, GuStatusBadgeKind.approved);
      expect(status.label, l10n.statusApproved);
      expect(_steps(tester).map((step) => step.state), [
        GuTimelineDotState.done,
        GuTimelineDotState.done,
        GuTimelineDotState.done,
      ]);
      expect(_steps(tester).last.caption, l10n.statusApproved);

      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.success);
      expect(banner.text, l10n.applicationApprovedNote);

      // Kart ve düğme aynı aksiyondur.
      expect(find.byKey(_openClub), findsNWidgets(2));
      final goClub = tester.widget<GuButton>(
        find.widgetWithText(GuButton, l10n.applicationGoClub),
      );
      expect(goClub.key, _openClub);
      expect(goClub.full, isTrue);
      expect(find.byType(GuInput), findsNothing);
      expect(find.byKey(_reapply), findsNothing);
    });

    for (final (name, membership) in [
      ('üyelik yok', null),
      ('iptal edilmiş', membershipWith(MembershipStatus.cancelled)),
      ('ayrılmış', membershipWith(MembershipStatus.left)),
    ]) {
      testWidgets('başvuru yok ($name): "İptal" rozeti, tarihsiz adımlar, '
          'bilgi bandı + "Katıl"', (tester) async {
        await _pump(
          tester,
          ClubApplicationState(club: kClub, membership: membership),
        );
        final l10n = tester.l10n;

        final status = tester.widget<GuStatusBadge>(
          find.byType(GuStatusBadge),
        );
        expect(status.kind, GuStatusBadgeKind.cancelled);
        expect(status.label, l10n.statusCancelled);
        final steps = _steps(tester);
        expect(steps.map((step) => step.state), [
          GuTimelineDotState.done,
          GuTimelineDotState.done,
          GuTimelineDotState.pending,
        ]);
        expect(steps.map((step) => step.caption), [
          null,
          null,
          l10n.applicationWaitingResult,
        ]);

        final banner = tester.widget<GuBanner>(find.byType(GuBanner));
        expect(banner.kind, GuBannerKind.info);
        expect(banner.text, l10n.applicationNoneNote);
        final join = _button(tester, _reapply);
        expect(join.label, l10n.clubsCardJoin);
        expect(join.full, isTrue);
        expect(join.disabled, isFalse);
        expect(find.byType(GuInput), findsNothing);
      });
    }

    testWidgets('yerleşim: yatay 16, üst 8, bloklar arası 20; alt güvenli '
        'alan + 24 + 8', (tester) async {
      const safe = EdgeInsets.only(top: 47, bottom: 34);
      await _pump(tester, kPendingState, viewPadding: safe);

      final bar = tester.getRect(find.byType(GuAppBar));
      final card = tester.getRect(find.byKey(_openClub));
      final timeline = tester.getRect(find.byType(GuTimeline));
      final input = tester.getRect(find.byType(GuInput));
      final save = tester.getRect(find.byKey(_save));
      final cancel = tester.getRect(find.byKey(_cancel));

      expect(card.left, 16);
      expect(card.right, 390 - 16);
      expect(card.top, bar.bottom + 8);
      expect(timeline.top, card.bottom + 20);
      expect(input.top, timeline.bottom + 20);
      expect(save.top, input.bottom + 20);
      expect(cancel.top, save.bottom + 20);
      expect(save.width, 358);
      expect(save.height, 48);
      expect(cancel.height, 48);

      final scroll = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(
        scroll.padding,
        const EdgeInsets.only(left: 16, top: 8, right: 16, bottom: 24 + 34 + 8),
      );
    });
  });

  group('CLB-05 · Başvuru durumu · durumlar', () {
    testWidgets('okunuyor: iskelet (içerik yok)', (tester) async {
      await _pump(tester, kLoadingState);
      final l10n = tester.l10n;
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.bySemanticsLabel(l10n.commonLoading), findsOneWidget);
      expect(find.byType(ApplicationStatusCard), findsNothing);
      expect(find.byType(GuErrorState), findsNothing);
      // Çubuk yüklenirken de çalışır.
      expect(find.byKey(_back), findsOneWidget);
    });

    testWidgets('okunamadı: hata durumu + "Yeniden dene" (içerik yok)', (
      tester,
    ) async {
      await _pump(tester, kErrorState);
      final l10n = tester.l10n;
      final error = tester.widget<GuErrorState>(find.byType(GuErrorState));
      expect(error.title, l10n.sysErrorTitle);
      expect(error.description, l10n.sysErrorDesc);
      expect(error.retryLabel, l10n.commonRetry);
      expect(error.retryActionKey, _retry);
      expect(error.onHome, isNull);
      expect(find.byType(ApplicationStatusCard), findsNothing);
      expect(find.byType(GuSkeletonList), findsNothing);
    });

    testWidgets('hata, yüklemeden önce gelir (eski kulüp eldeyken de)', (
      tester,
    ) async {
      await _pump(tester, kPendingState.copyWith(isError: true));
      expect(find.byType(GuErrorState), findsOneWidget);
      expect(find.byType(ApplicationStatusCard), findsNothing);
    });

    testWidgets('yeniden okunurken eldeki içerik kalır', (tester) async {
      await _pump(tester, kPendingState.copyWith(isFetching: true));
      expect(find.byType(ApplicationStatusCard), findsOneWidget);
      expect(find.byType(GuSkeletonList), findsNothing);
    });

    testWidgets('meşgul: "Kaydet" / "İsteği iptal et" / "Katıl" dönüyor', (
      tester,
    ) async {
      await _pump(
        tester,
        kPendingState.copyWith(note: 'yeni', isSaving: true),
      );
      expect(_button(tester, _save).loading, isTrue);
      expect(_button(tester, _cancel).loading, isFalse);

      await _pump(tester, kPendingState.copyWith(isCancelling: true));
      expect(_button(tester, _cancel).loading, isTrue);
      expect(_button(tester, _save).loading, isFalse);

      await _pump(tester, kNoneState.copyWith(isJoining: true));
      expect(_button(tester, _reapply).loading, isTrue);
    });

    testWidgets('alan ve yazım hataları ekranda gösterilir', (tester) async {
      await _pump(
        tester,
        kPendingState.copyWith(
          note: '',
          errors: const {ApplicationField.note: FormFieldError.required},
          submitError: SubmitError.unknown,
        ),
      );
      final l10n = tester.l10n;
      expect(
        tester.widget<GuInput>(find.byType(GuInput)).errorText,
        l10n.authErrRequired,
      );
      expect(find.text(l10n.authErrRequired), findsOneWidget);
      expect(find.text(l10n.sysErrorTitle), findsOneWidget);

      // Ağ ve çakışma hataları satır içi gösterilmez (toast / canlı durum).
      for (final error in [SubmitError.network, SubmitError.conflict]) {
        await _pump(tester, kPendingState.copyWith(submitError: error));
        expect(find.text(l10n.sysErrorTitle), findsNothing);
      }

      await _pump(
        tester,
        kNoneState.copyWith(submitError: SubmitError.unknown),
      );
      expect(find.text(l10n.sysErrorTitle), findsOneWidget);
    });
  });

  group('CLB-05 · Başvuru durumu · envanter ve matris', () {
    testWidgets('aksiyon envanteri: beklemede 5 aksiyon', (tester) async {
      await _pump(tester, kPendingState);
      expectActionInventory(tester, 'CLB-05');
    });

    for (final (name, state) in [
      ('reddedildi (bekleme)', kRejectedWaitingState),
      ('reddedildi (açık)', kRejectedOpenState),
      ('onaylandı', kApprovedState),
      ('başvuru yok', kNoneState),
      ('okunuyor', kLoadingState),
      ('okunamadı', kErrorState),
    ]) {
      testWidgets('aksiyon envanteri: $name', (tester) async {
        await _pump(tester, state);
        expectActionInventory(
          tester,
          'CLB-05',
          extraExempt: {
            ..._pendingOnly,
            // Kulüp kartı yalnızca içerik çizilince vardır.
            if (state.club == null) 'CLB-05.openClub',
          },
        );
      });
    }

    testWidgets('her etkileşimli öğenin anahtarı var (evrelere göre)', (
      tester,
    ) async {
      await _pump(tester, kRejectedWaitingState);
      expect(find.byKey(_reapply), findsOneWidget);
      await _pump(tester, kNoneState);
      expect(find.byKey(_reapply), findsOneWidget);
      await _pump(tester, kErrorState);
      expect(find.byKey(_retry), findsOneWidget);
    });

    testWidgets('cihaz matrisi: beklemede (klavye + güvenli alanlar)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: stateOverride(kPendingState),
        keyboard: true,
        safeAreas: true,
      );
    });

    testWidgets('cihaz matrisi: beklemede, uzun not + hata satırları', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: stateOverride(
          kPendingState.copyWith(
            note: 'a ' * 150,
            errors: const {ApplicationField.note: FormFieldError.required},
            submitError: SubmitError.unknown,
          ),
        ),
        keyboard: true,
      );
    });

    testWidgets('cihaz matrisi: reddedildi (bekleme + neden kartı)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: stateOverride(kRejectedWaitingState),
      );
    });

    testWidgets('cihaz matrisi: onaylandı', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: stateOverride(kApprovedState),
      );
    });

    testWidgets('cihaz matrisi: başvuru yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => _view,
        overrides: stateOverride(
          kNoneState.copyWith(submitError: SubmitError.unknown),
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
        safeAreas: true,
      );
    });
  });

  group('CLB-05 · Başvuru durumu · not (TST-07)', () {
    testWidgets('not sunucudan okunur ve alana yazılır', (tester) async {
      await pumpClubRoute(tester, _location, membership: kPending);
      expect(find.byType(ClubApplicationView), findsOneWidget);
      expect(
        tester.widget<GuInput>(find.byType(GuInput)).controller!.text,
        kNote,
      );
      expect(_button(tester, _save).disabled, isTrue);
    });

    testWidgets('not değişince "Kaydet" açılır; kaydedilince TST-07 ve '
        'düğme yeniden kapanır', (tester) async {
      await pumpClubRoute(tester, _location, membership: kPending);

      await tester.enterText(find.byKey(_noteField), 'Bas gitar da çalarım.');
      await tester.pump();
      expect(_button(tester, _save).disabled, isFalse);

      await _tap(tester, find.byKey(_save));

      expect(membershipsFake().noteUpdates, [
        (
          clubId: kClubId,
          userId: kUser.uid,
          note: 'Bas gitar da çalarım.',
        ),
      ]);
      expect(feedbackFake().toasts, [ToastId.tst07]);
      expect(_button(tester, _save).disabled, isTrue);
      expect(_button(tester, _save).loading, isFalse);
      // Üyelik belgesine dokunulmaz (CD-137).
      expect(
        membershipsFake().memberships[kPending.id]!.status,
        MembershipStatus.pending,
      );
    });

    testWidgets('eski nota dönülünce "Kaydet" yeniden kapanır', (tester) async {
      await pumpClubRoute(tester, _location, membership: kPending);
      await tester.enterText(find.byKey(_noteField), 'başka');
      await tester.pump();
      expect(_button(tester, _save).disabled, isFalse);
      await tester.enterText(find.byKey(_noteField), '$kNote ');
      await tester.pump();
      expect(_button(tester, _save).disabled, isTrue);
    });

    testWidgets('sınırı aşan notta "Kaydet" kapalıdır; dokunuş yazmaz', (
      tester,
    ) async {
      await pumpClubRoute(tester, _location, membership: kPending);
      await tester.enterText(
        find.byKey(_noteField),
        'a' * (Limits.applicationNoteMax + 5),
      );
      await tester.pump();
      expect(_button(tester, _save).disabled, isTrue);

      await _tap(tester, find.byKey(_save));
      expect(membershipsFake().noteUpdates, isEmpty);
      expect(feedbackFake().toasts, isEmpty);
    });

    testWidgets('kulüp not istiyorsa boş not: "Bu alan zorunlu"; yazınca '
        'hata silinir', (tester) async {
      await pumpClubRoute(
        tester,
        _location,
        club: kClub.copyWith(requireNote: true),
        membership: kPending,
      );
      final l10n = tester.l10n;

      await tester.enterText(find.byKey(_noteField), '');
      await tester.pump();
      await _tap(tester, find.byKey(_save));
      expect(find.text(l10n.authErrRequired), findsOneWidget);
      expect(membershipsFake().noteUpdates, isEmpty);

      await tester.enterText(find.byKey(_noteField), 'Yeni not');
      await tester.pump();
      expect(find.text(l10n.authErrRequired), findsNothing);
    });

    testWidgets('çevrimdışı: TST-24, not yazılmaz', (tester) async {
      await pumpClubRoute(tester, _location, membership: kPending);
      connectivityFake().isOffline = true;
      await tester.enterText(find.byKey(_noteField), 'yeni');
      await tester.pump();
      await _tap(tester, find.byKey(_save));
      expect(feedbackFake().toasts, [ToastId.tst24]);
      expect(membershipsFake().noteUpdates, isEmpty);
      expect(_button(tester, _save).disabled, isFalse);
    });

    testWidgets('beklenmeyen sunucu hatası düğmenin altında gösterilir', (
      tester,
    ) async {
      await pumpClubRoute(tester, _location, membership: kPending);
      await tester.enterText(find.byKey(_noteField), 'yeni');
      await tester.pump();
      membershipsFake().failNext(FirestoreError.unknown);
      await _tap(tester, find.byKey(_save));
      expect(find.text(tester.l10n.sysErrorTitle), findsOneWidget);
      expect(feedbackFake().toasts, isEmpty);
    });
  });

  group('CLB-05 · Başvuru durumu · iptal (DLG-07, TST-40)', () {
    testWidgets('"İsteği iptal et" → DLG-07 onayı → TST-40 → kulüp sayfası', (
      tester,
    ) async {
      final router = await pumpClubRoute(
        tester,
        _location,
        membership: kPending,
      );
      feedbackFake().nextDialogResult = true;

      await _tap(tester, find.byKey(_cancel));

      expect(feedbackFake().dialogs, [DialogId.dlg07]);
      expect(feedbackFake().dialogParams.single, {
        DialogParamKeys.club: kClub.name,
      });
      expect(
        membershipsFake().memberships[kPending.id]!.status,
        MembershipStatus.cancelled,
      );
      expect(feedbackFake().toasts, [ToastId.tst40]);
      expect(locationOf(router), _clubLocation);
      expect(find.byType(ClubApplicationView), findsNothing);
    });

    testWidgets('"Vazgeç": ekranda kalınır, başvuru durur', (tester) async {
      final router = await pumpClubRoute(
        tester,
        _location,
        membership: kPending,
      );
      feedbackFake().nextDialogResult = false;
      await _tap(tester, find.byKey(_cancel));
      expect(feedbackFake().dialogs, [DialogId.dlg07]);
      expect(feedbackFake().toasts, isEmpty);
      expect(locationOf(router), _location);
      expect(
        membershipsFake().memberships[kPending.id]!.status,
        MembershipStatus.pending,
      );
    });

    testWidgets('çevrimdışı: onaydan sonra TST-24, ekranda kalınır', (
      tester,
    ) async {
      final router = await pumpClubRoute(
        tester,
        _location,
        membership: kPending,
      );
      connectivityFake().isOffline = true;
      feedbackFake().nextDialogResult = true;
      await _tap(tester, find.byKey(_cancel));
      expect(feedbackFake().toasts, [ToastId.tst24]);
      expect(locationOf(router), _location);
      expect(
        membershipsFake().memberships[kPending.id]!.status,
        MembershipStatus.pending,
      );
    });
  });

  group('CLB-05 · Başvuru durumu · gezinme', () {
    testWidgets('geri → kulüp sayfası (yığındaki önceki sayfa)', (
      tester,
    ) async {
      final router = await pumpClubRoute(
        tester,
        _location,
        membership: kPending,
      );
      await _tap(tester, find.byKey(_back));
      expect(locationOf(router), _clubLocation);
      expect(feedbackFake().calls, isEmpty);
    });

    testWidgets('kulüp kartı → kulüp sayfası', (tester) async {
      final router = await pumpClubRoute(
        tester,
        _location,
        membership: kPending,
      );
      await _tap(tester, find.byKey(_openClub));
      expect(locationOf(router), _clubLocation);
    });

    testWidgets('onaylandı: "Kulübe git" → kulüp sayfası', (tester) async {
      final active = membershipWith(MembershipStatus.active);
      final router = await pumpClubRoute(tester, _location, membership: active);
      await _tap(
        tester,
        find.widgetWithText(GuButton, tester.l10n.applicationGoClub),
      );
      expect(locationOf(router), _clubLocation);
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
        overrides: stateOverride(
          const ClubApplicationState(isNotFound: true),
        ),
      );
      expect(locationOf(router), '/not-found');
    });

    testWidgets('okunamadı → "Yeniden dene" içeriği getirir', (tester) async {
      await pumpClubRoute(
        tester,
        _location,
        membership: kPending,
        seed: () => clubsFake().failNext(FirestoreError.unavailable),
      );
      expect(find.byType(GuErrorState), findsOneWidget);

      await _tap(tester, find.byKey(_retry));
      expect(find.byType(GuErrorState), findsNothing);
      expect(find.byType(ApplicationStatusCard), findsOneWidget);
      expect(
        tester.widget<GuInput>(find.byType(GuInput)).controller!.text,
        kNote,
      );
    });
  });

  group('CLB-05 · Başvuru durumu · yeniden başvuru '
      '(SHT-05, TST-X1, TST-X4, TST-34)', () {
    final open = rejectedMembership(
      retryAfter: kDefaultFakeNowUtc.subtract(const Duration(days: 1)),
    );
    final waiting = rejectedMembership(retryAfter: kRetryAfter);

    testWidgets('"Tekrar başvur" → SHT-05; başvuru gönderilince CLB-04', (
      tester,
    ) async {
      final router = await pumpClubRoute(tester, _location, membership: open);
      feedbackFake().nextSheetResult = JoinApplicationOutcome.applied;

      await _tap(tester, find.byKey(_reapply));

      expect(feedbackFake().sheets, [SheetId.sht05]);
      final sheet = feedbackFake().lastSheetBuilder!(
        tester.element(find.byType(Navigator).first),
      );
      expect(sheet, isA<JoinApplicationSheet>());
      expect((sheet as JoinApplicationSheet).clubId, kClubId);
      expect(locationOf(router), '/clubs/$kClubId/applied');
      expect(feedbackFake().toasts, isEmpty);
    });

    testWidgets('SHT-05 anında katılımla kapanırsa TST-34, ekranda kalınır', (
      tester,
    ) async {
      final router = await pumpClubRoute(tester, _location, membership: open);
      feedbackFake().nextSheetResult = JoinApplicationOutcome.joined;
      await _tap(tester, find.byKey(_reapply));
      expect(feedbackFake().toasts, [ToastId.tst34]);
      expect(locationOf(router), _location);

      // "Kulübe git" → kulüp sayfası.
      feedbackFake().tapToastAction();
      await tester.pumpAndSettle();
      expect(locationOf(router), _clubLocation);
    });

    testWidgets('SHT-05 gönderim olmadan kapanırsa hiçbir şey olmaz', (
      tester,
    ) async {
      final router = await pumpClubRoute(tester, _location, membership: open);
      await _tap(tester, find.byKey(_reapply));
      expect(feedbackFake().sheets, [SheetId.sht05]);
      expect(feedbackFake().toasts, isEmpty);
      expect(locationOf(router), _location);
    });

    testWidgets('bekleme sürerken (kapalı düğme) dokunuş → TST-X4 tarihle', (
      tester,
    ) async {
      await pumpClubRoute(tester, _location, membership: waiting);
      expect(_button(tester, _reapply).disabled, isTrue);

      await _tap(tester, find.byKey(_reapply));

      expect(feedbackFake().toasts, [ToastId.tstX4]);
      expect(
        feedbackFake().toastParams.single,
        const ToastParams(date: '16 Ekim 2026'),
      );
      expect(feedbackFake().sheets, isEmpty);
    });

    testWidgets('kulüp başvuru almıyorken (kapalı düğme) dokunuş → TST-X1', (
      tester,
    ) async {
      await pumpClubRoute(
        tester,
        _location,
        club: kClub.copyWith(applicationsOpen: false),
        membership: open,
      );
      expect(_button(tester, _reapply).disabled, isTrue);
      await _tap(tester, find.byKey(_reapply));
      expect(feedbackFake().toasts, [ToastId.tstX1]);
      expect(feedbackFake().sheets, isEmpty);
    });

    testWidgets('başvuru yok + onay isteyen kulüp: "Katıl" → SHT-05', (
      tester,
    ) async {
      await pumpClubRoute(tester, _location);
      await _tap(tester, find.byKey(_reapply));
      expect(feedbackFake().sheets, [SheetId.sht05]);
      expect(membershipsFake().applied, isEmpty);
    });

    testWidgets('başvuru yok + onaysız kulüp: "Katıl" → anında katılım → '
        'TST-34; üyelik gelince ekran "Onaylandı" olur', (tester) async {
      await pumpClubRoute(
        tester,
        _location,
        club: kClub.copyWith(approvalRequired: false),
      );

      await _tap(tester, find.byKey(_reapply));

      expect(membershipsFake().applied.single.status, MembershipStatus.active);
      expect(feedbackFake().toasts, [ToastId.tst34]);
      expect(feedbackFake().hasToastAction, isTrue);
      expect(feedbackFake().sheets, isEmpty);

      // Oturum akışı yeni üyeliği getirir.
      setSession(
        tester,
        sessionWith(
          membershipsFake().memberships[FirestoreIds.membership(
            kClubId,
            kUser.uid,
          )],
        ),
      );
      await tester.pumpAndSettle();
      final l10n = tester.l10n;
      expect(find.text(l10n.applicationApprovedNote), findsOneWidget);
      expect(find.byKey(_reapply), findsNothing);
    });
  });

  group('CLB-05 · Başvuru durumu · canlı üyelik', () {
    testWidgets('yönetici karar verince ekran evre değiştirir', (tester) async {
      await pumpClubRoute(tester, _location, membership: kPending);
      final l10n = tester.l10n;
      expect(find.byKey(_cancel), findsOneWidget);

      setSession(
        tester,
        sessionWith(rejectedMembership(retryAfter: kRetryAfter)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_cancel), findsNothing);
      expect(find.byType(GuInput), findsNothing);
      expect(find.byKey(_reapply), findsOneWidget);
      expect(find.text(l10n.rejectReasonQuota), findsOneWidget);

      setSession(tester, sessionWith(membershipWith(MembershipStatus.active)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.applicationApprovedNote), findsOneWidget);
      expect(find.byKey(_reapply), findsNothing);
    });
  });

  group('CLB-05 · Başvuru durumu · golden', () {
    testWidgets('golden: beklemede (açık + koyu, TR + EN)', (tester) async {
      await goldenForThemes(
        tester,
        'CLB-05',
        _view,
        locales: DeviceMatrix.locales,
        overrides: stateOverride(kPendingState),
      );
    });

    for (final (name, state) in [
      ('CLB-05__rejected', kRejectedWaitingState),
      ('CLB-05__approved', kApprovedState),
      ('CLB-05__none', kNoneState),
      ('CLB-05__loading', kLoadingState),
      ('CLB-05__error', kErrorState),
    ]) {
      testWidgets('golden: $name', (tester) async {
        await goldenForThemes(
          tester,
          name,
          _view,
          overrides: stateOverride(state),
        );
      });
    }
  });
}
