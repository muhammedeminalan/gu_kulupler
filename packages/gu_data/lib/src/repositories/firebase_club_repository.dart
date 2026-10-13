import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/club_model.dart';
import 'package:gu_data/src/repositories/club_repository.dart';
import 'package:gu_data/src/repositories/query_x.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/utils/field_validators.dart';

/// [ClubRepository] uygulaması: `clubs/{clubId}` (PLAN §10.4).
final class FirebaseClubRepository implements ClubRepository {
  /// [_firestore] servisi üzerinden okur.
  FirebaseClubRepository(this._firestore);

  final FirestoreService _firestore;

  /// Okunan [doc] kulüp belgesinin modeli; `fromJson` hatası fırlatır
  /// (çağıran `RepositoryHelpers.parse` ile sarar). Üyelik geçişleri de
  /// transaction içinde okuduğu kulübü bununla çevirir.
  static ClubModel clubOf(FirestoreDoc doc) =>
      ClubModel.fromJson(doc.data, id: doc.id);

  @override
  Future<FirestoreResult<List<ClubModel>>> fetchActiveClubs() async {
    final result = RepositoryHelpers.parseAll(
      await _firestore.getList(
        _clubs.notDeleted().limit(Limits.clubsFetchMax),
      ),
      clubOf,
    );
    return result.map(
      (clubs) => clubs.sortedBy((club) => club.nameLower),
    );
  }

  @override
  Future<FirestoreResult<ClubModel>> getClub(String clubId) async {
    if (RepositoryHelpers.rejectInvalidIds<ClubModel>({'clubId': clubId})
        case final rejected?) {
      return rejected;
    }
    final read = RepositoryHelpers.parseOrNull(
      await _firestore.getDoc(
        _firestore.doc(FirestoreCollections.clubs, clubId),
      ),
      clubOf,
    );
    return switch (read) {
      FirebaseSuccess(data: final club?) => FirebaseSuccess(club),
      FirebaseSuccess() => const FirebaseFailure(FirestoreError.notFound),
      FirebaseFailure(:final error, :final message, :final detail) =>
        FirebaseFailure(error, message: message, detail: detail),
    };
  }

  @override
  Future<FirestoreResult<List<ClubModel>>> getClubs(
    List<String> clubIds,
  ) async {
    final unique = clubIds.toSet().toList();
    if (!unique.every(RepositoryHelpers.isValidId)) {
      return RepositoryHelpers.invalidArgument('geçersiz kimlik: clubIds');
    }
    final found = <String, ClubModel>{};
    for (final chunk in unique.slices(RepositoryHelpers.whereInMax)) {
      // Silinmemiş süzgeci Rules'un kanıtıdır: süzgeçsiz kulüp sorgusu
      // reddedilir (rules-spec §3.3 R, §6).
      var result = RepositoryHelpers.parseAll(
        await _firestore.getList(
          _clubs.where(FieldPath.documentId, whereIn: chunk).notDeleted(),
        ),
        clubOf,
      );
      if (result.errorOrNull == FirestoreError.permissionDenied) {
        result = await _readEach(chunk);
      }
      switch (result) {
        case FirebaseFailure():
          return result;
        case FirebaseSuccess(data: final clubs):
          for (final club in clubs) {
            found[club.id] = club;
          }
      }
    }
    return FirebaseSuccess([for (final id in unique) ?found[id]]);
  }

  /// [ids] kulüplerini tek tek okur — kimlik listeli sorgunun reddinde
  /// yedek yol.
  ///
  /// Security Rules kimlik listeli sorguyu belge belge değerlendirir:
  /// listedeki soft delete edilmiş ya da var olmayan **tek** kimlik sorgunun
  /// tamamını düşürür (rules-spec §3.3 R). Tekil okumada olmayan kulüp boş,
  /// silinmiş kulüp ret döner; ikisi de atlanır. **Hiçbir** kimlik
  /// okunamadıysa (her okuma ret) çağıranın yetkisi yoktur: ret aynen döner.
  Future<FirestoreResult<List<ClubModel>>> _readEach(List<String> ids) async {
    final reads = await Future.wait([
      for (final id in ids)
        _firestore.getDoc(_firestore.doc(FirestoreCollections.clubs, id)),
    ]);
    final clubs = <ClubModel>[];
    var denied = 0;
    for (final read in reads) {
      switch (read) {
        case FirebaseSuccess(data: final doc?)
            when !RepositoryHelpers.isSoftDeleted(doc):
          switch (RepositoryHelpers.parse(doc, clubOf)) {
            case FirebaseSuccess(data: final club):
              clubs.add(club);
            case FirebaseFailure(:final error, :final message, :final detail):
              return FirebaseFailure(error, message: message, detail: detail);
          }
        case FirebaseSuccess():
          break;
        case FirebaseFailure(error: FirestoreError.permissionDenied):
          denied++;
        case FirebaseFailure(:final error, :final message, :final detail):
          return FirebaseFailure(error, message: message, detail: detail);
      }
    }
    if (denied == ids.length) {
      return const FirebaseFailure(FirestoreError.permissionDenied);
    }
    return FirebaseSuccess(clubs);
  }

  @override
  Future<FirestoreResult<bool>> isNameTaken(String nameLower) async {
    if (RepositoryHelpers.rejectInvalidFields<bool>({
          FirestoreFields.nameLower: FieldValidators.clubNameLower(nameLower),
        })
        case final rejected?) {
      return rejected;
    }
    // Silinmiş kulübün adı da dolu sayılır (geri alınabilir — D-10); bu
    // yüzden silinmemiş süzgeci yoktur. Sorguyu yalnızca süper admin koşar.
    final result = await _firestore.getList(
      _clubs.where(FirestoreFields.nameLower, isEqualTo: nameLower).limit(1),
    );
    return result.map((docs) => docs.isNotEmpty);
  }

  Query<Json> get _clubs => _firestore.collection(FirestoreCollections.clubs);
}
