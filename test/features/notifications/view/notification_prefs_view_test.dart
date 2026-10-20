// NTF-02 · Bildirim tercihleri — içerik (izin kartı, tür anahtarları,
// hatırlatma zamanı, sessiz saatler, kulüp bazlı ayarlar), durumlar
// (yükleniyor, hata, kulüpsüz, izin açık, yönetici, sessiz saat açık),
// aksiyon envanteri, aksiyon sonuçları (anahtar → yama + TST-19, dilim,
// SHT-29 → aralık, izin → DLG-03, kulüp → SHT-07 / CLB-03, geri → NTF-01),
// cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/NTF-02__*.webp,
// design/prototype/app/screens-events.js:108–120.
//
// İki kip (EVT-03 testleriyle aynı düzen): durum kipi (`pumpApp`, ViewModel
// durumu ezilir) ve akış kipi (gerçek ViewModel + sahte depolar + yer
// tutucu rotalar).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/notifications/provider/notification_prefs_state.dart';
import 'package:gu_kulupler/features/notifications/provider/notification_prefs_view_model.dart';
import 'package:gu_kulupler/features/notifications/view/notification_prefs_view.dart';
import 'package:gu_kulupler/features/notifications/view/widget/quiet_hours_picker.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/format/time_of_day_value.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_settings_repository.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/semantics_scan.dart';
import '../../../helpers/test_l10n.dart';
import '../notification_prefs_test_support.dart';

final Key _back = GuKey.action('NTF-02.back');
final Key _permission = GuKey.action('NTF-02.permission');
final Key _announcements = GuKey.action('NTF-02.toggle.announcements');
final Key _management = GuKey.action('NTF-02.toggle.management');
final Key _reminder1d = GuKey.action('NTF-02.reminderTime.1d');
final Key _quiet = GuKey.action('NTF-02.quiet');
final Key _quietFrom = GuKey.action('NTF-02.quietFrom');
final Key _quietTo = GuKey.action('NTF-02.quietTo');
final Key _clubC01 = GuKey.action('NTF-02.club.c01');
final Key _retry = GuKey.action('NTF-02.retry');

const String _prefsPath = '/notifications/preferences';

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeSettingsRepository _settings() =>
    GetIt.I<SettingsRepository>() as FakeSettingsRepository;

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({NotificationPrefsState? state}) => [
  sessionViewModelProvider.overrideWithBuild((ref, notifier) => prefsSession()),
  notificationPrefsViewModelProvider.overrideWithBuild(
    (ref, notifier) => state ?? loadedPrefsState(),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  NotificationPrefsState? state,
  Size size = const Size(390, 1200),
}) async {
  await tester.pumpApp(
    const NotificationPrefsView(),
    size: size,
    overrides: _overrides(state: state),
  );
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel + yer tutucu NTF-01 / CLB-03.
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  ClubPrefsSheetBuilder? sheetBuilder,
  void Function()? before,
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    size: const Size(390, 1200),
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: '/clubs/:clubId',
          builder: (_, state) => _Stub(state.uri.toString()),
        ),
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const _Stub('/notifications'),
          routes: [
            GoRoute(
              path: 'preferences',
              builder: (_, _) =>
                  NotificationPrefsView(clubPrefsSheetBuilder: sheetBuilder),
            ),
          ],
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => prefsSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedPrefs();
  before?.call();
  router.go(_prefsPath);
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

class _Stub extends StatelessWidget {
  const _Stub(this.path);

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(path));
}

