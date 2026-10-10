// T-04 · GuAvatar (widget-catalog #46; CD-94, K-55, K-57).
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/design_sources.dart';
import '../../helpers/pump_app.dart';

/// Tek karelik sahte görsel sağlayıcı: [image] verilirse hemen o kare,
/// verilmezse yükleme hatası.
class _FakeImage extends ImageProvider<_FakeImage> {
  _FakeImage([this.image]);

  final ui.Image? image;

  @override
  Future<_FakeImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_FakeImage>(this);

  @override
  ImageStreamCompleter loadImage(_FakeImage key, ImageDecoderCallback decode) {
    final frame = image;
    return OneFrameImageStreamCompleter(
      frame == null
          ? Future<ImageInfo>.error(StateError('yüklenemedi'))
          : SynchronousFuture<ImageInfo>(ImageInfo(image: frame.clone())),
    );
  }
}

List<BoxDecoration> _decorations(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(GuAvatar),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((box) => box.decoration as BoxDecoration)
    .toList();

Text _text(WidgetTester tester) => tester.widget<Text>(
  find.descendant(of: find.byType(GuAvatar), matching: find.byType(Text)),
);

void main() {
  group('T-04 · GuAvatar', () {
    testWidgets('T-04 · GuAvatar · tohum → 135° HSL gradyan (art.js:41), baş '
        'harf size × 0.4, tüm boyutlar, halka', (tester) async {
      // Kaynak: hue = hashStr('av:' + seed) % 360, hue2 = hue + 36.
      final art = prototypeJs('art.js');
      expect(art, contains("hashStr('av:' + seed)"));
      expect(art, contains(r'`hsl(${hue} 48% 42%)`, `hsl(${hue2} 55% 32%)`'));
      expect(art, contains('linear-gradient(135deg'));
      expect(GuAvatar.hueFor('u001'), 94);
      expect(GuAvatar.hueFor('u_ayse'), 42);
      final gradient = GuAvatar.gradientFor('u001');
      expect(gradient.begin, Alignment.topLeft);
      expect(gradient.end, Alignment.bottomRight);
      // hsl(94 48% 42%) = rgb(100 159 56); hsl(130 55% 32%) = rgb(37 126 52).
      expect(gradient.colors.map((color) => color.toARGB32()), [
        0xFF649F38,
        0xFF257E34,
      ]);
      // Ton çemberi sarar: 335 + 36 → 11 (`(hue + 36) % 360`).
      expect(GuAvatar.hueFor('u051'), 335);
      expect(
        GuAvatar.gradientFor('u051').colors.map((color) => color.toARGB32()),
        [0xFF9F3863, 0xFF7E3525],
      );
      // Kararlı: aynı tohum → aynı gradyan; farklı tohum → farklı.
      expect(GuAvatar.gradientFor('u_ayse'), GuAvatar.gradientFor('u_ayse'));
      expect(
        GuAvatar.gradientFor('u_ayse'),
        isNot(GuAvatar.gradientFor('u_long')),
      );

      // Varsayılan 40: daire + gradyan, baş harf 16 px #fff, ölçeklenmez.
      await tester.pumpApp(
        const Center(
          child: GuAvatar(initials: 'AD', seed: 'u001'),
        ),
      );
      expect(tester.getSize(find.byType(GuAvatar)), const Size.square(40));
      var boxes = _decorations(tester);
      expect(boxes, hasLength(1));
      expect(boxes.single.shape, BoxShape.circle);
      expect(boxes.single.gradient, gradient);
      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      final expectedFont = <double, double>{
        30: 12,
        32: 13,
        36: 14,
        40: 16,
        44: 18,
        48: 19,
        56: 22,
        96: 38,
        120: 48,
      };
      expect(expectedFont.keys, orderedEquals(GuSizes.avatarSizes));
      for (final size in GuSizes.avatarSizes) {
        await tester.pumpApp(
          Center(
            child: GuAvatar(initials: 'AD', seed: 'u001', size: size),
          ),
          theme: ThemeMode.dark,
        );
        expect(tester.getSize(find.byType(GuAvatar)), Size.square(size));
        final text = _text(tester);
        expect(text.data, 'AD');
        expect(text.textScaler, TextScaler.noScaling);
        expect(
          text.style,
          GuTypography.resolve(GuColors.dark)
              .avatarInitialsFor(size)
              .copyWith(color: GuComponentColors.dark.avatarInitials),
        );
        expect(text.style!.fontSize, expectedFont[size]);
        expect(
          text.style!.letterSpacing,
          closeTo(expectedFont[size]! * 0.02, 1e-9),
        );
        expect(text.style!.color!.toARGB32(), parseCssColor('#fff'));
      }

      // Halka (`.avatar-group .avatar`, border-box): dış 28, gradyan dairesi
      // 24, baş harf dış ölçüden (round(28 × 0.4) = 11).
      await tester.pumpApp(
        const Center(
          child: GuAvatar(initials: 'BŞ', seed: 'u002', size: 28, ring: true),
        ),
      );
      expect(tester.getSize(find.byType(GuAvatar)), const Size.square(28));
      boxes = _decorations(tester);
      expect(boxes, hasLength(2));
      expect(boxes.first.color, GuColors.light.bgSurface);
      expect(boxes.first.shape, BoxShape.circle);
      expect(boxes.last.gradient, GuAvatar.gradientFor('u002'));
      expect(tester.getSize(find.byType(ClipOval)), const Size.square(24));
      expect(_text(tester).style!.fontSize, 11);
    });

    testWidgets('T-04 · GuAvatar · görsel baş harf zemininin üstünde (cover); '
        'yükleme hatasında baş harf kalır', (tester) async {
      final frame = (await tester.runAsync(
        () => createTestImage(width: 4, height: 2),
      ))!;
      addTearDown(frame.dispose);

      await tester.pumpApp(
        Center(
          child: GuAvatar(
            initials: 'AD',
            seed: 'u001',
            size: 96,
            image: _FakeImage(frame),
          ),
        ),
      );
      await tester.pump();
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect(image.excludeFromSemantics, isTrue);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(tester.getSize(find.byType(RawImage)), const Size.square(96));
      // Baş harf zemini altta durur (yüklenirken görünen katman).
      expect(find.text('AD'), findsOneWidget);
      expect(_decorations(tester).single.gradient, isNotNull);

      await tester.pumpApp(
        Center(
          child: GuAvatar(initials: 'AD', seed: 'u001', image: _FakeImage()),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(RawImage), findsNothing);
      expect(find.text('AD'), findsOneWidget);
      expect(tester.getSize(find.byType(GuAvatar)), const Size.square(40));
    });

    testWidgets('T-04 · GuAvatar · Semantics (etiketli = görsel, etiketsiz = '
        'dekoratif); 320 dp × 1.6 uzun baş harf taşmaz', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpApp(
        const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GuAvatar(
                key: ValueKey<String>('labelled'),
                initials: 'AD',
                seed: 'u001',
                semanticLabel: 'Ayşe Demir',
              ),
              GuAvatar(initials: 'MA', seed: 'u_long'),
              GuAvatar(initials: 'ABCDEFGHIJKLMNOP', seed: 'u003', size: 30),
            ],
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSemantics(find.byKey(const ValueKey<String>('labelled'))),
        matchesSemantics(label: 'Ayşe Demir', isImage: true),
      );
      // Etiketsiz avatar dekoratif: baş harf okunmaz (`aria-hidden`).
      expect(find.bySemanticsLabel('MA'), findsNothing);
      expect(find.bySemanticsLabel('AD'), findsNothing);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.textScaler, TextScaler.noScaling);
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.clip);
      }
      expect(tester.getSize(find.byType(GuAvatar).last), const Size.square(30));
      handle.dispose();
    });
  });
}
