import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'splash_hold.g.dart';

/// Açılış beklemesi (architecture §4): açılış ekranı (SYS-01) **en az** logo
/// animasyonu kadar görünür.
///
/// `true` iken router kullanıcıyı `/splash`'ten çıkarmaz — oturum animasyon
/// bitmeden çözülse de (`AppRedirect.goRouterRedirect`). Animasyon bitince
/// açılış ekranı [release] çağırır; `SessionRefreshListenable` yönlendirmeyi
/// yeniden değerlendirtir ve R2–R7 uygulanır. Tek yönlüdür: bir kez kalkar
/// (soğuk açılış başına).
@Riverpod(keepAlive: true)
final class SplashHold extends _$SplashHold {
  @override
  bool build() => true;

  /// Beklemeyi kaldırır (logo animasyonu tamamlandı).
  void release() {
    if (state) state = false;
  }
}
