// T-44 · D3-01 · ReadCache: süre (TTL), boyut (LRU), eşzamanlı isteklerin
// birleşmesi, nesil koruması (süren okuma sırasında geçersiz kılma /
// temizleme), yalnızca saklanabilir başarının yazılması, forceRefresh.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';

void main() {
  late FakeAppClock clock;
  late ReadCache<String, int> cache;
  late int reads;

  /// Her çağrıda okuma sayacını artıran, [value] döndüren yükleyici.
  Future<CacheLoad<int>> Function() loader(
    int value, {
    bool storable = true,
    Completer<void>? gate,
  }) => () async {
    reads++;
    await gate?.future;
    return (
      result: FirebaseSuccess<int, FirestoreError>(value),
      storable: storable,
    );
  };

  setUp(() {
    clock = FakeAppClock(DateTime.utc(2026, 10, 15, 9));
    cache = ReadCache(
      clock: clock,
      ttl: const Duration(minutes: 5),
      maxEntries: 2,
    );
    reads = 0;
  });

  test(
    'TTL içinde ikinci okuma yükleyiciye gitmez; süre dolunca gider',
    () async {
      expect((await cache.load('a', loader(1))).dataOrNull, 1);
      expect((await cache.load('a', loader(2))).dataOrNull, 1);
      expect(reads, 1);

      clock.advance(const Duration(minutes: 5));
      expect((await cache.load('a', loader(3))).dataOrNull, 3);
      expect(reads, 2);
    },
  );

  test('forceRefresh önbelleği atlar ve sonucu yazar', () async {
    await cache.load('a', loader(1));
    expect(
      (await cache.load('a', loader(2), forceRefresh: true)).dataOrNull,
      2,
    );
    expect(cache.get('a'), 2);
    expect(reads, 2);
  });

  test('en çok maxEntries girdi; en eski kullanılan atılır (LRU)', () async {
    await cache.load('a', loader(1));
    await cache.load('b', loader(2));
    // `a` kullanıldı: en eski kullanılan artık `b`.
    expect(cache.get('a'), 1);
    await cache.load('c', loader(3));

    expect(cache.get('b'), isNull);
    expect(cache.get('a'), 1);
    expect(cache.get('c'), 3);
    expect(cache.length, 2);
  });

  test('aynı anahtara eşzamanlı istekler tek okumada birleşir', () async {
    final gate = Completer<void>();
    final first = cache.load('a', loader(1, gate: gate));
    final second = cache.load('a', loader(2));
    gate.complete();

    expect((await first).dataOrNull, 1);
    expect((await second).dataOrNull, 1);
    expect(reads, 1);
  });

  test('süren okuma sırasında invalidate: sonuç çağırana döner ama '
      'saklanmaz', () async {
    final gate = Completer<void>();
    final pending = cache.load('a', loader(1, gate: gate));
    cache.invalidate('a');
    gate.complete();

    expect((await pending).dataOrNull, 1);
    expect(cache.get('a'), isNull);
    // Geçersiz kılmadan sonra başlayan okuma yazar.
    await cache.load('a', loader(2));
    expect(cache.get('a'), 2);
  });

  test('süren okuma sırasında clear (oturum değişti): sonuç saklanmaz; '
      'yeni okuma eskisine katılmaz', () async {
    final gate = Completer<void>();
    final pending = cache.load('a', loader(1, gate: gate));
    cache.clear();
    final fresh = cache.load('a', loader(2));
    gate.complete();

    expect((await pending).dataOrNull, 1);
    expect((await fresh).dataOrNull, 2);
    expect(cache.get('a'), 2);
    expect(reads, 2);
  });

  test('saklanamaz sonuç (çevrimdışı önbellekten) ve hata yazılmaz', () async {
    await cache.load('a', loader(1, storable: false));
    expect(cache.get('a'), isNull);

    final failed = await cache.load(
      'b',
      () async => (
        result: const FirebaseFailure<int, FirestoreError>(
          FirestoreError.unavailable,
        ),
        storable: true,
      ),
    );
    expect(failed.errorOrNull, FirestoreError.unavailable);
    expect(cache.get('b'), isNull);
  });

  test('put: eski damgalı okuma daha yeni okumanın değerini ezmez', () {
    final older = cache.stamp;
    cache.invalidate('x'); // damga ilerler
    final newer = cache.stamp;

    expect(cache.put('a', 2, since: newer), isTrue);
    expect(cache.put('a', 1, since: older), isFalse);
    expect(cache.get('a'), 2);
  });
}
