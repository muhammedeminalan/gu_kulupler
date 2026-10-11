import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_clock_provider.g.dart';

/// View katmanının [AppClock] köprüsü (`feedbackServiceProvider` kalıbı,
/// CD-93): view ve widget dosyalarında servis bulucu çağrılmaz (HC13).
///
/// Geri sayımlar hedef anı State'ten, "şu an"ı buradan alır:
/// `GuCountdown(until: state.lockedUntil, now: ref.read(appClockProvider)
/// .nowUtc, …)` (PLAN §12.1; `DateTime.now()` doğrudan çağrılmaz).
/// ViewModel'ler `ProjectDependencyMixin.appClock` kullanır. Testte
/// `registerDefaultFakes` `FakeAppClock` kaydeder; ayrıca override gerekmez.
@Riverpod(keepAlive: true)
AppClock appClock(Ref ref) => GetIt.I<AppClock>();
