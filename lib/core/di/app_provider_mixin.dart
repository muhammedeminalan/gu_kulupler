import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/connectivity/connectivity_view_model.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/product/init/app_preferences_state.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';

/// `ConsumerState` tabanlı view'ların kök ViewModel'lere tek biçimli erişimi
/// (D-04, CD-92). View dosyasında servis bulucu çağrılmaz (HC13).
mixin AppProviderMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Oturum ve rol çözümü (izlenir).
  SessionState get session => ref.watch(sessionViewModelProvider);

  /// Oturumdaki kullanıcının kimliği; oturum yoksa `null`. Yalnızca bu alan
  /// değişince yeniden kurar.
  String? get uid => ref.watch(sessionViewModelProvider.select((s) => s.uid));

  /// Kullanıcı süper admin mi? Yalnızca bu alan değişince yeniden kurar.
  bool get isSuperAdmin =>
      ref.watch(sessionViewModelProvider.select((s) => s.isSuperAdmin));

  /// Oturum işlemleri (`signOut`, `resolve`, `markOnboardingSeen` …).
  SessionViewModel get sessionNotifier =>
      ref.read(sessionViewModelProvider.notifier);

  /// Tema / dil / metin ölçeği tercihleri (izlenir).
  AppPreferencesState get appPreferences =>
      ref.watch(appPreferencesViewModelProvider);

  /// Cihaz çevrimdışı mı? Yalnızca bu alan değişince yeniden kurar.
  bool get isOffline =>
      ref.watch(connectivityViewModelProvider.select((s) => s.isOffline));

  /// Tercih yazıcıları.
  AppPreferencesViewModel get appPreferencesNotifier =>
      ref.read(appPreferencesViewModelProvider.notifier);
}

/// `ConsumerWidget` tabanlı view'lar için aynı erişim; `WidgetRef` parametre
/// olarak verilir (CD-92).
mixin AppProviderStateMixin on ConsumerWidget {
  /// Oturum ve rol çözümü (izlenir).
  SessionState sessionOf(WidgetRef ref) => ref.watch(sessionViewModelProvider);

  /// Tema / dil / metin ölçeği tercihleri (izlenir).
  AppPreferencesState appPreferencesOf(WidgetRef ref) =>
      ref.watch(appPreferencesViewModelProvider);

  /// Cihaz çevrimdışı mı? Yalnızca bu alan değişince yeniden kurar.
  bool isOfflineOf(WidgetRef ref) =>
      ref.watch(connectivityViewModelProvider.select((s) => s.isOffline));
}
