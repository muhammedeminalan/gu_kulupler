// MGT-09 · Kulüp ayarları — içerik (tasarım yakalaması: başlık + rol rozeti,
// gruplar, kilitli ad, kategori, kapalı "Kaydet"), durumlar (yükleniyor,
// hata + yeniden dene, danışman salt okunur, yetkisiz, gönderim hatası,
// anında üyelik uyarısı; boş durum yok — form), aksiyon envanteri (15
// anahtar), aksiyon sonuçları (kilitli ad → TST-20, kategori → SHT-33 →
// TST-20, logo → SHT-16, kapak → SHT-31, kaydedilmemiş değişiklik → DLG-25,
// başvuru kapatma → TST-21 → TST-54, danışman → TST-26), cihaz matrisi,
// açık + koyu golden.
// Referans: design/reference-shots/screens/MGT-09__*.webp,
// design/prototype/app/screens-manage.js:170–188.
//
// İki kip (MGT-05 testleriyle aynı düzen):
// * **Durum kipi**: ekran `pumpApp` ile çizilir, ViewModel durumu ezilir.
// * **Akış kipi**: gerçek ViewModel, sahte depolar ve yer tutucu rotalar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/constants/app_durations.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/constants/club_settings_constants.dart';
import 'package:gu_kulupler/features/management/provider/club_settings_state.dart';
import 'package:gu_kulupler/features/management/provider/club_settings_view_model.dart';
import 'package:gu_kulupler/features/management/view/club_settings_view.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_management_repository.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../club_settings_test_support.dart';
import '../manage_test_support.dart';

final Key _back = GuKey.action('MGT-09.back');
final Key _save = GuKey.action('MGT-09.save');
final Key _retry = GuKey.action('MGT-09.retry');
final Key _lockedName = GuKey.action('MGT-09.lockedName');
final Key _category = GuKey.action('MGT-09.category');
final Key _logo = GuKey.action('MGT-09.logo');
final Key _cover = GuKey.action('MGT-09.cover');
final Key _summary = GuKey.action('MGT-09.summary');
final Key _applicationsOpen = GuKey.action('MGT-09.toggle.applicationsOpen');

const String _managePath = '/clubs/$kManageClubId/manage';
const String _settingsPath = '$_managePath/settings';

final ClubSettingsViewModelProvider _provider = clubSettingsViewModelProvider(
  kManageClubId,
);

const Widget _view = ClubSettingsView(clubId: kManageClubId);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({
  SessionState? session,
  ClubSettingsState? state,
}) => [
  sessionViewModelProvider.overrideWithBuild(
    (ref, notifier) => session ?? manageSession(),
  ),
  _provider.overrideWithBuild(
    (ref, notifier) => state ?? loadedSettingsState(),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  SessionState? session,
  ClubSettingsState? state,
}) async {
  await tester.pumpApp(
    _view,
    overrides: _overrides(session: session, state: state),
  );
  await tester.pump();
}

/// Akış kipi: ekranı gerçek ViewModel ve yer tutucu rotalarla açar.
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  SessionState? session,
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    size: const Size(390, 1600),
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: _managePath,
          builder: (_, state) => _Stub(state.uri.toString()),
          routes: [GoRoute(path: 'settings', builder: (_, _) => _view)],
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => session ?? manageSession(),
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedClubSettings();
  router.go(_settingsPath);
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Future<void> _tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, Key key, String text) async {
  final field = find.descendant(
    of: find.byKey(key),
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

ClubSettingsState _stateOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(ClubSettingsView)),
).read(_provider);

GuButton _saveButton(WidgetTester tester) =>
    tester.widget<GuButton>(find.byKey(_save));

/// Yer tutucu hedef sayfa: yolunu gösterir.
class _Stub extends StatelessWidget {
  const _Stub(this.path);

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(path));
}

