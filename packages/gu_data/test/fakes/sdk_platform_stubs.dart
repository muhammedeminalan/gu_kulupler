// El yazımı `firebase_remote_config` ve `firebase_crashlytics` SDK çiftleri
// (mock kütüphanesi yok — docs/testing.md §1.2; bu iki eklentinin hazır sahte
// paketi de yoktur).
import 'dart:async';
import 'dart:convert';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Kaynağı ve ham değeri verilen Remote Config değeri.
final class StubRemoteConfigValue extends RemoteConfigValue {
  /// Sunucudan gelmiş [text] değeri.
  StubRemoteConfigValue.remote(String text)
    : super(utf8.encode(text), ValueSource.valueRemote);

  /// Tanımsız anahtarın değeri (SDK'nın statik varsayılanı).
  StubRemoteConfigValue.missing() : super(null, ValueSource.valueStatic);
}

/// Bellekte çalışan Remote Config: [values] okunur, çağrılar kaydedilir;
/// [fetchError] / [activateError] / [readError] ile hata betiklenir.
final class StubRemoteConfig implements FirebaseRemoteConfig {
  /// Sunucudan gelmiş değerler (anahtar → ham metin).
  final Map<String, String> values = {};

  /// [setConfigSettings] çağrılarına verilen ayarlar, çağrı sırasıyla.
  final List<RemoteConfigSettings> appliedSettings = [];

  /// [onConfigUpdated] akışının denetleyicisi.
  final StreamController<RemoteConfigUpdate> updates =
      StreamController<RemoteConfigUpdate>();

  /// [fetchAndActivate] sonucu.
  bool fetchResult = true;

  /// Doluysa [fetchAndActivate] bu hatayla biter.
  Object? fetchError;

  /// `true` ise [fetchAndActivate] hiç tamamlanmaz.
  bool fetchHangs = false;

  /// Doluysa [activate] bu hatayla biter.
  Object? activateError;

  /// Doluysa [getValue] bu hatayı fırlatır.
  Object? readError;

  /// [fetchAndActivate] çağrı sayısı.
  int fetches = 0;

  /// [activate] çağrı sayısı.
  int activations = 0;

  @override
  Future<void> setConfigSettings(
    RemoteConfigSettings remoteConfigSettings,
  ) async => appliedSettings.add(remoteConfigSettings);

  @override
  Future<bool> fetchAndActivate() {
    fetches++;
    if (fetchHangs) return Completer<bool>().future;
    final error = fetchError;
    return error == null ? Future.value(fetchResult) : Future.error(error);
  }

  @override
  Future<bool> activate() {
    activations++;
    final error = activateError;
    return error == null ? Future.value(true) : Future.error(error);
  }

  @override
  RemoteConfigValue getValue(String key) {
    final error = readError;
    if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
    final text = values[key];
    return text == null
        ? StubRemoteConfigValue.missing()
        : StubRemoteConfigValue.remote(text);
  }

  @override
  Stream<RemoteConfigUpdate> get onConfigUpdated => updates.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Kaydedilmiş bir `recordError` çağrısı.
typedef RecordedCrash = ({
  Object? error,
  StackTrace? stack,
  Object? reason,
  bool fatal,
});

/// Çağrıları kaydeden Crashlytics; [error] doluysa her çağrı o hatayla biter.
final class StubCrashlytics implements FirebaseCrashlytics {
  /// Doluysa her çağrının fırlattığı hata.
  Object? error;

  /// `recordError` çağrıları.
  final List<RecordedCrash> crashes = [];

  /// `log` satırları.
  final List<String> logs = [];

  /// `setUserIdentifier` değerleri.
  final List<String> userIds = [];

  /// `setCrashlyticsCollectionEnabled` değerleri.
  final List<bool> collectionFlags = [];

  Future<void> _call(void Function() record) {
    final failure = error;
    if (failure != null) return Future.error(failure);
    record();
    return Future.value();
  }

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool? printDetails,
    bool fatal = false,
  }) => _call(
    () => crashes.add((
      error: exception as Object?,
      stack: stack,
      reason: reason as Object?,
      fatal: fatal,
    )),
  );

  @override
  Future<void> log(String message) => _call(() => logs.add(message));

  @override
  Future<void> setUserIdentifier(String identifier) =>
      _call(() => userIds.add(identifier));

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) =>
      _call(() => collectionFlags.add(enabled));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
