// T-31 · yönetim ortak widget'ları — `ManageHeader` (widget-catalog P19,
// prototip `MgtHeader` `screens-manage.js:7–10`), `ActivityRow` (P18,
// `screens-manage.js:34–39`) ve `ActivityTexts` (`activity.<kind>` ARB
// metinleri): içerik, rozet / kulüp değiştirme / salt okunur varyantları,
// kalın eylemci adı, silinmiş eylemci, çağıranın verdiği anahtarlar,
// erişilebilirlik, cihaz matrisi ve galeri golden'ı (açık + koyu).
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/manage/activity_lookups.dart';
import 'package:gu_kulupler/product/widget/manage/activity_row.dart';
import 'package:gu_kulupler/product/widget/manage/activity_texts.dart';
import 'package:gu_kulupler/product/widget/manage/activity_visuals.dart';
import 'package:gu_kulupler/product/widget/manage/manage_header.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fixtures/club_model_fixtures.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');

final ClubModel _club = ClubModelFixtures.byId('c03');
final ClubModel _longClub = _club.copyWith(
  name: 'Gümüşhane Üniversitesi Doğa Sporları, Dağcılık ve Kampçılık Kulübü',
);
final UserModel _burak = UserModelFixtures.byId('u_burak');
final UserModel _ayse = UserModelFixtures.byId('u_ayse');
final UserModel _long = UserModelFixtures.byId('u_long');

const String _deletedId = 'u_gone';
const String _eventId = 'e16';
const String _goneEventId = 'e_gone';

final ActivityLookups _lookups = ActivityLookups(
  users: {_burak.uid: _burak, _ayse.uid: _ayse, _long.uid: _long},
  eventTitles: const {_eventId: 'Dağcılık Temel Eğitimi'},
  missing: const {_deletedId, _goneEventId},
);

ActivityModel _activity(
  ActivityKind kind, {
  String id = 'a01',
  String actorId = 'u_burak',
  ActivityRefsModel refs = const ActivityRefsModel(),
}) => ActivityModel(
  id: id,
  clubId: _club.id,
  actorId: actorId,
  kind: kind,
  refs: refs,
);

/// Her türün hedefleri doldurulmuş kaydı.
ActivityModel _full(ActivityKind kind) => _activity(
  kind,
  refs: const ActivityRefsModel(
    userId: 'u_ayse',
    eventId: _eventId,
    role: ClubRole.board,
  ),
);

final Key _backKey = GuKey.action('MGT-01.back');
final Key _switchKey = GuKey.action('MGT-01.switchClub');
final Key _rowKey = GuKey.action('MGT-01.row.a01');

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = _tr,
  Size size = const Size(390, 844),
  double textScale = 1,
}) => tester.pumpApp(
  Scaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [child],
    ),
  ),
  locale: locale,
  size: size,
  textScale: textScale,
);

ActivityRow _row(
  BuildContext context,
  ActivityModel activity, {
  UserModel? actor,
  bool inCard = true,
  VoidCallback? onTap,
  String time = '3 sa önce',
}) => ActivityRow(
  activity: activity,
  text: ActivityTexts(context.l10n).text(activity, _lookups),
  timeLabel: time,
  onTap: onTap ?? () {},
  actionKey: GuKey.action('MGT-01.row.${activity.id}'),
  actor: actor,
  inCard: inCard,
);