void main() {
  group('NTF-02 · Bildirim tercihleri · içerik', () {
    testWidgets('varsayılan: izin kapalı + "İzni aç", yedi tür anahtarı açık '
        '(H-25 gönderi / yorum dahil), '
        '1 saat önce seçili, sessiz saat kapalı, iki kulüp', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;
      expect(find.text(l10n.notifPrefsTitle), findsOneWidget);
      expect(find.text(l10n.notifPrefsPermission), findsOneWidget);
      expect(find.text(l10n.commonOff), findsOneWidget);
      expect(find.byKey(_permission), findsOneWidget);
      for (final field in [
        NotificationPrefField.announcements,
        NotificationPrefField.newPosts,
        NotificationPrefField.newComments,
        NotificationPrefField.eventReminders,
        NotificationPrefField.newEvents,
        NotificationPrefField.applicationResults,
        NotificationPrefField.system,
      ]) {
        expect(
          find.text(NotificationPrefsView.labelOf(l10n, field)),
          findsOneWidget,
          reason: field.name,
        );
      }
      expect(find.byKey(_management), findsNothing);
      final switches = tester.widgetList<GuSwitch>(find.byType(GuSwitch));
      expect(switches.map((s) => s.value), [
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
      ]);
      expect(
        tester.widget<GuSegmented>(find.byType(GuSegmented)).value,
        ReminderOption.oneHour.json,
      );
      expect(find.text(l10n.notifPrefsQuietDesc), findsOneWidget);
      expect(find.byType(QuietHoursPicker), findsNothing);
      expect(find.text(l10n.notifPrefsPerClub), findsOneWidget);
      for (final club in kPrefsClubs) {
        expect(find.text(club.name), findsOneWidget);
      }
      expect(find.text(l10n.notifPrefsCustomize), findsNWidgets(2));
      await expectA11yGuidelines(tester);
    });

    testWidgets('izin açık: "Açık", düğme yok; yönetici: yönetim satırı; '
        'sessiz saat açık: aralık; sessize alınmış kulüp', (tester) async {
      await _pump(
        tester,
        state: loadedPrefsState(
          permissionGranted: true,
          showManagement: true,
          settings: const UserSettingsModel.defaults(kPrefsUid).copyWith(
            quiet: true,
            quietFrom: '23:00',
            quietTo: '07:30',
            clubs: {
              'c07': const ClubNotificationPrefsModel(
                announcements: false,
                events: false,
                posts: false,
                muted: true,
              ),
            },
          ),
        ),
      );
      final l10n = tester.l10n;
      expect(find.text(l10n.commonOn), findsOneWidget);
      expect(find.byKey(_permission), findsNothing);
      expect(find.byKey(_management), findsOneWidget);
      expect(find.byKey(_quietFrom), findsOneWidget);
      expect(find.text('23:00'), findsOneWidget);
      expect(find.text('07:30'), findsOneWidget);
      expect(find.text(l10n.notifPrefsMuted), findsOneWidget);
      expect(find.text(l10n.notifPrefsCustomize), findsOneWidget);
    });
  });

  group('NTF-02 · Bildirim tercihleri · durumlar', () {
    testWidgets('yükleniyor: iskelet', (tester) async {
      await _pump(
        tester,
        state: const NotificationPrefsState(isFetching: true),
      );
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byType(GuSwitch), findsNothing);
    });

    testWidgets('hata: "Yeniden dene"', (tester) async {
      await _pump(tester, state: const NotificationPrefsState(isError: true));
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.text(tester.l10n.sysErrorTitle), findsOneWidget);
    });

    testWidgets('kulüpsüz: "Üye olduğun kulüp yok."', (tester) async {
      await _pump(tester, state: loadedPrefsState(clubs: const []));
      expect(find.text(tester.l10n.notifPrefsNoClubs), findsOneWidget);
    });
  });

  group('NTF-02 · Bildirim tercihleri · aksiyon envanteri', () {
    testWidgets('Mehmet (c01, c07): envanterdeki anahtarlar birebir', (
      tester,
    ) async {
      await _pump(tester);
      expectActionInventory(tester, 'NTF-02', role: 'member');
    });
  });

  group('NTF-02 · Bildirim tercihleri · aksiyonlar', () {
    testWidgets('anahtar → tek alanlı yama + TST-19; dilim → 1 gün önce', (
      tester,
    ) async {
      await _pumpRoute(tester);
      await tester.tap(find.byKey(_announcements));
      await tester.pumpAndSettle();
      expect(
        _settings().patches.single.patch,
        const UserSettingsPatch(
          announcements: false,
        ),
      );
      expect(_feedback().toasts, [ToastId.tst19]);
      expect(
        tester.widget<GuSwitch>(find.byKey(_announcements)).value,
        isFalse,
      );

      await tester.tap(find.byKey(_reminder1d));
      await tester.pumpAndSettle();
      expect(
        _settings().patches.last.patch,
        const UserSettingsPatch(reminderTime: ReminderOption.oneDay),
      );
    });

    testWidgets('sessiz saat aç → aralık; "Başlangıç" SHT-29 → seçilen saat '
        'yazılır', (tester) async {
      await _pumpRoute(tester);
      await tester.tap(find.byKey(_quiet));
      await tester.pumpAndSettle();
      expect(find.byType(QuietHoursPicker), findsOneWidget);
      expect(find.text('22:00'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);

      _feedback().nextSheetResult = const TimeOfDayValue(23, 30);
      await tester.tap(find.byKey(_quietFrom));
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht29]);
      expect(
        _settings().patches.last.patch,
        const UserSettingsPatch(quietFrom: '23:30', quietTo: '08:00'),
      );
      expect(find.text('23:30'), findsOneWidget);

      // Vazgeçilen seçim yazılmaz.
      final writes = _settings().patches.length;
      await tester.tap(find.byKey(_quietTo));
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht29, SheetId.sht29]);
      expect(_settings().patches.length, writes);
    });

    testWidgets('"İzni aç" → DLG-03 → sistem izni → "Açık"', (tester) async {
      await _pumpRoute(tester);
      _feedback().nextDialogResult = true;
      await tester.tap(find.byKey(_permission));
      await tester.pumpAndSettle();
      expect(_feedback().dialogs, [DialogId.dlg03]);
      expect(find.byKey(_permission), findsNothing);
      expect(find.text(tester.l10n.commonOn), findsOneWidget);
    });

    testWidgets('kulüp satırı: gövde verilmişse SHT-07, verilmemişse CLB-03', (
      tester,
    ) async {
      var router = await _pumpRoute(
        tester,
        sheetBuilder: (clubId, clubName) => Text('$clubId:$clubName'),
      );
      await tester.tap(find.byKey(_clubC01));
      await tester.pumpAndSettle();
      expect(_feedback().sheets, [SheetId.sht07]);
      expect(_location(router), _prefsPath);
      expect(
        (_feedback().lastSheetBuilder!(tester.element(find.byType(Scaffold)))
                as Text)
            .data,
        'c01:${kPrefsClubs.first.name}',
      );

      router = await _pumpRoute(tester);
      await tester.tap(find.byKey(_clubC01));
      await tester.pumpAndSettle();
      expect(_location(router), '/clubs/c01');
    });

    testWidgets('geri → NTF-01', (tester) async {
      final router = await _pumpRoute(tester);
      await tester.tap(find.byKey(_back));
      await tester.pumpAndSettle();
      expect(_location(router), '/notifications');
    });
  });

  group('NTF-02 · Bildirim tercihleri · cihaz matrisi', () {
    Widget view(BuildContext context) => const NotificationPrefsView();

    testWidgets('dolu (güvenli alan); yönetici + sessiz saat açık; '
        'yükleniyor, hata', (tester) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(),
        safeAreas: true,
      );
      for (final state in [
        loadedPrefsState(
          showManagement: true,
          permissionGranted: true,
          settings: const UserSettingsModel.defaults(
            kPrefsUid,
          ).copyWith(quiet: true),
        ),
        const NotificationPrefsState(isFetching: true),
        const NotificationPrefsState(isError: true),
      ]) {
        await DeviceMatrix.run(
          tester,
          view,
          overrides: _overrides(state: state),
        );
      }
    });
  });

  group('NTF-02 · Bildirim tercihleri · semantik', () {
    testWidgets('kaydırma boyunca rol doğrulaması hatasız (hatırlatma '
        'GuSegmented; yönetici + sessiz saat açık; iOS + Android)', (
      tester,
    ) async {
      await expectSemanticsCleanWhileScrolling(
        tester,
        (platform) => tester.pumpApp(
          const NotificationPrefsView(),
          overrides: _overrides(
            state: loadedPrefsState(
              showManagement: true,
              permissionGranted: true,
              settings: const UserSettingsModel.defaults(
                kPrefsUid,
              ).copyWith(quiet: true),
            ),
          ),
          // `SingleChildScrollView`: semantik kırpma tüm içeriği kapsar
          // (önbellek kenarı yok); tarama kaydırılmış kareleri doğrular.
          size: const Size(320, 568),
          textScale: 1.6,
          platform: platform,
        ),
      );
    });
  });

  group('NTF-02 · Bildirim tercihleri · golden', () {
    testWidgets('varsayılan açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'NTF-02',
        const NotificationPrefsView(),
        overrides: _overrides(),
      );
    });
  });
}
