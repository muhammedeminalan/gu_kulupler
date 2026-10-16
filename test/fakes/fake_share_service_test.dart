// T-16 · FakeShareService sözleşmesi (PLAN §16.3).
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/product/service/share_service.dart';

import 'fake_base.dart';
import 'fake_share_service.dart';
import 'register_fakes.dart';

void main() {
  const link = 'https://gu-kulupler.web.app/clubs/c01';

  group('T-16 · FakeShareService', () {
    test('ShareService arayüzünü uygular; registerDefaultFakes kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<ShareService>(), isA<FakeShareService>());
    });

    test('shareText: metni ve konuyu sırasıyla kaydeder, true döner', () async {
      final fake = FakeShareService();

      expect(await fake.shareText(link), isTrue);
      expect(await fake.shareText('ikinci', subject: 'Konu'), isTrue);

      expect(fake.sharedTexts, [link, 'ikinci']);
      expect(fake.subjects, [null, 'Konu']);
      expect(fake.calls, const [
        FakeCall('shareText', [link, null]),
        FakeCall('shareText', ['ikinci', 'Konu']),
      ]);
    });

    test('shareFile: yolu ve içerik türünü kaydeder', () async {
      final fake = FakeShareService();

      expect(
        await fake.shareFile('/tmp/etkinlik.ics', mimeType: 'text/calendar'),
        isTrue,
      );

      expect(fake.sharedFiles, [
        (path: '/tmp/etkinlik.ics', mimeType: 'text/calendar'),
      ]);
      expect(fake.sharedTexts, isEmpty);
    });

    test('copyText: metni kaydeder ve panoya yazar', () async {
      final fake = FakeShareService();

      expect(await fake.copyText(link), isTrue);

      expect(fake.copied, [link]);
      expect(fake.clipboard, link);
      expect(fake.sharedTexts, isEmpty);
    });

    test('canShare / canCopy false: istek kaydedilir, sonuç false; pano '
        'değişmez', () async {
      final fake = FakeShareService();
      await fake.copyText('önceki');
      fake
        ..canShare = false
        ..canCopy = false;

      expect(await fake.shareText(link), isFalse);
      expect(
        await fake.shareFile('/tmp/a.ics', mimeType: 'text/calendar'),
        isFalse,
      );
      expect(await fake.copyText(link), isFalse);

      expect(fake.sharedTexts, [link]);
      expect(fake.sharedFiles, hasLength(1));
      expect(fake.copied, ['önceki', link]);
      expect(fake.clipboard, 'önceki');
    });

    test('failNext: fırlatmaz, tek seferlik false döner', () async {
      final fake = FakeShareService()..failNext();

      expect(await fake.shareText(link), isFalse);
      expect(await fake.shareText(link), isTrue);

      fake.failNext();
      expect(await fake.copyText(link), isFalse);
      expect(fake.clipboard, isNull);
      expect(await fake.copyText(link), isTrue);
    });

    test(
      'resetFake: günlükleri, panoyu ve sonuç bayraklarını sıfırlar',
      () async {
        final fake = FakeShareService()
          ..canShare = false
          ..canCopy = false;
        await fake.shareText(link);
        await fake.shareFile('/tmp/a.ics', mimeType: 'text/calendar');
        await fake.copyText(link);

        fake.resetFake();

        expect(fake.sharedTexts, isEmpty);
        expect(fake.subjects, isEmpty);
        expect(fake.sharedFiles, isEmpty);
        expect(fake.copied, isEmpty);
        expect(fake.clipboard, isNull);
        expect(fake.calls, isEmpty);
        expect(fake.canShare, isTrue);
        expect(fake.canCopy, isTrue);
      },
    );
  });
}
