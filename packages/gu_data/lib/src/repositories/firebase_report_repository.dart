import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/enums/report_reason.dart';
import 'package:gu_data/src/models/enums/report_target_type.dart';
import 'package:gu_data/src/models/report_model.dart';
import 'package:gu_data/src/repositories/report_repository.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/utils/field_validators.dart';

/// [ReportRepository] uygulaması:
/// `reports/{reporterId}_{targetType}_{targetId}` (PLAN §10.4).
final class FirebaseReportRepository implements ReportRepository {
  /// [_firestore] servisi üzerinden okur ve yazar.
  FirebaseReportRepository(this._firestore);

  final FirestoreService _firestore;

  @override
  Future<FirestoreResult<void>> report({
    required String reporterId,
    required ReportTarget target,
    required ReportReason reason,
    String note = '',
  }) async {
    final rejected =
        RepositoryHelpers.rejectInvalidIds<void>({
          'reporterId': reporterId,
          'target.id': target.id,
          'target.clubId': ?target.clubId,
        }) ??
        RepositoryHelpers.rejectInvalidFields<void>({
          FirestoreFields.targetId: FieldValidators.reportTarget(
            targetType: target.type,
            targetId: target.id,
            reporterId: reporterId,
            targetClubId: target.clubId,
          ),
          FirestoreFields.targetClubId: _clubTargetError(target),
          FirestoreFields.note: FieldValidators.reportNote(note),
        });
    if (rejected != null) return rejected;

    // Model varsayılanları: status open. `null` alanların (`action`,
    // `resolvedAt`, `resolvedBy`; kullanıcı hedefinde `targetClubId`) anahtarı
    // yazılmaz (W-51).
    final report = ReportModel(
      targetType: target.type,
      targetId: target.id,
      targetClubId: target.clubId,
      reporterId: reporterId,
      reason: reason,
      note: note,
    );
    final ref = _ref(reporterId, target);
    final written = await _firestore.set(ref, {
      ...report.toJson(),
      ...BaseFieldsPayload.create(),
    });
    // Var olan belgeye `set` Rules'ta güncellemedir ve şikayet edene kapalıdır
    // (`permission-denied`). Ret, belge zaten varsa "zaten bildirildi"
    // demektir; yoksa (etkin olmayan kullanıcı vb.) aynen döner.
    if (written.errorOrNull == FirestoreError.permissionDenied &&
        (await _firestore.getDoc(ref)).dataOrNull != null) {
      return FirebaseFailure(
        FirestoreError.alreadyExists,
        message: '${ref.path}: zaten bildirildi',
      );
    }
    return written;
  }

  @override
  Future<FirestoreResult<bool>> hasReported({
    required String reporterId,
    required ReportTarget target,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<bool>({
          'reporterId': reporterId,
          'target.id': target.id,
        })
        case final rejected?) {
      return rejected;
    }
    final read = await _firestore.getDoc(_ref(reporterId, target));
    return read.map((doc) => doc != null);
  }

  /// `club` hedefinde kulüp, hedefin kendisidir (PLAN §9.6.12); diğer
  /// türlerde kulübün doluluğunu `FieldValidators.reportTarget` denetler.
  static FieldError? _clubTargetError(ReportTarget target) =>
      target.type == ReportTargetType.club && target.clubId != target.id
      ? FieldError.invalidFormat
      : null;

  DocumentReference<Json> _ref(String reporterId, ReportTarget target) =>
      _firestore.doc(
        FirestoreCollections.reports,
        FirestoreIds.report(reporterId, target.type.json, target.id),
      );
}
