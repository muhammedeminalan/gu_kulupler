// T-14 · integration_test #1 (PLAN §16.8): kayıt → e-posta doğrulama → profil
// tamamlama → kulüpler. Gerçek uygulama (`AppBootstrap` + `GuApp`), gerçek
// Firebase SDK'ları, **yalnızca yerel emülatör**.
//
// Kalite kapısında KOŞMAZ (cihaz / simülatör + açık emülatör gerekir).
// Çalıştırma:
//
//   firebase emulators:start --only auth,firestore,storage \
//     --project demo-gu-kulupler
//   flutter test integration_test/auth_flow_test.dart \
//     --dart-define=ENV=emulator
//
// Adımlar:
//   AUT-01 → AUT-02 kayıt (`ogr.gumushane.edu.tr`, AUT-06 onayı)
//   AUT-03 "Doğruladım" (bağlantıya tıklanmadan) → TST-02
//   Auth emülatörünün OOB kodu REST ile alınır, doğrulama bağlantısı çağrılır
//   AUT-03 "Doğruladım" → AUT-05: fotoğraf atlanır → SHT-02 bölüm → SHT-03
//   sınıf → ilgi alanı → "Tamamla"
//   CLB-01 (kabuk) → DLG-03 "Şimdi değil"
//   Emülatör Firestore'unda `users/{uid}` tamamlanmış profildir.
//
// Sistem izin penceresi açılmaz: fotoğraf adımı atlanır, DLG-03 "Şimdi
// değil" ile kapatılır.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/app_bootstrap.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/features/auth/view/widget/setup_profile_interests_step.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/department_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/year_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/navigation/navigator_keys.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:integration_test/integration_test.dart';

const String _name = 'Entegrasyon Testi';
const String _password = 'Sifre123';
const String _department = 'd02';
const YearLevel _year = YearLevel.second;
const String _interest = 'i01';

/// Bir adımın ekrana gelmesi için beklenen en uzun süre.
const Duration _timeout = Duration(seconds: 30);

/// Bekleme döngüsünün kare aralığı.
const Duration _tick = Duration(milliseconds: 100);

Key _k(String id) => GuKey.action(id);

/// [finder] ekrana gelene kadar kare çizer. `pumpAndSettle` kullanılmaz:
/// iskelet ve yükleniyor animasyonları hiç durmayabilir.
Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(_timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Zaman aşımı: $finder ekrana gelmedi');
    }
    await tester.pump(_tick);
  }
  // Geçiş animasyonu bitsin: dokunma hedefi yerine otursun.
  await tester.pump(GuMotion.slow);
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump(_tick);
  await tester.tap(finder);
  await tester.pump(_tick);
}

Future<void> _enter(WidgetTester tester, String action, String text) async {
  final finder = find.byKey(_k(action));
  await _waitFor(tester, finder);
  await tester.enterText(finder, text);
  await tester.pump(_tick);
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byKey(rootNavigatorKey)));

/// Auth emülatörünün yerel REST ucundan [uri] adresini okur (yalnızca
/// emülatör adresi: `AppEnvironment.emulatorHost`).
Future<String> _get(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode != HttpStatus.ok) {
      fail('Emülatör isteği başarısız (${response.statusCode}): $uri\n$body');
    }
    return body;
  } finally {
    client.close();
  }
}

