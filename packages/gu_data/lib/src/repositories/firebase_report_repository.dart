import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/firestore_failure_detail.dart';
import 'package:gu_data/src/models/enums/report_reason.dart';
import 'package:gu_data/src/models/enums/report_target_type.dart';
import 'package:gu_data/src/models/report_model.dart';
import 'package:gu_data/src/repositories/announcement_counter_repository.dart';
import 'package:gu_data/src/repositories/report_repository.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/utils/field_validators.dart';

/// [ReportRepository] uygulaması:
/// `reports/{reporterId}_{targetType}_{targetId}` (PLAN §10.4).
///
/// **Günlük kota (T-45, kullanıcı kararı 3):** kullanıcı bir Istanbul
/// gününde en çok `Limits.reportDailyLimit` şikayet yazar. Sayaç
/// `reportCounters/{uid}_{yyyyMMdd}` şikayetle **aynı batch'te**
/// `count: increment(1)` ile artar (`set(merge)`; Rules artışı ve sınırı
/// `getAfter` ile eşler — rules-spec §3.18). Yazmadan önce sayaç okunur:
/// dolu → hiçbir şey yazılmaz, [FirestoreRuleCode.reportLimit]. Gün anahtarı
/// cihaz saatinden hesaplanır; Rules sunucu saatini kullanır ve eşitlik
/// toleranssızdır: ret gün sınırı penceresindeyse (CD-129, W-50) işlem komşu
/// günün sayacıyla **bir kez** yeniden denenir
/// (`AnnouncementCounterRepository.adjacentDayInstant`).
final class FirebaseReportRepository implements ReportRepository {
  /// [_firestore] servisi üzerinden okur ve yazar; "bugün" [_clock] saatinin
  /// Istanbul günüdür.
  FirebaseReportRepository(this._firestore, this._clock);

  final FirestoreService _firestore;
  final AppClock _clock;

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
    final payload = {...report.toJson(), ...BaseFieldsPayload.create()};
    final now = _clock.nowUtc();
    final first = await _reportCounted(ref, payload, reporterId, now);
    if (first.errorOrNull != FirestoreError.permissionDenied) return first;
    // Var olan belgeye `set` Rules'ta güncellemedir ve şikayet edene kapalıdır
    // (`permission-denied`): belge zaten varsa "zaten bildirildi".
    if (await _exists(ref)) return _alreadyReported(ref);
    // Gün sınırı (CD-129): ret yanlış gün anahtarından olabilir; komşu günün
    // sayacıyla bir kez baştan koşulur, o sonuç nihaidir.
    final adjacent = AnnouncementCounterRepository.adjacentDayInstant(
      _clock,
      now,
    );
    if (adjacent == null) return _limitOr(first, reporterId, now);
    final second = await _reportCounted(ref, payload, reporterId, adjacent);
    if (second.errorOrNull != FirestoreError.permissionDenied) return second;
    return _limitOr(second, reporterId, adjacent);
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

  /// [dayInstant] anının Istanbul gününe ait sayaçla tek deneme: sayaç okunur
  /// (ön denetim), hak varsa şikayet + sayaç artışı tek batch'te yazılır.
  ///
  /// Günün hakkı dolmuşsa hiçbir şey yazılmaz ve
  /// [FirestoreRuleCode.reportLimit] döner; aynı hedef zaten bildirilmişse
  /// önce "zaten bildirildi" ([FirestoreError.alreadyExists]) gelir (DLG-12).
  Future<FirestoreResult<void>> _reportCounted(
    DocumentReference<Json> ref,
    Json payload,
    String reporterId,
    DateTime dayInstant,
  ) async {
    final dayKey = _clock.istanbulDayKey(dayInstant);
    final counterRef = _counterRef(reporterId, dayKey);
    final count = await _countOf(counterRef);
    switch (count) {
      case FirebaseFailure(:final error, :final message):
        return FirebaseFailure(error, message: message);
      case FirebaseSuccess(data: final used)
          when used >= Limits.reportDailyLimit:
        return await _exists(ref) ? _alreadyReported(ref) : _limitReached();
      case FirebaseSuccess():
        return _firestore.commitBatch((batch) {
          batch
            ..set(ref, payload)
            ..set(counterRef, {
              FirestoreFields.userId: reporterId,
              FirestoreFields.day: _clock.istanbulDay(dayInstant),
              FirestoreFields.count: FieldValue.increment(1),
              FirestoreFields.reportId: ref.id,
              FirestoreFields.updatedAt: _firestore.serverTimestamp(),
            }, SetOptions(merge: true));
        });
    }
  }

  /// Rules reddinden sonra: [dayInstant] gününün sayacı dolmuşsa (ön
  /// denetimden sonra eşzamanlı şikayet) [FirestoreRuleCode.reportLimit],
  /// değilse [rejected] aynen.
  Future<FirestoreResult<void>> _limitOr(
    FirestoreResult<void> rejected,
    String reporterId,
    DateTime dayInstant,
  ) async {
    final counterRef = _counterRef(
      reporterId,
      _clock.istanbulDayKey(dayInstant),
    );
    final count = (await _countOf(counterRef)).dataOrNull ?? 0;
    return count >= Limits.reportDailyLimit ? _limitReached() : rejected;
  }

  /// Sayaç belgesinin `count` değeri; belge yoksa `0`. Tamsayı olmayan değer
  /// [FirestoreError.parse].
  Future<FirestoreResult<int>> _countOf(
    DocumentReference<Json> counterRef,
  ) async {
    switch (await _firestore.getDoc(counterRef)) {
      case FirebaseFailure(:final error, :final message):
        return FirebaseFailure(error, message: message);
      case FirebaseSuccess(:final data):
        return switch (data?.data[FirestoreFields.count]) {
          null => const FirebaseSuccess(0),
          final int count => FirebaseSuccess(count),
          final Object other => FirebaseFailure(
            FirestoreError.parse,
            message: '${counterRef.path}.count: $other',
          ),
        };
    }
  }

  /// Belge var mı (okuma hatası "yok" sayılır: ret aynen döner).
  Future<bool> _exists(DocumentReference<Json> ref) async =>
      (await _firestore.getDoc(ref)).dataOrNull != null;

  static FirestoreResult<void> _alreadyReported(DocumentReference<Json> ref) =>
      FirebaseFailure(
        FirestoreError.alreadyExists,
        message: '${ref.path}: zaten bildirildi',
      );

  static FirestoreResult<void> _limitReached() => const FirebaseFailure(
    FirestoreError.ruleViolation,
    message: 'reportDailyLimit',
    detail: FirestoreFailureDetail(FirestoreRuleCode.reportLimit),
  );

  DocumentReference<Json> _counterRef(String reporterId, String dayKey) =>
      _firestore.doc(
        FirestoreCollections.reportCounters,
        FirestoreIds.reportCounter(reporterId, dayKey),
      );

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
