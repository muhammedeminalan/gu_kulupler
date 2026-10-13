// `ReportRepository` fake'i (PLAN §16.3): şikayetleri bellekte tutar.
//
//   final reports = FakeReportRepository();
//   await reports.report(reporterId: 'u1', target: target, reason: …);
//   expect(reports.reports.values.single.reason, ReportReason.spam);
//
// Gerçek repository gibi: aynı hedefin ikinci şikayeti `alreadyExists`
// (var olan değişmez); kendini şikayet, hedefle uyuşmayan kulüp ve uzun not
// `invalidArgument`; geçersiz kimlik `invalidArgument`. Silme metodu yoktur
// (D-10).
import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

final class FakeReportRepository extends FakeBase implements ReportRepository {
  /// `reports/{reporterId}_{targetType}_{targetId}` belgeleri (anahtar =
  /// belge kimliği); test ön veriyi buraya yazar.
  final Map<String, ReportModel> reports = <String, ReportModel>{};

  @override
  Future<FirestoreResult<void>> report({
    required String reporterId,
    required ReportTarget target,
    required ReportReason reason,
    String note = '',
  }) async {
    record('report', [reporterId, target, reason, note]);
    if (_rejected<void>(reporterId, target) case final failure?) return failure;
    final clubMismatch =
        target.type == ReportTargetType.club && target.clubId != target.id;
    if (clubMismatch ||
        FieldValidators.reportTarget(
              targetType: target.type,
              targetId: target.id,
              reporterId: reporterId,
              targetClubId: target.clubId,
            ) !=
            null ||
        FieldValidators.reportNote(note) != null) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final key = _key(reporterId, target);
    if (reports.containsKey(key)) {
      return const FirebaseFailure(FirestoreError.alreadyExists);
    }
    reports[key] = ReportModel(
      targetType: target.type,
      targetId: target.id,
      targetClubId: target.clubId,
      reporterId: reporterId,
      reason: reason,
      note: note,
    );
    return const FirebaseSuccess(null);
  }

  @override
  Future<FirestoreResult<bool>> hasReported({
    required String reporterId,
    required ReportTarget target,
  }) async {
    record('hasReported', [reporterId, target]);
    if (_rejected<bool>(reporterId, target) case final failure?) return failure;
    return FirebaseSuccess(reports.containsKey(_key(reporterId, target)));
  }

  static String _key(String reporterId, ReportTarget target) =>
      FirestoreIds.report(reporterId, target.type.json, target.id);

  /// Bekleyen hata ya da geçersiz kimlik varsa başarısızlık; yoksa `null`.
  FirestoreResult<T>? _rejected<T>(String reporterId, ReportTarget target) {
    final failure = switch (takeFailure()) {
      null => null,
      final FirestoreError error => error,
      _ => FirestoreError.unknown,
    };
    if (failure != null) return FirebaseFailure(failure);
    final ids = [reporterId, target.id, ?target.clubId];
    if (!ids.every(RepositoryHelpers.isValidId)) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    return null;
  }
}
