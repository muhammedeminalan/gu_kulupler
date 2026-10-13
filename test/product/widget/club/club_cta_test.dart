// T-16 · ClubCta (CD-25; design-analysis A.2 #51) — kulübe katılım eylemi:
// 7 çıktı (`ClubCtaKind`), `ClubAccess` × `MembershipStatus` × kulüp ayarları
// eşlemesi, düğme varyantı / ikon / metin (TR + EN), boyut ve `full`
// aktarımı, çağıranın verdiği anahtarlar, geri çağrılar, rozetler, cihaz
// matrisi, galeri golden'ı (açık + koyu). Kaynak: prototip `cards.js:19–27`,
// `actions.js:22–27`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/widget/club/club_cta.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fixtures/club_model_fixtures.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

final ClubModel _open = ClubModelFixtures.c01.copyWith(applicationsOpen: true);
final ClubModel _closed = _open.copyWith(applicationsOpen: false);
final ClubModel _suspended = _open.copyWith(status: ClubStatus.suspended);

final Key _joinKey = GuKey.action('CLB-03.join.${_open.id}');
final Key _statusKey = GuKey.action('CLB-03.status.${_open.id}');
final Key _openKey = GuKey.action('CLB-03.open.${_open.id}');

/// Dokunma sayaçları.
final class _Taps {
  int join = 0;
  int closed = 0;
  int status = 0;
  int open = 0;

  List<int> get all => [join, closed, status, open];
}

ClubCta _cta(
  ClubAccess access, {
  ClubModel? club,
  MembershipStatus? status,
  GuButtonSize size = GuButtonSize.md,
  bool full = false,
  bool keyed = true,
  _Taps? taps,
}) => ClubCta(
  club: club ?? _open,
  access: access,
  membershipStatus: status,
  size: size,
  full: full,
  joinKey: keyed ? _joinKey : null,
  statusKey: keyed ? _statusKey : null,
  openKey: keyed ? _openKey : null,
  onJoin: () => taps?.join++,
  onClosedTap: () => taps?.closed++,
  onStatus: () => taps?.status++,
  onOpen: () => taps?.open++,
);

Future<void> _pump(
  WidgetTester tester,
  Widget cta, {
  Locale locale = _tr,
  ThemeMode theme = ThemeMode.light,
  bool stretch = false,
}) => tester.pumpApp(
  Scaffold(
    body: Padding(
      padding: GuInsets.all16,
      child: stretch
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [cta],
            )
          : Center(child: cta),
    ),
  ),
  locale: locale,
  theme: theme,
);

GuButton _button(WidgetTester tester) =>
    tester.widget<GuButton>(find.byType(GuButton));

