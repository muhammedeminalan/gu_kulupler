// CLB-03 · Kulüp — içerik (TR / EN), durum çubuğu ve güvenli alan, aksiyon
// envanteri, her aksiyonun sonucu (SHT-05 / SHT-06 / SHT-07 / SHT-10 /
// SHT-15, DLG-08 / DLG-12 / DLG-32, TST-24 / TST-34 / TST-35 / TST-X1,
// CLB-04 / CLB-05 / SYS-04 gezinmesi), durumlar (yükleniyor, hata, yok,
// çevrimdışı), kip görünümleri (ziyaretçi, bekleyen, reddedilen, çıkarılan,
// üye, yönetici, danışman, süper admin, askıdaki kulüp), cihaz matrisi,
// açık + koyu golden.
// Referans: design/reference-shots/screens/CLB-03__*.webp,
// design/prototype/app/screens-clubs.js:77–112.
//
// İki kip (CLB-04 / CLB-05 testleriyle aynı düzen):
// * **Durum kipi** (içerik, matris, envanter, golden): ekran `pumpApp` ile
//   çizilir, ViewModel durumu ezilir (okuma yapılmaz).
// * **Akış kipi** (aksiyon sonuçları): ekran gerçek ViewModel, sahte depolar
//   ve yer tutucu hedef rotalarla açılır.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_detail_state.dart';
import 'package:gu_kulupler/features/clubs/provider/club_detail_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/join_application_state.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_about_tab.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_detail_cta_bar.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_events_tab.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_feed_tab.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_header.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_locked_tab.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_members_tab.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/share_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/navigation/club_detail_tab.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_kulupler/product/service/share_service.dart';
import 'package:gu_kulupler/product/service/url_launcher_service.dart';
import 'package:gu_kulupler/product/widget/club/club_cta.dart';
import 'package:gu_kulupler/product/widget/event/event_card.dart';
import 'package:gu_kulupler/product/widget/event/event_card_status.dart';
import 'package:gu_kulupler/product/widget/event/event_cta.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_connectivity_service.dart';
import '../../../fakes/fake_event_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fakes/fake_rsvp_repository.dart';
import '../../../fakes/fake_share_service.dart';
import '../../../fakes/fake_url_launcher_service.dart';
import '../../../fakes/register_fakes.dart';
import '../../../fixtures/event_model_fixtures.dart';
import '../../../fixtures/rsvp_model_fixtures.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../club_detail_test_support.dart';

final Key _back = GuKey.action('CLB-03.back');
final Key _share = GuKey.action('CLB-03.share');
final Key _menu = GuKey.action('CLB-03.menu');
final Key _memberCount = GuKey.action('CLB-03.memberCount');
final Key _join = GuKey.action('CLB-03.join.$kClubId');
final Key _status = GuKey.action('CLB-03.status.$kClubId');
final Key _more = GuKey.action('CLB-03.about.more');
final Key _linkEmail = GuKey.action('CLB-03.about.link.email');
final Key _linkInstagram = GuKey.action('CLB-03.about.link.instagram');
final Key _linkWeb = GuKey.action('CLB-03.about.link.web');
final Key _report = GuKey.action('CLB-03.report');
final Key _openManage = GuKey.action('CLB-03.openManage');
final Key _createEvent = GuKey.action('CLB-03.createEvent');
final Key _allMembers = GuKey.action('CLB-03.allMembers');

Key _tab(ClubDetailTab tab) => GuKey.action('CLB-03.tab.${tab.name}');

Key _person(String userId) => GuKey.action('CLB-03.about.person.$userId');

Key _member(String userId) => GuKey.action('CLB-03.member.$userId');

/// [key] anahtarlı kişi satırı (anahtar satırın `GuTile` kabuğundadır).
UserRow _rowOf(WidgetTester tester, Key key) => tester.widget<UserRow>(
  find.ancestor(of: find.byKey(key), matching: find.byType(UserRow)),
);

Key _segment(ClubEventSegment segment) =>
    GuKey.action('CLB-03.eventSeg.${segment.name}');

/// Danışmanın kullanıcı kimliği (`clubs.advisor.userId`).
const String _advisorId = 'u_a_c03';

/// Yönetim kurulu satırlarının anahtarları. Üyelik belgeleri yalnızca
/// kulübün içini görene okunur (rules-spec §3.4 R(c)): ziyaretçi
/// görünümünde bu satırlar yoktur.
final Set<String> _boardKeys = {
  for (final manager in kManagers) 'CLB-03.about.person.${manager.userId}',
};

/// Akış kipinde ekrandan önceki sayfa.
const String _clubsPath = '/clubs';

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeEventRepository _events() =>
    GetIt.I<EventRepository>() as FakeEventRepository;

FakeRsvpRepository _rsvps() => GetIt.I<RsvpRepository>() as FakeRsvpRepository;

FakeClubRepository _clubs() => GetIt.I<ClubRepository>() as FakeClubRepository;

FakeMembershipRepository _memberships() =>
    GetIt.I<MembershipRepository>() as FakeMembershipRepository;

FakeShareService _shareService() => GetIt.I<ShareService>() as FakeShareService;

FakeUrlLauncherService _launcher() =>
    GetIt.I<UrlLauncherService>() as FakeUrlLauncherService;

FakeConnectivityService _connectivity() =>
    GetIt.I<ConnectivityService>() as FakeConnectivityService;

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides(SessionState session, {ClubDetailState? state}) => [
  sessionViewModelProvider.overrideWithBuild((ref, notifier) => session),
  clubDetailViewModelProvider(
    kClubId,
  ).overrideWithBuild((ref, notifier) => state ?? loadedState(session)),
];

/// Ekranı [session] oturumunun dolu durumuyla (ya da [state] ile) çizer.
Future<void> _pump(
  WidgetTester tester, {
  SessionState? session,
  ClubDetailState? state,
  ClubModel? club,
  ClubDetailTab? tab,
  Locale locale = const Locale('tr'),
  ThemeMode theme = ThemeMode.light,
  EdgeInsets viewPadding = EdgeInsets.zero,
}) async {
  final current = session ?? kVisitorSession;
  await tester.pumpApp(
    clubDetailView(),
    locale: locale,
    theme: theme,
    viewPadding: viewPadding,
    overrides: _overrides(
      current,
      state:
          state ??
          loadedState(
            current,
            club: club,
            base: ClubDetailState(tab: tab ?? ClubDetailTab.about),
          ),
    ),
  );
  await tester.pump();
}

