import 'package:equatable/equatable.dart';

/// Bölüm satırı (`StaticTables.departments`; PLAN §9.9, domain-model §10).
///
/// Statik tablo satırıdır: Firestore'a yazılmaz, JSON dönüşümü yoktur.
/// Görünen ad uygulama katmanında ARB'den çözülür (`deptD01`–`deptD24`).
final class DepartmentModel extends Equatable {
  /// Bölüm satırı oluşturur.
  const DepartmentModel({required this.id, required this.facultyId});

  /// Bölüm kimliği (`d01`–`d24`); `users.department` bu değeri taşır.
  final String id;

  /// Bağlı olduğu fakülte (`FacultyModel.id`; demo verideki `faculty` alanı).
  final String facultyId;

  @override
  List<Object?> get props => [id, facultyId];

  @override
  bool get stringify => true;
}
