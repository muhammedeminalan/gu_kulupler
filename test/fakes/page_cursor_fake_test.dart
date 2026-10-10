// T-08 · PageCursor.fake: kök test dizinindeki fake repository'ler belgesiz
// sayfalama imleci üretebilir (PLAN §10.2, §16.3; CD-129). `PageCursor`'ın
// belgeli kurucusu `@internal`'dır; bu dosya paket dışından yalnızca
// `@visibleForTesting` kurucunun kullanılabildiğini (analyzer temiz) ve
// sayfalı bir fake'in "sonraki sayfa var" diyebildiğini gösterir.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

/// Sayfalı fake repository kalıbı: imleç → kaldığı yer eşlemesi kimlikle
/// tutulur (imleç opaktır, içinde belge yoktur).
final class _FakePagedRepository extends FakeBase {
  _FakePagedRepository(this.entries);

  final List<String> entries;
  final Expando<int> _offsets = Expando<int>();

  Future<FirestoreResult<PageResult<String>>> list(PageRequest page) async {
    record('list', [page.limit, page.after]);
    if (takeFailure() != null) {
      return const FirebaseFailure(FirestoreError.unavailable);
    }
    final after = page.after;
    final start = after == null ? 0 : _offsets[after]!;
    final end = (start + page.limit).clamp(0, entries.length);
    final items = entries.sublist(start, end);
    if (items.length < page.limit) {
      return FirebaseSuccess(PageResult(items: items));
    }
    final next = PageCursor.fake();
    _offsets[next] = end;
    return FirebaseSuccess(PageResult(items: items, next: next));
  }
}

void main() {
  group('T-08 · PageCursor.fake · kök fake repository sayfalaması', () {
    test(
      'dolu sayfa hasMore == true döner; imleç sonraki sayfayı getirir',
      () async {
        final repository = _FakePagedRepository([
          for (var i = 1; i <= 45; i++) 'a$i',
        ]);

        final first = (await repository.list(const PageRequest())).dataOrNull!;
        final second = (await repository.list(
          PageRequest(after: first.next),
        )).dataOrNull!;
        final third = (await repository.list(
          PageRequest(after: second.next),
        )).dataOrNull!;

        expect(first.items, hasLength(Limits.pageSize));
        expect(first.hasMore, isTrue);
        expect(second.items.first, 'a21');
        expect(second.hasMore, isTrue);
        expect(third.items, ['a41', 'a42', 'a43', 'a44', 'a45']);
        expect(third.hasMore, isFalse);
        expect(third.next, isNull);
      },
    );

    test(
      'ViewModel imleci yalnızca taşır: isteğe aynı örnek geri verilir',
      () async {
        final repository = _FakePagedRepository(['a', 'b', 'c']);

        final first = (await repository.list(
          const PageRequest(limit: 2),
        )).dataOrNull!;
        await repository.list(PageRequest(limit: 2, after: first.next));

        expect(repository.callsTo('list').last.args, [2, same(first.next)]);
      },
    );

    test('her dolu sayfa ayrı kimlikli imleç üretir', () async {
      final repository = _FakePagedRepository(['a', 'b', 'c', 'd', 'e']);

      final first = (await repository.list(
        const PageRequest(limit: 2),
      )).dataOrNull!;
      final second = (await repository.list(
        PageRequest(limit: 2, after: first.next),
      )).dataOrNull!;

      expect(first.next, isNot(second.next));
      expect(identical(first.next, second.next), isFalse);
    });

    test('hata enjeksiyonu sayfalamayı bozmaz', () async {
      final repository = _FakePagedRepository(['a', 'b', 'c'])..failNext();

      final failed = await repository.list(const PageRequest(limit: 2));
      final retried = await repository.list(const PageRequest(limit: 2));

      expect(failed.errorOrNull, FirestoreError.unavailable);
      expect(retried.dataOrNull!.items, ['a', 'b']);
      expect(retried.dataOrNull!.hasMore, isTrue);
    });
  });
}
