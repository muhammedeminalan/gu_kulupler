import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unread_notification_clubs.g.dart';

/// Okunmamış bildirimi olan kulüplerin kimlikleri (W-68) — CLB-01
/// "Kulüplerim" kartının noktası (`MyClubChip.unread`; prototip
/// `notifsFor(u).some((n) => !n.read && n.refs.clubId === m.clubId)`,
/// `screens-clubs.js:25`).
///
/// Kaynak `NotificationsViewModel`'dir (canlı gelen kutusu, tercih süzgecinden
/// geçmiş okunmamışlar): feature'lar birbirini import edemediği için küme bu
/// ortak sağlayıcıya yazılır ([set]), kulüpler ekranı buradan okur. Oturum
/// kullanıcısı değişince boşalır.
@Riverpod(keepAlive: true)
final class UnreadNotificationClubs extends _$UnreadNotificationClubs {
  @override
  Set<String> build() {
    ref.watch(sessionViewModelProvider.select((s) => s.uid));
    return const <String>{};
  }

  /// Kümeyi [clubIds] yapar (değişmediyse dinleyiciler uyarılmaz).
  void set(Set<String> clubIds) {
    if (setEquals(state, clubIds)) return;
    state = Set<String>.unmodifiable(clubIds);
  }
}
