// FED-02 / SHT-09 · CommentComposer — K-93 (kullanıcı kararı, gerçek cihaz
// turu madde 3 + 4; tasarımdan bilinçli sapma):
// * alan tek satırla başlar, yazdıkça 5 satıra dek büyür, 6+ satırda 5
//   satırda kalır (içinde kayar); sınır ve sayaç değişmez;
// * avatar ve "Gönder" tek satırlık kutu yüksekliğinde ortalı, alta hizalı;
// * "Gönder" klavyeyi kapatmaz; yorum çubuğu dışına dokunmak kapatır.
// Ekran FED-02 durum kipinde çizilir (post_detail_view_test ile aynı düzen).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/feed/provider/post_detail_view_model.dart';
import 'package:gu_kulupler/features/feed/view/post_detail_view.dart';
import 'package:gu_kulupler/features/feed/view/widget/comment_composer.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../helpers/pump_app.dart';
import '../../../../helpers/test_l10n.dart';
import '../../post_detail_test_support.dart';

final Key _input = GuKey.action('FED-02.commentInput');
final Key _send = GuKey.action('FED-02.sendComment');

final PostDetailViewModelProvider _provider = postDetailViewModelProvider(
  clubId: kPostClubId,
  postId: kPostId,
);

Future<void> _pump(WidgetTester tester, {double textScale = 1.0}) async {
  await tester.pumpApp(
    const PostDetailView(clubId: kPostClubId, postId: kPostId),
    textScale: textScale,
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => postSession(),
      ),
      _provider.overrideWithBuild((ref, notifier) => loadedPostState()),
    ],
  );
  await tester.pump();
}

Finder get _composer => find.byType(CommentComposer);

/// Yorum alanının `.input` kutusu.
Finder get _box => find
    .descendant(
      of: find.descendant(of: _composer, matching: find.byType(GuInput)),
      matching: find.byType(AnimatedContainer),
    )
    .first;

FocusNode _focus(WidgetTester tester) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(_input),
        matching: find.byType(EditableText),
      ),
    )
    .focusNode;

double _lineHeight(WidgetTester tester) => tester
    .state<EditableTextState>(
      find.descendant(
        of: find.byKey(_input),
        matching: find.byType(EditableText),
      ),
    )
    .renderEditable
    .preferredLineHeight;

const double _chrome =
    (GuSizes.inputMultilinePaddingY + GuSizes.inputBorder) * 2;

String _lines(int count) =>
    List<String>.generate(count, (i) => 'Yorum satırı ${i + 1}').join('\n');

void main() {
  group('K-93 · FED-02 · yorum alanı', () {
    for (final scale in [1.0, 1.6]) {
      testWidgets('ölçek $scale: tek satırla başlar, 5 satıra dek büyür, 6+ '
          'satırda 5 satır yüksekliğinde kalır; avatar ve Gönder tek satırlık '
          'kutuda ortalı, alta hizalı', (tester) async {
        await _pump(tester, textScale: scale);
        final input = tester.widget<GuInput>(
          find.descendant(of: _composer, matching: find.byType(GuInput)),
        );
        expect(input.multiline, isTrue);
        expect(input.rows, 1);
        expect(input.maxRows, GuSizes.commentMaxRows);
        expect(input.maxLength, Limits.commentMax);
        expect(input.showCounter, isTrue);

        final line = _lineHeight(tester);
        final single = GuInput.growingLineBoxHeight(tester.element(_composer));
        expect(
          single,
          moreOrLessEquals(
            line + _chrome < GuSizes.inputHeight
                ? GuSizes.inputHeight
                : line + _chrome,
            epsilon: 0.01,
          ),
        );
        double boxHeight() => tester.getSize(_box).height;
        final avatar = find.descendant(
          of: _composer,
          matching: find.byType(GuAvatar),
        );

        void expectAligned() {
          final box = tester.getRect(_box);
          // Son satırın bandının ortası = kutunun altından yarım tek satır.
          final band = box.bottom - single / 2;
          expect(tester.getCenter(avatar).dy, moreOrLessEquals(band));
          expect(
            tester.getCenter(find.byKey(_send)).dy,
            moreOrLessEquals(band),
          );
        }

        // Boş: tek satır (tasarımdaki 4 satır / 88 değil).
        expect(boxHeight(), moreOrLessEquals(single, epsilon: 0.01));
        expectAligned();

        await tester.enterText(find.byKey(_input), _lines(3));
        await tester.pump();
        expect(
          boxHeight(),
          moreOrLessEquals(line * 3 + _chrome, epsilon: 0.01),
        );
        expectAligned();

        await tester.enterText(
          find.byKey(_input),
          _lines(GuSizes.commentMaxRows),
        );
        await tester.pump();
        final five = boxHeight();
        expect(five, moreOrLessEquals(line * 5 + _chrome, epsilon: 0.01));

        await tester.enterText(find.byKey(_input), _lines(8));
        await tester.pump();
        expect(boxHeight(), moreOrLessEquals(five, epsilon: 0.01));
        expectAligned();
        final scrollable = tester.state<ScrollableState>(
          find.descendant(
            of: find.byKey(_input),
            matching: find.byType(Scrollable),
          ),
        );
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Gönder klavyeyi kapatmaz; yorum çubuğu dışına dokunmak '
        'kapatır', (tester) async {
      await _pump(tester);
      final header = tester.l10n.postComments(kPostComments.length);
      await tester.tap(find.byKey(_input));
      await tester.pump();
      expect(_focus(tester).hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      // Boşken kapalı "Gönder" de klavyeyi kapatmaz.
      await tester.tap(find.byKey(_send));
      await tester.pump();
      expect(_focus(tester).hasFocus, isTrue);

      await tester.enterText(find.byKey(_input), 'Ben de katılıyorum!');
      await tester.pump();
      await tester.tap(find.byKey(_send));
      await tester.pumpAndSettle();
      expect(_focus(tester).hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);

      // Avatar yorum çubuğunun parçası.
      await tester.tap(
        find.descendant(of: _composer, matching: find.byType(GuAvatar)),
      );
      await tester.pump();
      expect(_focus(tester).hasFocus, isTrue);

      // Yorum listesi (çubuk dışı) → odak kalkar, klavye kapanır.
      await tester.tap(find.text(header));
      await tester.pump();
      expect(_focus(tester).hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
    });
  });
}
