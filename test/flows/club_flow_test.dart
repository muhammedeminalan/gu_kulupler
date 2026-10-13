// T-16 · Uçtan uca kulüp akışı: gerçek `GuApp` (rota ağacı, yönlendirme,
// oturum katmanı, `AppFeedbackService`) + sahte servisler. Oturum hazırdır
// (aktif öğrenci, hiçbir kulüpte üyeliği yok); üyelik değişiklikleri sahte
// repository'nin akışından oturuma, oradan ekranlara yansır.
//
//   CLB-03 (c03, onaylı + not zorunlu) → "Katıl" → SHT-05 (boş not → alan
//   hatası) → not → gönder → CLB-04 → kapat → CLB-03 "İstek gönderildi" →
//   CLB-05 → notu düzenle → "Kaydet" (TST-07) → "İsteği iptal et" → DLG-07 →
//   TST-40 → CLB-03 (yeniden "Katıl")
//   CLB-03 (c07, onaysız) → "Katıl" → TST-34 → menü (SHT-06) → Bildirimler
//   (SHT-07: "Tümünü sessize al" → TST-38) → menü → "Kulüpten ayrıl" → DLG-08
//   → TST-39
//   CLB-03 → "Bu kulübü şikayet et" → SHT-10 → gönder → DLG-12
//   CLB-03 → paylaş → SHT-15 → "Bağlantıyı kopyala" → TST-35
//   CLB-03 (c05, başvuru kapalı) → devre dışı düğme → TST-X1
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/club_application_view.dart';
import 'package:gu_kulupler/features/clubs/view/club_applied_view.dart';
import 'package:gu_kulupler/features/clubs/view/club_detail_view.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_detail_cta_bar.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_menu_sheet.dart';
import 'package:gu_kulupler/features/clubs/view/widget/club_notification_sheet.dart';
import 'package:gu_kulupler/features/clubs/view/widget/join_application_sheet.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/share_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/service/share_service.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_club_repository.dart';
import '../fakes/fake_membership_repository.dart';
import '../fakes/fake_report_repository.dart';
import '../fakes/fake_settings_repository.dart';
import '../fakes/fake_share_service.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';
import '../fixtures/club_model_fixtures.dart';
import '../helpers/test_asset_bundle.dart';

/// Oturumdaki öğrenci: demo veride `c03`, `c05`, `c07` kulüplerinde üyeliği
/// yoktur.
const String _uid = 'u_ayse';
const String _email = 'ayse.demir@ogr.gumushane.edu.tr';
const String _name = 'Ayşe Demir';

/// Onay gerekli + not zorunlu kulüp.
const String _approvalClub = 'c03';

/// Onaysız (anında katılım) kulüp.
const String _instantClub = 'c07';

/// Başvuruya kapalı kulüp.
const String _closedClub = 'c05';

const String _note = 'Dağ yürüyüşlerine katılmak istiyorum.';
const String _editedNote = 'Hafta sonu etkinliklerine katılabilirim.';

Key _k(String id) => GuKey.action(id);

FakeAuthRepository _auth() => GetIt.I<AuthRepository>() as FakeAuthRepository;

FakeUserRepository _users() => GetIt.I<UserRepository>() as FakeUserRepository;

FakeClubRepository _clubs() => GetIt.I<ClubRepository>() as FakeClubRepository;

FakeMembershipRepository _memberships() =>
    GetIt.I<MembershipRepository>() as FakeMembershipRepository;

FakeReportRepository _reports() =>
    GetIt.I<ReportRepository>() as FakeReportRepository;

FakeSettingsRepository _settings() =>
    GetIt.I<SettingsRepository>() as FakeSettingsRepository;

FakeShareService _share() => GetIt.I<ShareService>() as FakeShareService;