/// Akış kipi: ekranı gerçek ViewModel ve yer tutucu rotalarla açar. Depolar
/// ekran açılmadan önce tohumlanır ([seed] ek değişiklik içindir).
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  SessionState? session,
  ClubModel? club,
  void Function()? seed,
  String query = '',
  bool withClub = true,
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    routerOf: (_) => created ??= GoRouter(
      initialLocation: _clubsPath,
      routes: [
        GoRoute(
          path: _clubsPath,
          builder: (_, _) => const _Stub(_clubsPath),
          routes: [
            GoRoute(
              path: 'user/:userId',
              builder: (_, state) => _Stub(state.uri.path),
            ),
            GoRoute(
              path: ':clubId',
              builder: (_, state) => clubDetailView(
                tab: ClubDetailTab.values
                    .asNameMap()[state.uri.queryParameters['tab']],
              ),
              routes: [
                for (final segment in [
                  'applied',
                  'application',
                  'members',
                  'manage',
                  'manage/events/new',
                  'manage/settings',
                ])
                  GoRoute(
                    path: segment,
                    builder: (_, state) => _Stub(state.uri.path),
                  ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/events/:eventId',
          builder: (_, state) => _Stub(state.uri.path),
          routes: [
            GoRoute(
              path: 'ticket',
              builder: (_, state) => _Stub(state.uri.path),
            ),
          ],
        ),
        GoRoute(
          path: '/not-found',
          builder: (_, _) => const _Stub('/not-found'),
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => session ?? kVisitorSession,
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  if (withClub) seedClub(club: club);
  seed?.call();
  router.go('$_clubsPath/$kClubId$query');
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

/// Yer tutucu hedef sayfa: yolunu gösterir.
class _Stub extends StatelessWidget {
  const _Stub(this.path);

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(path));
}

ClubDetailState _stateOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ClubDetailView)),
).read(clubDetailViewModelProvider(kClubId));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _tapKey(WidgetTester tester, Key key) =>
    _tap(tester, find.byKey(key));

/// Alt çubuktaki `ClubCta` düğmesi (kilitli blokta aynı anahtarla bir tane
/// daha olabilir).
Finder _inBar(Key key) => find.descendant(
  of: find.byType(ClubDetailCtaBar),
  matching: find.byKey(key),
);

GuButton _button(WidgetTester tester, Finder finder) =>
    tester.widget<GuButton>(finder);

/// Ekranın durum çubuğu stili (en içteki bölge).
SystemUiOverlayStyle _statusBarStyle(WidgetTester tester) => tester
    .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(
        of: find.byType(ClubDetailView),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    )
    .last
    .value;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
  });

  group('CLB-03 · Kulüp · içerik', () {
    for (final locale in DeviceMatrix.locales) {
      testWidgets('ziyaretçi (${locale.languageCode}): başlık, rozetler, üye '
          'sayısı, sekmeler, Hakkında, "Katıl"', (tester) async {
        await _pump(tester, locale: locale);
        final l10n = tester.l10n;
        final context = tester.element(find.byType(ClubDetailView));
        final gu = context.gu;

        // Başlık çubuğu yok; kapak + üç düğme.
        expect(find.byType(GuAppBar), findsNothing);
        expect(find.byType(GuParallaxHeader), findsOneWidget);
        for (final (key, icon, label) in [
          (_back, GuIcons.arrowLeft, l10n.a11yBack),
          (_share, GuIcons.share2, l10n.commonShare),
          (_menu, GuIcons.moreVertical, l10n.a11yMore),
        ]) {
          final button = tester.widget<GuIconButton>(find.byKey(key));
          expect(button.icon, icon);
          expect(button.semanticLabel, label);
          expect(button.onCover, isTrue);
        }

        // Amblem (72) + ad + rozetler.
        final emblem = tester.widget<GuEmblem>(find.byType(GuEmblem));
        expect(emblem.icon, GuIcons.mountain);
        expect(emblem.size, GuEmblemSize.lg);
        final title = tester.widget<Text>(find.text(kClub.name));
        expect(title.style, gu.text.titleL);
        final badges = tester.widgetList<GuBadge>(
          find.descendant(
            of: find.byType(ClubHeader),
            matching: find.byType(GuBadge),
          ),
        );
        expect(badges.map((b) => (b.label, b.kind, b.icon)), [
          (
            StaticLabels.category(context, kClub.categoryId),
            GuBadgeKind.neutral,
            null,
          ),
          (l10n.clubTypeApproval, GuBadgeKind.info, GuIcons.shieldCheck),
        ]);
        expect(
          find.descendant(
            of: find.byType(ClubHeader),
            matching: find.byType(GuRoleBadge),
          ),
          findsNothing,
        );

        // Üye sayısı: ziyaretçide avatar grubu yöneticilerden kurulur
        // (CD-139), "+N" üye sayısından gelir.
        final group = tester.widget<GuAvatarGroup>(find.byType(GuAvatarGroup));
        expect(group.avatars, hasLength(GuSizes.avatarGroupMax));
        expect(
          group.moreLabel,
          '+${kClub.memberCount - GuSizes.avatarGroupMax}',
        );
        expect(
          find.descendant(
            of: find.byKey(_memberCount),
            matching: find.text(l10n.clubsCardMembers(kClub.memberCount)),
          ),
          findsOneWidget,
        );

        // Sekmeler: tasarım sırası, Hakkında seçili, yapışkan.
        final tabs = tester.widget<GuTabs>(find.byType(GuTabs));
        expect(tabs.sticky, isTrue);
        expect(tabs.value, ClubDetailTab.about.name);
        expect(tabs.tabs.map((t) => t.label), [
          l10n.clubTabAbout,
          l10n.clubTabEvents,
          l10n.clubTabPosts,
          l10n.clubTabMembers,
        ]);

        // Hakkında: metin üç satır + "Devamı" + kuruluş yılı.
        final about = tester.widget<Text>(find.text(kClub.about));
        expect(about.maxLines, 3);
        expect(about.overflow, TextOverflow.ellipsis);
        expect(about.style, gu.text.bodyM);
        final more = tester.widget<Text>(
          find.descendant(
            of: find.byKey(_more),
            matching: find.text(l10n.commonReadMore),
          ),
        );
        expect(more.style?.color, gu.colors.brandPrimaryText);
        expect(
          find.text(l10n.clubFounded(kClub.founded.toString())),
          findsOneWidget,
        );

        // İletişim kartı: üç satır, kart içi dolgu, marka renkli ikon.
        for (final (key, title, subtitle) in [
          (_linkEmail, kClub.social.email!, l10n.clubContactEmail),
          (
            _linkInstagram,
            kClub.social.instagram!,
            ClubAboutTab.instagramLabel,
          ),
          (
            _linkWeb,
            ShareLinks.display(kClub.social.web!),
            l10n.clubContactWeb,
          ),
        ]) {
          final tile = tester.widget<GuTile>(find.byKey(key));
          expect(tile.title, title);
          expect(tile.subtitle, subtitle);
          expect(tile.padding, GuTilePadding.inCard);
          expect((tile.leading! as GuIcon).color, gu.colors.brandPrimaryText);
        }

        // Danışman: ünvanlı ad, rol alt satırı. Yönetim kurulu ziyaretçiye
        // de okunur (CD-139).
        // "Danışman" hem bölüm başlığı hem satırın rol alt yazısıdır.
        expect(find.text(l10n.clubAdvisor), findsNWidgets(2));
        final advisor = _rowOf(tester, _person(_advisorId));
        expect(advisor.name, 'Doç. Dr. Hakan Yalçın');
        expect(advisor.sub, l10n.roleAdvisor);
        expect(advisor.badge, isNull);
        expect(advisor.inCard, isTrue);
        expect(advisor.chevron, isTrue);
        expect(find.byType(UserRow), findsNWidgets(1 + kManagers.length));
        // Yönetim kurulu satırları kart içi `MemberRow`'dur.
        expect(find.byType(MemberRow), findsNWidgets(kManagers.length));

        // Katılım koşulları ve şikayet.
        expect(find.text(l10n.clubConditions), findsOneWidget);
        for (final condition in kClub.conditions) {
          expect(find.text(condition), findsOneWidget);
        }
        final report = _button(tester, find.byKey(_report));
        expect(report.label, l10n.clubReport);
        expect(report.icon, GuIcons.flag);
        expect(report.variant, GuButtonVariant.text);

        // Alt çubuk: büyük, tam genişlik "Katıl"; not satırı yok.
        final join = _button(tester, _inBar(_join));
        expect(join.label, l10n.clubsCardJoin);
        expect(join.variant, GuButtonVariant.primary);
        expect(join.size, GuButtonSize.lg);
        expect(join.full, isTrue);
        expect(find.text(l10n.clubClosedNote), findsNothing);
      });
    }

    testWidgets('anında katılım kulübü: "Anında katılım" rozeti', (
      tester,
    ) async {
      await _pump(tester, club: kClub.copyWith(approvalRequired: false));
      final badge = tester.widget<GuBadge>(
        find.widgetWithText(GuBadge, tester.l10n.clubTypeInstant),
      );
      expect(badge.kind, GuBadgeKind.success);
      expect(badge.icon, GuIcons.sparkles);
      expect(find.text(tester.l10n.clubTypeApproval), findsNothing);
    });

    testWidgets('boş alanlar çizilmez: kısa tanıtımda "Devamı" yok; '
        'bağlantı, danışman ve koşul bölümleri yok', (tester) async {
      await _pump(
        tester,
        club: kClub.copyWith(
          about: 'Kısa tanıtım.',
          social: const ClubSocialModel(),
          clearAdvisor: true,
          conditions: const [],
          iconName: 'bilinmeyen-ikon',
        ),
      );
      final l10n = tester.l10n;
      expect(find.text('Kısa tanıtım.'), findsOneWidget);
      expect(find.byKey(_more), findsNothing);
      expect(find.byKey(_linkEmail), findsNothing);
      expect(find.byKey(_linkInstagram), findsNothing);
      expect(find.byKey(_linkWeb), findsNothing);
      // Tek kart yönetim kuruludur (herkese açık — CD-139).
      expect(find.byType(GuCard), findsOneWidget);
      expect(find.text(l10n.clubBoard), findsOneWidget);
      expect(find.text(l10n.clubAdvisor), findsNothing);
      expect(find.text(l10n.clubConditions), findsNothing);
      expect(find.byKey(_report), findsOneWidget);
      // Kayıtta olmayan ikon adı ekranı düşürmez.
      expect(
        tester.widget<GuEmblem>(find.byType(GuEmblem)).icon,
        ClubHeader.fallbackIcon,
      );
    });

    testWidgets('hesaba bağlanmamış danışman: satır dokunulmaz, anahtarsız', (
      tester,
    ) async {
      await _pump(
        tester,
        club: kClub.copyWith(
          advisor: const ClubAdvisorModel(name: 'Elif Aksoy', title: ''),
        ),
      );
      final advisorRow = find.widgetWithText(UserRow, 'Elif Aksoy');
      final row = tester.widget<UserRow>(advisorRow);
      expect(row.name, 'Elif Aksoy');
      expect(row.onTap, isNull);
      expect(row.actionKey, isNull);
      expect(row.chevron, isFalse);
      expect(
        find.descendant(of: advisorRow, matching: find.byType(GuIcon)),
        findsNothing,
      );
    });
  });

  group('CLB-03 · Kulüp · durum çubuğu ve güvenli alan', () {
    for (final theme in DeviceMatrix.themes) {
      testWidgets('durum çubuğu açık ikon (${theme.name}); kapak yukarı '
          'kayınca tema stili', (tester) async {
        await _pump(tester, theme: theme);
        expect(
          _statusBarStyle(tester).statusBarIconBrightness,
          Brightness.light,
        );
        expect(_statusBarStyle(tester).statusBarBrightness, Brightness.dark);

        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        expect(
          _statusBarStyle(tester).statusBarIconBrightness,
          theme == ThemeMode.dark ? Brightness.light : Brightness.dark,
        );

        // Başa dönünce yeniden açık ikon.
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 800));
        await tester.pumpAndSettle();
        expect(
          _statusBarStyle(tester).statusBarIconBrightness,
          Brightness.light,
        );
      });
    }

    testWidgets('üst güvenli alan: kapak ekranın tepesinden başlar, düğmeler '
        'güvenli alanda; sekmeler şeridin altına yapışır', (tester) async {
      const inset = 47.0;
      await _pump(tester, viewPadding: const EdgeInsets.only(top: inset));

      // Kapak 220 dp, y = 0'dan; üst çubuk `inset − 4`.
      final cover = tester.getRect(find.byType(GuParallaxHeader));
      expect(cover.top, 0);
      expect(cover.height, GuSizes.parallaxHeight);
      expect(tester.getRect(find.byKey(_back)).top, inset - 4);
      // Amblem kapağın altına 36 dp taşar.
      final emblem = tester.getRect(find.byType(GuEmblem));
      expect(emblem.top, GuSizes.parallaxHeight - 36);
      expect(emblem.height, 72);
      expect(emblem.left, 16);
      // Şerit kapak görünürken saydam.
      Opacity strip() => tester.widget<Opacity>(
        find.descendant(
          of: find.byType(PinnedHeaderSliver).first,
          matching: find.byType(Opacity),
        ),
      );
      expect(strip().opacity, 0);

      // Kaydırma sona dayanır: esneme (stretch) göstergesi çekilene kadar
      // beklenir.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(strip().opacity, 1);
      expect(tester.getRect(find.byKey(_tab(ClubDetailTab.about))).top, inset);
      expect(tester.takeException(), isNull);
    });

    testWidgets('alt güvenli alan: çubuk varken çubukta, yokken kaydırma '
        'sonunda', (tester) async {
      const inset = EdgeInsets.only(bottom: 34);
      await _pump(tester, viewPadding: inset);
      final bar = tester.getRect(find.byType(GuStickyCta));
      final join = tester.getRect(_inBar(_join));
      expect(bar.bottom, 844);
      expect(bar.bottom - join.bottom, 12 + 34);

      // Üyede çubuk yok: kaydırma sonunda güvenli alan kadar boşluk kalır.
      await _pump(tester, session: sessionWith(), viewPadding: inset);
      expect(find.byType(GuStickyCta), findsNothing);
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(tester.getRect(find.byKey(_report)).bottom, 844 - 24 - 34);
    });

    testWidgets('parallax: kapak kaydırmanın 0,4 katı kadar kayar', (
      tester,
    ) async {
      await _pump(tester);
      final header = tester.widget<GuParallaxHeader>(
        find.byType(GuParallaxHeader),
      );
      expect(header.scrollOffset.value, 0);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
      await tester.pump();
      expect(header.scrollOffset.value, greaterThan(100));
      expect(
        header.coverShift(header.scrollOffset.value),
        header.scrollOffset.value * GuSizes.parallaxFactor,
      );
    });
  });

  group('CLB-03 · Kulüp · aksiyon envanteri', () {
    testWidgets('ziyaretçi: envanterle birebir (yönetim kurulu satırları '
        'hariç — üyelik belgeleri üye olmayana okunmaz)', (tester) async {
      await _pump(tester);
      expectActionInventory(
        tester,
        'CLB-03',
        role: 'guest',
        extraExempt: _boardKeys,
      );
    });

    testWidgets('üye: yönetim kurulu satırları dahil; "Katıl" yok', (
      tester,
    ) async {
      await _pump(tester, session: sessionWith());
      expectActionInventory(
        tester,
        'CLB-03',
        role: 'member',
        extraExempt: {'CLB-03.join.*'},
      );
      for (final key in _boardKeys) {
        expect(find.byKey(GuKey.action(key)), findsOneWidget);
      }
    });

    testWidgets('yönetici ve süper admin: + "Yönetim", "Etkinlik oluştur"', (
      tester,
    ) async {
      for (final (session, role) in [
        (sessionWith(role: ClubRole.president), 'manager'),
        (kSuperSession, 'admin'),
      ]) {
        await _pump(tester, session: session);
        expectActionInventory(
          tester,
          'CLB-03',
          role: role,
          extraExempt: {'CLB-03.join.*'},
        );
        expect(find.byKey(_openManage), findsOneWidget);
        expect(find.byKey(_createEvent), findsOneWidget);
      }
    });

    testWidgets('diğer sekmeler ve kipler envanter dışı anahtar üretmez', (
      tester,
    ) async {
      // Hakkında sekmesi dışında "Hakkında" anahtarları yoktur.
      const aboutOnly = {'CLB-03.about.*', 'CLB-03.report'};
      for (final (session, tab, exempt) in [
        (kVisitorSession, ClubDetailTab.events, aboutOnly),
        (kVisitorSession, ClubDetailTab.posts, aboutOnly),
        (kVisitorSession, ClubDetailTab.members, aboutOnly),
        (sessionWith(), ClubDetailTab.members, {...aboutOnly, 'CLB-03.join.*'}),
        (
          sessionWith(status: MembershipStatus.pending),
          ClubDetailTab.posts,
          {...aboutOnly, 'CLB-03.join.*'},
        ),
      ]) {
        await _pump(tester, session: session, tab: tab);
        expectActionInventory(tester, 'CLB-03', extraExempt: exempt);
      }
    });
  });

  group('CLB-03 · Kulüp · aksiyonlar', () {
    testWidgets('geri → önceki sayfa (Kulüpler)', (tester) async {
      final router = await _pumpRoute(tester);
      expect(_location(router), '$_clubsPath/$kClubId');
      await _tapKey(tester, _back);
      await tester.pumpAndSettle();
      expect(_location(router), _clubsPath);
    });

    testWidgets('paylaş → SHT-15; "Bağlantıyı kopyala" → pano + TST-35', (
      tester,
    ) async {
      await _pumpRoute(tester);
      _feedback().nextSheetResult = ShareChoice.copyLink;
      await _tapKey(tester, _share);
      await tester.pumpAndSettle();

      expect(_feedback().sheets, [SheetId.sht15]);
      final sheet =
          _feedback().lastSheetBuilder!(
                tester.element(find.byType(ClubDetailView)),
              )
              as ShareSheet;
      expect(sheet.title, kClub.name);
      expect(sheet.url, 'https://kulupler.gumushane.edu.tr/clubs/$kClubId');
      expect(_shareService().copied, [sheet.url]);
      expect(_feedback().toasts, [ToastId.tst35]);
    });

    testWidgets('paylaş: sayfa kapatılırsa hiçbir şey olmaz; "Diğer…" → '
        'sistem paylaşımı; WhatsApp → DLG-32', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _share);
      await tester.pumpAndSettle();
      expect(_shareService().copied, isEmpty);
      expect(_feedback().toasts, isEmpty);

      _feedback().nextSheetResult = ShareChoice.other;
      await _tapKey(tester, _share);
      await tester.pumpAndSettle();
      expect(_shareService().sharedTexts, hasLength(1));

      _feedback().nextSheetResult = ShareChoice.whatsapp;
      await _tapKey(tester, _share);
      await tester.pumpAndSettle();
      expect(_feedback().dialogs, [DialogId.dlg32]);
    });

    testWidgets('menü → SHT-06 (kulüp adıyla); satırlar: paylaş → SHT-15, '
        'şikayet → SHT-10, bildirimler → SHT-07', (tester) async {
      await _pumpRoute(tester, session: sessionWith());
      await _tapKey(tester, _menu);
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht06]);
      final sheet =
          _feedback().lastSheetBuilder!(
                tester.element(find.byType(ClubDetailView)),
              )
              as ClubMenuSheet;
      expect(sheet.clubId, kClubId);
      expect(sheet.clubName, kClub.name);

      for (final (action, opened) in [
        (ClubMenuAction.share, SheetId.sht15),
        (ClubMenuAction.report, SheetId.sht10),
        (ClubMenuAction.notifications, SheetId.sht07),
      ]) {
        _feedback()
          ..sheets.clear()
          ..nextSheetResult = action;
        await _tapKey(tester, _menu);
        await tester.pumpAndSettle();
        expect(_feedback().sheets, [SheetId.sht06, opened]);
      }
    });

    testWidgets('menü → "Kulüpten ayrıl" → DLG-08 → TST-39', (tester) async {
      final session = sessionWith();
      await _pumpRoute(
        tester,
        session: session,
        seed: () => _memberships().put(session.memberships[kClubId]!),
      );
      _feedback()
        ..nextSheetResult = ClubMenuAction.leave
        ..nextDialogResult = true;
      await _tapKey(tester, _menu);
      await tester.pumpAndSettle();

      expect(_feedback().dialogs, [DialogId.dlg08]);
      expect(_feedback().dialogParams.single, {
        DialogParamKeys.club: kClub.name,
      });
      expect(_feedback().toasts, [ToastId.tst39]);
      expect(
        _memberships().memberships['${kClubId}_$kUid']?.status,
        MembershipStatus.left,
      );
    });

    testWidgets('menü: "Kulüp ayarları" → MGT-09 (T-36, W-13); "Üyeler" → '
        'CLB-06', (tester) async {
      final router = await _pumpRoute(
        tester,
        session: sessionWith(role: ClubRole.board),
      );
      _feedback().nextSheetResult = ClubMenuAction.settings;
      await _tapKey(tester, _menu);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_location(router), '$_clubsPath/$kClubId/manage/settings');
      router.go('$_clubsPath/$kClubId');
      await tester.pumpAndSettle();

      _feedback().nextSheetResult = ClubMenuAction.members;
      await _tapKey(tester, _menu);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_location(router), '$_clubsPath/$kClubId/members');
    });

    testWidgets('şikayet → SHT-10 (hedef kulüp) → DLG-12; sayfa kapatılırsa '
        'dialog yok', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _report);
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht10]);
      expect(_feedback().dialogs, isEmpty);
      final sheet =
          _feedback().lastSheetBuilder!(
                tester.element(find.byType(ClubDetailView)),
              )
              as ReportReasonSheet;
      const target = (
        type: ReportTargetType.club,
        id: kClubId,
        clubId: kClubId,
      );
      expect(sheet.target, target);
      expect(sheet.onSubmit, isNotNull);

      _feedback().nextSheetResult = const ReportReasonResult(
        target: target,
        reason: ReportReason.spam,
      );
      await _tapKey(tester, _report);
      await tester.pumpAndSettle();
      expect(_feedback().dialogs, [DialogId.dlg12]);
    });

    testWidgets('"Katıl" (onay gerekli) → SHT-05; başvuru yazıldı → CLB-04', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      await _tap(tester, _inBar(_join));
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht05]);
      expect(_location(router), '$_clubsPath/$kClubId');
      expect(_memberships().applied, isEmpty);

      _feedback().nextSheetResult = JoinApplicationOutcome.applied;
      await _tap(tester, _inBar(_join));
      await tester.pumpAndSettle();
      expect(_location(router), '$_clubsPath/$kClubId/applied');
    });

    testWidgets('"Katıl": SHT-05 katılımla kapanırsa TST-34', (tester) async {
      await _pumpRoute(tester);
      _feedback().nextSheetResult = JoinApplicationOutcome.joined;
      await _tap(tester, _inBar(_join));
      await tester.pumpAndSettle();
      expect(_feedback().toasts, [ToastId.tst34]);
      expect(_feedback().hasToastAction, isTrue);
    });

    testWidgets('"Katıl" (anında katılım) → doğrudan katılır: TST-34 '
        '("Kulübe git"), sayfa açılmaz, üye sayısı artar', (tester) async {
      final router = await _pumpRoute(
        tester,
        club: kClub.copyWith(approvalRequired: false),
      );
      await _tap(tester, _inBar(_join));
      await tester.pumpAndSettle();

      expect(_feedback().sheets, isEmpty);
      expect(_feedback().toasts, [ToastId.tst34]);
      expect(_memberships().applied.single.status, MembershipStatus.active);
      expect(_stateOf(tester).club?.memberCount, kClub.memberCount + 1);
      expect(
        find.text(tester.l10n.clubsCardMembers(kClub.memberCount + 1)),
        findsOneWidget,
      );
      // "Kulübe git": aynı kulüp sayfası.
      _feedback().tapToastAction();
      await tester.pumpAndSettle();
      expect(_location(router), '$_clubsPath/$kClubId');
    });

    testWidgets('başvurular kapalı: devre dışı düğme + not; dokunma → '
        'TST-X1', (tester) async {
      await _pumpRoute(
        tester,
        club: kClub.copyWith(applicationsOpen: false),
      );
      final l10n = tester.l10n;
      final closed = _button(tester, _inBar(_join));
      expect(closed.label, l10n.clubsCardClosed);
      expect(closed.disabled, isTrue);
      expect(closed.variant, GuButtonVariant.outline);
      expect(find.text(l10n.clubClosedNote), findsOneWidget);

      await _tap(tester, _inBar(_join));
      expect(_feedback().toasts, [ToastId.tstX1]);
      expect(_feedback().sheets, isEmpty);
    });

    testWidgets('bekleyen başvuru: "İstek gönderildi" → CLB-05', (
      tester,
    ) async {
      final router = await _pumpRoute(
        tester,
        session: sessionWith(status: MembershipStatus.pending),
      );
      final status = _button(tester, _inBar(_status));
      expect(status.label, tester.l10n.clubsCardPending);
      expect(status.icon, GuIcons.hourglass);
      await _tap(tester, _inBar(_status));
      await tester.pumpAndSettle();
      expect(_location(router), '$_clubsPath/$kClubId/application');
    });

    testWidgets('üye sayısı → Üyeler sekmesi', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _memberCount);
      expect(_stateOf(tester).tab, ClubDetailTab.members);
      expect(find.byType(ClubLockedTab), findsOneWidget);
      expect(find.byType(ClubAboutTab), findsNothing);
    });

    testWidgets('sekmeler: her biri kendi gövdesini açar', (tester) async {
      await _pumpRoute(tester, session: sessionWith());
      for (final (tab, body) in [
        (ClubDetailTab.events, ClubEventsTab),
        (ClubDetailTab.posts, ClubFeedTab),
        (ClubDetailTab.members, ClubMembersTab),
        (ClubDetailTab.about, ClubAboutTab),
      ]) {
        await _tapKey(tester, _tab(tab));
        expect(_stateOf(tester).tab, tab);
        expect(find.byType(body), findsOneWidget);
        expect(tester.widget<GuTabs>(find.byType(GuTabs)).value, tab.name);
      }
    });

    testWidgets('rota `?tab=` ilk sekmeyi seçer; tanınmayan değer Hakkında', (
      tester,
    ) async {
      await _pumpRoute(tester, query: '?tab=events');
      expect(_stateOf(tester).tab, ClubDetailTab.events);
      expect(find.byType(ClubEventsTab), findsOneWidget);

      await _pumpRoute(tester, query: '?tab=bilinmeyen');
      expect(_stateOf(tester).tab, ClubDetailTab.about);
    });

    testWidgets('açık ekranda `?tab=` değişirse sekme de değişir', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      router.go('$_clubsPath/$kClubId?tab=members');
      await tester.pumpAndSettle();
      expect(_stateOf(tester).tab, ClubDetailTab.members);
    });

    testWidgets('"Devamı" tanıtım metnini açar ve kaybolur; sekme değişse de '
        'açık kalır', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _more);
      expect(find.byKey(_more), findsNothing);
      expect(tester.widget<Text>(find.text(kClub.about)).maxLines, isNull);

      await _tapKey(tester, _tab(ClubDetailTab.events));
      await _tapKey(tester, _tab(ClubDetailTab.about));
      expect(find.byKey(_more), findsNothing);
    });

    testWidgets('bağlantılar → DLG-32 → adres açılır (e-posta, Instagram, '
        'web)', (tester) async {
      await _pumpRoute(tester);
      _feedback().dialogResults[DialogId.dlg32] = true;
      for (final key in [_linkEmail, _linkInstagram, _linkWeb]) {
        await _tapKey(tester, key);
        await tester.pumpAndSettle();
      }
      expect(_feedback().dialogs, List.filled(3, DialogId.dlg32));
      expect(_launcher().opened.map((uri) => uri.toString()), [
        'mailto:${kClub.social.email}',
        'https://instagram.com/guk_doga',
        kClub.social.web,
      ]);
      expect(_feedback().toasts, isEmpty);
    });

    testWidgets('e-posta cihazda açılamazsa adres kopyalanır → TST-08', (
      tester,
    ) async {
      await _pumpRoute(tester);
      _feedback().dialogResults[DialogId.dlg32] = true;
      _launcher().canOpen = false;
      await _tapKey(tester, _linkEmail);
      await tester.pumpAndSettle();
      expect(_shareService().copied, [kClub.social.email]);
      expect(_feedback().toasts, [ToastId.tst08]);
    });

    testWidgets('kişi satırı (danışman, yönetim kurulu) → CLB-07, kulüp '
        'bağlamıyla (`?clubId=`)', (tester) async {
      for (final userId in [_advisorId, kPresident.userId]) {
        final router = await _pumpRoute(tester, session: sessionWith());
        expect(_rowOf(tester, _person(userId)).onTap, isNotNull);
        await _tapKey(tester, _person(userId));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          _location(router),
          '$_clubsPath/user/$userId?clubId=$kClubId',
        );
        expect(_feedback().calls, isEmpty);
      }
    });

    testWidgets('Üyeler sekmesi: önizleme satırı → CLB-07; "Tüm üyeler" → '
        'CLB-06', (tester) async {
      var router = await _pumpRoute(
        tester,
        session: sessionWith(),
        query: '?tab=members',
      );
      final first = tester.widget<MemberRow>(find.byType(MemberRow).first);
      final userId = first.membership.userId;
      await _tapKey(tester, _member(userId));
      await tester.pumpAndSettle();
      expect(_location(router), '$_clubsPath/user/$userId?clubId=$kClubId');

      router = await _pumpRoute(
        tester,
        session: sessionWith(),
        query: '?tab=members',
      );
      await _tapKey(tester, _allMembers);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_location(router), '$_clubsPath/$kClubId/members');
    });

    testWidgets('etkinlik dilimi: "Geçmiş" seçilir', (tester) async {
      await _pumpRoute(tester, query: '?tab=events');
      GuSegmented segmented() =>
          tester.widget<GuSegmented>(find.byType(GuSegmented));
      expect(segmented().value, ClubEventSegment.upcoming.name);
      await _tapKey(tester, _segment(ClubEventSegment.past));
      expect(segmented().value, ClubEventSegment.past.name);
      await _tapKey(tester, _segment(ClubEventSegment.upcoming));
      expect(segmented().value, ClubEventSegment.upcoming.name);
    });

    testWidgets('yönetici düğmeleri: "Etkinlik oluştur" → MGT-05 (W-17); '
        '"Yönetim" → MGT-01 (W-12)', (tester) async {
      final router = await _pumpRoute(
        tester,
        session: sessionWith(role: ClubRole.board),
        query: '?tab=members',
      );
      await _tapKey(tester, _createEvent);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_location(router), '$_clubsPath/$kClubId/manage/events/new');
      router.go('$_clubsPath/$kClubId?tab=members');
      await tester.pumpAndSettle();
      await _tapKey(tester, _openManage);
      await tester.pumpAndSettle();
      expect(_location(router), '$_clubsPath/$kClubId/manage');
    });
  });

  group('CLB-03 · Kulüp · durumlar', () {
    testWidgets('yükleniyor: başlık çubuğu + iskelet; içerik ve alt çubuk '
        'yok', (tester) async {
      await _pump(tester, state: const ClubDetailState(isFetching: true));
      final l10n = tester.l10n;
      final bar = tester.widget<GuAppBar>(find.byType(GuAppBar));
      expect(bar.title, l10n.clubTitle);
      expect(bar.backActionKey, _back);
      final skeleton = tester.widget<GuSkeletonList>(
        find.byType(GuSkeletonList),
      );
      expect(skeleton.variant, GuSkeletonVariant.card);
      expect(skeleton.count, 3);
      expect(skeleton.semanticLabel, l10n.commonLoading);
      expect(find.byType(ClubHeader), findsNothing);
      expect(find.byType(GuStickyCta), findsNothing);
      expect(find.byType(GuErrorState), findsNothing);
      // Kapak yokken durum çubuğu tema stilindedir.
      expect(
        find.descendant(
          of: find.byType(ClubDetailView),
          matching: find.byType(GuSystemUi),
        ),
        findsNothing,
      );
    });

    testWidgets('hata: "Bir şeyler ters gitti" + "Yeniden dene"; hata '
        'yükleniyordan önce gelir', (tester) async {
      await _pump(
        tester,
        state: const ClubDetailState(isError: true, isFetching: true),
      );
      final l10n = tester.l10n;
      final error = tester.widget<GuErrorState>(find.byType(GuErrorState));
      expect(error.title, l10n.sysErrorTitle);
      expect(error.description, l10n.sysErrorDesc);
      expect(error.retryLabel, l10n.commonRetry);
      expect(find.byType(GuSkeletonList), findsNothing);
      expect(find.byType(GuAppBar), findsOneWidget);
      expect(find.byType(ClubHeader), findsNothing);
    });

    testWidgets('hata → "Yeniden dene" kulübü yeniden okur', (tester) async {
      final router = await _pumpRoute(
        tester,
        seed: () => _clubs().failNext(FirestoreError.unavailable),
      );
      expect(find.byType(GuErrorState), findsOneWidget);
      expect(_location(router), '$_clubsPath/$kClubId');

      await tester.tap(find.text(tester.l10n.commonRetry));
      await tester.pumpAndSettle();
      expect(find.byType(GuErrorState), findsNothing);
      expect(find.byType(ClubHeader), findsOneWidget);
      expect(_clubs().callsTo('getClub'), hasLength(2));
    });

    testWidgets('hata görünümünde geri çalışır', (tester) async {
      final router = await _pumpRoute(
        tester,
        seed: () => _clubs().failNext(FirestoreError.unknown),
      );
      await _tapKey(tester, _back);
      await tester.pumpAndSettle();
      expect(_location(router), _clubsPath);
    });

    testWidgets('kulüp yok → SYS-04', (tester) async {
      final router = await _pumpRoute(tester, withClub: false);
      expect(_location(router), '/not-found');
      expect(find.byType(ClubDetailView), findsNothing);
    });

    testWidgets('silinmiş kulüp → SYS-04', (tester) async {
      final router = await _pumpRoute(
        tester,
        club: kClub.copyWith(isDeleted: true),
      );
      expect(_location(router), '/not-found');
    });

    testWidgets('yok durumu: geçiş karesinde boş zemin (iskelet / hata yok)', (
      tester,
    ) async {
      // Yönlendirme rota gerektirir; burada yalnızca gövde denetlenir.
      await tester.pumpApp(
        clubDetailView(),
        overrides: _overrides(
          kVisitorSession,
          state: const ClubDetailState(isFetching: true),
        ),
      );
      ProviderScope.containerOf(
            tester.element(find.byType(ClubDetailView)),
          )
          .read(clubDetailViewModelProvider(kClubId).notifier)
          .state = const ClubDetailState(
        isNotFound: true,
      );
      await tester.pump();
      expect(find.byType(GuSkeletonList), findsNothing);
      expect(find.byType(GuErrorState), findsNothing);
      expect(find.byType(ClubHeader), findsNothing);
      // Rota olmadığı için yönlendirme denemesi düşer (beklenen).
      expect(tester.takeException(), isNotNull);
    });

    testWidgets('çevrimdışı: içerik ekranda kalır; "Katıl" → TST-24, '
        'yazılmaz', (tester) async {
      await _pumpRoute(
        tester,
        club: kClub.copyWith(approvalRequired: false),
      );
      _connectivity().isOffline = true;
      await _tap(tester, _inBar(_join));
      await tester.pumpAndSettle();

      expect(_feedback().toasts, [ToastId.tst24]);
      expect(_memberships().applied, isEmpty);
      expect(find.byType(ClubHeader), findsOneWidget);
      expect(find.byType(ClubAboutTab), findsOneWidget);
    });

    testWidgets('Etkinlikler sekmesi boş durumu: dilim + ziyaretçi bandı + '
        '"Etkinlik yok"', (tester) async {
      await _pump(tester, tab: ClubDetailTab.events);
      final l10n = tester.l10n;
      final segmented = tester.widget<GuSegmented>(find.byType(GuSegmented));
      expect(segmented.options.map((o) => o.label), [
        l10n.eventUpcoming,
        l10n.eventPast,
      ]);
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.text, l10n.clubEventsVisitorNote);
      expect(banner.kind, GuBannerKind.info);
      expect(banner.icon, GuIcons.lock);
      final empty = tester.widget<GuEmptyState>(find.byType(GuEmptyState));
      expect(empty.illustration, GuIllustrations.emptyEvents);
      expect(empty.title, l10n.eventEmptyTitle);
      expect(empty.compact, isTrue);

      // Kulübün içini görende bant yok.
      await _pump(tester, session: sessionWith(), tab: ClubDetailTab.events);
      expect(find.byType(GuBanner), findsNothing);
    });
  });

  group('CLB-03 · Kulüp · etkinlikler sekmesi (W-15)', () {
    /// `c03` etkinlikleri: `e03` (yaklaşan, dolu), `e16` (üyelere özel),
    /// `e19` (geçmiş), `e22` (taslak).
    void seedEvents() =>
        EventModelFixtures.ofClub(kClubId).forEach(_events().put);

    Key card(String id) => GuKey.action('CLB-03.card.$id');
    Key join(String id) => GuKey.action('CLB-03.join.$id');

    testWidgets('ziyaretçi: yaklaşan dilimde herkese açık kartlar '
        '(kompakt, kulüp satırı yok); geçmiş dilimde biten etkinlik', (
      tester,
    ) async {
      await _pumpRoute(tester, seed: seedEvents, query: '?tab=events');
      expect(find.byKey(card('e03')), findsOneWidget);
      expect(find.byKey(card('e16')), findsNothing); // üyelere özel
      expect(find.byKey(card('e19')), findsNothing); // geçmiş
      final e03 = tester.widget<EventCard>(find.byType(EventCard).first);
      expect(e03.compact, isTrue);
      expect(e03.showClub, isFalse);
      expect(e03.status, EventCardStatus.full);
      expect(e03.quickAction?.kind, EventCtaKind.joinWaitlist);

      await _tapKey(tester, _segment(ClubEventSegment.past));
      expect(find.byKey(card('e19')), findsOneWidget);
      expect(find.byKey(card('e03')), findsNothing);
      expect(find.byKey(card('e22')), findsNothing); // taslak
      expect(
        tester.widget<EventCard>(find.byType(EventCard)).status,
        EventCardStatus.past,
      );
    });

    testWidgets('üye: üyelere özel etkinlik de listelenir; bant yok', (
      tester,
    ) async {
      await _pumpRoute(
        tester,
        session: sessionWith(),
        seed: seedEvents,
        query: '?tab=events',
      );
      expect(find.byKey(card('e16')), findsOneWidget);
      expect(find.byType(GuBanner), findsNothing);
    });

    testWidgets('kart → EVT-02 (go); "Bekleme listesine katıl" akış '
        'verilmemişse EVT-02', (tester) async {
      var router = await _pumpRoute(
        tester,
        seed: seedEvents,
        query: '?tab=events',
      );
      await _tapKey(tester, card('e03'));
      await tester.pumpAndSettle();
      expect(_location(router), '/events/e03');

      router = await _pumpRoute(tester, seed: seedEvents, query: '?tab=events');
      await _tapKey(tester, join('e03'));
      await tester.pumpAndSettle();
      expect(_location(router), '/events/e03');
    });

    testWidgets('kayıtlıysa "Biletini göster" → EVT-03', (tester) async {
      final router = await _pumpRoute(
        tester,
        seed: () {
          seedEvents();
          _rsvps().put(
            RsvpModelFixtures.e01Mehmet.copyWith(
              id: FirestoreIds.rsvp('e03', kUid),
              eventId: 'e03',
              clubId: kClubId,
            ),
          );
        },
        query: '?tab=events',
      );
      expect(
        tester.widget<EventCard>(find.byType(EventCard).first).status,
        EventCardStatus.going,
      );
      await _tapKey(tester, join('e03'));
      await tester.pumpAndSettle();
      expect(_location(router), '/events/e03/ticket');
    });

    testWidgets('"Katıl" / "Bekleme listesine katıl" rotanın akışına gider; '
        'değiştiyse sekme yeniden okunur', (tester) async {
      final calls = <(String, EventCtaKind)>[];
      // `e03` yaklaşan; kontenjansız kopyası "Katıl" çizer.
      final full = EventModelFixtures.e03;
      final open = full.copyWith(id: 'e90', clearCapacity: true);
      await tester.pumpApp(
        ClubDetailView(
          clubId: kClubId,
          tab: ClubDetailTab.events,
          eventJoinFlow: (context, event, kind) async {
            calls.add((event.id, kind));
            // Yalnızca bekleme listesine katılım kaydı değiştirmiş olsun.
            return event.id == full.id;
          },
        ),
        overrides: _overrides(
          kVisitorSession,
          state: loadedState(
            kVisitorSession,
            base: ClubDetailState(
              tab: ClubDetailTab.events,
              events: [open, full],
            ),
          ),
        ),
      );
      await tester.pump();
      await _tapKey(tester, join(open.id));
      expect(calls, [(open.id, EventCtaKind.join)]);
      expect(_events().callsTo('listClubEvents'), isEmpty);

      await _tapKey(tester, join(full.id));
      await tester.pump();
      expect(calls.last, (full.id, EventCtaKind.joinWaitlist));
      expect(_events().callsTo('listClubEvents'), hasLength(1));
    });

    testWidgets('TST-X2: "Kayıtlar kapalı" (devre dışı) dokunması', (
      tester,
    ) async {
      final closed = EventModelFixtures.e03.copyWith(
        clearCapacity: true,
        registrationOpen: false,
      );
      await _pump(
        tester,
        state: loadedState(
          kVisitorSession,
          base: ClubDetailState(tab: ClubDetailTab.events, events: [closed]),
        ),
      );
      final button = tester.widget<GuButton>(find.byKey(join(closed.id)));
      expect(button.disabled, isTrue);
      await _tapKey(tester, join(closed.id));
      expect(_feedback().toasts, [ToastId.tstX2]);
    });

    testWidgets('yükleniyor: 3 kart iskeleti; hata: satır içi hata → '
        '"Yeniden dene" sekmeyi yeniden okur', (tester) async {
      await _pump(
        tester,
        state: loadedState(
          kVisitorSession,
          base: const ClubDetailState(
            tab: ClubDetailTab.events,
            isEventsFetching: true,
          ),
        ),
      );
      final skeleton = tester.widget<GuSkeletonList>(
        find.byType(GuSkeletonList),
      );
      expect(skeleton.count, ClubEventsTab.skeletonCount);
      expect(skeleton.variant, GuSkeletonVariant.card);

      await _pumpRoute(
        tester,
        seed: () {
          seedEvents();
          _events().failNext(FirestoreError.unavailable);
        },
        query: '?tab=events',
      );
      expect(find.byType(GuErrorState), findsOneWidget);
      await _tapKey(tester, GuKey.action('CLB-03.eventsRetry'));
      await tester.pumpAndSettle();
      expect(find.byType(GuErrorState), findsNothing);
      expect(find.byKey(card('e03')), findsOneWidget);
    });

    testWidgets('aksiyon envanteri: kartlar envanter dışı anahtar üretmez', (
      tester,
    ) async {
      await _pumpRoute(tester, seed: seedEvents, query: '?tab=events');
      expectActionInventory(
        tester,
        'CLB-03',
        extraExempt: {'CLB-03.about.*', 'CLB-03.report'},
      );
    });

    testWidgets('cihaz matrisi: dolu etkinlikler sekmesi', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => clubDetailView(tab: ClubDetailTab.events),
        overrides: _overrides(
          kVisitorSession,
          state: loadedState(
            kVisitorSession,
            base: ClubDetailState(
              tab: ClubDetailTab.events,
              events: EventModelFixtures.ofClub(kClubId),
            ),
          ),
        ),
      );
    });
  });

  group('CLB-03 · Kulüp · kip görünümleri', () {
    testWidgets('ziyaretçi: Gönderiler ve Üyeler kilitli (kilit 100, '
        'açıklama, orta boy "Katıl")', (tester) async {
      for (final tab in [ClubDetailTab.posts, ClubDetailTab.members]) {
        await _pump(tester, tab: tab);
        final l10n = tester.l10n;
        final locked = tester.widget<ClubLockedTab>(
          find.byType(ClubLockedTab),
        );
        expect(
          locked.text,
          tab == ClubDetailTab.posts
              ? l10n.clubPostsLocked
              : l10n.clubMembersLocked(kClub.memberCount),
        );
        final illustration = tester.widget<GuIllustration>(
          find.byType(GuIllustration),
        );
        expect(illustration.illustration, GuIllustrations.locked);
        expect(illustration.size, 100);
        // Aynı anahtarla iki "Katıl": kilitli blokta orta, alt çubukta büyük.
        final joins = tester.widgetList<GuButton>(find.byKey(_join)).toList();
        expect(joins.map((b) => b.size), [GuButtonSize.md, GuButtonSize.lg]);
        expect(joins.map((b) => b.full), [false, true]);
        expect(find.byType(ClubFeedTab), findsNothing);
        expect(find.byType(ClubMembersTab), findsNothing);
      }
    });

    testWidgets('kilitli bloktaki "Katıl" da katılım akışını başlatır', (
      tester,
    ) async {
      await _pumpRoute(tester, query: '?tab=posts');
      await _tap(
        tester,
        find.descendant(
          of: find.byType(ClubLockedTab),
          matching: find.byKey(_join),
        ),
      );
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht05]);
    });

    testWidgets('reddedilen: "Reddedildi"; bekleme sürüyorsa tarihli not', (
      tester,
    ) async {
      final retryAfter = kDefaultFakeNowUtc.add(const Duration(days: 3));
      await _pump(
        tester,
        session: sessionWith(
          status: MembershipStatus.rejected,
          retryAfter: retryAfter,
        ),
      );
      final l10n = tester.l10n;
      final status = _button(tester, _inBar(_status));
      expect(status.label, l10n.clubsCardRejected);
      expect(status.icon, GuIcons.circleX);
      expect(status.variant, GuButtonVariant.tonal);
      expect(
        find.text(l10n.applicationRetryAt('15 Ekim 2026')),
        findsOneWidget,
      );

      // Bekleme dolmuşsa not yok.
      await _pump(
        tester,
        session: sessionWith(
          status: MembershipStatus.rejected,
          retryAfter: kDefaultFakeNowUtc.subtract(const Duration(days: 1)),
        ),
      );
      expect(find.textContaining('2026'), findsNothing);
      expect(_button(tester, _inBar(_status)).label, l10n.clubsCardRejected);
    });

    testWidgets('çıkarılan: "Çıkarıldın"; not satırı yok', (tester) async {
      await _pump(
        tester,
        session: sessionWith(
          status: MembershipStatus.removed,
          retryAfter: kDefaultFakeNowUtc.add(const Duration(days: 3)),
        ),
      );
      final status = _button(tester, _inBar(_status));
      expect(status.label, tester.l10n.clubsCardRemoved);
      expect(status.icon, GuIcons.userX);
      expect(find.textContaining('2026'), findsNothing);
      // Çıkarılan kullanıcı kulübün içini görmez: avatar grubu
      // yöneticilerdendir (CD-139).
      expect(find.byType(GuAvatarGroup), findsOneWidget);
    });

    testWidgets('üye: rol rozeti, avatar grubu (+N), yönetim kurulu; alt '
        'çubuk yok; sekmeler açık', (tester) async {
      await _pump(tester, session: sessionWith());
      final l10n = tester.l10n;

      final role = tester.widget<GuRoleBadge>(
        find.descendant(
          of: find.byType(ClubHeader),
          matching: find.byType(GuRoleBadge),
        ),
      );
      expect(role.kind, GuRoleBadgeKind.member);
      expect(role.label, l10n.roleMember);
      final group = tester.widget<GuAvatarGroup>(find.byType(GuAvatarGroup));
      expect(group.avatars.map((a) => a.initials), ['BŞ', 'DY', 'EY', 'EU']);
      expect(group.moreLabel, '+${kClub.memberCount - 4}');
      expect(group.size, 28);
      expect(find.byType(GuStickyCta), findsNothing);
      expect(find.byType(ClubCta), findsNothing);
      expect(find.byType(GuBanner), findsNothing);

      // Yönetim kurulu: başkan önde, rol rozeti + bölüm · sınıf.
      expect(find.text(l10n.clubBoard), findsOneWidget);
      final rows = tester.widgetList<UserRow>(find.byType(UserRow)).toList();
      expect(rows.map((r) => r.name), [
        'Doç. Dr. Hakan Yalçın',
        'Burak Şahin',
        'Emre Yavuz',
        'Ebru Uslu',
        'Eren Kaya',
        'Furkan Yılmaz',
        'Zeynep Yılmaz',
      ]);
      expect((rows[1].badge! as GuRoleBadge).kind, GuRoleBadgeKind.president);
      expect((rows[2].badge! as GuRoleBadge).kind, GuRoleBadgeKind.board);
      expect(rows[1].sub, contains(' · '));
      expect(rows.every((r) => r.inCard && r.chevron), isTrue);

      await _pump(tester, session: sessionWith(), tab: ClubDetailTab.posts);
      final feed = tester.widget<GuEmptyState>(find.byType(GuEmptyState));
      expect(feed.illustration, GuIllustrations.emptyPosts);
      expect(feed.title, l10n.feedEmptyTitle);

      // Üyeler sekmesi: sayı · önizleme satırları (`MemberRow`, tam
      // genişlik, kart dışı, oksuz) · "Tüm üyeler".
      await _pump(tester, session: sessionWith(), tab: ClubDetailTab.members);
      expect(find.text(l10n.clubsCardMembers(kClub.memberCount)), findsWidgets);
      final preview = loadedState(sessionWith()).memberPreview;
      final members = tester
          .widgetList<MemberRow>(find.byType(MemberRow))
          .toList();
      expect(members.map((m) => m.membership), preview);
      for (final member in members) {
        expect(member.actionKey, _member(member.membership.userId));
        expect(member.onTap, isNotNull);
        expect(member.onMenu, isNull);
        expect(member.inCard, isFalse);
        expect(member.chevron, isFalse);
      }
      expect(
        tester.getSize(find.byType(MemberRow).first).width,
        tester.getSize(find.byType(ClubMembersTab)).width,
      );
      final all = _button(tester, find.byKey(_allMembers));
      expect(all.label, l10n.clubAllMembers);
      expect(all.variant, GuButtonVariant.outline);
      expect(all.iconTrailing, GuIcons.arrowRight);
      expect(all.full, isTrue);
    });

    for (final (name, session, badge) in [
      (
        'yönetim kurulu',
        sessionWith(role: ClubRole.board),
        GuRoleBadgeKind.board,
      ),
      (
        'başkan',
        sessionWith(role: ClubRole.president),
        GuRoleBadgeKind.president,
      ),
      ('süper admin', kSuperSession, null),
    ]) {
      testWidgets('$name: "Yönetim" + tonal "Etkinlik oluştur"', (
        tester,
      ) async {
        await _pump(tester, session: session);
        final l10n = tester.l10n;
        final manage = _button(tester, find.byKey(_openManage));
        expect(manage.label, l10n.clubCtaManage);
        expect(manage.icon, GuIcons.layoutGrid);
        expect(manage.variant, GuButtonVariant.primary);
        final create = _button(tester, find.byKey(_createEvent));
        expect(create.label, l10n.clubCtaCreateEvent);
        expect(create.icon, GuIcons.calendarPlus);
        expect(create.variant, GuButtonVariant.tonal);
        // İki düğme çubuğu eşit paylaşır.
        expect(
          tester.getSize(find.byKey(_openManage)).width,
          tester.getSize(find.byKey(_createEvent)).width,
        );
        expect(find.byType(ClubCta), findsNothing);
        final roles = tester.widgetList<GuRoleBadge>(
          find.descendant(
            of: find.byType(ClubHeader),
            matching: find.byType(GuRoleBadge),
          ),
        );
        expect(roles.map((r) => r.kind), [?badge]);
        expect(find.text(l10n.clubBoard), findsOneWidget);
      });
    }

    testWidgets('danışman: salt okunur bandı + tonal "Yönetimi görüntüle"', (
      tester,
    ) async {
      await _pump(tester, session: sessionWith(role: ClubRole.advisor));
      final l10n = tester.l10n;
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.readonly);
      expect(banner.text, l10n.mgtReadOnlyBanner);
      final view = _button(tester, find.byKey(_openManage));
      expect(view.label, l10n.clubCtaViewManage);
      expect(view.icon, GuIcons.eye);
      expect(view.variant, GuButtonVariant.tonal);
      expect(find.byKey(_createEvent), findsNothing);
      expect(
        tester
            .widget<GuRoleBadge>(
              find.descendant(
                of: find.byType(ClubHeader),
                matching: find.byType(GuRoleBadge),
              ),
            )
            .kind,
        GuRoleBadgeKind.advisor,
      );
      // Bant kapağın hemen altında; amblem bandın üstüne taşar.
      expect(
        tester.getRect(find.byType(GuBanner)).top,
        GuSizes.parallaxHeight,
      );
    });

    testWidgets('askıdaki kulüp: uyarı bandı, alt çubuk yok; kilitli blokta '
        '"Askıda" rozeti', (tester) async {
      final suspended = kClub.copyWith(status: ClubStatus.suspended);
      await _pump(tester, club: suspended);
      final l10n = tester.l10n;
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.warning);
      expect(banner.icon, GuIcons.ban);
      expect(banner.text, l10n.clubSuspendedBanner);
      expect(find.byType(GuStickyCta), findsNothing);
      expect(find.byKey(_join), findsNothing);

      await _pump(tester, club: suspended, tab: ClubDetailTab.members);
      expect(
        find.descendant(
          of: find.byType(ClubLockedTab),
          matching: find.widgetWithText(GuBadge, l10n.statusSuspended),
        ),
        findsOneWidget,
      );

      // Yöneticide de çubuk yok.
      await _pump(
        tester,
        club: suspended,
        session: sessionWith(role: ClubRole.board),
      );
      expect(find.byType(GuStickyCta), findsNothing);
    });

    testWidgets('üyelik onaylanınca görünüm canlı değişir (ziyaretçi → üye)', (
      tester,
    ) async {
      await _pumpRoute(
        tester,
        session: sessionWith(status: MembershipStatus.pending),
      );
      expect(find.byType(GuStickyCta), findsOneWidget);
      // Yönetim kurulu ve avatar grubu başvurana da görünür (CD-139).
      expect(find.byType(GuAvatarGroup), findsOneWidget);
      expect(find.text(tester.l10n.clubBoard), findsOneWidget);

      ProviderScope.containerOf(
        tester.element(find.byType(ClubDetailView)),
      ).read(sessionViewModelProvider.notifier).state = sessionWith();
      await tester.pumpAndSettle();
      expect(find.byType(GuStickyCta), findsNothing);
      expect(find.byType(GuAvatarGroup), findsOneWidget);
      expect(find.text(tester.l10n.clubBoard), findsOneWidget);
    });
  });

  group('CLB-03 · Kulüp · cihaz matrisi', () {
    Widget view(BuildContext _) => clubDetailView();

    testWidgets('ziyaretçi (Hakkında) + güvenli alan varyantları', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(kVisitorSession),
        safeAreas: true,
      );
    });

    testWidgets('üye (Hakkında: avatar grubu + yönetim kurulu)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(sessionWith(role: ClubRole.board)),
        safeAreas: true,
      );
    });

    for (final tab in [
      ClubDetailTab.events,
      ClubDetailTab.posts,
      ClubDetailTab.members,
    ]) {
      testWidgets('ziyaretçi · ${tab.name} sekmesi', (tester) async {
        await DeviceMatrix.run(
          tester,
          view,
          overrides: _overrides(
            kVisitorSession,
            state: loadedState(
              kVisitorSession,
              base: ClubDetailState(tab: tab),
            ),
          ),
        );
      });
    }

    testWidgets('üye · üyeler ve gönderiler sekmesi', (tester) async {
      for (final tab in [ClubDetailTab.members, ClubDetailTab.posts]) {
        await DeviceMatrix.run(
          tester,
          view,
          overrides: _overrides(
            sessionWith(),
            state: loadedState(sessionWith(), base: ClubDetailState(tab: tab)),
          ),
        );
      }
    });

    testWidgets('reddedilen (bekleme notu), danışman (bant), başvurular '
        'kapalı, askıdaki kulüp', (tester) async {
      final rejected = sessionWith(
        status: MembershipStatus.rejected,
        retryAfter: kDefaultFakeNowUtc.add(const Duration(days: 3)),
      );
      final advisor = sessionWith(role: ClubRole.advisor);
      for (final overrides in [
        _overrides(rejected),
        _overrides(advisor),
        _overrides(
          kVisitorSession,
          state: loadedState(
            kVisitorSession,
            club: kClub.copyWith(applicationsOpen: false),
          ),
        ),
        _overrides(
          kVisitorSession,
          state: loadedState(
            kVisitorSession,
            club: kClub.copyWith(status: ClubStatus.suspended),
          ),
        ),
      ]) {
        await DeviceMatrix.run(tester, view, overrides: overrides);
      }
    });

    testWidgets('yükleniyor ve hata', (tester) async {
      for (final state in const [
        ClubDetailState(isFetching: true),
        ClubDetailState(isError: true),
      ]) {
        await DeviceMatrix.run(
          tester,
          view,
          overrides: _overrides(kVisitorSession, state: state),
          safeAreas: true,
        );
      }
    });
  });

  group('CLB-03 · Kulüp · golden', () {
    // Referans görüntüdeki üye sayısı (prototip verisi); fixture'daki sayı
    // tohum dönüşümünün gerçek üyelik sayımıdır.
    final reference = kClub.copyWith(memberCount: 231);

    testWidgets('varsayılan (ziyaretçi) açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'CLB-03',
        clubDetailView(),
        overrides: _overrides(
          kVisitorSession,
          state: loadedState(kVisitorSession, club: reference),
        ),
      );
    });

    testWidgets('üye (avatar grubu + rol rozeti) açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'CLB-03__member',
        clubDetailView(),
        overrides: _overrides(
          sessionWith(),
          state: loadedState(sessionWith(), club: reference),
        ),
      );
    });
  });
}
