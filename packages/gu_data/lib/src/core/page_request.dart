import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/page_cursor.dart';

/// Sayfalı liste isteği (PLAN §10.3).
///
/// Varsayılan istek ilk sayfayı [Limits.pageSize] belgeyle ister; sonraki
/// sayfa için bir önceki `PageResult.next` imleci [after] olarak verilir.
final class PageRequest extends Equatable {
  /// [limit] belgelik bir sayfa ister; [after] verilmezse ilk sayfa.
  const PageRequest({this.limit = Limits.pageSize, this.after})
    : assert(limit > 0, 'PageRequest.limit pozitif olmalı');

  /// Sayfadaki en çok belge sayısı (pozitif).
  final int limit;

  /// Bu imleçten sonraki belgeler istenir; `null` ise ilk sayfa.
  final PageCursor? after;

  @override
  List<Object?> get props => [limit, after];
}
