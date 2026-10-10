// T-08 · PageResult: sayfalama sonucu, hasMore türetimi ve eşitlik
// (PLAN §10.3, §12.1).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PageCursor cursorA;
  late PageCursor cursorB;

  Future<DocumentSnapshot<Map<String, Object?>>> snapshotOf(String id) async {
    final ref = db.collection('posts').doc(id);
    await ref.set({'order': id});
    return ref.get();
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    cursorA = PageCursor(await snapshotOf('p01'));
    cursorB = PageCursor(await snapshotOf('p02'));
  });

  group('T-08 · PageResult · alanlar', () {
    test('next verilmezse null; hasMore false (liste bitti)', () {
      const result = PageResult<String>(items: ['a', 'b']);

      expect(result.items, ['a', 'b']);
      expect(result.next, isNull);
      expect(result.hasMore, isFalse);
    });

    test('next doluysa hasMore true', () {
      final result = PageResult<String>(items: const ['a'], next: cursorA);

      expect(result.next, same(cursorA));
      expect(result.hasMore, isTrue);
    });

    test(
      "hasMore yalnızca next'e bakar: boş ama imleçli sayfa devam eder",
      () {
        final result = PageResult<int>(items: const [], next: cursorA);

        expect(result.items, isEmpty);
        expect(result.hasMore, isTrue);
      },
    );

    test('boş son sayfa: öğe yok, hasMore false', () {
      const result = PageResult<int>(items: []);

      expect(result.items, isEmpty);
      expect(result.hasMore, isFalse);
    });

    test('öğelerin sırası korunur', () {
      const result = PageResult<int>(items: [3, 1, 2]);

      expect(result.items, [3, 1, 2]);
    });

    test('const kurucu: aynı değerli iki sabit özdeş', () {
      const a = PageResult<int>(items: [1, 2]);
      const b = PageResult<int>(items: [1, 2]);

      expect(identical(a, b), isTrue);
    });

    test('öğe tipi korunur', () {
      const result = PageResult<String>(items: ['a']);

      expect(result, isA<PageResult<String>>());
      expect(result.items, isA<List<String>>());
    });
  });

  group('T-08 · PageResult · eşitlik', () {
    test('aynı öğeler ve aynı imleç eşit (liste içeriği karşılaştırılır)', () {
      // Her çağrı ayrı bir liste örneği üretir (const olsaydı özdeş olurdu).
      List<int> fresh() => List.of(const [1, 2, 3]);
      final a = PageResult<int>(items: fresh(), next: cursorA);
      final b = PageResult<int>(items: fresh(), next: cursorA);

      expect(identical(a.items, b.items), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('öğe farkı eşitliği bozar', () {
      expect(
        const PageResult<int>(items: [1, 2, 3]),
        isNot(const PageResult<int>(items: [1, 2, 4])),
      );
    });

    test('öğe sırası farkı eşitliği bozar', () {
      expect(
        const PageResult<int>(items: [1, 2]),
        isNot(const PageResult<int>(items: [2, 1])),
      );
    });

    test('imleç farkı eşitliği bozar', () {
      expect(
        PageResult<int>(items: const [1], next: cursorA),
        isNot(PageResult<int>(items: const [1], next: cursorB)),
      );
      expect(
        PageResult<int>(items: const [1], next: cursorA),
        isNot(const PageResult<int>(items: [1])),
      );
    });

    test('props items ve next alanlarını içerir', () {
      final result = PageResult<int>(items: const [1], next: cursorA);

      expect(result.props, [
        [1],
        cursorA,
      ]);
    });
  });

  group('T-08 · PageResult · PageRequest ile sayfalama döngüsü', () {
    /// Servisin (T-10) uygulayacağı kural: `next` yalnızca sayfa dolu geldiyse
    /// doludur.
    Future<PageResult<String>> fetch(PageRequest request) async {
      // İmleç limit'ten ÖNCE uygulanır: fake_cloud_firestore sorgu adımlarını
      // çağrı sırasıyla işler (gerçek Firestore'da sıra fark etmez).
      var query = db.collection('posts').orderBy('order');
      final after = request.after;
      if (after != null) query = query.startAfterDocument(after.snapshot);
      final docs = (await query.limit(request.limit).get()).docs;
      return PageResult(
        items: [for (final doc in docs) doc.id],
        next: docs.length == request.limit ? PageCursor(docs.last) : null,
      );
    }

    setUp(() async {
      for (final id in ['p03', 'p04', 'p05']) {
        await db.collection('posts').doc(id).set({'order': id});
      }
    });

    test('result.next bir sonraki isteğin after değeridir; son sayfada '
        'hasMore false', () async {
      final first = await fetch(const PageRequest(limit: 2));
      expect(first.items, ['p01', 'p02']);
      expect(first.hasMore, isTrue);

      final second = await fetch(PageRequest(limit: 2, after: first.next));
      expect(second.items, ['p03', 'p04']);
      expect(second.hasMore, isTrue);

      final third = await fetch(PageRequest(limit: 2, after: second.next));
      expect(third.items, ['p05']);
      expect(third.hasMore, isFalse);
      expect(third.next, isNull);
    });

    test('varsayılan istek (20) beş belgeyi tek sayfada getirir', () async {
      final page = await fetch(const PageRequest());

      expect(page.items, hasLength(5));
      expect(page.hasMore, isFalse);
    });
  });
}
