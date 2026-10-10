import 'package:equatable/equatable.dart';

/// Fakülte satırı (`StaticTables.faculties`; PLAN §9.9, domain-model §10).
///
/// Statik tablo satırıdır: Firestore'a yazılmaz, JSON dönüşümü yoktur.
/// Görünen ad uygulama katmanında ARB'den çözülür (`facultyF1`–`facultyF6`).
final class FacultyModel extends Equatable {
  /// Fakülte satırı oluşturur.
  const FacultyModel({required this.id});

  /// Fakülte kimliği (`f1`–`f6`).
  final String id;

  @override
  List<Object?> get props => [id];

  @override
  bool get stringify => true;
}
