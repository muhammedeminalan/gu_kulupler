// T-23 · EventCard galerisi (widget-catalog P9) — etkinlik kartı: tarih
// rozeti, kapak (kompakt değilse), başlık + durum rozeti, kulüp satırı, saat ·
// mekân, kontenjan çubuğu / "Sınırsız", hızlı eylem (`EventCta(sm)`),
// çağıranın verdiği anahtarlar, dokunmalar, erişilebilirlik, 320 dp × 1.6,
// cihaz matrisi ve galeri golden'ı. Kaynak: prototip `cards.js:48–80`.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/product/widget/event/event_card.dart';
import 'package:gu_kulupler/product/widget/event/event_card_status.dart';
import 'package:gu_kulupler/product/widget/event/event_cta.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/register_fakes.dart';
import '../../../fixtures/club_model_fixtures.dart';
import '../../../fixtures/event_model_fixtures.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/fake_app_clock.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/overflow_detector.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

const Locale _tr = Locale('tr');

final ClubModel _club = ClubModelFixtures.c01;

/// `e01` — c01, herkese açık, 40 kontenjan, `pl04`.
final EventModel _event = EventModelFixtures.e01;

final EventModel _unlimited = _event.copyWith(clearCapacity: true);

final EventModel _longTitle = _event.copyWith(
  title:
      'Uluslararası Öğrenci Değişim Programları ve Kültürlerarası İletişim '
      'Üzerine Uzun Başlıklı Bir Söyleşi Dizisi',
);

final Key _cardKey = GuKey.action('EVT-01.card.${_event.id}');
final Key _clubKey = GuKey.action('EVT-01.club.${_event.id}');
final Key _joinKey = GuKey.action('EVT-01.join.${_event.id}');

final class _Taps {
  int open = 0;
  int club = 0;
  int quick = 0;
}

EventCard _card({
  EventModel? event,
  ClubModel? club,
  bool noClub = false,
  EventCardStatus? status,
  int registered = 36,
  EventCtaKind? quick = EventCtaKind.join,
  bool compact = false,
  bool showClub = true,
  bool keyed = true,
  _Taps? taps,
}) => EventCard(
  event: event ?? _event,
  club: noClub ? null : club ?? _club,
  status: status,
  registeredCount: registered,
  compact: compact,
  showClub: showClub,
  quickAction: quick == null
      ? null
      : EventQuickAction(
          kind: quick,
          onPressed: () => taps?.quick++,
          actionKey: keyed ? _joinKey : null,
        ),
  actionKey: keyed ? _cardKey : null,
  clubKey: keyed ? _clubKey : null,
  onOpen: () => taps?.open++,
  onClub: () => taps?.club++,
);

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) => tester.pumpApp(
  Scaffold(
    body: SingleChildScrollView(
      padding: GuInsets.all16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [card],
      ),
    ),
  ),
  size: size,
  textScale: textScale,
);

/// Galeri: varsayılan · dolu (kompakt) · kayıtlı · iptal · sınırsız · uzun
/// başlık + üyelere özel.
Widget _gallery(BuildContext context) => Scaffold(
  backgroundColor: context.gu.colors.bgCanvas,
  body: SafeArea(
    child: SingleChildScrollView(
      padding: GuInsets.all16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s12,
        children: [
          _card(keyed: false),
          _card(
            event: EventModelFixtures.e03,
            club: ClubModelFixtures.byId('c03'),
            status: EventCardStatus.full,
            registered: 30,
            quick: EventCtaKind.joinWaitlist,
            compact: true,
            keyed: false,
          ),
          _card(
            status: EventCardStatus.going,
            registered: 39,
            quick: EventCtaKind.ticket,
            keyed: false,
          ),
          _card(
            event: EventModelFixtures.e21,
            club: ClubModelFixtures.byId('c07'),
            status: EventCardStatus.cancelled,
            registered: 12,
            quick: null,
            keyed: false,
          ),
          _card(event: _unlimited, quick: EventCtaKind.closed, keyed: false),
          _card(
            event: _longTitle,
            status: EventCardStatus.members,
            quick: EventCtaKind.applyClub,
            compact: true,
            showClub: false,
            keyed: false,
          ),
        ],
      ),
    ),
  ),
);

