import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'club_category_request.g.dart';

/// CLB-01 kategori süzgeci isteği (T-27): PRF-01 ilgi alanı çipi
/// (`PRF-01.interest.<id>`) ilgi alanının kategorisini buraya yazar ve
/// Kulüpler sekmesini açar; CLB-01 isteği dinler, süzgecin kategorisini bu
/// tek kategoriye çevirir (diğer süzgeçler korunur) ve isteği tüketir
/// ([consume]). Prototip: `clubFilters.categories = [cat]` +
/// `switchTab('clubs')` (`screens-profile.js:16`).
///
/// Feature'lar birbirini içe aktarmadığı için (CLAUDE.md §1) köprü ürün
/// katmanındadır (`ScrollTopRequest` kalıbı). Değer kategori kimliğidir
/// (`k01`…); `null` → bekleyen istek yok.
@Riverpod(keepAlive: true)
final class ClubCategoryRequest extends _$ClubCategoryRequest {
  @override
  String? build() => null;

  /// CLB-01'in süzgecini [categoryId] kategorisine çevirme isteği.
  void request(String categoryId) => state = categoryId;

  /// İstek uygulandı (CLB-01).
  void consume() => state = null;
}
