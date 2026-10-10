import 'package:equatable/equatable.dart';

/// Kulüp kategorisi satırı (`StaticTables.categories`; PLAN §9.9,
/// domain-model §10).
///
/// Statik tablo satırıdır: Firestore'a yazılmaz, JSON dönüşümü yoktur.
/// Görünen ad uygulama katmanında ARB'den çözülür (`catK01`–`catK08`).
final class CategoryModel extends Equatable {
  /// Kategori satırı oluşturur.
  const CategoryModel({required this.id, required this.icon});

  /// Kategori kimliği (`k01`–`k08`); `clubs.categoryId` bu değeri taşır.
  final String id;

  /// Lucide ikon adı (`cpu`, `flask-conical` …; `assets/icons` dosya adı).
  final String icon;

  @override
  List<Object?> get props => [id, icon];

  @override
  bool get stringify => true;
}