/// Galeri: başlık varyantları (tek kulüp + rozet, kulüp değiştirme + uzun ad,
/// süper admin, salt okunur) ve satırlar (kart içi ayraçlı, düz, silinmiş
/// eylemci, uzun metin).
Widget _gallery(BuildContext context) => Scaffold(
  backgroundColor: context.gu.colors.bgCanvas,
  body: SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ManageHeader(
          club: _club,
          title: context.l10n.mgtTitle,
          role: ClubRole.president,
          onBack: () {},
          backKey: _backKey,
        ),
        ManageHeader(
          club: _longClub,
          title: context.l10n.activityTitle,
          role: ClubRole.board,
          onSwitchClub: () {},
          switchClubKey: _switchKey,
          onBack: () {},
          backKey: GuKey.action('MGT-10.back'),
        ),
        ManageHeader(
          club: _club,
          title: context.l10n.mgtTitle,
          isSuperAdmin: true,
          onBack: () {},
          backKey: GuKey.action('MGT-02.back'),
        ),
        ManageHeader(
          club: _club,
          title: context.l10n.mgtTitle,
          role: ClubRole.advisor,
          onBack: () {},
          backKey: GuKey.action('MGT-03.back'),
        ),
        Padding(
          padding: GuInsets.all16,
          child: GuCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _row(
                  context,
                  _full(ActivityKind.eventPublished),
                  actor: _burak,
                ),
                const GuDivider(),
                _row(
                  context,
                  _full(ActivityKind.applicationRejected).copyWith(id: 'a02'),
                  actor: _burak,
                ),
                const GuDivider(),
                _row(
                  context,
                  _activity(
                    ActivityKind.memberLeft,
                    id: 'a03',
                    actorId: _deletedId,
                  ),
                ),
              ],
            ),
          ),
        ),
        _row(
          context,
          _activity(ActivityKind.poll, id: 'a04', actorId: 'u_ayse'),
          actor: _ayse,
          inCard: false,
          time: '20 saat önce',
        ),
        _row(
          context,
          _full(
            ActivityKind.roleChanged,
          ).copyWith(id: 'a05', actorId: 'u_long'),
          actor: _long,
          inCard: false,
          time: '2 hafta önce',
        ),
      ],
    ),
  ),
);

