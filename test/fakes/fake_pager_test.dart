// T-15 · FakePager: sayfalı fake repository'lerin ortak dilimleyicisi
// (PLAN §16.3, CD-129).
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_pager.dart';

void main() {
  group('T-15 · FakePager', () {
    test('dolu sayfa imleç taşır; imleç kaldığı yerden sürdürür; kısa sayfa '
        'son sayfadır', () {
      final pager = FakePager();
      final all = [for (var i = 1; i <= 5; i++) 'a$i'];

      final first = pager.slice(all, const PageRequest(limit: 2));
      final second = pager.slice(all, PageRequest(limit: 2, after: first.next));
      final third = pager.slice(all, PageRequest(limit: 2, after: second.next));

      expect(first.items, ['a1', 'a2']);
      expect(second.items, ['a3', 'a4']);
      expect(third.items, ['a5']);
      expect(
        [first.hasMore, second.hasMore, third.hasMore],
        [
          true,
          true,
          false,
        ],
      );
    });

    test('tam dolu son sayfadan sonra boş sayfa gelir; tanınmayan imleç boş '
        'döner', () {
      final pager = FakePager();
      final all = ['a', 'b'];

      final first = pager.slice(all, const PageRequest(limit: 2));
      final tail = pager.slice(all, PageRequest(limit: 2, after: first.next));
      final foreign = pager.slice(
        all,
        PageRequest(limit: 2, after: PageCursor.fake()),
      );

      expect(first.hasMore, isTrue);
      expect(tail.items, isEmpty);
      expect(tail.hasMore, isFalse);
      expect(foreign.items, isEmpty);
    });
  });
}
