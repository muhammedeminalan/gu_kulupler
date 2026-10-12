// AUT-05 · Profilini tamamla — gerçek uygulama kabuğunda (GuApp + gerçek
// router + gerçek FeedbackService) uçtan uca: doğrulanmış, profili olmayan
// oturum AUT-05'e yönlenir → üç adım (SHT-02, SHT-03 gerçek alt sayfalarla)
// → "Tamamla" → kabuk (`/clubs`) + TST-05; kapat → DLG-25 → "Kaydetmeden
// çık" → giriş. Ekran kendisi gezinmez: yönlendirme router'dadır.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/auth/view/login_view.dart';
import 'package:gu_kulupler/features/auth/view/setup_profile_view.dart';
import 'package:gu_kulupler/features/auth/view/widget/setup_profile_interests_step.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/department_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/year_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_kulupler/product/navigation/shell/app_shell_view.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_auth_repository.dart';
import '../../../fakes/fake_user_repository.dart';
import '../../../fakes/register_fakes.dart';

const String _uid = 'u1';
const String _email = 'ayse.demir@ogr.gumushane.edu.tr';
const String _name = 'Ayşe Demir';

Key _k(String id) => GuKey.action(id);

FakeAuthRepository _auth() => GetIt.I<AuthRepository>() as FakeAuthRepository;

FakeUserRepository _users() => GetIt.I<UserRepository>() as FakeUserRepository;

/// Uygulamayı doğrulanmış ama profili olmayan oturumla açar ve AUT-05'e
/// yönlenmesini bekler.
Future<void> _launch(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await GetIt.I.reset();
  registerDefaultFakes();
  addTearDown(GetIt.I.reset);
  final toasts = GuToastController();
  addTearDown(toasts.dispose);
  await GetIt.I.unregister<FeedbackService>();
  GetIt.I.registerSingleton<FeedbackService>(
    AppFeedbackService(navigatorKey: rootNavigatorKey, toastController: toasts),
  );
  (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
          .values[AppPreferenceKeys.onboardingSeen] =
      true;
  _auth().currentUser = const AuthUserInfo(
    uid: _uid,
    email: _email,
    emailVerified: true,
    displayName: _name,
  );
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(child: GuApp(toastController: toasts)));
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GuApp)));

String _location(WidgetTester tester) => _container(
  tester,
).read(appRouterProvider).routerDelegate.currentConfiguration.uri.toString();

AuthStatus _status(WidgetTester tester) =>
    _container(tester).read(sessionViewModelProvider).status;

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byKey(rootNavigatorKey)));

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pump();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  group('AUT-05 · Profilini tamamla · gerçek router ile akış', () {
    testWidgets('doğrulanmış + profilsiz oturum AUT-05’e yönlenir; üç adım → '
        '"Tamamla" → kabuk (/clubs) + TST-05', (tester) async {
      await _launch(tester);
      expect(_location(tester), '/setup-profile');
      expect(_status(tester), AuthStatus.profileIncomplete);
      expect(find.byType(SetupProfileView), findsOneWidget);

      // 1 · fotoğraf atlanır.
      await _tap(tester, _k('AUT-05.skipPhoto'));

      // 2 · bölüm (SHT-02) ve sınıf (SHT-03) gerçek alt sayfalardan seçilir.
      await _tap(tester, _k('AUT-05.department'));
      expect(find.byType(DepartmentPickerSheet), findsOneWidget);
      await _tap(tester, DepartmentPickerSheet.keyOf('d01'));
      expect(find.byType(DepartmentPickerSheet), findsNothing);
      await _tap(tester, _k('AUT-05.year'));
      expect(find.byType(YearPickerSheet), findsOneWidget);
      await _tap(tester, YearPickerSheet.keyOf(YearLevel.third));
      expect(find.byType(YearPickerSheet), findsNothing);
      await _tap(tester, _k('AUT-05.next'));

      // 3 · ilgi alanları ve gönderim.
      await _tap(tester, SetupProfileInterestsStep.keyOf('i01'));
      await _tap(tester, SetupProfileInterestsStep.keyOf('i11'));
      await _tap(tester, _k('AUT-05.finish'));

      final user = _users().users[_uid]!;
      expect(user.name, _name);
      expect(user.department, 'd01');
      expect(user.year, YearLevel.third);
      expect(user.interests, ['i01', 'i11']);
      expect(user.profileComplete, isTrue);
      expect(_users().accounts[_uid]!.email, _email);

      // Ekran gezinmedi: oturum `active` oldu, router kabuğa yönlendirdi.
      expect(_status(tester), AuthStatus.active);
      expect(_location(tester), '/clubs');
      expect(find.byType(AppShellView), findsOneWidget);
      expect(find.byType(SetupProfileView), findsNothing);
      expect(
        find.byKey(const ValueKey<ToastId>(ToastId.tst05)),
        findsOneWidget,
      );
      expect(find.text(_l10n(tester).tst05('Ayşe')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AUT-05.close seçim varken: DLG-25 (Kaydet yok) → '
        '"Düzenlemeye devam et" ekranda kalır; "Kaydetmeden çık" oturumu '
        'kapatır ve girişe döner', (tester) async {
      await _launch(tester);
      await _tap(tester, _k('AUT-05.skipPhoto'));
      await _tap(tester, _k('AUT-05.department'));
      await _tap(tester, DepartmentPickerSheet.keyOf('d05'));
      final dlg25 = DialogId.dlg25.designId;

      await _tap(tester, _k('AUT-05.close'));
      expect(find.text(_l10n(tester).dlg25Title), findsOneWidget);
      expect(find.byKey(FeedbackKeys.of(dlg25, 'save')), findsNothing);
      await _tap(tester, FeedbackKeys.of(dlg25, 'keep'));
      expect(find.text(_l10n(tester).dlg25Title), findsNothing);
      expect(_location(tester), '/setup-profile');
      expect(_status(tester), AuthStatus.profileIncomplete);

      // Sistem geri tuşu da aynı soruyu sorar.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(_l10n(tester).dlg25Title), findsOneWidget);
      await _tap(tester, FeedbackKeys.of(dlg25, 'discard'));

      expect(_auth().callsTo('signOut'), hasLength(1));
      expect(_status(tester), AuthStatus.signedOut);
      expect(_location(tester), '/login');
      expect(find.byType(LoginView), findsOneWidget);
      expect(_users().users, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AUT-05.close seçim yokken doğrudan oturumu kapatır ve girişe '
        'döner', (tester) async {
      await _launch(tester);

      await _tap(tester, _k('AUT-05.close'));

      expect(find.text(_l10n(tester).dlg25Title), findsNothing);
      expect(_status(tester), AuthStatus.signedOut);
      expect(_location(tester), '/login');
    });
  });
}