void main() {
  group('T-31 · ActivityTexts', () {
    testWidgets('her tür ARB cümlesi: eylemci + hedef + etkinlik + rol — TR '
        've EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final l10n = tester.l10nFor(locale);
        final texts = ActivityTexts(l10n);
        for (final kind in ActivityKind.values) {
          final text = texts.text(_full(kind), _lookups);
          expect(text.actorName, _burak.name);
          expect(text.text, contains(_burak.name), reason: '$kind');
          if (kind == ActivityKind.unknown) {
            expect(text.text, _burak.name);
          } else {
            expect(text.text.length, greaterThan(_burak.name.length));
          }
        }
        final role = texts.text(_full(ActivityKind.roleChanged), _lookups);
        expect(role.text, contains(_ayse.name));
        expect(role.text, contains(l10n.roleBoard));
        expect(
          texts.text(_full(ActivityKind.eventPublished), _lookups).text,
          contains('Dağcılık Temel Eğitimi'),
        );
      }
    });

    testWidgets('silinmiş / bulunamayan hedefler: "Silinmiş kullanıcı", '
        '"İçerik kaldırıldı"; okunmamış ad boş', (tester) async {
      final l10n = tester.l10nFor(_tr);
      final texts = ActivityTexts(l10n);
      final deleted = texts.text(
        _activity(ActivityKind.memberJoined, actorId: _deletedId),
        _lookups,
      );
      expect(deleted.actorName, l10n.commonDeletedUser);
      expect(deleted.text, l10n.activityMemberJoined(l10n.commonDeletedUser));
      final anonymized = ActivityLookups(
        users: {_burak.uid: _burak.copyWith(status: UserStatus.deleted)},
      );
      expect(texts.userName(_burak.uid, anonymized), l10n.commonDeletedUser);
      expect(texts.userName('u_unread', _lookups), isEmpty);
      final gone = texts.text(
        _activity(
          ActivityKind.eventCancelled,
          refs: const ActivityRefsModel(eventId: _goneEventId),
        ),
        _lookups,
      );
      expect(gone.text, contains(l10n.notifTargetRemoved));
    });
  });

  group('T-31 · ActivityRow', () {
    testWidgets('avatar 36, metin bodyS + kalın eylemci, zaman, tür ikonu 18 '
        '(muted), kart içi dolgu', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) =>
              _row(context, _full(ActivityKind.eventPublished), actor: _burak),
        ),
      );
      final avatar = tester.widget<GuAvatar>(find.byType(GuAvatar));
      expect(avatar.size, GuSizes.activityRowAvatar);
      expect(avatar.initials, _burak.name.initials);
      final icon = tester.widget<GuIcon>(
        find.descendant(of: find.byType(GuTile), matching: find.byType(GuIcon)),
      );
      expect(icon.icon, ActivityVisuals.icon(ActivityKind.eventPublished));
      expect(icon.size, GuSizes.icon18);
      final context = tester.element(find.byType(ActivityRow));
      expect(icon.color, context.gu.colors.textMuted);
      final tile = tester.widget<GuTile>(find.byType(GuTile));
      expect(tile.padding, GuTilePadding.inCard);
      expect(tile.subtitle, '3 sa önce');
      expect(tile.titleStyle?.fontSize, context.gu.text.bodyS.fontSize);
      final title = tile.titleWidget! as Text;
      // Satır kutusu `.tile-title` body-m'dir (22), metin body-s (13).
      expect(title.strutStyle?.fontSize, context.gu.text.bodyM.fontSize);
      expect(title.strutStyle?.height, context.gu.text.bodyM.height);
      final span = title.textSpan! as TextSpan;
      final bold = span.children!.cast<TextSpan>().singleWhere(
        (s) => s.style?.fontWeight != null,
      );
      expect(bold.text, _burak.name);
      expect(bold.style!.fontWeight, context.gu.text.titleL.fontWeight);
      expect(span.toPlainText(), tile.title);
    });

    testWidgets('düz liste dolgusu; ad cümlede yoksa düz metin', (
      tester,
    ) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => _row(
            context,
            _activity(ActivityKind.poll, actorId: 'u_unread'),
            inCard: false,
          ),
        ),
      );
      final tile = tester.widget<GuTile>(find.byType(GuTile));
      expect(tile.padding, GuTilePadding.normal);
      final span = (tile.titleWidget! as Text).textSpan! as TextSpan;
      expect(span.children, isNull);
    });

    testWidgets('silinmiş eylemci: "?" avatar, foto yok, erişilebilirlik '
        'etiketi "Silinmiş kullanıcı"', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => _row(
            context,
            _activity(ActivityKind.memberLeft),
            actor: _burak.copyWith(isDeleted: true),
          ),
        ),
      );
      final avatar = tester.widget<GuAvatar>(find.byType(GuAvatar));
      expect(avatar.initials, '?');
      expect(avatar.image, isNull);
      final l10n = tester.l10nFor(_tr);
      expect(avatar.semanticLabel, l10n.commonDeletedUser);
    });

    testWidgets('çağıranın anahtarı satırın kendisi; dokunma geri çağrısı; '
        'Semantics düğme + metin', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await _pump(
        tester,
        Builder(
          builder: (context) => _row(
            context,
            _full(ActivityKind.memberJoined),
            actor: _burak,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byKey(_rowKey));
      expect(taps, 1);
      final data = tester.getSemantics(find.byKey(_rowKey)).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(
        data.label,
        contains(tester.l10nFor(_tr).activityMemberJoined(_burak.name)),
      );
      handle.dispose();
    });
  });

  group('T-31 · ManageHeader', () {
    testWidgets('iki satır (ekran adı caption · kulüp adı titleS), rol '
        'rozetleri, süper admin, rozetsiz; geri anahtarı', (tester) async {
      for (final locale in [_tr, _en]) {
        final l10n = tester.l10nFor(locale);
        for (final (role, kind, label) in [
          (ClubRole.president, GuRoleBadgeKind.president, l10n.rolePresident),
          (ClubRole.board, GuRoleBadgeKind.board, l10n.roleBoard),
          (ClubRole.advisor, GuRoleBadgeKind.advisor, l10n.roleAdvisor),
        ]) {
          var backs = 0;
          await _pump(
            tester,
            ManageHeader(
              club: _club,
              title: l10n.mgtTitle,
              role: role,
              onBack: () => backs++,
              backKey: _backKey,
            ),
            locale: locale,
          );
          final caption = tester.widget<Text>(find.text(l10n.mgtTitle));
          final context = tester.element(find.byType(ManageHeader));
          expect(caption.style, context.gu.text.caption);
          final name = tester.widget<Text>(find.text(_club.name));
          expect(name.style, context.gu.text.titleS);
          expect(name.overflow, TextOverflow.ellipsis);
          final badge = tester.widget<GuRoleBadge>(find.byType(GuRoleBadge));
          expect(badge.kind, kind);
          expect(badge.label, label);
          expect(find.byKey(_switchKey), findsNothing);
          expect(find.byType(GuBanner), findsNothing);
          await tester.tap(find.byKey(_backKey));
          expect(backs, 1);
        }
      }

      final l10n = tester.l10nFor(_tr);
      await _pump(
        tester,
        ManageHeader(
          club: _club,
          title: l10n.mgtTitle,
          isSuperAdmin: true,
          onBack: () {},
          backKey: _backKey,
        ),
      );
      final badge = tester.widget<GuRoleBadge>(find.byType(GuRoleBadge));
      expect(badge.kind, GuRoleBadgeKind.superadmin);
      expect(badge.label, l10n.roleSuperadmin);

      await _pump(
        tester,
        ManageHeader(
          club: null,
          title: l10n.mgtTitle,
          onBack: () {},
          backKey: _backKey,
        ),
      );
      expect(find.byType(GuRoleBadge), findsNothing);
      expect(find.text(l10n.mgtTitle), findsOneWidget);
    });

    testWidgets('kulüp değiştirme: chevron-down 16, anahtar → geri çağrı, '
        'Semantics düğme + başlık + ipucu', (tester) async {
      final handle = tester.ensureSemantics();
      final l10n = tester.l10nFor(_tr);
      var switches = 0;
      await _pump(
        tester,
        ManageHeader(
          club: _club,
          title: l10n.mgtTitle,
          role: ClubRole.president,
          onSwitchClub: () => switches++,
          switchClubKey: _switchKey,
          onBack: () {},
          backKey: _backKey,
        ),
      );
      final chevron = tester.widget<GuIcon>(
        find.descendant(
          of: find.byKey(_switchKey),
          matching: find.byType(GuIcon),
        ),
      );
      expect(chevron.icon, GuIcons.chevronDown);
      expect(chevron.size, GuSizes.icon16);
      await tester.tap(find.byKey(_switchKey));
      expect(switches, 1);
      final data = tester
          .getSemantics(find.byKey(_switchKey))
          .getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(data.label, _club.name);
      expect(
        find.bySemanticsLabel(_club.name),
        findsOneWidget,
      );
      final header = tester.getSemantics(
        find.ancestor(
          of: find.byKey(_switchKey),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && (w.properties.header ?? false),
          ),
        ),
      );
      expect(header.getSemanticsData().hint, l10n.sht18Title);
      handle.dispose();
    });

    testWidgets('uzun kulüp adı: düğmede en çok 190 geniş, üç nokta', (
      tester,
    ) async {
      final l10n = tester.l10nFor(_tr);
      await _pump(
        tester,
        ManageHeader(
          club: _longClub,
          title: l10n.mgtTitle,
          role: ClubRole.president,
          onSwitchClub: () {},
          switchClubKey: _switchKey,
          onBack: () {},
          backKey: _backKey,
        ),
        size: const Size(430, 844),
      );
      expect(
        tester.getSize(find.text(_longClub.name)).width,
        lessThanOrEqualTo(GuSizes.manageHeaderClubMaxWidth),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('salt okunur bant çubuğa dahil değil: preferredSize tek '
        'çubuk boyu', (tester) async {
      final header = ManageHeader(
        club: _club,
        title: tester.l10nFor(_tr).mgtTitle,
        role: ClubRole.advisor,
        onBack: () {},
        backKey: _backKey,
      );
      await _pump(tester, header);
      expect(find.byType(GuBanner), findsNothing);
      expect(header.preferredSize, const GuAppBar().preferredSize);
    });
  });

  group("T-31 · yönetim widget'ları · galeri", () {
    testWidgets('cihaz matrisi: galeri taşmaz (320 dp, ölçek 1.6, TR / EN)', (
      tester,
    ) async {
      await DeviceMatrix.run(tester, _gallery);
    });

    testWidgets('golden: galeri — açık + koyu (TR)', (tester) async {
      await goldenForThemes(
        tester,
        'manage_widgets',
        const Builder(builder: _gallery),
        size: const Size(390, 640),
      );
    });
  });
}