/// Sahte servisleri kaydeder, hazır oturumu ve demo kulüpleri kurar, gerçek
/// `GuApp`'i açar ve [clubId] kulübünün sayfasına gider. Overlay'ler gerçek
/// `AppFeedbackService` ile kök gezgine itilir (uygulamadaki kayıtla aynı).
Future<void> _launch(WidgetTester tester, {required String clubId}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await GetIt.I.reset();
  registerDefaultFakes();
  addTearDown(GetIt.I.reset);
  final toasts = GuToastController();
  addTearDown(toasts.dispose);
  GetIt.I
    ..unregister<FeedbackService>()
    ..registerSingleton<FeedbackService>(
      AppFeedbackService(
        navigatorKey: rootNavigatorKey,
        toastController: toasts,
      ),
    );
  // Hazır oturum: doğrulanmış, profili tamam, aktif hesap. Tanıtım görülmüş,
  // bildirim ön izni (DLG-03) daha önce sorulmuş.
  _auth()
    ..service.uid = _uid
    ..service.emailVerified = true
    ..currentUser = const AuthUserInfo(
      uid: _uid,
      email: _email,
      emailVerified: true,
    );
  _users().putActive(_uid, name: _name, email: _email);
  (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
    ..values[AppPreferenceKeys.onboardingSeen] = true
    ..values[AppPreferenceKeys.notificationPermissionAsked] = true;
  for (final id in const [_approvalClub, _instantClub, _closedClub]) {
    _clubs().clubs[id] = ClubModelFixtures.byId(id);
  }
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    // Kapak şablonları depo kökünden eşzamanlı okunur (> 50 KB).
    DefaultAssetBundle(
      bundle: TestAssetBundle.instance,
      child: ProviderScope(child: GuApp(toastController: toasts)),
    ),
  );
  await tester.pumpAndSettle();
  expect(_session(tester).status, AuthStatus.active);
  expect(_location(tester), '/clubs');

  _router(tester).go('/clubs/$clubId');
  await tester.pumpAndSettle();
  expect(_location(tester), '/clubs/$clubId');
  expect(find.byType(ClubDetailView), findsOneWidget);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GuApp)));

GoRouter _router(WidgetTester tester) =>
    _container(tester).read(appRouterProvider);

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

SessionState _session(WidgetTester tester) =>
    _container(tester).read(sessionViewModelProvider);

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byKey(rootNavigatorKey)));

MembershipStatus? _status(WidgetTester tester, String clubId) =>
    _session(tester).memberships[clubId]?.status;

Future<void> _tapFinder(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) =>
    _tapFinder(tester, find.byKey(key));

/// Alt çubuktaki katılım düğmesi (`ClubCta`).
Finder _inBar(Key key) => find.descendant(
  of: find.byType(ClubDetailCtaBar),
  matching: find.byKey(key),
);

Finder _toast(ToastId id) => find.byKey(ValueKey<ToastId>(id));

