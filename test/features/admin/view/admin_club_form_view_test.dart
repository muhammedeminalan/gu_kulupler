// ADM-03 · Kulüp oluştur / düzenle — içerik (yeni kulüp: tasarım
// yakalaması; düzenleme: başkan kartı + "Kaldır", bağlı danışman + "Kaldır"
// W-101 a), alan hataları (zorunlu, ad çakışması CD-63), durumlar
// (yükleniyor, hata + "Yeniden dene"), aksiyon envanteri (13 anahtar),
// temel aksiyon sonuçları (kategori → SHT-33, logo → SHT-16, kapak → SHT-31,
// "Başkan ata" → SHT-25, oluştur → TST-33 + ADM-02, düzenle → TST-21 +
// ADM-02, kaydedilmemiş değişiklik → DLG-25), cihaz matrisi, açık + koyu
// golden.
// Referans: design/reference-shots/screens/ADM-03__*.webp,
// design/prototype/app/screens-admin.js:39–56.
//
// İki kip (MGT-09 testleriyle aynı düzen):
// * **Durum kipi**: ekran `pumpApp` ile çizilir, ViewModel durumu ezilir.
// * **Akış kipi**: gerçek ViewModel, sahte depolar ve yer tutucu rotalar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_club_form_state.dart';
import 'package:gu_kulupler/features/admin/provider/admin_club_form_view_model.dart';
import 'package:gu_kulupler/features/admin/view/admin_club_form_view.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/mixin/unsaved_changes_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_club_repository.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_membership_repository.dart';
import '../../../fixtures/club_model_fixtures.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/a11y_guidelines.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';
import '../admin_club_form_test_support.dart';
import '../admin_test_support.dart';

final Key _close = GuKey.action('ADM-03.close');
final Key _save = GuKey.action('ADM-03.save');
final Key _retry = GuKey.action('ADM-03.retry');
final Key _name = GuKey.action('ADM-03.name');
final Key _summary = GuKey.action('ADM-03.summary');
final Key _category = GuKey.action('ADM-03.category');
final Key _logo = GuKey.action('ADM-03.logo');
final Key _cover = GuKey.action('ADM-03.cover');
final Key _assign = GuKey.action('ADM-03.assignPresident');
final Key _removePresident = GuKey.action('ADM-03.removePresident');
final Key _unlinkAdvisor = GuKey.action('ADM-03.unlinkAdvisor');

const String _clubsPath = '/admin/clubs';

/// Uzun yüzey: formun tamamı kurulsun.
const Size _tall = Size(390, 1600);

const Widget _newView = AdminClubFormView();

/// Düzenleme kipinin durum fixture'ı: `c03`, başkanı ve bağlı danışmanı.
AdminClubFormState _editState({bool linkedAdvisor = true}) {
  final club = ClubModelFixtures.byId('c03');
  final withAdvisor = club.copyWith(
    advisor: ClubAdvisorModel(
      name: 'Ayşe Kaya',
      title: 'Dr.',
      userId: linkedAdvisor ? kFormAdvisorUid : null,
    ),
  );
  return AdminClubFormState.of(
    withAdvisor,
    president: UserModelFixtures.byId(club.presidentId),
  );
}

/// Durum kipi: oturum + ViewModel durumu ezilir.
List<Override> _overrides({AdminClubFormState? state, String? clubId}) => [
  sessionViewModelProvider.overrideWithBuild((ref, notifier) => kAdminSession),
  adminClubFormViewModelProvider(
    clubId,
  ).overrideWithBuild((ref, notifier) => state ?? const AdminClubFormState()),
];

Future<void> _pump(
  WidgetTester tester, {
  AdminClubFormState? state,
  String? clubId,
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpApp(
    AdminClubFormView(clubId: clubId),
    locale: locale,
    size: _tall,
    overrides: _overrides(state: state, clubId: clubId),
  );
  await tester.pump();
}

/// Akış kipi: gerçek ViewModel + yer tutucu rotalar; yeni kulüp formu ya da
/// ([editClub]) fake kulübün düzenlemesi açılır.
Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  bool editClub = false,
}) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    size: _tall,
    routerOf: (_) => created ??= GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(path: '/start', builder: (_, _) => const _Stub('/start')),
        GoRoute(
          path: _clubsPath,
          builder: (_, s) => _Stub(s.uri.toString()),
          routes: [
            GoRoute(path: 'new', builder: (_, _) => _newView),
            GoRoute(
              path: ':clubId/edit',
              builder: (_, s) =>
                  AdminClubFormView(clubId: s.pathParameters['clubId']),
            ),
          ],
        ),
      ],
    ),
    overrides: [
      sessionViewModelProvider.overrideWithBuild(
        (ref, notifier) => kAdminSession,
      ),
    ],
  );
  final router = created!;
  addTearDown(router.dispose);
  seedClubForm();
  if (editClub) {
    final club = await seedFormClub();
    router.go('$_clubsPath/${club.id}/edit');
  } else {
    router.go('$_clubsPath/new');
  }
  await tester.pumpAndSettle();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

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

