import 'package:gu_data/src/core/firestore_error.dart';

/// Transaction gövdesinde beklenen durum tutmadığında atılır (PLAN §10.3).
///
/// Yalnızca `gu_data` içinde dolaşır: repository `runTransaction` gövdesinde
/// atar, `FirestoreService` yakalayıp [error] başarısızlığına çevirir
/// (`FirebaseFailure(e.error, detail: e.detail)`). ViewModel bu istisnayı
/// hiçbir zaman görmez.
///
/// İki tür reddi ayırır (PLAN §10.1):
///
/// - **İş kuralı reddi** — varsayılan kurucu, [code] dolu →
///   [FirestoreError.ruleViolation] (kontenjan dolu, bekleme süresi, kayıt
///   kapalı …). Kullanıcıya hangi geri bildirimin gösterileceğini [code]
///   belirler.
/// - **Çakışma** — [ConflictException.conflict], [code] `null` →
///   [FirestoreError.conflict]: belge, işlem başlarken beklenen durumda değil
///   (ör. başvuruyu başka bir yönetici az önce sonuçlandırdı — DLG-18 + liste
///   yenile). Bir iş kuralı ihlali değildir, bu yüzden [FirestoreRuleCode]
///   taşımaz.
final class ConflictException implements Exception {
  /// [code] iş kuralının reddini bildirir ([FirestoreError.ruleViolation]);
  /// [detail] başarısızlığa eklenecek ek bilgidir (ör.
  /// `FirestoreFailureDetail`).
  const ConflictException(FirestoreRuleCode this.code, {this.detail});

  /// Beklenen önceki durumun tutmadığını bildirir ([FirestoreError.conflict]);
  /// [code] `null`'dır.
  const ConflictException.conflict({this.detail}) : code = null;

  /// Tutmayan iş kuralı; saf çakışmada ([ConflictException.conflict]) `null`.
  final FirestoreRuleCode? code;

  /// Başarısızlığın `detail` alanına aktarılacak ek bilgi.
  final Object? detail;

  /// Servisin bu istisnayı çevireceği hata: [code] doluysa
  /// [FirestoreError.ruleViolation], değilse [FirestoreError.conflict].
  FirestoreError get error =>
      code == null ? FirestoreError.conflict : FirestoreError.ruleViolation;

  @override
  String toString() {
    final label = code?.name ?? FirestoreError.conflict.name;
    return detail == null
        ? 'ConflictException($label)'
        : 'ConflictException($label, $detail)';
  }
}
