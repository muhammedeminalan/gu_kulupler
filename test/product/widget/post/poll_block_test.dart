// T-20 · PollBlock (widget-catalog P13) — anket bloğu: oy öncesi (sonuç
// gizli / "oy vermeden sonuç göster"), oy verilmiş (kendi oyu işareti, dolum,
// yüzde — TR `%37`, EN `37%`), süresi bitmiş, üst yazımlar (`ended`,
// `showResults`, `remainingLabel`), toplam oy + kalan süre satırı, anahtarlar,
// erişilebilirlik, dar ekran + büyük metin. Kaynak: prototip `cards.js:83–91`,
// css:328–330.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/widget/post/poll_block.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../helpers/device_matrix.dart';
import '../../../helpers/test_l10n.dart';
import 'post_test_support.dart';

Key _optionKey(String optionId) =>
    GuKey.action('FED-01.vote.${kPollPost.id}.$optionId');

/// Seçenek kutusunun kenarlık rengi.
Color _borderOf(WidgetTester tester, String optionId) {
  final box = tester.widget<DecoratedBox>(
    find
        .descendant(
          of: find.byKey(_optionKey(optionId)),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return ((box.decoration as BoxDecoration).border! as Border).top.color;
}

List<double?> _fills(WidgetTester tester) => [
  for (final fill in tester.widgetList<AnimatedFractionallySizedBox>(
    find.byType(AnimatedFractionallySizedBox),
  ))
    fill.widthFactor,
];

void main() {
  group('T-20 · PollBlock · durumlar', () {
    testWidgets('oy öncesi, sonuç oydan sonra: düz seçenekler — dolum, yüzde '
        've işaret yok; "41 oy · 4 gün kaldı"; dokunma seçenek kimliğini '
        'verir', (tester) async {
      final votes = <String>[];
      await pumpPost(
        tester,
        PollBlock(
          poll: kPoll,
          results: kPollResults,
          onVote: votes.add,
          optionKey: _optionKey,
        ),
      );
      final l10n = tester.l10n;
      final gu = tester.element(find.byType(PollBlock)).gu;

      for (final option in kPoll.options) {
        expect(find.text(option.text), findsOneWidget);
        expect(_borderOf(tester, option.id), gu.colors.borderDefault);
      }
      expect(find.byType(AnimatedFractionallySizedBox), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is GuIcon && w.icon == GuIcons.circleCheck,
        ),
        findsNothing,
      );
      expect(
        find.text(
          '${l10n.feedPollVotes(41)} · ${l10n.feedPollRemaining('4 gün')}',
        ),
        findsOneWidget,
      );

      // Seçenek kutusu: 10 / 12 dolgu + 1 px kenarlık → 40 yükseklik; aralık 6.
      final first = tester.getRect(find.byKey(_optionKey('o1')));
      final second = tester.getRect(find.byKey(_optionKey('o2')));
      expect(first.height, 40);
      expect(second.top - first.bottom, GuSpacing.s6);

      await tester.tap(find.byKey(_optionKey('o3')));
      expect(votes, ['o3']);
    });

    testWidgets('"oy vermeden sonuç göster": oy yokken de dolum + yüzde — TR '
        '`%24`, EN `24%`', (tester) async {
      final open = PollModel(
        options: kPoll.options,
        endsAt: kPoll.endsAt,
        showResultsAfterVote: false,
      );
      for (final (locale, labels) in [
        (kTr, ['%24', '%22', '%17', '%37']),
        (kEn, ['24%', '22%', '17%', '37%']),
      ]) {
        await pumpPost(
          tester,
          PollBlock(poll: open, results: kPollResults),
          locale: locale,
        );
        for (final label in labels) {
          expect(find.text(label), findsOneWidget);
        }
        expect(_fills(tester), [0.24, 0.22, 0.17, 0.37]);
      }
    });

    testWidgets('oy verilmiş: kendi seçeneği marka kenarlığı + onay işareti; '
        'tüm seçeneklerde dolum + yüzde; seçenekler kilitli okunur ama dokunma '
        'yine bildirilir (TST-10 çağıranda)', (tester) async {
      final handle = tester.ensureSemantics();
      final votes = <String>[];
      await pumpPost(
        tester,
        PollBlock(
          poll: kPoll,
          results: kPollResults,
          myOptionId: 'o4',
          onVote: votes.add,
          optionKey: _optionKey,
        ),
      );
      final gu = tester.element(find.byType(PollBlock)).gu;

      expect(_borderOf(tester, 'o4'), gu.colors.brandPrimary);
      expect(_borderOf(tester, 'o1'), gu.colors.borderDefault);
      final check = tester.widget<GuIcon>(
        find.descendant(
          of: find.byKey(_optionKey('o4')),
          matching: find.byType(GuIcon),
        ),
      );
      expect(check.icon, GuIcons.circleCheck);
      expect(check.size, GuSizes.icon16);
      expect(check.color, gu.colors.brandPrimaryText);
      expect(
        find.descendant(
          of: find.byKey(_optionKey('o1')),
          matching: find.byType(GuIcon),
        ),
        findsNothing,
      );
      expect(_fills(tester), [0.24, 0.22, 0.17, 0.37]);
      final fill = tester.widget<AnimatedFractionallySizedBox>(
        find.byType(AnimatedFractionallySizedBox).first,
      );
      expect(fill.duration, GuMotion.fill);
      expect(fill.curve, GuMotion.easeStandard);
      expect(
        tester
            .widget<ColoredBox>(
              find.descendant(
                of: find.byType(AnimatedFractionallySizedBox).first,
                matching: find.byType(ColoredBox),
              ),
            )
            .color,
        gu.colors.brandPrimaryContainer,
      );

      expect(
        tester.getSemantics(find.text('Eğitim teknolojileri')),
        isSemantics(
          label: 'Eğitim teknolojileri · %37',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byKey(_optionKey('o1')));
      expect(votes, ['o1']);
      handle.dispose();
    });

    testWidgets('süresi bitmiş: sonuçlar + "Anket sona erdi"; `ended`, '
        '`showResults` ve `remainingLabel` saati / kuralı ezer', (
      tester,
    ) async {
      final after = kPoll.endsAt.add(const Duration(minutes: 1));
      await pumpPost(
        tester,
        PollBlock(poll: kPoll, results: kPollResults),
        now: after,
      );
      final l10n = tester.l10n;
      expect(
        find.text('${l10n.feedPollVotes(41)} · ${l10n.feedPollEnded}'),
        findsOneWidget,
      );
      expect(find.text('%37'), findsOneWidget);

      // Bitiş anı kapalı sayılır.
      await pumpPost(tester, PollBlock(poll: kPoll), now: kPoll.endsAt);
      expect(find.textContaining(l10n.feedPollEnded), findsOneWidget);

      await pumpPost(
        tester,
        PollBlock(
          poll: kPoll,
          results: kPollResults,
          ended: false,
          showResults: false,
          remainingLabel: '2 gün',
        ),
        now: after,
      );
      expect(
        find.text(
          '${l10n.feedPollVotes(41)} · ${l10n.feedPollRemaining('2 gün')}',
        ),
        findsOneWidget,
      );
      expect(find.byType(AnimatedFractionallySizedBox), findsNothing);
    });

    testWidgets('oy yokken yüzdeler 0; anketin seçeneği olmayan anahtar '
        'sayılmaz', (tester) async {
      await pumpPost(tester, PollBlock(poll: kPoll, myOptionId: 'o1'));
      expect(find.text('%0'), findsNWidgets(4));
      expect(find.textContaining(tester.l10n.feedPollVotes(0)), findsOneWidget);

      final block = PollBlock(
        poll: PollModel(
          options: const [
            PollOptionModel(id: 'o1', text: 'A'),
            PollOptionModel(id: 'o2', text: 'B'),
          ],
          endsAt: kPoll.endsAt,
        ),
        results: const {'o1': 1, 'o2': 2, 'yabancı': 97},
      );
      expect(block.totalVotes, 3);
      expect(block.percentOf('o1'), 33);
      expect(block.percentOf('o2'), 67);
      expect(block.percentOf('yok'), 0);
    });
  });

  group('T-20 · PollBlock · taşma', () {
    testWidgets('cihaz matrisi: uzun seçenek metinleri + yüzde taşmaz (320 dp, '
        'ölçek 1.6, TR / EN)', (tester) async {
      final long = PollModel(
        options: [
          for (final option in kPoll.options)
            PollOptionModel(
              id: option.id,
              text:
                  'Sürdürülebilirlik ve eğitim teknolojileri üzerine '
                  'disiplinlerarası',
            ),
        ],
        endsAt: kPoll.endsAt,
      );
      await DeviceMatrix.run(
        tester,
        (_) => Scaffold(
          body: SingleChildScrollView(
            padding: GuInsets.all16,
            child: PollBlock(
              poll: long,
              results: kPollResults,
              myOptionId: 'o2',
              onVote: (_) {},
            ),
          ),
        ),
        overrides: [clockAt(kPostNow)],
      );
    });
  });
}
