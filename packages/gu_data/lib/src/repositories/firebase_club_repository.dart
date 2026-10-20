import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:gu_data/src/constants/cache_policy.dart';
import 'package:gu_data/src/constants/firestore_collections.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/read_cache.dart';
import 'package:gu_data/src/models/club_model.dart';
import 'package:gu_data/src/repositories/club_repository.dart';
import 'package:gu_data/src/repositories/query_x.dart';
import 'package:gu_data/src/repositories/repository_helpers.dart';
import 'package:gu_data/src/repositories/repository_read_caches.dart';
import 'package:gu_data/src/services/firestore_service.dart';
import 'package:gu_data/src/services/firestore_types.dart';
import 'package:gu_data/src/utils/field_validators.dart';

/// [ClubRepository] uygulaması: `clubs/{clubId}` (PLAN §10.4).
///
/// `cache` verilirse (kompozisyon kökü) etkin liste ve kulüp belgeleri
/// bellekte [CachePolicy.clubTtl] süre tutulur (T-44 · D3-01): yalnızca
/// sunucudan gelen başarı saklanır; `forceRefresh` önbelleği atlar; kulübe
/// yazım (servis yazım kancası) ve oturum değişimi girdiyi atar. `null`
/// önbelleksiz davranıştır.
final class FirebaseClubRepository implements ClubRepository {
  /// [_firestore] servisi üzerinden okur; `cache` isteğe bağlı bellek içi
  /// önbellektir.
  FirebaseClubRepository(this._firestore, {this._cache});

  final FirestoreService _firestore;
  final RepositoryReadCaches? _cache;

  /// Okunan [doc] kulüp belgesinin modeli; `fromJson` hatası fırlatır
  /// (çağıran `RepositoryHelpers.parse` ile sarar). Üyelik geçişleri de
  /// transaction içinde okuduğu kulübü bununla çevirir.
  static ClubModel clubOf(FirestoreDoc doc) =>
      ClubModel.fromJson(doc.data, id: doc.id);

  @override
  Future<FirestoreResult<List<ClubModel>>> fetchActiveClubs({
    bool forceRefresh = false,
  }) async {
    final cache = _cache;
    if (cache == null) return (await _readActive(null)).result;
    final result = await cache.activeClubs.load(
      RepositoryReadCaches.activeClubsKey,
      () => _readActive(cache),
      forceRefresh: forceRefresh,
    );
    // Önbellekteki liste paylaşılır: her çağıran kendi kopyasını alır.
    return result.map(List.of);
  }

  @override
  Stream<FirestoreResult<List<ClubModel>>> watchActiveClubs() => _firestore
      .watchList(_clubs.notDeleted().limit(Limits.clubsFetchMax))
      .map(
        (event) => RepositoryHelpers.parseAll(
          event,
          clubOf,
        ).map((clubs) => clubs.sortedBy((club) => club.nameLower)),
      );

  /// Etkin kulüp listesini sunucudan okur; [cache] verilirse sunucudan gelen
  /// her kulübü kimliğiyle de yazar.
  Future<CacheLoad<List<ClubModel>>> _readActive(
    RepositoryReadCaches? cache,
  ) async {
    final since = cache?.clubs.stamp ?? 0;
    final read = await _firestore.getList(
      _clubs.notDeleted().limit(Limits.clubsFetchMax),
    );
    final result = RepositoryHelpers.parseAll(
      read,
      clubOf,
    ).map((clubs) => clubs.sortedBy((club) => club.nameLower));
    // Boş liste ve çevrimdışı önbellekten gelen sonuç saklanmaz.
    final storable =
        _fromServer(read) && (result.dataOrNull?.isNotEmpty ?? false);
    if (cache != null && storable) {
      for (final club in result.dataOrNull!) {
        cache.clubs.put(club.id, club, since: since);
      }
    }
    return (result: result, storable: storable);
  }

  @override
  Future<FirestoreResult<ClubModel>> getClub(
    String clubId, {
    bool forceRefresh = false,
  }) async {
    if (RepositoryHelpers.rejectInvalidIds<ClubModel>({'clubId': clubId})
        case final rejected?) {
      return rejected;
    }
    final cache = _cache;
    if (cache == null) return (await _readClub(clubId)).result;
    return cache.clubs.load(
      clubId,
      () => _readClub(clubId),
      forceRefresh: forceRefresh,
    );
  }

  Future<CacheLoad<ClubModel>> _readClub(String clubId) async {
    final doc = await _firestore.getDoc(
      _firestore.doc(FirestoreCollections.clubs, clubId),
    );
    final result = _required(RepositoryHelpers.parseOrNull(doc, clubOf));
    final storable = switch (doc) {
      FirebaseSuccess(data: final snapshot?) => !snapshot.isFromCache,
      _ => false,
    };
    return (result: result, storable: storable && result.isSuccess);
  }

  /// Tekil okuma: "yok" (ya da silinmiş) [FirestoreError.notFound] olur.
  static FirestoreResult<ClubModel> _required(
    FirestoreResult<ClubModel?> read,
  ) => switch (read) {
    FirebaseSuccess(data: final club?) => FirebaseSuccess(club),
    FirebaseSuccess() => const FirebaseFailure(FirestoreError.notFound),
    FirebaseFailure(:final error, :final message, :final detail) =>
      FirebaseFailure(error, message: message, detail: detail),
  };

  @override
  Future<FirestoreResult<List<ClubModel>>> getClubs(
    List<String> clubIds, {
    bool forceRefresh = false,
  }) async {
    final unique = clubIds.toSet().toList();
    if (!unique.every(RepositoryHelpers.isValidId)) {
      return RepositoryHelpers.invalidArgument('geçersiz kimlik: clubIds');
    }
    final cache = _cache;
    final since = cache?.clubs.stamp ?? 0;
    final found = <String, ClubModel>{};
    final missing = <String>[];
    for (final id in unique) {
      final hit = forceRefresh ? null : cache?.clubs.get(id);
      if (hit != null) {
        found[id] = hit;
      } else {
        missing.add(id);
      }
    }
    for (final chunk in missing.slices(RepositoryHelpers.whereInMax)) {
      // Silinmemiş süzgeci Rules'un kanıtıdır: süzgeçsiz kulüp sorgusu
      // reddedilir (rules-spec §3.3 R, §6).
      final read = await _firestore.getList(
        _clubs.where(FieldPath.documentId, whereIn: chunk).notDeleted(),
      );
      var result = RepositoryHelpers.parseAll(read, clubOf);
      // Yedek yol (tek tek okuma) önbelleğe yazmaz.
      var storable = _fromServer(read);
      if (result.errorOrNull == FirestoreError.permissionDenied) {
        result = await _readEach(chunk);
        storable = false;
      }
      switch (result) {
        case FirebaseFailure():
          return result;
        case FirebaseSuccess(data: final clubs):
          for (final club in clubs) {
            found[club.id] = club;
            if (storable) cache?.clubs.put(club.id, club, since: since);
          }
      }
    }
    return FirebaseSuccess([for (final id in unique) ?found[id]]);
  }

  /// Okuma başarılı ve tüm belgeler sunucudan mı geldi?
  static bool _fromServer(FirestoreResult<List<FirestoreDoc>> read) =>
      switch (read) {
        FirebaseSuccess(data: final docs) => docs.every(
          (doc) => !doc.isFromCache,
        ),
        FirebaseFailure() => false,
      };

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