void main() {
  group('MGT-09 · Kulüp ayarları · içerik', () {
    testWidgets('tasarım yakalaması: başlık + kulüp adı + "Başkan"; dört '
        'grup + danışman; kilitli ad; kategori; "Kaydet" kapalı', (
      tester,
    ) async {
      await _pump(tester);
      final l10n = tester.l10n;
      const tr = Locale('tr');
      expect(find.text(l10n.clubSettingsTitle), findsOneWidget);
      expect(find.text(l10n.rolePresident), findsOneWidget);
      for (final title in [
        l10n.clubSettingsGroupLook,
        l10n.clubSettingsGroupInfo,
        l10n.clubSettingsGroupContact,
        l10n.clubSettingsGroupJoin,
      ]) {
        expect(find.text(title.upperFor(tr)), findsOneWidget, reason: title);
      }
      expect(find.text(l10n.clubSettingsNameLocked), findsOneWidget);
      final name = tester.widget<GuInput>(
        find.ancestor(
          of: find.byKey(GuKey.action('MGT-09.name')),
          matching: find.byType(GuInput),
        ),
      );
      expect(name.locked, isTrue);
      expect(name.controller!.text, kManageClub.name);
      expect(find.text(l10n.catK03), findsOneWidget);
      expect(find.text(kManageClub.summary), findsOneWidget);
      expect(find.text(ClubSettingsConstants.instagramLabel), findsOneWidget);
      expect(find.text(l10n.clubSettingsCover), findsOneWidget);
      // Onay açıkken anında üyelik uyarısı yok.
      expect(find.text(l10n.clubSettingsInstantWarning), findsNothing);
      expect(
        tester.widget<GuSwitch>(find.byKey(_applicationsOpen)).value,
        isTrue,
      );
      expect(_saveButton(tester).disabled, isTrue);
      expect(find.byType(GuErrorState), findsNothing);
      if (kManageClub.advisor != null) {
        expect(find.text(l10n.clubSettingsAdvisorLocked), findsOneWidget);
      }
    });

    testWidgets('kirli form: "Kaydet" etkin; onay kapalı → uyarı bandı; '
        'alan hatası metni', (tester) async {
      await _pump(
        tester,
        state: loadedSettingsState().copyWith(
          approvalRequired: false,
          web: 'kulupler',
          errors: const {ClubSettingsField.web: FormFieldError.invalidFormat},
          isDirty: true,
        ),
      );
      final l10n = tester.l10n;
      expect(_saveButton(tester).disabled, isFalse);
      expect(find.text(l10n.clubSettingsInstantWarning), findsOneWidget);
      expect(find.text(l10n.clubSettingsErrWeb), findsOneWidget);
    });
  });

  group('MGT-09 · Kulüp ayarları · durumlar', () {
    testWidgets('yükleniyor: iskelet, alt çubuk yok', (tester) async {
      await _pump(
        tester,
        state: const ClubSettingsState(
          role: ClubRole.president,
        ),
      );
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byKey(_save), findsNothing);
    });

    testWidgets('hata: "Yeniden dene" kulübü okur', (tester) async {
      await _pump(
        tester,
        state: const ClubSettingsState(
          role: ClubRole.president,
          isLoading: false,
          isError: true,
        ),
      );
      expect(find.byType(GuErrorState), findsOneWidget);
      expect(find.byKey(_retry), findsOneWidget);
      expect(find.byKey(_save), findsNothing);
    });

    testWidgets('gönderim hatası: üstte hata bandı', (tester) async {
      await _pump(
        tester,
        state: loadedSettingsState().copyWith(isSubmitError: true),
      );
      expect(find.text(tester.l10n.sysErrorTitle), findsOneWidget);
    });

    testWidgets('danışman: salt okunur bandı, alanlar ve "Kaydet" kapalı', (
      tester,
    ) async {
      await _pump(
        tester,
        session: manageSession(role: ClubRole.advisor),
        state: loadedSettingsState(role: ClubRole.advisor),
      );
      expect(find.text(tester.l10n.mgtReadOnlyBanner), findsOneWidget);
      expect(_saveButton(tester).disabled, isTrue);
      expect(
        tester
            .widget<GuInput>(
              find.ancestor(
                of: find.byKey(_summary),
                matching: find.byType(GuInput),
              ),
            )
            .disabled,
        isTrue,
      );
      expect(
        tester.widget<GuSwitch>(find.byKey(_applicationsOpen)).disabled,
        isTrue,
      );
    });

    testWidgets('üye (yetkisiz): kilit + "Bu paneli görüntüleme yetkin yok."', (
      tester,
    ) async {
      await _pump(
        tester,
        session: manageSession(role: ClubRole.member),
        state: loadedSettingsState(role: ClubRole.member),
      );
      expect(find.text(tester.l10n.mgtNoAccess), findsOneWidget);
      expect(find.byKey(_back), findsOneWidget);
      expect(find.byKey(_save), findsNothing);
    });
  });

  group('MGT-09 · Kulüp ayarları · aksiyon envanteri', () {
    testWidgets('yönetici bakışı: envanterdeki 15 anahtar birebir', (
      tester,
    ) async {
      await _pump(tester);
      expectActionInventory(tester, 'MGT-09', role: 'manager');
    });
  });

  group('MGT-09 · Kulüp ayarları · aksiyonlar', () {
    testWidgets('kilitli ad → TST-20; kategori → SHT-33, başka kategori → '
        'TST-20; logo → SHT-16; kapak → SHT-31', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _lockedName);
      expect(_feedback().toasts, [ToastId.tst20]);

      _feedback().nextSheetResult = 'k01';
      await _tapKey(tester, _category);
      expect(_feedback().sheets, [SheetId.sht33]);
      expect(_feedback().toasts, [ToastId.tst20, ToastId.tst20]);
      expect(_stateOf(tester).isDirty, isFalse);

      await _tapKey(tester, _logo);
      await _tapKey(tester, _cover);
      expect(_feedback().sheets, [SheetId.sht33, SheetId.sht16, SheetId.sht31]);
    });

    testWidgets('geri: değişiklik yokken MGT-01; değişiklik varken DLG-25 — '
        '"Kaydetmeden çık" çıkar', (tester) async {
      var router = await _pumpRoute(tester);
      await _tapKey(tester, _back);
      expect(_location(router), _managePath);
      expect(_feedback().dialogs, isEmpty);

      router = await _pumpRoute(tester);
      await _enter(tester, _summary, 'Yeni özet');
      expect(_saveButton(tester).disabled, isFalse);
      _feedback().nextDialogResult = UnsavedChangesResult.discard;
      await _tapKey(tester, _back);
      expect(_feedback().dialogs, [DialogId.dlg25]);
      expect(_location(router), _managePath);
    });

    testWidgets('DLG-25 "Kaydet": kaydeder (TST-21) ve çıkar', (tester) async {
      final router = await _pumpRoute(tester);
      await _enter(tester, _summary, 'Yeni özet');
      _feedback().nextDialogResult = UnsavedChangesResult.save;
      await _tapKey(tester, _back);
      expect(_feedback().toasts, [ToastId.tst21]);
      expect(_location(router), _managePath);
      final management =
          GetIt.I<ManagementRepository>() as FakeManagementRepository;
      expect(management.settingsUpdates.single.patch.summary, 'Yeni özet');
    });

    testWidgets('başvuruları kapat + "Kaydet" → TST-21, ardından TST-54 '
        '(kapatıldı); ekranda kalınır', (tester) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _applicationsOpen);
      expect(_stateOf(tester).applicationsOpen, isFalse);
      await _tapKey(tester, _save);
      expect(_feedback().toasts, [ToastId.tst21]);
      await tester.pump(AppDurations.applicationsToastDelay);
      expect(_feedback().toasts, [ToastId.tst21, ToastId.tst54]);
      expect(_feedback().toastParams.last, const ToastParams());
      expect(_location(router), _settingsPath);
      expect(_saveButton(tester).disabled, isTrue);
    });

    testWidgets('kapalı "Kaydet" → TST-X9; danışman: anahtar / kaydet / logo '
        '→ TST-26', (tester) async {
      await _pumpRoute(tester);
      await _tapKey(tester, _save);
      expect(_feedback().toasts, [ToastId.tstX9]);

      await _pumpRoute(tester, session: manageSession(role: ClubRole.advisor));
      _feedback().toasts.clear();
      await _tapKey(tester, _applicationsOpen);
      await _tapKey(tester, _save);
      await _tapKey(tester, _logo);
      expect(_feedback().toasts, [
        ToastId.tst26,
        ToastId.tst26,
        ToastId.tst26,
      ]);
      expect(_feedback().sheets, isEmpty);
      expect(_stateOf(tester).applicationsOpen, isTrue);
    });
  });

  group('MGT-09 · Kulüp ayarları · cihaz matrisi', () {
    Widget view(BuildContext context) => _view;

    testWidgets('dolu form (klavye + güvenli alan)', (tester) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(),
        keyboard: true,
        safeAreas: true,
      );
    });

    testWidgets('danışman, uyarı + hata bandı, yükleniyor, hata', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        view,
        overrides: _overrides(
          session: manageSession(role: ClubRole.advisor),
          state: loadedSettingsState(role: ClubRole.advisor),
        ),
      );
      for (final state in [
        loadedSettingsState().copyWith(
          approvalRequired: false,
          isSubmitError: true,
        ),
        const ClubSettingsState(role: ClubRole.president),
        const ClubSettingsState(
          role: ClubRole.president,
          isLoading: false,
          isError: true,
        ),
      ]) {
        await DeviceMatrix.run(
          tester,
          view,
          overrides: _overrides(state: state),
        );
      }
    });
  });

  group('MGT-09 · Kulüp ayarları · golden', () {
    testWidgets('varsayılan (tasarım yakalaması) açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'MGT-09',
        _view,
        overrides: _overrides(),
      );
    });
  });
}
