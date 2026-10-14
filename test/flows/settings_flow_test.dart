// T-28 · Uçtan uca ayarlar akışı: gerçek `GuApp` (rota ağacı, yönlendirme,
// oturum katmanı, kabuk, `AppFeedbackService` — sheet / menü / toast gerçekten
// çizilir) + sahte servisler. Oturum hazırdır (`u_mehmet`; `u042` engelli).
//
//   Profil (PRF-01) → ⚙ (W-32) → Ayarlar (SET-01) → Tema → SHT-17 "Koyu"
//   (kalıcı) → Dil → SHT-01 "English" (kalıcı) → metin boyutu %130 (kalıcı)
//   → Engellenenler (SET-02) → "Engeli kaldır" → TST-09 → "Geri al" (engel
//   geri gelir) → geri → Hakkında (SET-04) → "Destek" (SET-05) → konu menüsü
//   "Hata" + mesaj + ek (SHT-16 galeri) → Gönder → TST-23 `#GU-AAAAAB` +
//   başarı kartı → geri → SET-01
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/settings/view/about_view.dart';
import 'package:gu_kulupler/features/settings/view/blocked_users_view.dart';
import 'package:gu_kulupler/features/settings/view/settings_view.dart';
import 'package:gu_kulupler/features/settings/view/support_view.dart';
import 'package:gu_kulupler/features/settings/view/widget/support_sent_card.dart';
import 'package:gu_kulupler/features/settings/view/widget/theme_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/language_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_kulupler/product/navigation/app_router.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../fakes/fake_app_preferences_store.dart';
import '../fakes/fake_auth_repository.dart';
import '../fakes/fake_block_repository.dart';
import '../fakes/fake_support_repository.dart';
import '../fakes/fake_user_repository.dart';
import '../fakes/register_fakes.dart';
import '../features/profile/profile_test_support.dart';
import '../features/settings/blocked_users_test_support.dart';
import '../helpers/test_asset_bundle.dart';

const String _email = 'mehmet.kaya@ogr.gumushane.edu.tr';
const String _message = 'Bildirimler gelmiyor.';

Key _k(String id) => GuKey.action(id);

FakeAppPreferencesStore _store() =>
    GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore;

FakeBlockRepository _blocks() =>
    GetIt.I<BlockRepository>() as FakeBlockRepository;

/// `blocks/{blocker}_{blocked}` etkin mi (soft delete edilmemiş).
bool _isBlocked(String blockedId) =>
    _blocks().blocks['${kProfileUid}_$blockedId']?.isDeleted == false;

FakeSupportRepository _support() =>
    GetIt.I<SupportRepository>() as FakeSupportRepository;

Future<void> _launch(WidgetTester tester) async {
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
  (GetIt.I<AuthRepository>() as FakeAuthRepository)
    ..service.uid = kProfileUid
    ..service.emailVerified = true
    ..currentUser = const AuthUserInfo(
      uid: kProfileUid,
      email: _email,
      emailVerified: true,
    );
  (GetIt.I<UserRepository>() as FakeUserRepository).putActive(
    kProfileUid,
    email: _email,
  );
  seedProfile();
  seedBlocked();
  _store()
    ..values[AppPreferenceKeys.onboardingSeen] = true
    ..values[AppPreferenceKeys.notificationPermissionAsked] = true
    ..values[AppPreferenceKeys.photoAccessExplained] = true;
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    DefaultAssetBundle(
      bundle: TestAssetBundle.instance,
      child: ProviderScope(child: GuApp(toastController: toasts)),
    ),
  );
  await tester.pumpAndSettle();
  expect(
    _container(tester).read(sessionViewModelProvider).status,
    AuthStatus.active,
  );
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GuApp)));