void main() {
  group('T-23 · EventCard · içerik', () {
    testWidgets('varsayılan: tarih rozeti (Istanbul günü + büyük harf ay), '
        'kapak, başlık, kulüp, saat · mekân, kontenjan, "Katıl"', (
      tester,
    ) async {
      await _pump(tester, _card());
      final l10n = tester.l10nFor(_tr);
      final local = AppDateFormats.toIstanbul(_event.startsAt);

      final badge = tester.widget<GuDateBadge>(find.byType(GuDateBadge));
      expect(badge.day, local.day);
      expect(badge.monthShort, badge.monthShort.toUpperCase());
      expect(find.byType(GuCover), findsOneWidget);
      expect(find.text(_event.title), findsOneWidget);
      expect(find.text(_club.name), findsOneWidget);
      expect(find.text(l10n.placePl04), findsOneWidget);
      final formats = AppDateFormats(_tr, FakeAppClock(kDefaultFakeNowUtc));
      expect(find.text('${formats.time(_event.startsAt)} · '), findsOneWidget);
      expect(find.text('36/${_event.capacity}'), findsOneWidget);
      expect(find.byType(GuProgress), findsOneWidget);
      expect(find.text(l10n.eventCtaJoin), findsOneWidget);
      expect(find.byType(GuStatusBadge), findsNothing);
    });

    testWidgets('kompakt: kapak yok; showClub false / kulüp yok → kulüp '
        'satırı yok; düğme yok', (tester) async {
      await _pump(tester, _card(compact: true, showClub: false, quick: null));
      expect(find.byType(GuCover), findsNothing);
      expect(find.text(_club.name), findsNothing);
      expect(find.byType(GuButton), findsNothing);

      await _pump(tester, _card(noClub: true));
      expect(find.byKey(_clubKey), findsNothing);
      expect(find.byType(GuCover), findsOneWidget);
    });

    testWidgets('kontenjansız: "Sınırsız · N kayıtlı", çubuk yok', (
      tester,
    ) async {
      await _pump(tester, _card(event: _unlimited, registered: 7));
      final l10n = tester.l10nFor(_tr);
      expect(
        find.text('${l10n.eventUnlimited} · ${l10n.eventRegisteredCount(7)}'),
        findsOneWidget,
      );
      expect(find.byType(GuProgress), findsNothing);
    });

    testWidgets('mekân yoksa "Yer belirlenecek"', (tester) async {
      await _pump(
        tester,
        _card(event: _event.copyWith(clearPlaceId: true, clearPlaceText: true)),
      );
      expect(find.text(tester.l10nFor(_tr).eventPlaceTbd), findsOneWidget);
    });

    testWidgets('her durum kendi rozetini çizer', (tester) async {
      final l10n = tester.l10nFor(_tr);
      for (final status in EventCardStatus.values) {
        await _pump(tester, _card(status: status, quick: null));
        final badge = tester.widget<GuStatusBadge>(find.byType(GuStatusBadge));
        expect(badge.kind, EventCard.badgeKindOf(status), reason: '$status');
        expect(badge.label, EventCard.badgeLabelOf(l10n, status));
      }
    });

    test('kontenjan rengi: dolu → soluk, %85 üstü → uyarı, değilse marka', () {
      expect(EventCard.capacityKindOf(40, 40), GuProgressKind.muted);
      expect(EventCard.capacityKindOf(41, 40), GuProgressKind.muted);
      expect(EventCard.capacityKindOf(35, 40), GuProgressKind.warning);
      expect(EventCard.capacityKindOf(34, 40), GuProgressKind.brand);
      expect(EventCard.capacityKindOf(0, 0), GuProgressKind.muted);
    });

    testWidgets('hızlı eylem: kart türüne göre varyant / ikon '
        '(cards.js:60–66); "Kayıtlar kapalı" devre dışı ama dokunma iletilir', (
      tester,
    ) async {
      const expected = {
        EventCtaKind.ticket: (GuButtonVariant.tonal, GuIcons.ticket),
        EventCtaKind.applyClub: (GuButtonVariant.outline, GuIcons.lock),
        EventCtaKind.waitlist: (GuButtonVariant.tonal, GuIcons.hourglass),
        EventCtaKind.joinWaitlist: (GuButtonVariant.outline, null),
        EventCtaKind.closed: (GuButtonVariant.outline, null),
        EventCtaKind.join: (GuButtonVariant.primary, null),
      };
      for (final MapEntry(key: kind, value: (variant, icon))
          in expected.entries) {
        final taps = _Taps();
        await _pump(tester, _card(quick: kind, taps: taps));
        final button = tester.widget<GuButton>(find.byKey(_joinKey));
        expect(button.variant, variant, reason: '$kind');
        expect(button.icon, icon, reason: '$kind');
        expect(button.size, GuButtonSize.sm);
        await tester.tap(find.byKey(_joinKey));
        await tester.pump();
        expect(taps.quick, 1, reason: '$kind');
        expect(taps.open, 0, reason: '$kind');
      }
    });
  });

  group('T-23 · EventCard · etkileşim', () {
    testWidgets('kart → onOpen, kulüp → onClub (kart açılmaz)', (tester) async {
      final taps = _Taps();
      await _pump(tester, _card(taps: taps));
      await tester.tap(find.byKey(_cardKey));
      await tester.pump();
      expect(taps.open, 1);
      await tester.tap(find.byKey(_clubKey));
      await tester.pump();
      expect(taps.club, 1);
      expect(taps.open, 1);
    });

    testWidgets('erişilebilirlik: kart başlık + tarih + saat okunan tek '
        'düğmedir; kulüp ve "Katıl" ayrı düğmelerdir', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _card(status: EventCardStatus.full));
      final l10n = tester.l10nFor(_tr);
      final data = tester.getSemantics(find.byKey(_cardKey)).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, contains(_event.title));
      expect(data.label, contains(l10n.statusFull));
      expect(data.label, contains(l10n.placePl04));
      expect(data.label, isNot(contains(l10n.eventCtaJoin)));
      expect(
        tester.getSemantics(find.byKey(_clubKey)),
        isSemantics(label: _club.name, isButton: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.byKey(_joinKey)),
        isSemantics(
          label: l10n.eventCtaJoin,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  group('T-23 · EventCard · yerleşim', () {
    testWidgets('uzun başlık iki satırda kesilir; 320 dp × 1.6 rozet + düğme '
        'taşmaz', (tester) async {
      OverflowDetector.install();
      addTearDown(OverflowDetector.reset);
      for (final compact in [false, true]) {
        OverflowDetector.reset();
        await _pump(
          tester,
          _card(
            event: _longTitle,
            status: EventCardStatus.waitlist,
            quick: EventCtaKind.joinWaitlist,
            compact: compact,
          ),
          size: const Size(320, 844),
          textScale: 1.6,
        );
        final title = tester.widget<Text>(find.text(_longTitle.title));
        expect(title.maxLines, 2);
        expect(title.overflow, TextOverflow.ellipsis);
        OverflowDetector.assertNone('320 × 1.6 compact=$compact');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('cihaz matrisi: galeri taşmaz', (tester) async {
      await DeviceMatrix.run(tester, _gallery);
    });

    testWidgets('golden: galeri — açık + koyu (TR)', (tester) async {
      await goldenForThemes(
        tester,
        'event_card',
        const Builder(builder: _gallery),
        size: const Size(390, 1250),
      );
    });
  });
}
