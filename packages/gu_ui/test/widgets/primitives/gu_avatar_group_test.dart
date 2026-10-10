// T-04 · GuAvatarGroup (widget-catalog #47; K-47, K-57).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const List<GuAvatarData> _people = [
  GuAvatarData(initials: 'BŞ', seed: 'u101'),
  GuAvatarData(initials: 'DY', seed: 'u102'),
  GuAvatarData(initials: 'EY', seed: 'u103'),
  GuAvatarData(initials: 'EU', seed: 'u104'),
  GuAvatarData(initials: 'ZK', seed: 'u105'),
];

/// "+N" hapının (dıştan içe) `ShapeDecoration` zinciri.
List<ShapeDecoration> _pill(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(GuAvatarGroup),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox && widget.decoration is ShapeDecoration,
        ),
      ),
    )
    .map((box) => box.decoration as ShapeDecoration)
    .toList();

void main() {
  group('T-04 · GuAvatarGroup', () {
    testWidgets('T-04 · GuAvatarGroup · en çok 4 avatar, 8 px bindirme, 2 px '
        'halka, "+N" hapı; boyutlar 24 / 28 / 32 (K-47)', (tester) async {
      // Varsayılan 28 + "+227" (CLB-03): 4 avatar, her biri 20 px adımla.
      await tester.pumpApp(
        const Center(
          child: GuAvatarGroup(avatars: _people, moreLabel: '+227'),
        ),
      );
      final avatars = find.byType(GuAvatar);
      expect(avatars, findsNWidgets(4));
      final origin = tester.getTopLeft(find.byType(GuAvatarGroup));
      for (var i = 0; i < 4; i++) {
        final avatar = tester.widget<GuAvatar>(avatars.at(i));
        expect(avatar.initials, _people[i].initials);
        expect(avatar.seed, _people[i].seed);
        expect(avatar.size, 28);
        expect(avatar.ring, isTrue);
        expect(tester.getSize(avatars.at(i)), const Size.square(28));
        expect(tester.getTopLeft(avatars.at(i)), origin + Offset(i * 20, 0));
      }
      // Hap: son avatara 8 px biner; yükseklik 28, genişlik metin + 2 × 6
      // dolgu + 2 × 2 halka; elips (border-radius:50%).
      final label = find.text('+227');
      final text = tester.widget<Text>(label);
      expect(
        text.style,
        GuTypography.resolve(GuColors.light).avatarMoreFor(28),
      );
      expect(text.style!.fontSize, 11);
      expect(text.style!.color, GuColors.light.textSecondary);
      expect(text.textScaler, TextScaler.noScaling);
      final pill = _pill(tester);
      expect(pill, hasLength(2));
      expect(pill.first.color, GuColors.light.bgSurface);
      expect(pill.first.shape, const OvalBorder());
      expect(pill.last.color, GuColors.light.bgSurfaceMuted);
      expect(pill.last.shape, const OvalBorder());
      final pillWidth = tester.getSize(label).width + 2 * 6 + 2 * 2;
      final group = tester.getSize(find.byType(GuAvatarGroup));
      expect(group.height, 28);
      expect(group.width, closeTo(4 * 20 + pillWidth, 1e-6));

      // Hap yok: son avatar bindirilmez → (n − 1) × 20 + 28.
      await tester.pumpApp(
        Center(child: GuAvatarGroup(avatars: _people.sublist(0, 3))),
        theme: ThemeMode.dark,
      );
      expect(find.byType(GuAvatar), findsNWidgets(3));
      expect(_pill(tester), isEmpty);
      expect(
        tester.getSize(find.byType(GuAvatarGroup)),
        const Size(2 * 20 + 28, 28),
      );

      // 24 (ClubCard, max 3, yazı 10: hap metin + 16) ve 32 (EVT-02, yazı 12:
      // kısa "+N" → en az `size` genişlik, daire).
      await tester.pumpApp(
        const Center(
          child: GuAvatarGroup(
            avatars: _people,
            moreLabel: '+2',
            size: 24,
            max: 3,
          ),
        ),
      );
      expect(find.byType(GuAvatar), findsNWidgets(3));
      expect(tester.widget<Text>(find.text('+2')).style!.fontSize, 10);
      final small = tester.getSize(find.byType(GuAvatarGroup));
      expect(small.height, 24);
      expect(
        small.width,
        closeTo(3 * 16 + tester.getSize(find.text('+2')).width + 16, 1e-6),
      );
      await tester.pumpApp(
        const Center(
          child: GuAvatarGroup(avatars: _people, moreLabel: '+1', size: 32),
        ),
      );
      expect(tester.widget<Text>(find.text('+1')).style!.fontSize, 12);
      expect(
        tester.getSize(find.byType(GuAvatarGroup)),
        const Size(4 * 24 + 32, 32),
      );
    });

    testWidgets('T-04 · GuAvatarGroup · 320 dp × 1.6 uzun "+N" taşmaz, metin '
        'ölçeklenmez; Semantics; küme dışı boyut reddedilir', (tester) async {
      final handle = tester.ensureSemantics();
      final long = '+${'9' * 80}';
      await tester.pumpApp(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GuAvatarGroup(
                key: ValueKey<String>('plain'),
                avatars: _people,
                moreLabel: '+227',
              ),
              GuAvatarGroup(
                avatars: _people,
                moreLabel: long,
                size: 32,
                semanticLabel: '231 üye',
              ),
            ],
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.textScaler, TextScaler.noScaling);
        expect(text.maxLines, 1);
      }
      expect(
        tester.widget<Text>(find.text(long)).overflow,
        TextOverflow.ellipsis,
      );
      expect(
        tester.getSize(find.byType(GuAvatarGroup).last),
        const Size(320, 32),
      );
      // Etiketsiz grup: avatarlar dekoratif, yalnız "+N" okunur.
      expect(find.bySemanticsLabel('+227'), findsOneWidget);
      expect(find.bySemanticsLabel('BŞ'), findsNothing);
      // Etiketli grup: tek düğüm, içerik dışlanır.
      expect(find.bySemanticsLabel('231 üye'), findsOneWidget);
      expect(find.bySemanticsLabel(long), findsNothing);

      // K-47: boyut kümesi [24, 28, 32].
      await tester.pumpApp(
        const Center(child: GuAvatarGroup(avatars: _people, size: 40)),
      );
      expect(tester.takeException(), isAssertionError);
      handle.dispose();
    });
  });
}
