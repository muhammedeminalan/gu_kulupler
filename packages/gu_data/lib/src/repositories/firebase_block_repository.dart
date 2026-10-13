import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/firestore_ids.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/block_model.dart';
import 'package:gu_data/src/repositories/block_repository.dart';
import 'package:gu_data/src/repositories/query_x.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/utils/field_validators.dart';

/// [BlockRepository] uygulaması: `blocks/{blockerId}_{blockedId}`
/// (PLAN §10.4).
final class FirebaseBlockRepository implements BlockRepository {
  /// [_firestore] servisi üzerinden okur ve yazar.
  FirebaseBlockRepository(this._firestore);

  final FirestoreService _firestore;

  @override
  Future<FirestoreResult<Set<String>>> fetchActiveBlocks(
    String blockerId,
  ) async => (await listBlocked(blockerId)).map(
    (blocks) => {for (final block in blocks) block.blockedId},
  );

  @override
  Future<FirestoreResult<List<BlockModel>>> listBlocked(
    String blockerId,
  ) async {
    if (RepositoryHelpers.rejectInvalidIds<List<BlockModel>>({
          'blockerId': blockerId,
        })
        case final rejected?) {
      return rejected;
    }
    // Sorgu sözleşmesi (rules-spec §6, SET-02): sahibi + silinmemiş.
    return RepositoryHelpers.parseAll(
      await _firestore.getList(
        _firestore
            .collection(FirestoreCollections.blocks)
            .where(FirestoreFields.blockerId, isEqualTo: blockerId)
            .notDeleted(),
      ),
      (doc) => BlockModel.fromJson(doc.data, id: doc.id),
    );
  }

  @override
  Future<FirestoreResult<void>> block({
    required String blockerId,
    required String blockedId,
  }) async {
    if (_rejectPair(blockerId, blockedId) case final rejected?) return rejected;
    final ref = _ref(blockerId, blockedId);
    switch (await _firestore.getDoc(ref)) {
      case FirebaseSuccess(data: final doc?):
        // Kayıt var: kaldırılmışsa geri yüklenir, yürürlükteyse yazım yok.
        return RepositoryHelpers.isSoftDeleted(doc)
            ? _firestore.restore(ref)
            : const FirebaseSuccess(null);
      // Okuma reddi "kayıt yok" anlamına da gelebilir: Security Rules var
      // olmayan belgede sahibi alanını göremez. Oluşturma denenir; yetkiye
      // yine kural karar verir (yetkisiz çağrıda yazım da reddedilir).
      case FirebaseSuccess() ||
          FirebaseFailure(error: FirestoreError.permissionDenied):
        final block = BlockModel(blockerId: blockerId, blockedId: blockedId);
        return _firestore.set(ref, {
          ...block.toJson(),
          ...BaseFieldsPayload.create(),
        });
      case FirebaseFailure(:final error, :final message, :final detail):
        return FirebaseFailure(error, message: message, detail: detail);
    }
  }

  @override
  Future<FirestoreResult<void>> softDeleteBlock({
    required String blockerId,
    required String blockedId,
  }) async {
    if (_rejectPair(blockerId, blockedId) case final rejected?) return rejected;
    return _firestore.softDelete(
      _ref(blockerId, blockedId),
      actorId: blockerId,
    );
  }

  @override
  Future<FirestoreResult<void>> restoreBlock({
    required String blockerId,
    required String blockedId,
  }) async {
    if (_rejectPair(blockerId, blockedId) case final rejected?) return rejected;
    return _firestore.restore(_ref(blockerId, blockedId));
  }

  /// Engelleme çiftini yazmadan önce doğrular: iki kimlik de geçerli yol
  /// parçası ve kullanıcı kendisi değil. Geçerliyse `null`.
  static FirestoreResult<void>? _rejectPair(
    String blockerId,
    String blockedId,
  ) =>
      RepositoryHelpers.rejectInvalidIds<void>({
        'blockerId': blockerId,
        'blockedId': blockedId,
      }) ??
      RepositoryHelpers.rejectInvalidFields<void>({
        FirestoreFields.blockedId: FieldValidators.blockTarget(
          blockerId: blockerId,
          blockedId: blockedId,
        ),
      });

  DocumentReference<Json> _ref(String blockerId, String blockedId) =>
      _firestore.doc(
        FirestoreCollections.blocks,
        FirestoreIds.block(blockerId, blockedId),
      );
}
