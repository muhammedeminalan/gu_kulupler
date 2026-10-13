import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/conflict_exception.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/firestore_failure_detail.dart';
import 'package:gu_data/src/models/counter_model.dart';
import 'package:gu_data/src/repositories/announcement_counter_repository.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';

/// [AnnouncementCounterRepository] uygulaması:
/// `announcementCounters/{clubId}_{yyyyMMdd}` (PLAN §10.4; rules-spec §3.16).
///
/// Okumaya ek olarak sayaç artışını duyuru yayınının batch'ine ([addToBatch])
/// ya da transaction'ına ([addToTransaction]) ekler; bu üyeler SDK tipi aldığı
/// için arayüzde değil buradadır ve yalnızca `gu_data` içindeki repository
/// uygulamaları çağırır. Sayaç tek başına yazılmaz: Security Rules artışı
/// aynı işlemdeki bildirimli duyuruyla eşler (`lastPostRef`).
final class FirebaseAnnouncementCounterRepository
    implements AnnouncementCounterRepository {
  /// [_firestore] servisi üzerinden okur ve yazar; "bugün" [_clock] saatinin
  /// Istanbul günüdür.
  FirebaseAnnouncementCounterRepository(this._firestore, this._clock);

  final FirestoreService _firestore;
  final AppClock _clock;

  /// [doc] belgesinden sayaç modeli (işlem içinde okunan sayaç için de
  /// kullanılır).
  static CounterModel counterOf(FirestoreDoc doc) =>
      CounterModel.fromJson(doc.data, id: doc.id);

  @override
  Future<FirestoreResult<CounterModel?>> getToday(String clubId) async {
    if (RepositoryHelpers.rejectInvalidIds<CounterModel?>({'clubId': clubId})
        case final rejected?) {
      return rejected;
    }
    final now = _clock.nowUtc();
    final today = await _read(clubId, _clock.istanbulDayKey(now));
    final adjacentKey = AnnouncementCounterRepository.adjacentDayKey(
      _clock,
      now,
    );
    if (adjacentKey == null || !today.isSuccess) return today;
    // Gün sınırı penceresi (CD-129): Rules hangi günü geçerli sayacak
    // bilinemez; sayısı büyük olan (kalan hakkı az olan) gösterilir.
    final adjacent = await _read(clubId, adjacentKey);
    return switch (adjacent) {
      FirebaseFailure() => adjacent,
      FirebaseSuccess(data: final other) =>
        (other?.count ?? 0) > (today.dataOrNull?.count ?? 0) ? adjacent : today,
    };
  }

  @override
  Future<FirestoreResult<int>> remainingToday(String clubId) async =>
      (await getToday(clubId)).map(
        (counter) =>
            math.max(0, counter?.remaining ?? Limits.announcementDailyLimit),
      );

  /// [clubId] kulübünün [dayKey] (`yyyyMMdd`) gününe ait sayaç belgesinin
  /// referansı. Kimlikler önceden doğrulanmış olmalıdır.
  DocumentReference<Json> refOf(String clubId, String dayKey) => _firestore.doc(
    FirestoreCollections.announcementCounters,
    FirestoreIds.announcementCounter(clubId, dayKey),
  );

  /// Sayaç artışını [batch]'e ekler: `set(merge)` `{clubId, day, count:
  /// previousCount + 1, lastPostRef: 'posts/{postId}', updatedAt}`.
  ///
  /// Artış, [postId] bildirimli duyurusunun yazımıyla **aynı batch'te**
  /// olmalıdır. [previousCount] sayacın şimdiki değeridir (belge yoksa `0`);
  /// günün hakkı dolmuşsa (`>= Limits.announcementDailyLimit`) hiçbir şey
  /// eklenmez ve [ConflictException] atılır
  /// ([FirestoreRuleCode.announcementLimit]) — `commitBatch` bunu iş kuralı
  /// reddine çevirir ve batch'i işlemez.
  void addToBatch(
    WriteBatch batch, {
    required String clubId,
    required String dayKey,
    required String day,
    required int previousCount,
    required String postId,
  }) => batch.set(
    refOf(clubId, dayKey),
    payload(
      clubId: clubId,
      day: day,
      previousCount: previousCount,
      postId: postId,
    ),
    SetOptions(merge: true),
  );

  /// Sayaç artışını [tx] transaction'ına ekler ([addToBatch]'in transaction
  /// karşılığı; duyuru yayını sayacı aynı işlemde okuduğu için transaction
  /// kullanır). Hak dolmuşsa hiçbir şey eklenmez ve [ConflictException]
  /// atılır.
  void addToTransaction(
    Transaction tx, {
    required String clubId,
    required String dayKey,
    required String day,
    required int previousCount,
    required String postId,
  }) => tx.set(
    refOf(clubId, dayKey),
    payload(
      clubId: clubId,
      day: day,
      previousCount: previousCount,
      postId: postId,
    ),
    SetOptions(merge: true),
  );

  /// Sayaç artışının Firestore yükü: `clubId`, `day` (`yyyy-MM-dd`), `count`
  /// ([previousCount] + 1), `lastPostRef` (`posts/{postId}`) ve sunucu
  /// zamanlı `updatedAt`.
  ///
  /// [previousCount] günün hakkını doldurmuşsa [ConflictException] atar
  /// ([FirestoreRuleCode.announcementLimit]).
  Json payload({
    required String clubId,
    required String day,
    required int previousCount,
    required String postId,
  }) {
    if (previousCount >= Limits.announcementDailyLimit) {
      throw const ConflictException(
        FirestoreRuleCode.announcementLimit,
        detail: FirestoreFailureDetail(FirestoreRuleCode.announcementLimit),
      );
    }
    return {
      ...CounterModel(
        clubId: clubId,
        day: day,
        count: previousCount + 1,
        lastPostRef: FirestoreIds.postRef(postId),
      ).toJson(),
      FirestoreFields.updatedAt: _firestore.serverTimestamp(),
    };
  }

  /// [clubId] kulübünün [dayKey] gününe ait sayacı; belge yoksa başarı
  /// `null`.
  Future<FirestoreResult<CounterModel?>> _read(
    String clubId,
    String dayKey,
  ) async => RepositoryHelpers.parseOrNull(
    await _firestore.getDoc(refOf(clubId, dayKey)),
    counterOf,
  );
}
