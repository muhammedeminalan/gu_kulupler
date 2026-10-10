import 'package:equatable/equatable.dart';

/// İlgi alanı satırı (`StaticTables.interests`; PLAN §9.9, domain-model §10).
///
/// Statik tablo satırıdır: Firestore'a yazılmaz, JSON dönüşümü yoktur.
/// Görünen ad uygulama katmanında ARB'den çözülür (`interestI01`–
/// `interestI16`).
final class InterestModel extends Equatable {
  /// İlgi alanı satırı oluşturur.
  const InterestModel({required this.id, required this.categoryId});

  /// İlgi alanı kimliği (`i01`–`i16`); `users.interests` bu değerleri taşır.
  final String id;

  /// Bağlı olduğu kategori (`CategoryModel.id`; demo verideki `cat` alanı).
  final String categoryId;

  @override
  List<Object?> get props => [id, categoryId];

  @override
  bool get stringify => true;
}
