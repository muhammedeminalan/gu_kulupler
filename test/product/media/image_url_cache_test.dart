// T-21 · ImageUrlCache: Storage yolu → indirme adresi önbelleği (PLAN §10.2:
// 1 saat) — tek istek, tazeleme, hata sonrası bekleme, dinleyici, üst sınır.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/media/constants/media_constants.dart';
import 'package:gu_kulupler/product/media/image_url_cache.dart';

import '../../helpers/fake_app_clock.dart';

const String _path = 'posts/p01/20261013T090000Z_0001020304050607.jpg';
const String _other = 'posts/p01/20261013T090000Z_08090a0b0c0d0e0f.jpg';

void main() {
  late FakeAppClock clock;
  late List<String> fetched;
  late Map<String, StorageResult<String>> answers;
  late int notified;

  ImageUrlCache cacheWith({ImageUrlFetch? fetch, int? maxEntries}) {
    final cache = ImageUrlCache(
      fetch:
          fetch ??
          (path) async {
            fetched.add(path);
            return answers[path] ??
                const FirebaseFailure(StorageError.notFound);
          },
      clock: clock,
      maxEntries: maxEntries ?? MediaConstants.imageUrlCacheMaxEntries,
    )..addListener(() => notified++);
    addTearDown(cache.dispose);
    return cache;
  }

  setUp(() {
    clock = FakeAppClock(DateTime.utc(2026, 10, 13, 9));
    fetched = [];
    notified = 0;
    answers = {
      _path: const FirebaseSuccess('https://storage.test/a?token=1'),
      _other: const FirebaseSuccess('https://storage.test/b?token=1'),
    };
  });

  test('bilinmeyen yol: peek null; request adresi getirir ve dinleyiciyi bir '
      'kez uyarır', () async {
    final cache = cacheWith();

    expect(cache.peek(_path), isNull);
    expect(fetched, isEmpty);

    expect(await cache.request(_path), 'https://storage.test/a?token=1');
    expect(cache.peek(_path), 'https://storage.test/a?token=1');
    expect(notified, 1);
  });

  test('taze adres yeniden istenmez; süren istek varken ikincisi '
      'başlatılmaz', () async {
    final gate = Completer<StorageResult<String>>();
    final cache = cacheWith(
      fetch: (path) {
        fetched.add(path);
        return gate.future;
      },
    );

    final first = cache.request(_path);
    expect(cache.request(_path), isNull);
    gate.complete(const FirebaseSuccess('https://storage.test/a'));
    await first;

    expect(cache.request(_path), isNull);
    clock.advance(
      MediaConstants.imageUrlTtl - const Duration(seconds: 1),
    );
    expect(cache.request(_path), isNull);
    expect(fetched, [_path]);
  });

  test('süresi dolan adres kullanılmaya devam eder ve arka planda yenilenir; '
      'aynı adres dinleyiciyi yeniden uyarmaz, değişen uyarır', () async {
    final cache = cacheWith();
    await cache.request(_path);

    clock.advance(MediaConstants.imageUrlTtl);
    expect(cache.peek(_path), 'https://storage.test/a?token=1');
    await cache.request(_path);
    expect(notified, 1);

    clock.advance(MediaConstants.imageUrlTtl);
    answers[_path] = const FirebaseSuccess('https://storage.test/a?token=2');
    await cache.request(_path);

    expect(cache.peek(_path), 'https://storage.test/a?token=2');
    expect(notified, 2);
    expect(fetched, [_path, _path, _path]);
  });

  test('alınamayan adres null döner, dinleyici uyarılmaz ve bekleme süresi '
      'dolmadan yeniden istenmez', () async {
    final cache = cacheWith();
    answers[_path] = const FirebaseFailure(StorageError.unauthorized);

    expect(await cache.request(_path), isNull);
    expect(cache.peek(_path), isNull);
    expect(notified, 0);
    expect(cache.request(_path), isNull);

    clock.advance(MediaConstants.imageUrlRetryAfter);
    answers[_path] = const FirebaseSuccess('https://storage.test/a');
    expect(await cache.request(_path), 'https://storage.test/a');
    expect(fetched, [_path, _path]);
    expect(notified, 1);
  });

  test('adres çağrısı fırlatsa da istek sessizce başarısız sayılır', () async {
    final cache = cacheWith(fetch: (_) => throw StateError('servis yok'));

    expect(await cache.request(_path), isNull);
    expect(cache.request(_path), isNull);
    expect(notified, 0);
  });

  test('yenileme başarısız olursa bilinen adres kalır', () async {
    final cache = cacheWith();
    await cache.request(_path);

    clock.advance(MediaConstants.imageUrlTtl);
    answers[_path] = const FirebaseFailure(StorageError.unknown);

    expect(await cache.resolve(_path), 'https://storage.test/a?token=1');
    expect(cache.peek(_path), 'https://storage.test/a?token=1');
  });

  test('resolve: önbellekten, süren istekten ya da yeni istekten aynı adresi '
      'verir; alınamazsa null', () async {
    final cache = cacheWith();

    final both = await Future.wait([
      cache.resolve(_path),
      cache.resolve(_path),
    ]);
    expect(both, everyElement('https://storage.test/a?token=1'));
    expect(await cache.resolve(_path), 'https://storage.test/a?token=1');
    expect(fetched, [_path]);
    expect(await cache.resolve('posts/p01/yok.jpg'), isNull);
  });

  test('üst sınır aşılınca en eski adres atılır', () async {
    final cache = cacheWith(maxEntries: 1);

    await cache.request(_path);
    await cache.request(_other);

    expect(cache.peek(_path), isNull);
    expect(cache.peek(_other), isNotNull);
  });

  test('kapatılan önbellek istek başlatmaz; süren istek sessizce '
      'biter', () async {
    final gate = Completer<StorageResult<String>>();
    final cache = ImageUrlCache(fetch: (_) => gate.future, clock: clock)
      ..addListener(() => notified++);

    final pending = cache.request(_path);
    cache.dispose();
    gate.complete(const FirebaseSuccess('https://storage.test/a'));

    expect(await pending, isNull);
    expect(cache.request(_other), isNull);
    expect(notified, 0);
  });

  group('T-44 · kalıcı tohum (D2-05) ve yeniden bağlanma (A4-04)', () {
    ImageUrlCache seeded(
      Map<String, ImageUrlEntry> initial, {
      List<Map<String, ImageUrlEntry>>? stored,
      int? maxEntries,
      ImageUrlFetch? fetch,
    }) {
      final cache = ImageUrlCache(
        fetch:
            fetch ??
            (path) async {
              fetched.add(path);
              return answers[path] ??
                  const FirebaseFailure(StorageError.notFound);
            },
        clock: clock,
        maxEntries: maxEntries ?? MediaConstants.imageUrlCacheMaxEntries,
        initial: initial,
        onStored: stored?.add,
      )..addListener(() => notified++);
      addTearDown(cache.dispose);
      return cache;
    }

    test("tohumlu yol ilk peek'te adres döner; taze tohum yeniden "
        'istenmez', () {
      final cache = seeded({
        _path: (url: 'https://storage.test/a?token=0', at: clock.nowUtc()),
      });

      expect(cache.peek(_path), 'https://storage.test/a?token=0');
      expect(cache.request(_path), isNull);
      expect(fetched, isEmpty);
    });

    test('süresi dolmuş tohum arka planda yenilenir; çevrimdışında (hata) '
        'eski adres kalır', () async {
      final old = clock.nowUtc().subtract(
        MediaConstants.imageUrlTtl + const Duration(minutes: 1),
      );
      answers.remove(_path);
      final cache = seeded({
        _path: (url: 'https://storage.test/a?token=0', at: old),
      });

      expect(await cache.request(_path), isNull);
      expect(fetched, [_path]);
      expect(cache.peek(_path), 'https://storage.test/a?token=0');
      expect(notified, 0);
    });

    testWidgets('yeni adresler birleştirilip tek onStored çağrısıyla '
        'verilir; kapanışta bekleyen yazım hemen verilir', (tester) async {
      final stored = <Map<String, ImageUrlEntry>>[];
      final cache = ImageUrlCache(
        fetch: (path) async =>
            answers[path] ?? const FirebaseFailure(StorageError.notFound),
        clock: clock,
        onStored: stored.add,
      );

      unawaited(cache.request(_path));
      unawaited(cache.request(_other));
      await tester.pump();
      expect(stored, isEmpty);

      await tester.pump(MediaConstants.imageUrlPersistDebounce);
      expect(stored, hasLength(1));
      expect(stored.single.keys, unorderedEquals([_path, _other]));
      expect(stored.single[_path]!.url, 'https://storage.test/a?token=1');

      // Adres aynı kalsa da alındığı an yenilenir: yine saklanır.
      clock.advance(MediaConstants.imageUrlTtl);
      unawaited(cache.request(_path));
      await tester.pump();
      cache.dispose();
      expect(stored, hasLength(2));
      expect(stored.last[_path]!.at, clock.nowUtc());
    });

    test('tohum üst sınırla kesilir: en eski alınan atılır', () {
      final now = clock.nowUtc();
      final cache = seeded({
        _path: (url: 'https://storage.test/a', at: now),
        _other: (
          url: 'https://storage.test/b',
          at: now.subtract(const Duration(minutes: 5)),
        ),
      }, maxEntries: 1);

      expect(cache.peek(_path), 'https://storage.test/a');
      expect(cache.peek(_other), isNull);
    });

    test('retryFailed: başarısız yolun beklemesi kalkar ve yeniden istenir; '
        'gelen adres dinleyiciyi uyarır; başarısız yol yoksa hiçbir şey '
        'yapmaz', () async {
      final cache = cacheWith();
      answers.remove(_path);
      expect(await cache.request(_path), isNull);
      // Bekleme süresi içinde yeniden istenmez.
      expect(cache.request(_path), isNull);
      expect(fetched, [_path]);

      answers[_path] = const FirebaseSuccess('https://storage.test/a?token=2');
      cache.retryFailed();
      await pumpEventQueue();
      expect(fetched, [_path, _path]);
      expect(cache.peek(_path), 'https://storage.test/a?token=2');
      expect(notified, 1);

      // Başarısız yol kalmadı: hiçbir şey istenmez.
      cache.retryFailed();
      expect(fetched, [_path, _path]);
    });
  });
}