/// Görünen toast'ın süresini doldurur (test sonunda bekleyen zamanlayıcı
/// kalmasın).
Future<void> _flushToast(WidgetTester tester) async {
  await tester.pump(GuMotion.toastUndo);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  group('T-16 · akış · başvuru (CLB-03 → SHT-05 → CLB-04 → CLB-05)', () {
    testWidgets('"Katıl" → SHT-05: boş not alan hatası; not ile gönder → '
        'CLB-04 → kapat → CLB-03 "İstek gönderildi" → CLB-05 → notu düzenle '
        '(TST-07) → "İsteği iptal et" → DLG-07 → TST-40 → CLB-03', (
      tester,
    ) async {
      await _launch(tester, clubId: _approvalClub);
      final l10n = _l10n(tester);
      final joinKey = _k('CLB-03.join.$_approvalClub');
      final statusKey = _k('CLB-03.status.$_approvalClub');
      expect(_status(tester, _approvalClub), isNull);
      expect(_inBar(joinKey), findsOneWidget);

      // "Katıl": kulüp onay istiyor → başvuru formu.
      await _tapFinder(tester, _inBar(joinKey));
      expect(find.byType(JoinApplicationSheet), findsOneWidget);
      expect(_location(tester), '/clubs/$_approvalClub');

      // Not zorunlu: boş gönderim sayfayı kapatmaz, başvuru yazılmaz.
      await _tap(tester, _k('SHT-05.submit'));
      expect(find.byType(JoinApplicationSheet), findsOneWidget);
      expect(find.text(l10n.authErrRequired), findsOneWidget);
      expect(_memberships().applied, isEmpty);

      await tester.enterText(find.byKey(_k('SHT-05.note')), '  $_note ');
      await tester.pump();
      await _tap(tester, _k('SHT-05.submit'));

      // Başvuru yazıldı (not kırpılmış) → CLB-04.
      expect(_memberships().applied, [
        (
          clubId: _approvalClub,
          userId: _uid,
          email: _email,
          note: _note,
          status: MembershipStatus.pending,
        ),
      ]);
      expect(find.byType(JoinApplicationSheet), findsNothing);
      expect(_location(tester), '/clubs/$_approvalClub/applied');
      expect(find.byType(ClubAppliedView), findsOneWidget);
      expect(_status(tester, _approvalClub), MembershipStatus.pending);
      // Onaylı kulüpte katılım toast'ı yoktur; üye sayısı değişmez.
      expect(_toast(ToastId.tst34), findsNothing);
      expect(
        _clubs().clubs[_approvalClub]!.memberCount,
        ClubModelFixtures.byId(_approvalClub).memberCount,
      );

      // CLB-04 kapat → kulüp sayfası; düğme artık başvuru durumunu açar.
      await _tap(tester, _k('CLB-04.close'));
      expect(_location(tester), '/clubs/$_approvalClub');
      expect(find.byType(ClubAppliedView), findsNothing);
      expect(_inBar(joinKey), findsNothing);
      expect(_inBar(statusKey), findsOneWidget);

      await _tapFinder(tester, _inBar(statusKey));
      expect(_location(tester), '/clubs/$_approvalClub/application');
      expect(find.byType(ClubApplicationView), findsOneWidget);

      // CLB-05: gönderilen not alanda; düzenle → "Kaydet" → TST-07.
      final noteField = find.descendant(
        of: find.byKey(_k('CLB-05.note')),
        matching: find.byType(EditableText),
        matchRoot: true,
      );
      expect(tester.widget<EditableText>(noteField).controller.text, _note);
      await tester.enterText(find.byKey(_k('CLB-05.note')), _editedNote);
      await tester.pump();
      await _tap(tester, _k('CLB-05.saveNote'));
      expect(_memberships().noteUpdates, [
        (clubId: _approvalClub, userId: _uid, note: _editedNote),
      ]);
      expect(_toast(ToastId.tst07), findsOneWidget);
      expect(find.text(l10n.tst07), findsOneWidget);
      // Not düzenleme üyeliği değiştirmez.
      expect(_status(tester, _approvalClub), MembershipStatus.pending);

      // "İsteği iptal et" → DLG-07: "Vazgeç" hiçbir şey yazmaz.
      await _tap(tester, _k('CLB-05.cancel'));
      expect(
        tester.widget<GuDialogFrame>(find.byType(GuDialogFrame)).title,
        l10n.dlg07Title,
      );
      await _tap(tester, FeedbackKeys.of('DLG-07', 'cancel'));
      expect(find.byType(GuDialogFrame), findsNothing);
      expect(_memberships().callsTo('cancelApplication'), isEmpty);
      expect(_location(tester), '/clubs/$_approvalClub/application');

      // Onay → iptal yazılır → TST-40 → kulüp sayfasına dönülür.
      await _tap(tester, _k('CLB-05.cancel'));
      await _tap(tester, FeedbackKeys.of('DLG-07', 'confirm'));
      expect(_memberships().callsTo('cancelApplication'), hasLength(1));
      expect(_status(tester, _approvalClub), MembershipStatus.cancelled);
      expect(_toast(ToastId.tst40), findsOneWidget);
      expect(_location(tester), '/clubs/$_approvalClub');
      expect(find.byType(ClubApplicationView), findsNothing);
      expect(find.byType(ClubDetailView), findsOneWidget);
      // Başvurusu kalmayan kullanıcı yeniden "Katıl" görür.
      expect(_inBar(statusKey), findsNothing);
      expect(_inBar(joinKey), findsOneWidget);

      await _flushToast(tester);
    });
  });

  group(
    'T-16 · akış · anında katılım ve ayrılma (CLB-03 → SHT-06 / SHT-07)',
    () {
      testWidgets('onaysız kulüpte "Katıl" → TST-34 (form yok) → menü → '
          'Bildirimler: "Tümünü sessize al" → TST-38 → menü → "Kulüpten ayrıl" '
          '→ DLG-08 → TST-39', (tester) async {
        await _launch(tester, clubId: _instantClub);
        final l10n = _l10n(tester);
        final joinKey = _k('CLB-03.join.$_instantClub');
        final before = ClubModelFixtures.byId(_instantClub).memberCount;

        await _tapFinder(tester, _inBar(joinKey));

        // Form açılmaz; üyelik hemen aktiftir, üye sayısı artar.
        expect(find.byType(JoinApplicationSheet), findsNothing);
        expect(_memberships().callsTo('joinInstant'), hasLength(1));
        expect(_memberships().callsTo('apply'), isEmpty);
        // Onaysız katılım notsuzdur ve doğrudan `active` yazar.
        expect(_memberships().applied, [
          (
            clubId: _instantClub,
            userId: _uid,
            email: _email,
            note: '',
            status: MembershipStatus.active,
          ),
        ]);
        expect(_status(tester, _instantClub), MembershipStatus.active);
        expect(_toast(ToastId.tst34), findsOneWidget);
        expect(_clubs().clubs[_instantClub]!.memberCount, before + 1);
        expect(_location(tester), '/clubs/$_instantClub');
        // Üye, katılım çubuğunu görmez.
        expect(find.byKey(joinKey), findsNothing);
        // Toast alt kenarda durur ve açılan sayfanın son satırını örter;
        // süresi dolunca kalkar.
        await _flushToast(tester);
        expect(_toast(ToastId.tst34), findsNothing);

        // Menü → Bildirimler (yalnızca üyede) → "Tümünü sessize al".
        await _tap(tester, _k('CLB-03.menu'));
        expect(find.byType(ClubMenuSheet), findsOneWidget);
        await _tap(tester, _k('SHT-06.notifications'));
        expect(find.byType(ClubMenuSheet), findsNothing);
        expect(find.byType(ClubNotificationSheet), findsOneWidget);

        await _tap(tester, _k('SHT-07.toggle.muted'));
        // Rules yük sözleşmesindeki "SHT-07 tümünü sessize al" yazımı.
        expect(_settings().clubSettingsWrites, [
          (
            uid: _uid,
            clubId: _instantClub,
            prefs: const ClubNotificationPrefsModel(
              announcements: false,
              events: false,
              posts: false,
              muted: true,
            ),
          ),
        ]);
        expect(_toast(ToastId.tst38), findsOneWidget);
        await _tap(tester, _k('SHT-07.close'));
        expect(find.byType(ClubNotificationSheet), findsNothing);
        await _flushToast(tester);

        // Menü → "Kulüpten ayrıl" → DLG-08 → onay → TST-39.
        await _tap(tester, _k('CLB-03.menu'));
        await _tap(tester, _k('SHT-06.leave'));
        expect(find.byType(ClubMenuSheet), findsNothing);
        expect(
          tester.widget<GuDialogFrame>(find.byType(GuDialogFrame)).title,
          l10n.dlg08Title,
        );
        expect(_memberships().callsTo('leave'), isEmpty);
        await _tap(tester, FeedbackKeys.of('DLG-08', 'confirm'));

        expect(find.byType(GuDialogFrame), findsNothing);
        expect(_memberships().callsTo('leave'), hasLength(1));
        expect(_status(tester, _instantClub), MembershipStatus.left);
        expect(_toast(ToastId.tst39), findsOneWidget);
        expect(_clubs().clubs[_instantClub]!.memberCount, before);
        expect(_location(tester), '/clubs/$_instantClub');
        // Ayrılan kullanıcı yeniden "Katıl" görür.
        expect(_inBar(joinKey), findsOneWidget);

        await _flushToast(tester);
      });

      testWidgets('başvuruya kapalı kulüp: düğme TST-X1 gösterir, hiçbir şey '
          'yazılmaz', (tester) async {
        await _launch(tester, clubId: _closedClub);

        await _tapFinder(
          tester,
          find.descendant(
            of: find.byType(ClubDetailCtaBar),
            matching: find.byType(GuButton),
          ),
        );

        expect(_toast(ToastId.tstX1), findsOneWidget);
        expect(find.byType(JoinApplicationSheet), findsNothing);
        expect(_memberships().applied, isEmpty);
        expect(_memberships().callsTo('joinInstant'), isEmpty);
        expect(_status(tester, _closedClub), isNull);

        await _flushToast(tester);
      });
    },
  );

  group('T-16 · akış · şikayet ve paylaşım (SHT-10 → DLG-12, SHT-15)', () {
    testWidgets('"Bu kulübü şikayet et" → SHT-10: neden seç → gönder → '
        'şikayet yazılır → DLG-12 "Tamam"', (tester) async {
      await _launch(tester, clubId: _approvalClub);
      final l10n = _l10n(tester);

      await _tap(tester, _k('CLB-03.report'));
      expect(find.byType(ReportReasonSheet), findsOneWidget);
      await _tap(tester, ReportReasonSheet.reasonKey(ReportReason.spam));
      await _tap(tester, ReportReasonSheet.submitKey);

      // Hedef kulübün kendisidir (Rules: targetClubId == targetId).
      expect(_reports().reports.values, hasLength(1));
      final report = _reports().reports.values.single;
      expect(report.reporterId, _uid);
      expect(report.targetType, ReportTargetType.club);
      expect(report.targetId, _approvalClub);
      expect(report.targetClubId, _approvalClub);
      expect(report.reason, ReportReason.spam);
      expect(report.note, isEmpty);

      // Sayfa kapanır; DLG-12 kulüp şikayetinde tek "Tamam" ile gelir.
      expect(find.byType(ReportReasonSheet), findsNothing);
      expect(
        tester.widget<GuDialogFrame>(find.byType(GuDialogFrame)).title,
        l10n.dlg12Title,
      );
      expect(find.byKey(FeedbackKeys.of('DLG-12', 'block')), findsNothing);
      await _tap(tester, FeedbackKeys.of('DLG-12', 'ok'));
      expect(find.byType(GuDialogFrame), findsNothing);
      expect(_location(tester), '/clubs/$_approvalClub');
    });

    testWidgets('paylaş → SHT-15 → "Bağlantıyı kopyala": kulüp bağlantısı '
        'panoya yazılır → TST-35', (tester) async {
      await _launch(tester, clubId: _approvalClub);
      const url = '${AppConstants.shareBaseUrl}/clubs/$_approvalClub';

      await _tap(tester, _k('CLB-03.share'));
      expect(find.byType(ShareSheet), findsOneWidget);
      expect(find.text(ShareLinks.display(url)), findsOneWidget);
      await _tap(tester, ShareSheet.keyOf(ShareChoice.copyLink));

      expect(find.byType(ShareSheet), findsNothing);
      expect(_share().copied, [url]);
      expect(_share().sharedTexts, isEmpty);
      expect(_toast(ToastId.tst35), findsOneWidget);

      await _flushToast(tester);
    });
  });
}
