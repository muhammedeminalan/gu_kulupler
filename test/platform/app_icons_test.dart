// T-46 · uygulama ve bildirim ikonları (2026-10-16): dosyalar yerinde, biçimleri
// platform kurallarına uygun (iOS ikonu alfasız tam kare; Android bildirim
// ikonu tek renkli — yalnızca beyaz + alfa; uyarlanabilir ikon ön plan +
// tek renk katmanı bağlı).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// PNG IHDR'den genişlik / yükseklik / renk türü.
({int width, int height, int colorType}) _ihdr(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  return (
    width: data.getUint32(16),
    height: data.getUint32(20),
    colorType: bytes[25],
  );
}

void main() {
  const res = 'android/app/src/main/res';

  test('Android bildirim ikonu her yoğunlukta, alfalı (RGBA) PNG', () {
    const sizes = {
      'drawable-mdpi': 24,
      'drawable-hdpi': 36,
      'drawable-xhdpi': 48,
      'drawable-xxhdpi': 72,
      'drawable-xxxhdpi': 96,
    };
    for (final MapEntry(key: folder, value: px) in sizes.entries) {
      final path = '$res/$folder/ic_stat_notification.png';
      expect(File(path).existsSync(), isTrue, reason: path);
      final h = _ihdr(path);
      expect((h.width, h.height), (px, px), reason: path);
      // 6 = RGBA (beyaz siluet + şeffaf zemin).
      expect(h.colorType, 6, reason: path);
    }
  });

  test('Android uyarlanabilir ikon: zemin rengi + ön plan + tek renk', () {
    final xml = File(
      '$res/mipmap-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(xml, contains('@color/ic_launcher_background'));
    expect(xml, contains('@drawable/ic_launcher_foreground'));
    expect(xml, contains('@drawable/ic_launcher_monochrome'));
    final colors = File('$res/values/colors.xml').readAsStringSync();
    expect(
      colors,
      contains('<color name="ic_launcher_background">#D00A2D</color>'),
    );
    expect(
      colors,
      contains('<color name="notification_accent">#D00A2D</color>'),
    );
  });

  test('iOS uygulama ikonu 1024 px, alfasız (App Store şartı)', () {
    const path =
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png';
    final h = _ihdr(path);
    expect((h.width, h.height), (1024, 1024));
    // 2 = RGB (alfa yok).
    expect(h.colorType, 2);
  });

  test('yerel hatırlatıcılar push ile aynı bildirim ikonunu kullanır', () {
    final source = File(
      'lib/product/service/local_reminder_service.dart',
    ).readAsStringSync();
    expect(source, contains("'@drawable/ic_stat_notification'"));
  });
}
