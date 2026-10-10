import 'package:equatable/equatable.dart';
import 'package:gu_data/src/core/firestore_error.dart';

/// `FirestoreError.ruleViolation` / `FirestoreError.conflict` ile dönen
/// başarısızlığın ek bilgisi (PLAN §10.1).
///
/// `FirebaseFailure.detail` alanında taşınır; ham SDK mesajı (`message`)
/// yerine ViewModel'in kullanıcıya doğru geri bildirimi seçebilmesi içindir.
final class FirestoreFailureDetail extends Equatable {
  /// [code] hangi iş kuralının reddettiğini söyler; [retryAfter] ve [position]
  /// yalnızca ilgili kurallarda doludur.
  const FirestoreFailureDetail(this.code, {this.retryAfter, this.position});

  /// Reddeden iş kuralı.
  final FirestoreRuleCode code;

  /// İşlemin yeniden denenebileceği an (UTC); bekleme süreli kurallarda
  /// (`FirestoreRuleCode.retryCooldown`) dolu.
  final DateTime? retryAfter;

  /// Sıra bilgisi (bekleme listesindeki yer); kontenjan kurallarında dolu.
  final int? position;

  @override
  List<Object?> get props => [code, retryAfter, position];

  @override
  bool? get stringify => true;
}
