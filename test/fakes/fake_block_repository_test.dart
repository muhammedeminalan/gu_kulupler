// T-15 · FakeBlockRepository sözleşmesi (PLAN §16.3): `blocks`; gerçek
// repository'nin sonuçlarını izler (engeli kaldırma = soft delete, D-10).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_block_repository.dart';
import 'register_fakes.dart';

const String _me = 'u_ayse';

void main() {
  late FakeBlockRepository fake;

  setUp(() => fake = FakeBlockRepository());

  group('T-15 · FakeBlockRepository', () {
    test('BlockRepository arayüzünü uygular; registerDefaultFakes '
        'kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<BlockRepository>(), isA<FakeBlockRepository>());
    });

    test('block → softDeleteBlock → block: kayıt silinmez, işaretlenir ve '
        'aynı kayıt geri yüklenir', () async {
      await fake.block(blockerId: _me, blockedId: 'u2');
      expect((await fake.fetchActiveBlocks(_me)).dataOrNull, {'u2'});

      await fake.softDeleteBlock(blockerId: _me, blockedId: 'u2');
      final removed = fake.blocks['${_me}_u2']!;
      expect(removed.isDeleted, isTrue);
      expect(removed.deletedBy, _me);
      expect((await fake.fetchActiveBlocks(_me)).dataOrNull, isEmpty);
      expect((await fake.listBlocked(_me)).dataOrNull, isEmpty);

      await fake.block(blockerId: _me, blockedId: 'u2');
      expect(fake.blocks, hasLength(1));
      expect(fake.blocks['${_me}_u2']!.isDeleted, isFalse);
      expect(fake.blocks['${_me}_u2']!.deletedBy, isNull);
      expect(
        [
          for (final block in (await fake.listBlocked(_me)).dataOrNull!)
            block.blockedId,
        ],
        ['u2'],
      );
    });

    test('restoreBlock kaldırılmış engeli geri yükler; olmayan kayıtta '
        'kaldırma / geri yükleme notFound', () async {
      fake.put(_me, 'u2');
      await fake.softDeleteBlock(blockerId: _me, blockedId: 'u2');

      expect(
        (await fake.restoreBlock(blockerId: _me, blockedId: 'u2')).isSuccess,
        isTrue,
      );
      expect((await fake.fetchActiveBlocks(_me)).dataOrNull, {'u2'});
      expect(
        (await fake.softDeleteBlock(
          blockerId: _me,
          blockedId: 'u9',
        )).errorOrNull,
        FirestoreError.notFound,
      );
      expect(
        (await fake.restoreBlock(blockerId: _me, blockedId: 'u9')).errorOrNull,
        FirestoreError.notFound,
      );
    });

    test('yalnızca kendi engelleri okunur', () async {
      fake
        ..put(_me, 'u2')
        ..put('u_other', 'u3');
      expect((await fake.fetchActiveBlocks(_me)).dataOrNull, {'u2'});
    });

    test('kendini engelleme ve geçersiz kimlik invalidArgument; failNext '
        'sıradaki çağrıyı düşürür', () async {
      expect(
        (await fake.block(blockerId: _me, blockedId: _me)).errorOrNull,
        FirestoreError.invalidArgument,
      );
      expect(
        (await fake.block(blockerId: _me, blockedId: 'u/2')).errorOrNull,
        FirestoreError.invalidArgument,
      );
      fake.failNext(FirestoreError.unavailable);
      expect(
        (await fake.fetchActiveBlocks(_me)).errorOrNull,
        FirestoreError.unavailable,
      );
      expect(fake.blocks, isEmpty);
    });

    test('fetchActiveBlocksGate: sonuç çağrı anındaki kümedir ve kapı '
        'açılana kadar dönmez', () async {
      fake.put(_me, 'u2');
      final gate = Completer<void>();
      fake.fetchActiveBlocksGate = gate;

      var done = false;
      final pending = fake
          .fetchActiveBlocks(_me)
          .whenComplete(() => done = true);
      fake.put(_me, 'u3');
      await pumpEventQueue();
      expect(done, isFalse);

      gate.complete();
      expect((await pending).dataOrNull, {'u2'});
    });
  });
}
