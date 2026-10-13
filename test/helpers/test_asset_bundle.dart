// Kök testler için dosya tabanlı varlık paketi (T-16; gu_ui'deki
// `packages/gu_ui/test/helpers/test_asset_bundle.dart` ile aynı yaklaşım).
//
// `pumpApp` / `pumpAppRouter` ağacı bu paketle sarar (`DefaultAssetBundle`):
// `GuIcon`, `GuCover`, `GuIllustration`, `GuLogo` varlıklarını depo kökündeki
// dosyadan **eşzamanlı** okur.
//
// Neden: 50 KB'den büyük metin varlığını (`assets/covers/*-dots.svg` kapak
// şablonları) `rootBundle.loadString` ayrı yalıtımda çözer; sahte zamanlı
// widget testinde bu okuma tamamlanmaz, flutter_svg önbelleğinde asılı kalır
// ve dosyadaki sonraki testleri de kilitler.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Depo kökündeki varlıkları (`assets/...`) eşzamanlı okuyan paket.
///
/// * Anahtar depo köküne göre dosya yoludur (`flutter test` kökte koşar).
/// * Dosyası olmayan anahtar (`AssetManifest.bin`, `FontManifest.json` …)
///   `rootBundle`'a devredilir: test derlemesinin ürettiği varlıklar eskisi
///   gibi okunur.
final class TestAssetBundle extends CachingAssetBundle {
  TestAssetBundle._();

  /// Testlerin paylaştığı tek örnek (flutter_svg önbellek anahtarı paketi de
  /// içerir; bayt önbelleği ortaktır).
  static final TestAssetBundle instance = TestAssetBundle._();

  static const String _assetsPrefix = 'assets/';

  final Map<String, ByteData> _bytes = <String, ByteData>{};

  /// [key] depo kökünde bir varlık dosyasıysa baytları, değilse `null`.
  ByteData? _read(String key) {
    final cached = _bytes[key];
    if (cached != null) return cached;
    if (!key.startsWith(_assetsPrefix)) return null;
    final file = File(key);
    if (!file.existsSync()) return null;
    return _bytes[key] = ByteData.sublistView(file.readAsBytesSync());
  }

  @override
  Future<ByteData> load(String key) {
    final data = _read(key);
    return data == null
        ? rootBundle.load(key)
        : SynchronousFuture<ByteData>(data);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    final data = _read(key);
    return data == null
        ? rootBundle.loadString(key, cache: cache)
        : SynchronousFuture<String>(utf8.decode(Uint8List.sublistView(data)));
  }
}
