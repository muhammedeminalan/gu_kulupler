// T-18 · UserRow (widget-catalog P1) — kişi satırı: avatar + ad (+ rozet) +
// alt satır + sondaki öğe; silinmiş kullanıcı, belgesiz (`named`) biçim, kart
// içi biçim, uzun adın kesilmesi / rozetin alt satıra inmesi, çağıranın
// verdiği anahtar, dokunma ve erişilebilirlik. Kaynak: prototip
// `ui.js:129–132`. Galeri golden'ı `member_row_test.dart`'tadır.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/overflow_detector.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

/// Demo `u_burak` — Burak Şahin.
final UserModel _user = UserModelFixtures.byId('u_burak');

const String _sub = 'Bilgisayar Mühendisliği · 4. sınıf';
const String _longName =
    'Doç. Dr. Abdurrahman Gazi Kahramanmaraşlıoğlu Yıldırımtürk';

final Key _rowKey = GuKey.action('SHT-25.select.${_user.uid}');

const GuRoleBadge _badge = GuRoleBadge(
  kind: GuRoleBadgeKind.board,
  label: 'Yönetim Kurulu',
);

Future<void> _pump(
  WidgetTester tester,
  Widget row, {
  Locale locale = _tr,
  Size size = const Size(390, 844),
  double textScale = 1,
}) => tester.pumpApp(
  Scaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [row],
    ),
  ),
  locale: locale,
  size: size,
  textScale: textScale,
);

GuTile _tile(WidgetTester tester) => tester.widget<GuTile>(find.byType(GuTile));

GuAvatar _avatar(WidgetTester tester) =>
    tester.widget<GuAvatar>(find.byType(GuAvatar));

