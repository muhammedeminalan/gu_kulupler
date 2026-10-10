// Taşma toplayıcı (D-21, testing.md §5, PLAN §16.2).
//
// `FlutterError.onError` sarmalanır: taşma/yerleşim hataları [collected]'a
// alınır, diğer hatalar önceki işleyiciye (flutter_test bağlayıcısı)
// iletilir → `tester.takeException()` ile görünür kalır. Kurulum/söküm
// `DeviceMatrix.run` içinde `try/finally` ile yapılır (flutter_test
// `FlutterError.onError`'ın test sonunda geri konmasını bekler).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

abstract final class OverflowDetector {
  /// Hata sayılan mesaj parçaları.
  static const List<String> patterns = [
    'A RenderFlex overflowed',
    'RenderBox was not laid out',
    'overflowed by',
  ];

  /// Kurulumdan (ya da son [reset]'ten) beri yakalanan taşma hataları.
  static final List<FlutterErrorDetails> collected = [];

  static FlutterExceptionHandler? _previous;
  static bool _installed = false;

  /// Kurulu mu.
  static bool get isInstalled => _installed;

  /// `FlutterError.onError`'ı sarar ve [collected]'ı temizler (tekrar
  /// çağrı etkisiz).
  static void install() {
    if (_installed) return;
    _previous = FlutterError.onError;
    _installed = true;
    collected.clear();
    FlutterError.onError = _handle;
  }

  /// Önceki işleyiciyi geri koyar (kurulu değilse etkisiz).
  static void uninstall() {
    if (!_installed) return;
    FlutterError.onError = _previous;
    _previous = null;
    _installed = false;
  }

  /// [collected]'ı temizler.
  static void reset() => collected.clear();

  /// [details] bir taşma/yerleşim hatası mı ([patterns]).
  static bool isOverflow(FlutterErrorDetails details) {
    final text = details.exceptionAsString();
    return patterns.any(text.contains);
  }

  /// Taşma yakalandıysa testi [context] adıyla düşürür (`TestFailure`);
  /// [collected] tüketilir.
  static void assertNone(String context) {
    if (collected.isEmpty) return;
    final lines = [
      for (final d in collected)
        '  • ${d.exceptionAsString().split('\n').first}',
    ];
    collected.clear();
    fail('Taşma ($context) — ${lines.length} hata:\n${lines.join('\n')}');
  }

  static void _handle(FlutterErrorDetails details) {
    if (isOverflow(details)) {
      collected.add(details);
      return;
    }
    _previous?.call(details);
  }
}