/// Yer tutucu hedef sayfa: yolunu gösterir.
class _Stub extends StatelessWidget {
  const _Stub(this.path);

  final String path;

  @override
  Widget build(BuildContext context) => Scaffold(body: Text(path));
}

void main() {
  group('ADM-03 · Kulüp formu · içerik', () {
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets('yeni kulüp (${locale.languageCode}): X + başlık, alanlar, '
          'logo + kapak, "Başkan ata", unvan + danışman, iki anahtar, '
          '"Oluştur"', (tester) async {
        await _pump(tester, locale: locale);
        final l10n = tester.l10n;

        final bar = tester.widget<GuAppBar>(find.byType(GuAppBar));
        expect(bar.title, l10n.clubFormTitle);
        expect(bar.closeIcon, isTrue);
        for (final label in [
          l10n.clubSettingsName,
          l10n.clubSettingsCategory,
          l10n.clubSettingsSummary,
          l10n.clubSettingsAbout,
          l10n.clubFormPresident,
          l10n.clubFormAdvisorTitle,
          l10n.clubAdvisor,
          l10n.clubSettingsApplicationsOpen,
          l10n.clubSettingsApprovalRequired,
          l10n.clubFormAssignPresident,
          l10n.clubFormCreate,
          l10n.commonSelect,
        ]) {
          expect(find.text(label), findsWidgets, reason: label);
        }
        expect(find.byKey(_removePresident), findsNothing);
        expect(find.byKey(_unlinkAdvisor), findsNothing);
        final switches = tester.widgetList<GuSwitch>(find.byType(GuSwitch));
        expect(switches.map((s) => s.value), [true, true]);
        await expectA11yGuidelines(tester);
      });
    }

    testWidgets('düzenleme: "Kulübü düzenle", başkan kartı + "Kaldır", bağlı '
        'danışman + "Kaldır" (W-101 a), "Kaydet"', (tester) async {
      final state = _editState();
      await _pump(tester, state: state, clubId: state.original!.id);
      final l10n = tester.l10n;
      expect(
        tester.widget<GuAppBar>(find.byType(GuAppBar)).title,
        l10n.clubFormEditTitle,
      );
      expect(find.byKey(_assign), findsNothing);
      expect(find.byKey(_removePresident), findsOneWidget);
      expect(find.text(state.president!.name), findsOneWidget);
      expect(find.byKey(_unlinkAdvisor), findsOneWidget);
      expect(find.text(l10n.clubFormAdvisorLinked), findsOneWidget);
      expect(find.text(l10n.commonSave), findsOneWidget);
    });

    testWidgets('alan hataları: zorunlu alanlar; ad çakışması (CD-63)', (
      tester,
    ) async {
      await _pump(
        tester,
        state: const AdminClubFormState(
          errors: {
            AdminClubField.category: FormFieldError.required,
            AdminClubField.president: FormFieldError.required,
          },
          isNameTaken: true,
        ),
      );
      final l10n = tester.l10n;
      expect(find.text(l10n.clubFormErrUnique), findsOneWidget);
      expect(find.text(l10n.authErrRequired), findsNWidgets(2));
    });

    testWidgets('aksiyon envanteri: 13 anahtar (yeni kulüp)', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'ADM-03', role: 'admin');
    });
  });

  group('ADM-03 · Kulüp formu · durumlar', () {
    testWidgets('düzenleme yükleniyor: iskelet, alt çubuk yok', (tester) async {
      await _pump(
        tester,
        clubId: 'c03',
        state: const AdminClubFormState(isLoading: true),
      );
      expect(find.byType(GuSkeletonList), findsOneWidget);
      expect(find.byKey(_save), findsNothing);
    });

    testWidgets('düzenleme hatası: "Yeniden dene" okur', (tester) async {
      await _pump(
        tester,
        clubId: 'c03',
        state: const AdminClubFormState(isError: true),
      );
      expect(find.byType(GuErrorState), findsOneWidget);
      expect(find.byKey(_save), findsNothing);
      await _tapKey(tester, _retry);
      expect(
        (GetIt.I<ClubRepository>() as FakeClubRepository).callsTo('getClub'),
        isNotEmpty,
      );
    });
  });

  group('ADM-03 · Kulüp formu · aksiyonlar', () {
    testWidgets('kategori → SHT-33; logo → SHT-16; kapak → SHT-31', (
      tester,
    ) async {
      await _pumpRoute(tester);
      _feedback().nextSheetResult = 'k07';
      await _tapKey(tester, _category);
      await _tapKey(tester, _logo);
      await _tapKey(tester, _cover);
      expect(_feedback().sheets, [SheetId.sht33, SheetId.sht16, SheetId.sht31]);
      expect(find.text(tester.l10n.catK07), findsOneWidget);
    });

    testWidgets('oluştur: ad + kategori + "Başkan ata" (SHT-25) → TST-33, '
        'ADM-02; başkan üyeliği + presidentId tutarlı', (tester) async {
      final router = await _pumpRoute(tester);
      await _enter(tester, _name, 'Satranç Kulübü');
      _feedback().nextSheetResult = 'k07';
      await _tapKey(tester, _category);
      _feedback().nextSheetResult = kFormPresidentId;
      await _tapKey(tester, _assign);
      expect(_feedback().sheets, [SheetId.sht33, SheetId.sht25]);
      expect(find.byKey(_removePresident), findsOneWidget);

      await _tapKey(tester, _save);
      expect(_feedback().toasts, [ToastId.tst33]);
      expect(_location(router), _clubsPath);
      final club = (GetIt.I<ClubRepository>() as FakeClubRepository)
          .clubs
          .values
          .singleWhere((c) => c.name == 'Satranç Kulübü');
      expect(club.presidentId, kFormPresidentId);
      final membership =
          (GetIt.I<MembershipRepository>() as FakeMembershipRepository)
              .memberships
              .values
              .singleWhere((m) => m.clubId == club.id);
      expect(membership.userId, kFormPresidentId);
      expect(membership.role, ClubRole.president);
    });

    testWidgets('boş formda "Oluştur" → alan hataları, ekranda kalınır', (
      tester,
    ) async {
      final router = await _pumpRoute(tester);
      await _tapKey(tester, _save);
      expect(find.text(tester.l10n.authErrRequired), findsNWidgets(3));
      expect(_location(router), '$_clubsPath/new');
      expect(_feedback().toasts, isEmpty);
    });

    testWidgets('kapat: değişiklik yokken çıkar; değişiklik varken DLG-25 — '
        '"Kaydetmeden çık" çıkar', (tester) async {
      var router = await _pumpRoute(tester);
      await _tapKey(tester, _close);
      expect(_location(router), _clubsPath);
      expect(_feedback().dialogs, isEmpty);

      router = await _pumpRoute(tester);
      await _enter(tester, _name, 'Taslak');
      _feedback().nextDialogResult = UnsavedChangesResult.discard;
      await _tapKey(tester, _close);
      expect(_feedback().dialogs, [DialogId.dlg25]);
      expect(_location(router), _clubsPath);
    });

    testWidgets('düzenle: kısa açıklama → "Kaydet" → TST-21, ADM-02', (
      tester,
    ) async {
      final router = await _pumpRoute(tester, editClub: true);
      await _enter(tester, _summary, 'Yeni özet');
      await _tapKey(tester, _save);
      expect(_feedback().toasts, [ToastId.tst21]);
      expect(_location(router), _clubsPath);
    });
  });

  group('ADM-03 · Kulüp formu · cihaz matrisi', () {
    testWidgets('yeni kulüp (klavye + güvenli alan)', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => _newView,
        overrides: _overrides(),
        keyboard: true,
        safeAreas: true,
      );
    });

    testWidgets('düzenleme (başkan + bağlı danışman, hata bandı + alan '
        'hataları), yükleniyor, hata', (tester) async {
      final edit = _editState().copyWith(
        isSubmitError: true,
        isNameTaken: true,
        errors: const {AdminClubField.advisorName: FormFieldError.tooShort},
      );
      final clubId = edit.original!.id;
      for (final state in [
        edit,
        const AdminClubFormState(isLoading: true),
        const AdminClubFormState(isError: true),
      ]) {
        await DeviceMatrix.run(
          tester,
          (_) => AdminClubFormView(clubId: clubId),
          overrides: _overrides(state: state, clubId: clubId),
        );
      }
    });
  });

  group('ADM-03 · Kulüp formu · golden', () {
    testWidgets('varsayılan (tasarım yakalaması) açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'ADM-03',
        _newView,
        overrides: _overrides(),
      );
    });
  });
}
