import 'package:equatable/equatable.dart';

/// Toplu yönetici işleminin sonucu (PLAN §10.4 `ManagementRepository
/// .approveMany` / `rejectMany`, `AttendanceRepository.markAllAttended`;
/// DLG-17).
///
/// Her öğe **ayrı** bir işlemdir (transaction); biri başarısız olsa da
/// diğerleri sürer. Listeler öğe kimliklerini (kullanıcı kimliği) girdi
/// sırasıyla taşır; üç liste ayrıktır ve birleşimi girdi kümesidir.
final class BulkResult extends Equatable {
  /// [succeeded] yazılan, [conflicted] beklenen önceki durumda olmadığı için
  /// atlanan (`FirestoreError.conflict` — DLG-18, liste yenilenmeli),
  /// [failed] başka bir hatayla yazılamayan öğeler.
  const BulkResult({
    this.succeeded = const [],
    this.conflicted = const [],
    this.failed = const [],
  });

  /// Başarıyla yazılan öğeler.
  final List<String> succeeded;

  /// Durumu değişmiş (çakışan) öğeler.
  final List<String> conflicted;

  /// Başka bir hatayla yazılamayan öğeler.
  final List<String> failed;

  /// İşlenen toplam öğe sayısı.
  int get total => succeeded.length + conflicted.length + failed.length;

  @override
  List<Object?> get props => [succeeded, conflicted, failed];
}
