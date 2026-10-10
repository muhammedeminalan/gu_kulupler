// gu_ui testleri için dosya tabanlı varlık paketi (CD-23, PLAN §7.11/§16).
//
// Varlıklar kök uygulamanın `assets/` klasöründedir (kayıt kök pubspec'te);
// gu_ui'nin kendi paketi yoktur. `flutter test` gu_ui paket kökünde koştuğu
// için anahtar `assets/...` → `../../assets/...` dosyasına çözülür. `pumpApp`
// bu paketi `DefaultAssetBundle` olarak sarar; `GuIcon`, `GuIllustration`,
// `GuCover`, `GuLogo` gerçek dosyaları okur.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Kök `assets/` klasörünü okuyan `CachingAssetBundle`.
///
/// * Okuma eşzamanlıdır (`SynchronousFuture`): sahte zamanlı widget testinde
///   `runAsync` gerekmeden tek `pump` ile tamamlanır.
/// * `AssetManifest.bin` klasör taranarak üretilir (`Image.asset` /
///   `AssetImage` çözünürlük varyantı araması için).
/// * Olmayan anahtar `FlutterError` ile sonuçlanır (üretimdeki
///   "Unable to load asset" eşdeğeri).
class GuTestAssetBundle extends CachingAssetBundle {
  GuTestAssetBundle({String? repoRoot})
    : _repoRoot = repoRoot ?? Directory('../..').absolute.path;

  /// Testlerin paylaştığı tek örnek (bayt önbelleği ortak).
  static final GuTestAssetBundle instance = GuTestAssetBundle();

  static const String _manifestKey = 'AssetManifest.bin';
  static const String _assetsPrefix = 'assets/';

  final String _repoRoot;
  final Map<String, ByteData> _bytes = {};

  @override
  Future<ByteData> load(String key) {
    final cached = _bytes[key];
    if (cached != null) return SynchronousFuture(cached);
    final ByteData data;
    if (key == _manifestKey) {
      data = _buildManifest();
    } else {
      final file = File('$_repoRoot/$key');
      if (!key.startsWith(_assetsPrefix) || !file.existsSync()) {
        return Future.error(
          FlutterError('GuTestAssetBundle: "$key" bulunamadı (${file.path})'),
        );
      }
      data = ByteData.sublistView(file.readAsBytesSync());
    }
    _bytes[key] = data;
    return SynchronousFuture(data);
  }

  /// `assets/` altındaki her dosya için tek varyantlı manifest
  /// (`{anahtar: [{asset: anahtar}]}`, `StandardMessageCodec`).
  ByteData _buildManifest() {
    final root = Directory('$_repoRoot/$_assetsPrefix');
    final manifest = <String, List<Map<String, Object>>>{};
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File) continue;
      final relative = entity.path
          .substring(root.path.length)
          .replaceAll(r'\', '/');
      final key = '$_assetsPrefix$relative';
      manifest[key] = [
        {'asset': key},
      ];
    }
    return const StandardMessageCodec().encodeMessage(manifest)!;
  }
}
