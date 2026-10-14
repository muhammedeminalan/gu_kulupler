// T-23 · FakeFileService sözleşmesi (PLAN §16.3): diske yazmaz, içeriği
// bellekte tutar; yazılamadığında `null` döner (fırlatmaz).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/product/service/file_service.dart';

import 'fake_file_service.dart';
import 'register_fakes.dart';

void main() {
  group('T-23 · FakeFileService', () {
    test('FileService arayüzünü uygular; registerDefaultFakes kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<FileService>(), isA<FakeFileService>());
    });

    test('writeTemp yolu döndürür ve içeriği saklar; canWrite / failNext '
        '→ null', () async {
      final fake = FakeFileService();
      final bytes = utf8.encode('BEGIN:VCALENDAR');

      expect(
        await fake.writeTemp('etkinlik.ics', bytes),
        '${FakeFileService.tempDirectory}/etkinlik.ics',
      );
      expect(fake.written['etkinlik.ics'], bytes);

      fake.canWrite = false;
      expect(await fake.writeTemp('b.ics', bytes), isNull);
      fake
        ..canWrite = true
        ..failNext();
      expect(await fake.writeTemp('c.ics', bytes), isNull);
      expect(fake.written.keys, ['etkinlik.ics']);

      fake.resetFake();
      expect(fake.written, isEmpty);
      expect(fake.calls, isEmpty);
    });
  });
}
