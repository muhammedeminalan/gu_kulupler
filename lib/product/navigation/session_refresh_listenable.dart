import 'package:flutter/foundation.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/navigation/splash_hold.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_refresh_listenable.g.dart';

/// Router'ın `refreshListenable`'ı: oturum durumu her değiştiğinde
/// yönlendirmeyi yeniden değerlendirtir (PLAN §13.1).
///
/// Rol düşürülen kullanıcı bulunduğu yönetim ekranından, oturumu kapanan
/// kullanıcı uygulama rotalarından böyle atılır. Açılış beklemesi
/// (`SplashHold`) kalktığında da bildirir: açılışta bekleyen kullanıcı o an
/// yönlendirilir.
final class SessionRefreshListenable extends ChangeNotifier {
  /// [ref] üzerinden `SessionViewModel`'i ve açılış beklemesini dinler;
  /// dinleme [ref]'in ömrüyle biter.
  SessionRefreshListenable(Ref ref) {
    ref
      ..listen<SessionState>(sessionViewModelProvider, (previous, next) {
        if (previous != next) notifyListeners();
      })
      ..listen<bool>(splashHoldProvider, (previous, next) {
        if (previous != next) notifyListeners();
      });
  }
}

/// Uygulama ömrü boyunca tek [SessionRefreshListenable].
@Riverpod(keepAlive: true)
SessionRefreshListenable sessionRefreshListenable(Ref ref) {
  final listenable = SessionRefreshListenable(ref);
  ref.onDispose(listenable.dispose);
  return listenable;
}
