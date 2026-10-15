import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/club_model.dart';

/// Kulüp okuma yüzeyi — `clubs/{clubId}` (PLAN §10.4; rules-spec §3.3).
///
/// **Salt okunurdur:** kulüp alanlarını yönetim (`ManagementRepository`) ve
/// süper admin (`AdminRepository`) yazar; `memberCount` sayacı yalnızca üyelik
/// geçişiyle aynı işlemde değişir (`MembershipRepository`). Kimlik
/// parametreleri dış girdi sayılır: geçersiz kimlik
/// [FirestoreError.invalidArgument] döner.
abstract interface class ClubRepository {
  /// Silinmemiş tüm kulüpler, `nameLower` sırasıyla (CLB-01 / CLB-02).
  ///
  /// Tek okumadır (en çok `Limits.clubsFetchMax`); sıralama istemcidedir
  /// (`nameLower` yazım anında Türkçe kurallarıyla üretilmiştir — CD-11).
  /// **Askıdaki kulüpler de döner** (`ClubModel.isSuspended`); listeden
  /// ayıklamak ya da "askıda" göstermek çağıranın işidir (rules-spec §3.3 R).
  ///
  /// Bellek içi önbellekten gelebilir (T-44 · D3-01, `CachePolicy.clubTtl`);
  /// [forceRefresh] `true` ise (çek-yenile, yönetim / admin ekranı) sunucudan
  /// okunur.
  Future<FirestoreResult<List<ClubModel>>> fetchActiveClubs({
    bool forceRefresh = false,
  });

  /// [clubId] kulübü (CLB-03).
  ///
  /// Belge yoksa ya da soft delete edilmişse [FirestoreError.notFound];
  /// askıdaki kulüp döner (arayüz askı kartını gösterir). Ayrıştırılamayan
  /// belge [FirestoreError.parse]. Önbellek ve [forceRefresh]
  /// [fetchActiveClubs] ile aynıdır.
  Future<FirestoreResult<ClubModel>> getClub(
    String clubId, {
    bool forceRefresh = false,
  });

  /// [clubIds] kulüpleri (PRF-03, MGT-01).
  ///
  /// Sonuç [clubIds] sırasındadır; tekrarlar tekilleştirilir, belgesi olmayan
  /// ya da soft delete edilmiş kulüp atlanır. Boş liste sorgu yapmadan boş
  /// döner.
  ///
  /// Toplu sorgu reddedilirse (Security Rules listedeki silinmiş ya da
  /// olmayan tek kimlik yüzünden sorgunun tamamını düşürür) kimlikler tek tek
  /// okunur ve okunamayan atlanır; hiçbiri okunamazsa
  /// [FirestoreError.permissionDenied] döner.
  ///
  /// Önbellekteki kulüpler bellekten gelir, yalnızca eksikler okunur;
  /// [forceRefresh] `true` ise hepsi sunucudan okunur.
  Future<FirestoreResult<List<ClubModel>>> getClubs(
    List<String> clubIds, {
    bool forceRefresh = false,
  });

  /// [nameLower] adlı bir kulüp var mı (ADM-03 ad benzersizliği — CD-63)?
  ///
  /// Soft delete edilmiş kulübün adı da **dolu** sayılır (geri alınabilir).
  /// [nameLower] çağıranın ürettiği Türkçe küçük harfli addır (CD-11);
  /// biçimi geçersizse [FirestoreError.invalidArgument]. Yalnızca süper admin
  /// çağırır (Rules süzgeçsiz sorguyu başkasına açmaz).
  Future<FirestoreResult<bool>> isNameTaken(String nameLower);
}
