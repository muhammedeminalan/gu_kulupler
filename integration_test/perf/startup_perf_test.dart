// T-44 · açılış ölçümü: `AppBootstrap.run` → ilk kare → açılış beklemesi
// (`SplashHold`) kalkıp CLB-01 çizilene dek. Zaman çizelgesi `startup`
// anahtarıyla raporlanır (`test_driver/perf_driver.dart` → `build/`).
//
// Oturum önceki koşudan kalmışsa (Auth emülatörü oturumu cihazda saklanır)
// ölçüm saf açılıştır; yoksa demo üyeyle giriş ölçüme girer ve
// `startup_signed_in_during_run: true` raporlanır — bu durumda ölçümü bir
// kez daha koşun. Komut: `docs/reports/T-44-perf.md`.
import 'package:flutter_test/flutter_test.dart';

import 'perf_harness.dart';

void main() {
  final binding = perfBinding();

  testWidgets('açılış: ilk kare ve CLB-01', (tester) async {
    late Duration firstFrame;
    late Duration clubList;
    var signedIn = false;
    final watch = Stopwatch()..start();
    await binding.traceAction(() async {
      firstFrame = await perfLaunch(tester);
      signedIn = await perfEnsureClubList(tester);
      clubList = watch.elapsed;
    }, reportKey: 'startup');
    binding.reportData = <String, dynamic>{
      ...?binding.reportData,
      'startup_first_frame_ms': firstFrame.inMilliseconds,
      'startup_club_list_ms': clubList.inMilliseconds,
      'startup_signed_in_during_run': signedIn,
    };
  });
}
