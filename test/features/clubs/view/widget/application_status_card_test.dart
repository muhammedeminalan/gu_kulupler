// ApplicationStatusCard (CLB-05 üst bloğu; widget-catalog F3): evre → rozet
// ve zaman çizelgesi tablosu, kart içeriği (amblem, ad, kategori), dokunma,
// semantik etiket, bilinmeyen ikon yedeği, TR / EN tarih biçimi.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_state.dart';
import 'package:gu_kulupler/features/clubs/view/widget/application_status_card.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_l10n.dart';
import '../club_application_test_support.dart';

final Key _openClub = GuKey.action('CLB-05.openClub');

Future<void> _pump(
  WidgetTester tester, {
  required ApplicationPhase phase,
  MembershipModel? membership,
  ClubModel? club,
  VoidCallback? onOpenClub,
  Locale locale = const Locale('tr'),
}) => tester.pumpApp(
  Scaffold(
    body: SingleChildScrollView(
      child: ApplicationStatusCard(
        club: club ?? kClub,
        phase: phase,
        membership: membership,
        onOpenClub: onOpenClub ?? () {},
      ),
    ),
  ),
  locale: locale,
);

List<GuTimelineItem> _steps(WidgetTester tester) =>
    tester.widget<GuTimeline>(find.byType(GuTimeline)).items;

void main() {
  setUpAll(initDateFormats);

  group('CLB-05 · ApplicationStatusCard', () {
    testWidgets('kart: amblem + ad + kategori; dokununca onOpenClub', (
      tester,
    ) async {
      var opened = 0;
      await _pump(
        tester,
        phase: ApplicationPhase.pending,
        membership: kPending,
        onOpenClub: () => opened++,
      );
      final l10n = tester.l10n;

      final card = tester.widget<GuCard>(find.byKey(_openClub));
      expect(card.semanticLabel, kClub.name);
      expect(card.padding, GuInsets.h16v12);
      expect(find.bySemanticsLabel(kClub.name), findsOneWidget);
      expect(
        tester.widget<GuEmblem>(find.byType(GuEmblem)).icon,
        GuIcons.music,
      );
      expect(find.text(kClub.name), findsOneWidget);
      expect(find.text(l10n.catK04), findsOneWidget);

      await tester.tap(find.byKey(_openClub));
      await tester.pumpAndSettle();
      expect(opened, 1);

      // Kart ile zaman çizelgesi arası 20.
      final cardRect = tester.getRect(find.byKey(_openClub));
      final timeline = tester.getRect(find.byType(GuTimeline));
      expect(timeline.top, cardRect.bottom + 20);
    });

    testWidgets('kayıtta olmayan ikon adı: amblem yedek ikonla çizilir', (
      tester,
    ) async {
      await _pump(
        tester,
        phase: ApplicationPhase.pending,
        membership: kPending,
        club: kClub.copyWith(iconName: 'bilinmeyen-ikon'),
      );
      expect(
        tester.widget<GuEmblem>(find.byType(GuEmblem)).icon,
        GuIcons.users,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('evre tablosu: rozet, nokta durumları ve açıklamalar', (
      tester,
    ) async {
      final decided = membershipWith(MembershipStatus.active);
      const done = GuTimelineDotState.done;
      const active = GuTimelineDotState.active;
      const pending = GuTimelineDotState.pending;
      const danger = GuTimelineDotState.danger;

      for (final (phase, membership, kind, dots) in [
        (
          ApplicationPhase.pending,
          kPending,
          GuStatusBadgeKind.pending,
          [done, active, pending],
        ),
        (
          ApplicationPhase.approved,
          decided,
          GuStatusBadgeKind.approved,
          [done, done, done],
        ),
        (
          ApplicationPhase.rejected,
          rejectedMembership(),
          GuStatusBadgeKind.rejected,
          [done, done, danger],
        ),
        (
          ApplicationPhase.removed,
          rejectedMembership(status: MembershipStatus.removed),
          GuStatusBadgeKind.removed,
          [done, done, danger],
        ),
        (
          ApplicationPhase.none,
          membershipWith(MembershipStatus.cancelled),
          GuStatusBadgeKind.cancelled,
          [done, done, pending],
        ),
      ]) {
        await _pump(tester, phase: phase, membership: membership);
        final l10n = tester.l10n;
        final reason = phase.name;

        final badge = tester.widget<GuStatusBadge>(find.byType(GuStatusBadge));
        expect(badge.kind, kind, reason: reason);
        expect(
          badge.label,
          switch (phase) {
            ApplicationPhase.pending => l10n.statusPending,
            ApplicationPhase.approved => l10n.statusApproved,
            ApplicationPhase.rejected => l10n.statusRejected,
            ApplicationPhase.removed => l10n.statusRemoved,
            ApplicationPhase.none => l10n.statusCancelled,
          },
          reason: reason,
        );

        final steps = _steps(tester);
        expect(steps.map((step) => step.state), dots, reason: reason);
        expect(steps.map((step) => step.title), [
          l10n.applicationStepSent,
          l10n.applicationStepReview,
          l10n.applicationStepResult,
        ], reason: reason);
        expect(
          steps[2].caption,
          switch (phase) {
            ApplicationPhase.approved => l10n.statusApproved,
            ApplicationPhase.rejected => l10n.statusRejected,
            ApplicationPhase.removed => l10n.statusRemoved,
            ApplicationPhase.pending ||
            ApplicationPhase.none => l10n.applicationWaitingResult,
          },
          reason: reason,
        );
        // "Başvuru yok" evresinde adımlar tarih taşımaz.
        expect(
          steps[0].caption,
          phase == ApplicationPhase.none ? isNull : '6 Eki Sal, 19:08',
          reason: reason,
        );
        expect(
          steps[1].caption,
          switch (phase) {
            ApplicationPhase.pending => l10n.applicationReviewing,
            ApplicationPhase.none => isNull,
            ApplicationPhase.approved ||
            ApplicationPhase.rejected ||
            ApplicationPhase.removed => isNotNull,
          },
          reason: reason,
        );
      }
    });

    testWidgets('üyelik yok / karar anı yok: adımlar tarihsiz çizilir', (
      tester,
    ) async {
      await _pump(tester, phase: ApplicationPhase.none);
      expect(_steps(tester).map((step) => step.caption), [
        null,
        null,
        tester.l10n.applicationWaitingResult,
      ]);

      await _pump(
        tester,
        phase: ApplicationPhase.approved,
        membership: kPending.copyWith(status: MembershipStatus.active),
      );
      expect(_steps(tester)[1].caption, isNull);
    });

    testWidgets('EN: etiketler ve tarih İngilizce biçimde', (tester) async {
      await _pump(
        tester,
        phase: ApplicationPhase.pending,
        membership: kPending,
        locale: const Locale('en'),
      );
      final l10n = tester.l10n;
      expect(find.text(l10n.catK04), findsOneWidget);
      expect(find.text(l10n.statusPending), findsOneWidget);
      expect(_steps(tester)[0].caption, 'Tue 6 Oct, 19:08');
      expect(_steps(tester)[1].caption, l10n.applicationReviewing);
    });
  });
}
