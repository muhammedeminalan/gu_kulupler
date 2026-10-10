// Kök testlerin ortak başlangıcı (CD-122(7), PLAN §7.10).
//
// `flutter test` kökte koşar. Golden'lar gerçek glifle (Ahem/FlutterTest
// değil) üretilsin diye paketli fontlar bir kez yüklenir; liste kopyası
// yoktur — aileler ve dosyalar kök `pubspec.yaml` `flutter: fonts:`
// bloğundan okunur (`helpers/design_files.dart` `pubspecFontFamilies`).
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/design_files.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final families = pubspecFontFamilies(readText('pubspec.yaml'));
  for (final MapEntry(key: family, value: assets) in families.entries) {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(_readFont(asset));
    }
    await loader.load();
  }
  await testMain();
}

Future<ByteData> _readFont(String asset) async =>
    ByteData.sublistView(await repoFile(asset).readAsBytes());