/// [email] adresine gönderilen doğrulama bağlantısına "tıklar": Auth
/// emülatörünün bekleyen OOB kodunu alır ve eylem ucunu çağırır (PLAN
/// §16.8). Bağlantıdaki ana makine, cihazın emülatörü gördüğü adresle
/// değiştirilir (Android emülatöründe `10.0.2.2`).
Future<void> _clickVerificationLink(String email) async {
  final host = AppEnvironment.emulatorHost;
  const port = AppEnvironment.authPort;
  final listed = await _get(
    Uri(
      scheme: 'http',
      host: host,
      port: port,
      path:
          '/emulator/v1/projects/${AppEnvironment.emulatorProjectId}/oobCodes',
    ),
  );
  final codes =
      ((jsonDecode(listed) as Map<String, dynamic>)['oobCodes'] as List?) ??
      const <Object?>[];
  final match = codes.cast<Map<String, dynamic>>().lastWhere(
    (code) => code['email'] == email && code['requestType'] == 'VERIFY_EMAIL',
    orElse: () => fail('Doğrulama kodu bulunamadı: $email'),
  );
  final link = Uri.parse(match['oobLink'] as String);
  await _get(link.replace(host: host, port: port));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AUT-02 kayıt → AUT-03 doğrulama (TST-02 → OOB bağlantısı) → '
      'AUT-05 profil → CLB-01', (tester) async {
    // Gerçek projeye hiçbir istek gitmemeli: emülatör açıkça seçilmiş olmalı.
    expect(
      AppEnvironment.isEmulator,
      isTrue,
      reason: 'Bu test yalnızca --dart-define=ENV=emulator ile koşar',
    );

    // Uygulamanın hata yakalayıcıları test çerçevesininkini ezmesin.
    final frameworkOnError = FlutterError.onError;
    await AppBootstrap.run(
      appBuilder: (toastController) => GuApp(toastController: toastController),
    );
    FlutterError.onError = frameworkOnError;
    expect(AppEnvironment.configured, AppEnv.emulator);

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'it$stamp@ogr.gumushane.edu.tr';
    final auth = GetIt.I<AuthRepository>();
    final users = GetIt.I<UserRepository>();

    // İlk kurulumda tanıtım görünür; önceki koşudan kalan oturum kapatılır.
    await tester.pump(GuMotion.slow);
    if (auth.currentUser != null) await auth.signOut();
    final register = find.byKey(_k('AUT-01.register'));
    final skip = find.byKey(_k('ONB-01.skip'));
    final deadline = DateTime.now().add(_timeout);
    while (register.evaluate().isEmpty && skip.evaluate().isEmpty) {
      if (DateTime.now().isAfter(deadline)) fail('Giriş ekranı açılmadı');
      await tester.pump(_tick);
    }
    if (skip.evaluate().isNotEmpty) await _tap(tester, _k('ONB-01.skip'));

    // AUT-01 → AUT-02 · kayıt.
    await _tap(tester, _k('AUT-01.register'));
    await _enter(tester, 'AUT-02.name', _name);
    await _enter(tester, 'AUT-02.email', email);
    await _enter(tester, 'AUT-02.password', _password);
    await _enter(tester, 'AUT-02.password2', _password);
    await _tap(tester, _k('AUT-02.legal'));
    await _tap(tester, _k('AUT-06.accept'));
    await _tap(tester, _k('AUT-02.submit'));

    // AUT-03 · bağlantıya tıklanmadan "Doğruladım": TST-02.
    await _tap(tester, _k('AUT-03.confirm'));
    await _waitFor(tester, find.text(_l10n(tester).tst02));
    final uid = auth.currentUser!.uid;
    expect(auth.currentUser!.emailVerified, isFalse);
    // Profil belgesi doğrulanmamış oturumda oluşturulmaz (W-56).
    expect((await users.getUser(uid)).dataOrNull, isNull);

    // Doğrulama bağlantısı → "Doğruladım" → AUT-05.
    await _clickVerificationLink(email);
    // TST-02 alt kenardaki düğmeleri örtmesin.
    await tester.pump(GuMotion.toastDefault);
    await _tap(tester, _k('AUT-03.confirm'));
    await _waitFor(tester, find.byKey(_k('AUT-05.skipPhoto')));
    expect(auth.currentUser!.emailVerified, isTrue);

    // AUT-05 · fotoğraf atlanır → bölüm + sınıf → ilgi alanı → "Tamamla".
    await _tap(tester, _k('AUT-05.skipPhoto'));
    await _tap(tester, _k('AUT-05.department'));
    await _tap(tester, DepartmentPickerSheet.keyOf(_department));
    await _tap(tester, _k('AUT-05.year'));
    await _tap(tester, YearPickerSheet.keyOf(_year));
    await _tap(tester, _k('AUT-05.next'));
    await _tap(tester, SetupProfileInterestsStep.keyOf(_interest));
    await _tap(tester, _k('AUT-05.finish'));

    // CLB-01 · kabuk; ilk aktif girişte DLG-03 bir kez sorulur.
    await _waitFor(tester, find.byKey(_k('NAV.tab.clubs')));
    final notNow = FeedbackKeys.of('DLG-03', 'notNow');
    if (find.byKey(notNow).evaluate().isNotEmpty) await _tap(tester, notNow);

    // Emülatör Firestore'u: profil Rules'tan geçerek yazıldı.
    final user = (await users.getUser(uid)).dataOrNull;
    expect(user, isNotNull);
    expect(user!.name, _name);
    expect(user.department, _department);
    expect(user.year, _year);
    expect(user.interests, [_interest]);
    expect(user.profileComplete, isTrue);
    expect((await users.getPrivateAccount(uid)).dataOrNull?.email, email);

    // Karşılama toast'ının süresi dolsun (bekleyen zamanlayıcı kalmasın).
    await tester.pump(GuMotion.toastUndo);
  });
}
