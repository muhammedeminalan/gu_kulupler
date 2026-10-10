import 'package:equatable/equatable.dart';
import 'package:gu_data/src/core/page_cursor.dart';

/// Sayfalı liste sonucu (PLAN §10.3).
///
/// [next] yalnızca sayfa dolu geldiyse (`items.length == limit`) doludur; boş
/// ise liste bitmiştir ([hasMore] `false`, "Hepsi bu kadar").
final class PageResult<T> extends Equatable {
  /// [items] sayfanın öğeleridir; [next] sonraki sayfanın imlecidir.
  const PageResult({required this.items, this.next});

  /// Sayfanın öğeleri (sorgu sırasıyla).
  final List<T> items;

  /// Sonraki sayfa için `PageRequest.after` değeri; son sayfada `null`.
  final PageCursor? next;

  /// Sonraki sayfa var mı?
  bool get hasMore => next != null;

  @override
  List<Object?> get props => [items, next];
}
