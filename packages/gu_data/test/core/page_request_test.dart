// T-08 · PageRequest: sayfalama isteği varsayılanları ve eşitlik
// (PLAN §10.3).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

void main() {
  late PageCursor cursorA;
  late PageCursor cursorB;

  setUp(() async {
    final db = FakeFirebaseFirestore();
    Future<DocumentSnapshot<Map<String, Object?>>> snapshotOf(String id) async {
      final ref = db.collection('posts').doc(id);
      await ref.set({'text': id});
      return ref.get();
    }

    cursorA = PageCursor(await snapshotOf('p01'));
    cursorB = PageCursor(await snapshotOf('p02'));
  });

  group('T-08 · PageRequest · varsayılanlar', () {
    test('limit = Limits.pageSize (20), after = null (ilk sayfa)', () {
      const request = PageRequest();

      expect(request.limit, Limits.pageSize);
      expect(request.limit, 20);
      expect(request.after, isNull);
    });

    test('const kurucu: iki varsayılan istek özdeş', () {
      const a = PageRequest();
      const b = PageRequest();

      expect(identical(a, b), isTrue);
    });

    test('yalnızca after verilirse limit varsayılan kalır (sonraki sayfa)', () {
      final request = PageRequest(after: cursorA);

      expect(request.limit, Limits.pageSize);
      expect(request.after, same(cursorA));
    });

    test('yalnızca limit verilirse ilk sayfa istenir', () {
      const request = PageRequest(limit: 3);

      expect(request.limit, 3);
      expect(request.after, isNull);
    });

    test('limit ve after birlikte verilebilir', () {
      final request = PageRequest(limit: 50, after: cursorB);

      expect(request.limit, 50);
      expect(request.after, same(cursorB));
    });
  });

  group('T-08 · PageRequest · limit pozitif olmalı', () {
    // Değerler çalışma anında üretilir: sabit ifade olsaydı derleme hatası
    // olurdu.
    for (final raw in const ['0', '-1', '-20']) {
      test('limit $raw reddedilir', () {
        final limit = int.parse(raw);

        expect(() => PageRequest(limit: limit), throwsAssertionError);
      });
    }

    test('limit 1 kabul edilir', () {
      expect(PageRequest(limit: int.parse('1')).limit, 1);
    });
  });

  group('T-08 · PageRequest · eşitlik', () {
    test('aynı limit ve aynı imleç eşit', () {
      expect(
        PageRequest(limit: 10, after: cursorA),
        PageRequest(limit: 10, after: cursorA),
      );
      expect(
        PageRequest(limit: 10, after: cursorA).hashCode,
        PageRequest(limit: 10, after: cursorA).hashCode,
      );
    });

    test('varsayılan istek, açıkça yazılmış eşdeğerine eşit', () {
      expect(
        const PageRequest(),
        // Varsayılanla aynı değer bilerek açıkça veriliyor.
        // ignore: avoid_redundant_argument_values
        const PageRequest(limit: Limits.pageSize, after: null),
      );
    });

    test('limit farkı eşitliği bozar', () {
      expect(const PageRequest(limit: 10), isNot(const PageRequest(limit: 11)));
    });

    test('imleç farkı eşitliği bozar', () {
      expect(
        PageRequest(after: cursorA),
        isNot(PageRequest(after: cursorB)),
      );
      expect(PageRequest(after: cursorA), isNot(const PageRequest()));
    });

    test('props limit ve after alanlarını içerir', () {
      expect(PageRequest(limit: 7, after: cursorA).props, [7, cursorA]);
      expect(const PageRequest().props, [Limits.pageSize, null]);
    });
  });
}
