import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/models/activity_draft.dart';
import 'package:gu_data/src/models/activity_model.dart';
import 'package:gu_data/src/models/enums/activity_category.dart';
import 'package:gu_data/src/models/enums/activity_kind.dart';
import 'package:gu_data/src/repositories/activity_repository.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';

/// [ActivityRepository] uygulaması: `activity/{id}` (PLAN §10.4).
///
/// Okumaya ek olarak günlük kaydını başka bir yazımın batch'ine
/// ([addToBatch]) ya da transaction'ına ([addToTransaction]) ekler; bu iki
/// üye SDK tipi aldığı için arayüzde değil buradadır ve yalnızca `gu_data`
/// içindeki repository uygulamaları çağırır.
final class FirebaseActivityRepository implements ActivityRepository {
  /// [_firestore] servisi üzerinden okur ve yazar.
  FirebaseActivityRepository(this._firestore);

  final FirestoreService _firestore;

  @override
  Future<FirestoreResult<PageResult<ActivityModel>>> listActivity(
    String clubId,
    PageRequest page, {
    ActivityCategory? category,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<PageResult<ActivityModel>>({
          'clubId': clubId,
        })
        case final rejected?) {
      return rejected;
    }
    // Günlükte `isDeleted` alanı yoktur: silinmemiş süzgeci uygulanmaz.
    var query = _firestore
        .collection(FirestoreCollections.activity)
        .where(FirestoreFields.clubId, isEqualTo: clubId);
    if (category != null) {
      query = query.where(
        FirestoreFields.kind,
        whereIn: [for (final kind in category.kinds) kind.json],
      );
    }
    return RepositoryHelpers.parsePage(
      await _firestore.getPage(
        query.orderBy(FirestoreFields.createdAt, descending: true),
        page,
      ),
      (doc) => ActivityModel.fromJson(doc.data, id: doc.id),
    );
  }

  @override
  Future<FirestoreResult<List<int>>> countByWeek({
    required Set<ActivityKind> kinds,
    required DateTime fromUtc,
    required int weeks,
  }) async {
    if (kinds.isEmpty ||
        kinds.length > RepositoryHelpers.whereInMax ||
        weeks <= 0) {
      return const FirebaseFailure(FirestoreError.invalidArgument);
    }
    final kindValues = [for (final kind in kinds) kind.json];
    final start = fromUtc.toUtc();
    // Kovalar paralel; her biri tek `count()` (belge okunmaz). Açık
    // `orderBy createdAt ↓` indeks `activity (kind, createdAt↓)` ile eşleşir.
    final counts = await Future.wait([
      for (var i = 0; i < weeks; i++)
        _firestore.count(
          _firestore
              .collection(FirestoreCollections.activity)
              .where(FirestoreFields.kind, whereIn: kindValues)
              .where(
                FirestoreFields.createdAt,
                isGreaterThanOrEqualTo: Timestamp.fromDate(
                  start.add(_week * i),
                ),
              )
              .where(
                FirestoreFields.createdAt,
                isLessThan: Timestamp.fromDate(start.add(_week * (i + 1))),
              )
              .orderBy(FirestoreFields.createdAt, descending: true),
        ),
    ]);
    final values = <int>[];
    for (final count in counts) {
      switch (count) {
        case FirebaseFailure(:final error, :final message, :final detail):
          return FirebaseFailure(error, message: message, detail: detail);
        case FirebaseSuccess(:final data):
          values.add(data);
      }
    }
    return FirebaseSuccess(values);
  }

  static const Duration _week = Duration(days: DateTime.daysPerWeek);

  /// [draft] kaydını [batch]'e yeni bir `activity/{id}` belgesi olarak ekler.
  ///
  /// Kayıt, tarif ettiği asıl yazımla **aynı batch'te** olmalıdır (Rules
  /// eşlik eden yazımı `getAfter` ile arar — rules-spec §3.11). Kimlik
  /// `draft.id`'dir; verilmemişse yeni bir kimlik üretilir.
  void addToBatch(WriteBatch batch, ActivityDraft draft) =>
      batch.set(_refOf(draft), payload(draft));

  /// [draft] kaydını [tx] transaction'ına yeni bir `activity/{id}` belgesi
  /// olarak ekler ([addToBatch]'in transaction karşılığı; üyelik geçişleri
  /// beklenen durumu okuduğu için transaction kullanır).
  void addToTransaction(Transaction tx, ActivityDraft draft) =>
      tx.set(_refOf(draft), payload(draft));

  /// [draft] kaydının Firestore yükü: `clubId`, `actorId`, `kind`, `refs`
  /// (yalnızca dolu referanslar — W-51) ve sunucu zamanlı `createdAt`.
  /// Günlük ortak alan (`BaseFields`) taşımaz.
  Json payload(ActivityDraft draft) => {
    ...ActivityModel(
      clubId: draft.clubId,
      actorId: draft.actorId,
      kind: draft.kind,
      refs: draft.refs,
    ).toJson(),
    FirestoreFields.createdAt: _firestore.serverTimestamp(),
  };

  DocumentReference<Json> _refOf(ActivityDraft draft) => _firestore.doc(
    FirestoreCollections.activity,
    draft.id ?? _firestore.newId(FirestoreCollections.activity),
  );
}
