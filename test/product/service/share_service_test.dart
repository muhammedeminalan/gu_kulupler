// T-16 · DeviceShareService: share_plus çağrısı, pano yazımı ve hata
// davranışı (CD-08; K-D).
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/core/constants/app_constants.dart';
import 'package:gu_kulupler/product/service/share_service.dart';
import 'package:share_plus/share_plus.dart';

import '../../helpers/design_files.dart';

void main() {
  const link = '${AppConstants.shareBaseUrl}/clubs/c01';
  const fallback = Rect.fromLTWH(0, 0, 390, 422);
  const button = Rect.fromLTWH(16, 700, 358, 48);
  const shared = ShareResult('', ShareResultStatus.success);

  /// Hata günlüğünü (`AppLogger.warn`) test çıktısından uzak tutar.
  void silenceLogs() {
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) {};
    addTearDown(() => debugPrint = original);
  }

  group('T-16 · DeviceShareService · paylaşım', () {
    late List<ShareParams> calls;

    DeviceShareService service({ShareResult result = shared}) =>
        DeviceShareService(
          share: (params) async {
            calls.add(params);
            return result;
          },
          fallbackOrigin: () => fallback,
        );

    setUp(() => calls = []);

    test('shareText: metin + konu paylaşım sayfasına gider; çıkış '
        'dikdörtgeni verilmezse yedek kullanılır', () async {
      expect(
        await service().shareText(link, subject: 'Yazılım Kulübü'),
        isTrue,
      );

      final params = calls.single;
      expect(params.text, link);
      expect(params.subject, 'Yazılım Kulübü');
      expect(params.files, isNull);
      expect(params.sharePositionOrigin, fallback);
    });

    test('shareText: verilen çıkış dikdörtgeni (dokunulan düğme) aynen '
        'iletilir', () async {
      expect(await service().shareText(link, origin: button), isTrue);

      expect(calls.single.sharePositionOrigin, button);
      expect(calls.single.subject, isNull);
    });

    test('shareFile: dosya yolu ve içerik türüyle paylaşılır', () async {
      expect(
        await service().shareFile(
          '/tmp/etkinlik.ics',
          mimeType: 'text/calendar',
        ),
        isTrue,
      );

      final params = calls.single;
      expect(params.text, isNull);
      expect(params.files, hasLength(1));
      expect(params.files!.single.path, '/tmp/etkinlik.ics');
      expect(params.files!.single.mimeType, 'text/calendar');
      expect(params.sharePositionOrigin, fallback);
    });

    test('sayfa açıldıysa kullanıcı vazgeçse de (dismissed / unavailable) '
        'true', () async {
      for (final status in ShareResultStatus.values) {
        final result = ShareResult('', status);
        expect(
          await service(result: result).shareText(link),
          isTrue,
          reason: status.name,
        );
      }
    });

    test('platform hatası fırlatılmaz, false döner', () async {
      silenceLogs();
      final failing = DeviceShareService(
        share: (params) async => throw PlatformException(code: 'unavailable'),
        fallbackOrigin: () => fallback,
      );

      expect(await failing.shareText(link), isFalse);
      expect(
        await failing.shareFile('/tmp/a.ics', mimeType: 'text/calendar'),
        isFalse,
      );
    });

    testWidgets('varsayılan yedek dikdörtgen: ekranın üst yarısı (boş '
        'değil — iPad paylaşım sayfası boş dikdörtgeni reddeder)', (
      tester,
    ) async {
      final service = DeviceShareService(
        share: (params) async {
          calls.add(params);
          return shared;
        },
      );
      final view = tester.view;
      final size = view.physicalSize / view.devicePixelRatio;

      expect(await service.shareText(link), isTrue);

      final origin = calls.single.sharePositionOrigin!;
      expect(origin.isEmpty, isFalse);
      expect(origin, Offset.zero & Size(size.width, size.height / 2));
    });
  });

  group('T-16 · DeviceShareService · pano', () {
    test('copyText: metni panoya yazar', () async {
      final written = <String?>[];
      final service = DeviceShareService(
        writeClipboard: (data) async => written.add(data.text),
      );

      expect(await service.copyText(link), isTrue);
      expect(written, [link]);
    });

    test('copyText: platform hatası fırlatılmaz, false döner', () async {
      silenceLogs();
      final service = DeviceShareService(
        writeClipboard: (data) async =>
            throw PlatformException(code: 'clipboard'),
      );

      expect(await service.copyText(link), isFalse);
    });

    testWidgets('varsayılan pano çağrısı Flutter Clipboard: yazılan metin '
        'geri okunur', (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      expect(await const DeviceShareService().copyText(link), isTrue);
      expect(clipboard, link);
    });
  });

  group('T-16 · ShareService · sözleşme', () {
    test('varsayılan kurucu const kurulur', () {
      expect(const DeviceShareService(), isA<ShareService>());
    });

    test('share_plus ve Clipboard yalnızca serviste çağrılır (CD-08)', () {
      const service = 'lib/product/service/share_service.dart';
      final sources = [
        for (final entry in Directory(
          '$repoRoot/lib',
        ).listSync(recursive: true))
          if (entry is File && entry.path.endsWith('.dart')) entry,
      ];
      expect(sources, isNotEmpty);
      for (final file in sources) {
        if (file.path.endsWith(service)) continue;
        final source = file.readAsStringSync();
        expect(
          source,
          isNot(contains('package:share_plus')),
          reason: file.path,
        );
        expect(source, isNot(contains('Clipboard.setData')), reason: file.path);
      }
    });
  });
}
