// gu_ui testlerinin ortak başlangıcı (PLAN §7.10, CD-23).
//
// `flutter test` gu_ui paket kökünde koşar; fontlar depo kökündeki
// `assets/fonts` altındadır (kayıt kök uygulamanın pubspec'inde). Golden'lar
// gerçek glifle (Ahem/FlutterTest değil) üretilsin diye 7 TTF burada bir kez
// yüklenir: 4 Montserrat + 3 Inter (`helpers/test_fonts.dart`; liste kök
// pubspec ile `helpers/test_fonts_test.dart`'ta karşılaştırılır).
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final families = <String, List<String>>{};
  for (final face in testFontFaces) {
    families.putIfAbsent(face.family, () => []).add(face.file);
  }
  for (final e in families.entries) {
    await _loadFamily(e.key, e.value);
  }
  await testMain();
}

Future<void> _loadFamily(String family, List<String> files) async {
  final fontsDir = '${Directory('../..').absolute.path}/assets/fonts';
  final loader = FontLoader(family);
  for (final name in files) {
    loader.addFont(_readFont('$fontsDir/$name.ttf'));
  }
  await loader.load();
}

Future<ByteData> _readFont(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(bytes);
}