/// Galeri: dokuz görünüm (yedi çıktı + "Aç"ın rozetli iki biçimi), etiketli
/// satırlar; altta `lg` + `full` (CLB-03 alt çubuğu) ve `sm` (kart) örnekleri.
Widget _gallery(BuildContext context) {
  Widget row(String name, Widget child) => Padding(
    padding: GuInsets.only(bottom: GuSpacing.s12),
    child: Row(
      children: [
        Expanded(child: Text(name, style: context.gu.text.caption)),
        child,
      ],
    ),
  );
  return Scaffold(
    backgroundColor: context.gu.colors.bgCanvas,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: GuInsets.all16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            row('suspended', _cta(ClubAccess.visitor, club: _suspended)),
            row('join', _cta(ClubAccess.visitor)),
            row('closed', _cta(ClubAccess.visitor, club: _closed)),
            row('pending', _cta(ClubAccess.pending)),
            row('rejected', _cta(ClubAccess.rejected)),
            row(
              'removed',
              _cta(ClubAccess.visitor, status: MembershipStatus.removed),
            ),
            row('open · member', _cta(ClubAccess.member)),
            row('open · manager', _cta(ClubAccess.manager)),
            row('open · advisor', _cta(ClubAccess.advisor)),
            row(
              'join · sm',
              _cta(ClubAccess.visitor, size: GuButtonSize.sm),
            ),
            row(
              'pending · sm',
              _cta(ClubAccess.pending, size: GuButtonSize.sm),
            ),
            _cta(ClubAccess.visitor, size: GuButtonSize.lg, full: true),
            GuGap.v12,
            _cta(ClubAccess.rejected, size: GuButtonSize.lg, full: true),
            GuGap.v12,
            _cta(ClubAccess.manager, size: GuButtonSize.sm, full: true),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('T-16 · ClubCta · eşleme (kindOf)', () {
    test('çıktı kümesi prototipin yedi dalıdır (cards.js:21–26)', () {
      expect(ClubCtaKind.values.map((kind) => kind.name), [
        'suspended',
        'join',
        'closed',
        'pending',
        'rejected',
        'removed',
        'open',
      ]);
    });

    test('ziyaretçi: başvurular açık → join, kapalı → closed; ayrılan / geri '
        'çeken / üyeliği olmayan aynı çıktıyı alır', () {
      for (final status in [
        null,
        MembershipStatus.left,
        MembershipStatus.cancelled,
      ]) {
        expect(
          ClubCta.kindOf(
            club: _open,
            access: ClubAccess.visitor,
            membershipStatus: status,
          ),
          ClubCtaKind.join,
          reason: '$status',
        );
        expect(
          ClubCta.kindOf(
            club: _closed,
            access: ClubAccess.visitor,
            membershipStatus: status,
          ),
          ClubCtaKind.closed,
          reason: '$status',
        );
      }
    });

    test('çıkarılmış üye (visitor + removed) → removed; başvuruların açık / '
        'kapalı olması değiştirmez', () {
      for (final club in [_open, _closed]) {
        expect(
          ClubCta.kindOf(
            club: club,
            access: ClubAccess.visitor,
            membershipStatus: MembershipStatus.removed,
          ),
          ClubCtaKind.removed,
        );
      }
    });

    test('bekleyen → pending, reddedilen → rejected (kulüp ayarından '
        'bağımsız)', () {
      for (final club in [_open, _closed]) {
        expect(
          ClubCta.kindOf(
            club: club,
            access: ClubAccess.pending,
            membershipStatus: MembershipStatus.pending,
          ),
          ClubCtaKind.pending,
        );
        expect(
          ClubCta.kindOf(
            club: club,
            access: ClubAccess.rejected,
            membershipStatus: MembershipStatus.rejected,
          ),
          ClubCtaKind.rejected,
        );
      }
    });

    test('kulübün içini gören her kip → open; süper admin üyelik durumundan '
        'bağımsızdır', () {
      for (final access in [
        ClubAccess.member,
        ClubAccess.manager,
        ClubAccess.advisor,
        ClubAccess.superAdmin,
      ]) {
        expect(
          ClubCta.kindOf(
            club: _closed,
            access: access,
            membershipStatus: MembershipStatus.active,
          ),
          ClubCtaKind.open,
          reason: access.name,
        );
      }
      for (final status in [null, ...MembershipStatus.values]) {
        expect(
          ClubCta.kindOf(
            club: _open,
            access: ClubAccess.superAdmin,
            membershipStatus: status,
          ),
          ClubCtaKind.open,
          reason: '$status',
        );
      }
    });

    test('askıdaki kulüp her erişim kipinde ve üyelik durumunda '
        'suspended', () {
      for (final access in ClubAccess.values) {
        for (final status in [null, ...MembershipStatus.values]) {
          expect(
            ClubCta.kindOf(
              club: _suspended,
              access: access,
              membershipStatus: status,
            ),
            ClubCtaKind.suspended,
            reason: '${access.name} · $status',
          );
        }
      }
    });

    test('oturumdaki erişim kipi (`RolePolicy.accessOf`) ile uçtan uca: '
        'her üyelik durumu tek bir çıktıya düşer', () {
      ClubCtaKind of(MembershipStatus? status, {ClubRole? role}) =>
          ClubCta.kindOf(
            club: _open,
            access: RolePolicy.accessOf(
              isSuper: false,
              status: status,
              role: role,
            ),
            membershipStatus: status,
          );
      expect(of(null), ClubCtaKind.join);
      expect(of(MembershipStatus.pending), ClubCtaKind.pending);
      expect(of(MembershipStatus.rejected), ClubCtaKind.rejected);
      expect(of(MembershipStatus.removed), ClubCtaKind.removed);
      expect(of(MembershipStatus.left), ClubCtaKind.join);
      expect(of(MembershipStatus.cancelled), ClubCtaKind.join);
      for (final role in ClubRole.values) {
        expect(
          of(MembershipStatus.active, role: role),
          ClubCtaKind.open,
          reason: role.name,
        );
      }
    });

    testWidgets('`kind` getter widget girdilerinden okunur', (tester) async {
      expect(_cta(ClubAccess.visitor).kind, ClubCtaKind.join);
      expect(_cta(ClubAccess.visitor, club: _closed).kind, ClubCtaKind.closed);
      expect(
        _cta(ClubAccess.visitor, status: MembershipStatus.removed).kind,
        ClubCtaKind.removed,
      );
      expect(_cta(ClubAccess.manager).kind, ClubCtaKind.open);
    });
  });

  group('T-16 · ClubCta · çizim', () {
    testWidgets('join: birincil "Katıl", ikonsuz, etkin; anahtar `joinKey`; '
        'dokunma yalnızca onJoin — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final taps = _Taps();
        await _pump(
          tester,
          _cta(ClubAccess.visitor, taps: taps),
          locale: locale,
        );
        final button = _button(tester);
        expect(button.label, tester.l10nFor(locale).clubsCardJoin);
        expect(button.variant, GuButtonVariant.primary);
        expect(button.icon, isNull);
        expect(button.disabled, isFalse);
        expect(button.key, _joinKey);
        expect(find.byType(GuBadge), findsNothing);

        await tester.tap(find.byKey(_joinKey));
        expect(taps.all, [1, 0, 0, 0]);
      }
    });

    testWidgets('closed: çerçeveli, devre dışı "Başvurular kapalı"; aynı '
        '`joinKey`; dokunma onClosedTap (onJoin değil) — TR ve EN', (
      tester,
    ) async {
      for (final locale in [_tr, _en]) {
        final taps = _Taps();
        await _pump(
          tester,
          _cta(ClubAccess.visitor, club: _closed, taps: taps),
          locale: locale,
        );
        final button = _button(tester);
        expect(button.label, tester.l10nFor(locale).clubsCardClosed);
        expect(button.variant, GuButtonVariant.outline);
        expect(button.disabled, isTrue);
        expect(button.onPressed, isNull);
        expect(button.key, _joinKey);

        await tester.tap(find.byKey(_joinKey));
        expect(taps.all, [0, 1, 0, 0]);
      }
    });

    testWidgets('pending / rejected / removed: tonal + ikon + durum metni; '
        'anahtar `statusKey`; dokunma onStatus — TR ve EN', (tester) async {
      final cases =
          <
            ({
              ClubAccess access,
              MembershipStatus status,
              GuIcons icon,
              String Function(Locale) label,
            })
          >[
            (
              access: ClubAccess.pending,
              status: MembershipStatus.pending,
              icon: GuIcons.hourglass,
              label: (locale) => tester.l10nFor(locale).clubsCardPending,
            ),
            (
              access: ClubAccess.rejected,
              status: MembershipStatus.rejected,
              icon: GuIcons.circleX,
              label: (locale) => tester.l10nFor(locale).clubsCardRejected,
            ),
            (
              access: ClubAccess.visitor,
              status: MembershipStatus.removed,
              icon: GuIcons.userX,
              label: (locale) => tester.l10nFor(locale).clubsCardRemoved,
            ),
          ];
      for (final locale in [_tr, _en]) {
        for (final c in cases) {
          final taps = _Taps();
          await _pump(
            tester,
            _cta(c.access, status: c.status, taps: taps),
            locale: locale,
          );
          final button = _button(tester);
          expect(button.label, c.label(locale), reason: c.status.name);
          expect(button.variant, GuButtonVariant.tonal, reason: c.status.name);
          expect(button.icon, c.icon, reason: c.status.name);
          expect(button.disabled, isFalse);
          expect(button.key, _statusKey);
          expect(find.byType(GuBadge), findsNothing);

          await tester.tap(find.byKey(_statusKey));
          expect(taps.all, [0, 0, 1, 0], reason: c.status.name);
        }
      }
    });

    testWidgets('rejected düz tonal çizilir: `.c-danger` `.btn-tonal`dan önce '
        'tanımlıdır, metin ve ikon `brand.onPrimaryContainer` kalır', (
      tester,
    ) async {
      await _pump(tester, _cta(ClubAccess.rejected));
      final colors = tester.element(find.byType(ClubCta)).gu.colors;
      final icon = tester.widget<GuIcon>(
        find.descendant(
          of: find.byType(GuButton),
          matching: find.byType(GuIcon),
        ),
      );
      expect(icon.color, colors.brandOnPrimaryContainer);
      expect(icon.color, isNot(colors.stateDanger));
    });

    testWidgets('open: çerçeveli "Aç"; anahtar `openKey`; dokunma onOpen; '
        'üye ve süper adminde rozet yok — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        for (final access in [ClubAccess.member, ClubAccess.superAdmin]) {
          final taps = _Taps();
          await _pump(tester, _cta(access, taps: taps), locale: locale);
          final button = _button(tester);
          expect(button.label, tester.l10nFor(locale).clubsCardOpen);
          expect(button.variant, GuButtonVariant.outline);
          expect(button.icon, isNull);
          expect(button.key, _openKey);
          expect(find.byType(GuBadge), findsNothing, reason: access.name);

          await tester.tap(find.byKey(_openKey));
          expect(taps.all, [0, 0, 0, 1], reason: access.name);
        }
      }
    });

    testWidgets('open · yönetici: "Yönetici" rozeti (president, '
        'shield-check) düğmenin solunda, aralık 8 — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        await _pump(tester, _cta(ClubAccess.manager), locale: locale);
        final l10n = tester.l10nFor(locale);
        final badge = tester.widget<GuBadge>(find.byType(GuBadge));
        expect(badge.label, l10n.clubsCardManager);
        expect(badge.kind, GuBadgeKind.president);
        expect(badge.icon, GuIcons.shieldCheck);
        expect(find.byType(GuRoleBadge), findsNothing);
        expect(_button(tester).label, l10n.clubsCardOpen);

        final badgeRect = tester.getRect(find.byType(GuBadge));
        final buttonRect = tester.getRect(find.byType(GuButton));
        expect(buttonRect.left - badgeRect.right, GuSpacing.s8);
        expect(badgeRect.center.dy, buttonRect.center.dy);
      }
    });

    testWidgets('open · danışman: rol rozeti (advisor) + "Aç" — TR ve EN', (
      tester,
    ) async {
      for (final locale in [_tr, _en]) {
        await _pump(tester, _cta(ClubAccess.advisor), locale: locale);
        final l10n = tester.l10nFor(locale);
        final badge = tester.widget<GuRoleBadge>(find.byType(GuRoleBadge));
        expect(badge.kind, GuRoleBadgeKind.advisor);
        expect(badge.label, l10n.roleAdvisor);
        expect(_button(tester).label, l10n.clubsCardOpen);
        expect(_button(tester).key, _openKey);
      }
    });

    testWidgets('suspended: "Askıda" rozeti (danger, ban); düğme ve anahtar '
        'yok; satırı doldurmaz — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final taps = _Taps();
        await _pump(
          tester,
          _cta(ClubAccess.manager, club: _suspended, full: true, taps: taps),
          locale: locale,
          stretch: true,
        );
        final badge = tester.widget<GuBadge>(find.byType(GuBadge));
        expect(badge.label, tester.l10nFor(locale).statusSuspended);
        expect(badge.kind, GuBadgeKind.danger);
        expect(badge.icon, GuIcons.ban);
        expect(find.byType(GuButton), findsNothing);
        expect(ActionInventory.found(tester), isEmpty);

        // Ebeveyn genişliği zorlasa da rozet kendi genişliğindedir.
        final cta = tester.getRect(find.byType(ClubCta));
        final badgeRect = tester.getRect(find.byType(GuBadge));
        expect(cta.width, 390 - 32);
        expect(badgeRect.width, lessThan(cta.width / 2));
        expect(badgeRect.left, cta.left);
        expect(badgeRect.height, GuSizes.badgeHeight);

        await tester.tap(find.byType(GuBadge));
        expect(taps.all, [0, 0, 0, 0]);
      }
    });
  });

  group('T-16 · ClubCta · boyut, genişlik, anahtar', () {
    testWidgets('`size` düğmeye aktarılır: sm 40 · md 48 · lg 56', (
      tester,
    ) async {
      for (final size in GuButtonSize.values) {
        for (final access in [
          ClubAccess.visitor,
          ClubAccess.pending,
          ClubAccess.member,
        ]) {
          await _pump(tester, _cta(access, size: size));
          expect(_button(tester).size, size);
          expect(
            tester.getSize(find.byType(GuButton)).height,
            size.minHeight,
            reason: '${access.name} · ${size.name}',
          );
        }
      }
    });

    testWidgets('varsayılan: md, içerik genişliğinde', (tester) async {
      await _pump(tester, _cta(ClubAccess.visitor));
      final button = _button(tester);
      expect(button.size, GuButtonSize.md);
      expect(button.full, isFalse);
      expect(tester.getSize(find.byType(GuButton)).width, lessThan(200));
    });

    testWidgets('`full`: tek düğmeli çıktılar satırı doldurur', (tester) async {
      final cases = <ClubCta>[
        _cta(ClubAccess.visitor, full: true),
        _cta(ClubAccess.visitor, club: _closed, full: true),
        _cta(ClubAccess.pending, full: true),
        _cta(ClubAccess.rejected, full: true),
        _cta(ClubAccess.visitor, status: MembershipStatus.removed, full: true),
        _cta(ClubAccess.member, full: true),
      ];
      for (final cta in cases) {
        await _pump(tester, cta, stretch: true);
        expect(_button(tester).full, isTrue, reason: cta.kind.name);
        expect(
          tester.getSize(find.byType(GuButton)).width,
          390 - 32,
          reason: cta.kind.name,
        );
      }
    });

    testWidgets('`full` + rozet: rozet kendi genişliğinde, düğme kalan alanı '
        'doldurur', (tester) async {
      await _pump(tester, _cta(ClubAccess.manager, full: true), stretch: true);
      final cta = tester.getRect(find.byType(ClubCta));
      final badge = tester.getRect(find.byType(GuBadge));
      final button = tester.getRect(find.byType(GuButton));
      expect(badge.left, cta.left);
      expect(button.left - badge.right, GuSpacing.s8);
      expect(button.right, cta.right);
      expect(cta.width, 390 - 32);
    });

    testWidgets('anahtar verilmezse aksiyon anahtarı çizilmez; verilen anahtar '
        'yalnızca kendi çıktısında kullanılır', (tester) async {
      await _pump(tester, _cta(ClubAccess.visitor, keyed: false));
      expect(ActionInventory.found(tester), isEmpty);

      final expected = <ClubCta, String>{
        _cta(ClubAccess.visitor): 'CLB-03.join.c01',
        _cta(ClubAccess.visitor, club: _closed): 'CLB-03.join.c01',
        _cta(ClubAccess.pending): 'CLB-03.status.c01',
        _cta(ClubAccess.rejected): 'CLB-03.status.c01',
        _cta(ClubAccess.visitor, status: MembershipStatus.removed):
            'CLB-03.status.c01',
        _cta(ClubAccess.member): 'CLB-03.open.c01',
        _cta(ClubAccess.manager): 'CLB-03.open.c01',
        _cta(ClubAccess.advisor): 'CLB-03.open.c01',
        _cta(ClubAccess.superAdmin): 'CLB-03.open.c01',
      };
      for (final MapEntry(key: cta, value: action) in expected.entries) {
        await _pump(tester, cta);
        expect(ActionInventory.found(tester), {action}, reason: cta.kind.name);
      }
    });

    testWidgets('erişilebilirlik: düğme etiketi görünen metindir; kapalı '
        'düğme devre dışı okunur', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _cta(ClubAccess.visitor));
      final l10n = tester.l10nFor(_tr);
      expect(
        tester.getSemantics(find.byKey(_joinKey)),
        isSemantics(
          label: l10n.clubsCardJoin,
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );

      await _pump(tester, _cta(ClubAccess.visitor, club: _closed));
      expect(
        tester.getSemantics(find.byKey(_joinKey)),
        isSemantics(
          label: l10n.clubsCardClosed,
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });
  });

  group('T-16 · ClubCta · yerleşim', () {
    testWidgets('cihaz matrisi: galeri taşmaz (320 dp, ölçek 1.6, TR / EN)', (
      tester,
    ) async {
      await DeviceMatrix.run(tester, _gallery);
    });

    testWidgets('golden: galeri — açık + koyu (TR)', (tester) async {
      await goldenForThemes(
        tester,
        'club_cta',
        const Builder(builder: _gallery),
      );
    });
  });
}
