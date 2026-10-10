// T-08 · PageCursor: opak sayfalama imleci ve test imleci (PLAN §6.1, §10.2,
// §10.3, §16.3).
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

void main() {
  late FakeFirebaseFirestore db;

  Future<DocumentSnapshot<Map<String, Object?>>> snapshotOf(String id) async {
    final ref = db.collection('posts').doc(id);
    await ref.set({'text': id});
    return ref.get();
  }

  setUp(() => db = FakeFirebaseFirestore());

  group('T-08 · PageCursor', () {
    test('kurulduğu belgeyi aynen taşır', () async {
      final snapshot = await snapshotOf('p01');

      final cursor = PageCursor(snapshot);

      expect(cursor.snapshot, same(snapshot));
      expect(cursor.snapshot.id, 'p01');
      expect(cursor.snapshot.data(), {'text': 'p01'});
    });

    test('sorgu startAfterDocument ile imleçten devam eder', () async {
      for (final id in ['p01', 'p02', 'p03', 'p04']) {
        await db.collection('posts').doc(id).set({'order': id});
      }
      final firstPage = await db
          .collection('posts')
          .orderBy('order')
          .limit(2)
          .get();
      final cursor = PageCursor(firstPage.docs.last);

      final secondPage = await db
          .collection('posts')
          .orderBy('order')
          .startAfterDocument(cursor.snapshot)
          .limit(2)
          .get();

      expect([for (final doc in firstPage.docs) doc.id], ['p01', 'p02']);
      expect([for (final doc in secondPage.docs) doc.id], ['p03', 'p04']);
    });

    test('eşitlik kimliğe göre: imleç kendisine eşittir', () async {
      final cursor = PageCursor(await snapshotOf('p01'));
      final alias = cursor;

      expect(cursor == alias, isTrue);
      expect(cursor.hashCode, alias.hashCode);
    });

    test('aynı belgeyi gösteren iki ayrı imleç eşit değildir', () async {
      final snapshot = await snapshotOf('p01');

      expect(PageCursor(snapshot) == PageCursor(snapshot), isFalse);
    });

    test('farklı belgelerin imleçleri eşit değildir', () async {
      final a = PageCursor(await snapshotOf('p01'));
      final b = PageCursor(await snapshotOf('p02'));

      expect(a == b, isFalse);
    });
  });

  group('T-08 · PageCursor.fake (test imleci, PLAN §16.3)', () {
    test('belge taşımaz: snapshot okunursa StateError', () {
      final cursor = PageCursor.fake();

      expect(
        () => cursor.snapshot,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('PageCursor.fake()'),
          ),
        ),
      );
    });

    test('her çağrı ayrı kimlikli bir imleç üretir (const değildir)', () {
      final a = PageCursor.fake();
      final b = PageCursor.fake();

      expect(identical(a, b), isFalse);
      expect(a == b, isFalse);
      expect(a == a, isTrue);
    });

    test('PageResult.next olarak "sonraki sayfa var" der', () {
      final page = PageResult<String>(
        items: const ['a', 'b'],
        next: PageCursor.fake(),
      );

      expect(page.hasMore, isTrue);
    });

    test('PageRequest.after olarak aynen geri taşınır', () {
      final cursor = PageCursor.fake();
      final request = PageRequest(after: cursor);

      expect(request.after, same(cursor));
      expect(request, PageRequest(after: cursor));
      expect(request, isNot(PageRequest(after: PageCursor.fake())));
    });

    test('fake repository imleci kimliğiyle sayfaya eşler (iki sayfa + son '
        'sayfa)', () {
      // Kök test/fakes içindeki fake repository'lerin kullanacağı kalıp:
      // belge yok, imleç → kaldığı yer eşlemesi kimlikle tutulur.
      const all = ['a', 'b', 'c', 'd', 'e'];
      final offsets = Expando<int>();

      PageResult<String> fetch(PageRequest request) {
        final after = request.after;
        final start = after == null ? 0 : offsets[after]!;
        final end = (start + request.limit).clamp(0, all.length);
        final items = all.sublist(start, end);
        if (items.length < request.limit) return PageResult(items: items);
        final next = PageCursor.fake();
        offsets[next] = end;
        return PageResult(items: items, next: next);
      }

      final first = fetch(const PageRequest(limit: 2));
      final second = fetch(PageRequest(limit: 2, after: first.next));
      final third = fetch(PageRequest(limit: 2, after: second.next));

      expect(first.items, ['a', 'b']);
      expect(first.hasMore, isTrue);
      expect(second.items, ['c', 'd']);
      expect(second.hasMore, isTrue);
      expect(third.items, ['e']);
      expect(third.hasMore, isFalse);
    });

    test('belgeli imleç fake değildir: snapshot okunur', () async {
      final cursor = PageCursor(await snapshotOf('p01'));

      expect(() => cursor.snapshot, returnsNormally);
    });
  });

  group('T-08 · PageCursor · opaklık', () {
    final source = readRepoFile(
      'packages/gu_data/lib/src/core/page_cursor.dart',
    );

    test('belgeli kurucu ve snapshot erişimi @internal işaretlidir', () {
      expect(
        source,
        matches(
          RegExp(
            r'@internal\s+const PageCursor\('
            r'DocumentSnapshot<Map<String, Object\?>> snapshot\)',
          ),
        ),
      );
      expect(
        source,
        matches(
          RegExp(
            r'@internal\s+DocumentSnapshot<Map<String, Object\?>> get '
            'snapshot',
          ),
        ),
      );
    });

    test('test kurucusu @visibleForTesting işaretlidir (lib/ kodundan '
        'çağrılamaz) ve const değildir', () {
      expect(
        source,
        matches(RegExp(r'@visibleForTesting\s+PageCursor\.fake\(\)')),
      );
      expect(source, isNot(contains('const PageCursor.fake')));
    });

    test('belge alanı private: dışarıya yalnızca @internal getter açılır', () {
      expect(
        source,
        contains(
          'final DocumentSnapshot<Map<String, Object?>>? _snapshot;',
        ),
      );
      expect(
        RegExp(r'^\s+final [^;]*\bsnapshot;', multiLine: true).hasMatch(source),
        isFalse,
      );
    });

    test('uygulama kodu (lib/) PageCursor.fake çağırmaz', () {
      final offenders = [
        for (final root in [
          'lib',
          'packages/gu_data/lib',
          'packages/gu_ui/lib',
        ])
          for (final file
              in Directory('$repoRoot/$root')
                  .listSync(recursive: true)
                  .whereType<File>()
                  .where((file) => file.path.endsWith('.dart'))
                  .where((file) => !file.path.endsWith('page_cursor.dart')))
            if (file.readAsStringSync().contains('PageCursor.fake(')) file.path,
      ];

      expect(offenders, isEmpty);
    });
  });
}
