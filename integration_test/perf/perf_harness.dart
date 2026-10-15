// T-44 · profil ölçümü ortak kabuğu (PLAN §21 #11): gerçek uygulama
// (`AppBootstrap` + `GuApp`), yerel emülatör + seed verisi, demo hesap.
//
// Kalite kapısında KOŞMAZ (cihaz + açık emülatör gerekir). Senaryolar
// `integration_test/perf/*_perf_test.dart`; sürücü `test_driver/perf_driver
// .dart` zaman çizelgesi özetini `build/` altına yazar. Komutlar ve neye
// bakılacağı: `docs/reports/T-44-perf.md`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/bootstrap/app_bootstrap.dart';
import 'package:gu_kulupler/core/bootstrap/gu_app.dart';
import 'package:gu_kulupler/core/env/app_environment.dart';
import 'package:gu_kulupler/features/clubs/view/club_list_view.dart';
import 'package:gu_kulupler/features/system/debug_menu/provider/debug_demo_accounts.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:integration_test/integration_test.dart';

/// Bir adımın ekrana gelmesi için beklenen en uzun süre.
const Duration perfTimeout = Duration(seconds: 30);

/// Bekleme döngüsünün kare aralığı.
const Duration perfTick = Duration(milliseconds: 100);

/// Kaydırma ölçümünde tek fırlatmanın hızı (dp/sn) ve mesafesi.
const double perfFlingSpeed = 4000;

/// Tek fırlatmanın kaydırma mesafesi (dp).
const double perfFlingDistance = 600;

/// Fırlatmadan sonra kaydırmanın durması için çizilen süre.
const Duration perfFlingSettle = Duration(milliseconds: 1200);

/// Ölçüm bağlaması: kareler gerçek zamanlı çizilir (profil ölçümü test
/// çerçevesinin sahte saatini değil, cihazın kare hattını görmeli).
IntegrationTestWidgetsFlutterBinding perfBinding() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  return binding;
}

/// [finder] ekrana gelene kadar kare çizer (`pumpAndSettle` yok: iskelet
/// animasyonları durmayabilir).
Future<void> perfWaitFor(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(perfTimeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Zaman aşımı: $finder ekrana gelmedi');
    }
    await tester.pump(perfTick);
  }
  await tester.pump(GuMotion.slow);
}

/// [key] öğesine dokunur (görünene kadar bekler).
Future<void> perfTap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await perfWaitFor(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump(perfTick);
  await tester.tap(finder);
  await tester.pump(perfTick);
}

/// Uygulamayı açar (emülatör zorunlu). Dönen süre: `AppBootstrap.run`
/// başlangıcından ilk kareye.
Future<Duration> perfLaunch(WidgetTester tester) async {
  expect(
    AppEnvironment.isEmulator,
    isTrue,
    reason: 'Profil ölçümü yalnızca --dart-define=ENV=emulator ile koşar',
  );
  final watch = Stopwatch()..start();
  // Uygulamanın hata yakalayıcıları test çerçevesininkini ezmesin.
  final frameworkOnError = FlutterError.onError;
  await AppBootstrap.run(
    appBuilder: (toastController) => GuApp(toastController: toastController),
  );
  FlutterError.onError = frameworkOnError;
  await tester.pump();
  return watch.elapsed;
}

/// Oturum yoksa seed'deki demo üyeyle (`u_mehmet`, `c01` üyesi) emülatörde
/// oturum açar; tanıtım ve DLG-03 geçilir. CLB-01 açılınca döner.
/// `true` → bu koşuda oturum açıldı (açılış süresine giriş dahildir).
Future<bool> perfEnsureClubList(WidgetTester tester) async {
  final auth = GetIt.I<AuthRepository>();
  var signedIn = false;
  if (auth.currentUser == null) {
    final member = DebugDemoAccounts.all.firstWhere(
      (account) => account.role == DebugDemoRole.member,
    );
    final result = await auth.signIn(
      email: member.email,
      password: DebugDemoAccounts.password,
    );
    if (result case FirebaseFailure(:final error)) {
      fail('Demo hesap girişi başarısız ($error) — seed yüklü mü?');
    }
    signedIn = true;
  }
  final list = find.byType(ClubListView);
  final skip = GuKey.action('ONB-01.skip');
  final deadline = DateTime.now().add(perfTimeout);
  while (list.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) fail('CLB-01 açılmadı');
    if (find.byKey(skip).evaluate().isNotEmpty) {
      await perfTap(tester, skip);
    }
    await tester.pump(perfTick);
  }
  final notNow = FeedbackKeys.of('DLG-03', 'notNow');
  await tester.pump(GuMotion.slow);
  if (find.byKey(notNow).evaluate().isNotEmpty) await perfTap(tester, notNow);
  return signedIn;
}

/// [scrollable] alanını [flings] kez aşağı, sonra aynı sayıda yukarı
/// fırlatır; her fırlatmadan sonra kaydırma durana dek gerçek kare çizilir.
Future<void> perfFlingDownUp(
  WidgetTester tester,
  Finder scrollable, {
  int flings = 6,
}) async {
  for (final direction in const [-1, 1]) {
    for (var index = 0; index < flings; index++) {
      await tester.fling(
        scrollable,
        Offset(0, direction * perfFlingDistance),
        perfFlingSpeed,
      );
      await tester.pump(perfFlingSettle);
    }
  }
}