GoRouter _router(WidgetTester tester) =>
    _container(tester).read(appRouterProvider);

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _toast(ToastId id) => find.byKey(ValueKey<ToastId>(id));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
    await initializeDateFormatting('en_GB');
    await initializeDateFormatting('en_US');
  });

  testWidgets('Profil → Ayarlar: tema koyu + dil EN + metin %130 (kalıcı) → '
      'Engellenenler kaldır + Geri al → Hakkında → Destek talebi (konu + '
      'mesaj + ek) → #GU-AAAAAB → geri', (tester) async {
    await _launch(tester);

    // PRF-01 → SET-01 (W-32).
    await _tap(tester, _k('NAV.tab.profile'));
    expect(_location(tester), '/profile');
    await _tap(tester, _k('PRF-01.settings'));
    expect(_location(tester), '/profile/settings');
    expect(find.byType(SettingsView), findsOneWidget);

    // Tema → SHT-17 "Koyu": tercih yazılır, sayfa kapanır.
    await _tap(tester, _k('SET-01.theme'));
    expect(find.byType(ThemeSheet), findsOneWidget);
    await _tap(tester, ThemeSheet.keyOf(ThemeMode.dark));
    expect(find.byType(ThemeSheet), findsNothing);
    expect(
      _container(tester).read(appPreferencesViewModelProvider).themeMode,
      ThemeMode.dark,
    );
    expect(_store().values[AppPreferenceKeys.themeMode], 'dark');
    expect(
      Theme.of(tester.element(find.byType(SettingsView))).brightness,
      Brightness.dark,
    );

    // Dil → SHT-01 "English".
    await _tap(tester, _k('SET-01.language'));
    expect(find.byType(LanguageSheet), findsOneWidget);
    await _tap(tester, LanguageOptions.keyOf(const Locale('en')));
    expect(_store().values[AppPreferenceKeys.locale], 'en');
    expect(
      Localizations.localeOf(
        tester.element(find.byType(SettingsView)),
      ).languageCode,
      'en',
    );

    // Metin boyutu %130 (anında uygulanır, kalıcı).
    await _tap(tester, _k('SET-01.textScale.1.3'));
    expect(
      _container(tester).read(appPreferencesViewModelProvider).textScale,
      GuTextScaleLevel.s130,
    );
    expect(_store().values[AppPreferenceKeys.textScale], 's130');

    // SET-02: engeli kaldır → TST-09 → Geri al.
    await _tap(tester, _k('SET-01.blocked'));
    expect(_location(tester), '/profile/settings/blocked');
    expect(find.byType(BlockedUsersView), findsOneWidget);
    final eren = kBlockedEren.uid;
    await _tap(tester, _k('SET-02.unblock.$eren'));
    expect(_toast(ToastId.tst09), findsOneWidget);
    expect(_isBlocked(eren), isFalse);
    expect(find.byKey(_k('SET-02.unblock.$eren')), findsNothing);
    await _tap(tester, FeedbackKeys.of('TST-09', 'undo'));
    expect(_isBlocked(eren), isTrue);
    expect(find.byKey(_k('SET-02.unblock.$eren')), findsOneWidget);

    // SET-04 → "Destek" (SET-05).
    await _tap(tester, _k('SET-02.back'));
    expect(_location(tester), '/profile/settings');
    await _tap(tester, _k('SET-01.about'));
    expect(_location(tester), '/profile/settings/about');
    expect(find.byType(AboutView), findsOneWidget);
    await _tap(tester, _k('SET-04.support'));
    expect(_location(tester), '/profile/settings/support');
    expect(find.byType(SupportView), findsOneWidget);

    // Konu + mesaj + ek → Gönder → TST-23 `#GU-AAAAAB` + başarı kartı.
    await _tap(tester, _k('SET-05.subject'));
    await _tap(tester, _k('SET-05.subject.bug'));
    await tester.enterText(find.byKey(_k('SET-05.message')), _message);
    await tester.pump();
    await _tap(tester, _k('SET-05.attach'));
    expect(find.byType(PhotoSourceSheet), findsOneWidget);
    await _tap(tester, PhotoSourceSheet.keyOf(PhotoSourceChoice.gallery));
    await _tap(tester, _k('SET-05.send'));

    final ticket = _support().tickets.values.single;
    expect(ticket.ticketNo, 'GU-AAAAAB');
    expect(ticket.id, ticket.ticketNo);
    expect(ticket.userId, kProfileUid);
    expect(ticket.subject, SupportSubject.bug);
    expect(ticket.message, _message);
    expect(ticket.attachmentPaths, hasLength(1));
    expect(_support().attachments.single.uploaderId, kProfileUid);
    expect(_toast(ToastId.tst23), findsOneWidget);
    expect(find.textContaining('#GU-AAAAAB'), findsWidgets);
    expect(find.byType(SupportSentCard), findsOneWidget);

    // Geri: gönderilmiş form kirli değildir → SET-01 (DLG-25 yok).
    await _tap(tester, _k('SET-05.back'));
    expect(_location(tester), '/profile/settings');
    expect(find.byType(SettingsView), findsOneWidget);
    expect(find.byKey(FeedbackKeys.of('DLG-25', 'discard')), findsNothing);
  });
}