void main() {
  group('T-18 · UserRow · içerik', () {
    testWidgets('kullanıcı: avatar 40 (baş harf + tohum), ad tek satır, alt '
        'satır; satır `GuTile` ile aynı yükseklikte (en az 56)', (
      tester,
    ) async {
      await _pump(tester, UserRow(user: _user, sub: _sub));

      expect(find.text(_user.name), findsOneWidget);
      final name = tester.widget<Text>(find.text(_user.name));
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);
      final gu = tester.element(find.byType(UserRow)).gu;
      expect(
        DefaultTextStyle.of(tester.element(find.text(_user.name))).style,
        gu.text.bodyM.copyWith(color: gu.colors.textHeading),
      );

      final tile = _tile(tester);
      expect(tile.subtitle, _sub);
      expect(tile.padding, GuTilePadding.normal);
      expect(tile.chevron, isFalse);
      expect(tile.onTap, isNull);
      expect(tile.key, isNull);
      expect(_avatar(tester).initials, 'BŞ');
      expect(_avatar(tester).seed, _user.avatarSeed);
      expect(_avatar(tester).size, GuSizes.avatar);
      final height = tester.getSize(find.byType(UserRow)).height;

      // Aynı içerikli düz `GuTile` ile aynı ölçü: widget başlık satır
      // yüksekliğini değiştirmez.
      await _pump(
        tester,
        GuTile(
          title: _user.name,
          subtitle: _sub,
          leading: const GuAvatar(initials: 'BŞ', seed: 'x'),
        ),
      );
      expect(tester.getSize(find.byType(GuTile)).height, height);
      expect(height, greaterThanOrEqualTo(GuSizes.tileMinHeight));
    });

    testWidgets('silinmiş kullanıcı (`user == null`): "Silinmiş kullanıcı" + '
        '`?` avatarı — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        await _pump(tester, const UserRow(user: null), locale: locale);
        final l10n = tester.l10nFor(locale);
        expect(find.text(l10n.commonDeletedUser), findsOneWidget);
        expect(_tile(tester).title, l10n.commonDeletedUser);
        expect(_tile(tester).subtitle, isNull);
        expect(_avatar(tester).initials, '?');
        expect(_avatar(tester).seed, '?');
      }
    });

    testWidgets('`named`: belgesiz satır; boş alt satır çizilmez; tohum boşsa '
        'kullanıcı kimliği kullanılır', (tester) async {
      await _pump(
        tester,
        const UserRow.named(name: 'Elif Aksoy', avatarSeed: 'elif', sub: ''),
      );
      expect(find.text('Elif Aksoy'), findsOneWidget);
      expect(_tile(tester).subtitle, isNull);
      expect(_avatar(tester).initials, 'EA');
      expect(_avatar(tester).seed, 'elif');

      await _pump(tester, UserRow(user: _user.copyWith(avatarSeed: '')));
      expect(_avatar(tester).seed, _user.uid);
    });

    testWidgets('kart içi + ok + sondaki öğe + avatar boyu', (tester) async {
      await _pump(
        tester,
        UserRow(
          user: _user,
          inCard: true,
          chevron: true,
          size: GuSizes.icon24,
          trailing: const Text('sonda'),
        ),
      );
      final tile = _tile(tester);
      expect(tile.padding, GuTilePadding.inCard);
      expect(tile.chevron, isTrue);
      expect(find.text('sonda'), findsOneWidget);
      expect(_avatar(tester).size, GuSizes.icon24);
    });
  });

  group('T-18 · UserRow · rozet ve uzun ad', () {
    testWidgets('rozet adın yanında (aralık 6), dikeyde ortalı', (
      tester,
    ) async {
      await _pump(tester, UserRow(user: _user, sub: _sub, badge: _badge));
      final name = tester.getRect(find.text(_user.name));
      final badge = tester.getRect(find.byType(GuRoleBadge));
      expect(badge.left - name.right, GuSpacing.s6);
      expect(badge.center.dy, moreOrLessEquals(name.center.dy, epsilon: 0.5));
      expect(badge.height, GuSizes.badgeHeight);
    });

    testWidgets('uzun ad: rozet esnemez, ad kesilir ve rozet aynı satırda '
        'kalır (K-29)', (tester) async {
      OverflowDetector.install();
      addTearDown(OverflowDetector.reset);
      OverflowDetector.reset();
      await _pump(
        tester,
        const UserRow.named(
          name: _longName,
          avatarSeed: 'x',
          sub: _sub,
          badge: _badge,
          chevron: true,
        ),
      );
      final row = tester.getRect(find.byType(UserRow));
      final name = tester.getRect(find.text(_longName));
      final badge = tester.getRect(find.byType(GuRoleBadge));
      expect(badge.left - name.right, GuSpacing.s6);
      expect(badge.center.dy, moreOrLessEquals(name.center.dy, epsilon: 0.5));
      expect(
        badge.right,
        lessThanOrEqualTo(row.right - GuSizes.tilePaddingX - GuSizes.tileGap),
      );
      OverflowDetector.assertNone('390');
    });

    testWidgets('320 dp × 1.6: ada yer kalmayınca rozet alt satıra iner '
        '(aralık 6); taşma yok', (tester) async {
      OverflowDetector.install();
      addTearDown(OverflowDetector.reset);
      OverflowDetector.reset();
      await _pump(
        tester,
        UserRow.named(
          name: _longName,
          avatarSeed: 'x',
          sub: _sub,
          badge: _badge,
          chevron: true,
          trailing: GuIconButton(
            icon: GuIcons.moreVertical,
            semanticLabel: 'menü',
            onPressed: () {},
          ),
          onTap: () {},
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      final name = tester.getRect(find.text(_longName));
      final badge = tester.getRect(find.byType(GuRoleBadge));
      expect(badge.top - name.bottom, GuSpacing.s6);
      expect(badge.left, name.left);
      OverflowDetector.assertNone('320 × 1.6');
      expect(tester.takeException(), isNull);
    });

    testWidgets('üçüncü satır (`sub2`): alt satırın altında, `caption` '
        'stiliyle çizilir', (tester) async {
      await _pump(
        tester,
        UserRow(user: _user, sub: _sub, sub2: const Text('üçüncü')),
      );
      final gu = tester.element(find.byType(UserRow)).gu;
      final sub = tester.getRect(find.text(_sub));
      final third = tester.getRect(find.text('üçüncü'));
      expect(third.top, sub.bottom);
      expect(sub.top, tester.getRect(find.text(_user.name)).bottom);
      expect(
        tester.widget<Text>(find.text(_sub)).style,
        gu.text.bodyS.copyWith(color: gu.colors.textMuted),
      );
      final style = DefaultTextStyle.of(
        tester.element(find.text('üçüncü')),
      ).style;
      expect(style, gu.text.caption);
    });
  });

  group('T-18 · UserRow · anahtar, dokunma, erişilebilirlik', () {
    testWidgets('anahtar çağırandan gelir ve satırın kendisidir; dokunma '
        '`onTap` çağırır', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        UserRow(user: _user, actionKey: _rowKey, onTap: () => taps++),
      );
      expect(find.byKey(_rowKey), findsOneWidget);
      expect(tester.widget(find.byKey(_rowKey)), isA<GuTile>());
      await tester.tap(find.byKey(_rowKey));
      expect(taps, 1);
    });

    testWidgets('erişilebilirlik: dokunulabilir satır ad + rozet + alt satırla '
        'okunan düğmedir (avatar okunmaz); düz satır düğme değildir', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        UserRow(
          user: _user,
          sub: _sub,
          badge: _badge,
          actionKey: _rowKey,
          onTap: () {},
        ),
      );
      var data = tester.getSemantics(find.byKey(_rowKey)).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, contains(_user.name));
      expect(data.label, contains(_badge.label));
      expect(data.label, contains(_sub));
      expect(data.label, isNot(contains('BŞ')));

      await _pump(tester, UserRow(user: _user, sub: _sub));
      data = tester.getSemantics(find.text(_user.name)).getSemanticsData();
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      handle.dispose();
    });
  });
}
