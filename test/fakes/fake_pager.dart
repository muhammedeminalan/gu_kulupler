// Sayfalı fake repository'lerin ortak sayfalayıcısı (PLAN §16.3, CD-129;
// kalıp: `page_cursor_fake_test.dart`). İmleç opaktır (`PageCursor.fake()`):
// kaldığı yer kimlikle tutulur.
//
//   final FakePager _pager = FakePager();
//   return FirebaseSuccess(_pager.slice(sorted, page));
import 'package:gu_data/gu_data.dart';

/// Bellekteki bir listeyi `PageRequest` ile dilimler.
final class FakePager {
  final Expando<int> _offsets = Expando<int>();

  /// [all] listesinden [page] dilimini döndürür. Sayfa dolu geldiyse sonuç
  /// bir sonraki sayfanın imlecini taşır (gerçek servis gibi: son sayfa tam
  /// doluysa ardından boş bir sayfa gelir).
  PageResult<T> slice<T>(List<T> all, PageRequest page) {
    final after = page.after;
    final start = after == null ? 0 : _offsets[after] ?? all.length;
    final end = (start + page.limit).clamp(0, all.length);
    final items = all.sublist(start.clamp(0, all.length), end);
    if (items.length < page.limit) return PageResult(items: items);
    final next = PageCursor.fake();
    _offsets[next] = end;
    return PageResult(items: items, next: next);
  }
}
