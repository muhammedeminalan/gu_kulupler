import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/block_model.dart';

/// Engellenen kullanıcılar — `blocks/{blockerId}_{blockedId}` (PLAN §10.4;
/// rules-spec §3.13).
///
/// Engel kaydını yalnızca sahibi (`blockerId`) okur ve yazar. **Belge silme
/// yoktur (D-10):** engeli kaldırmak kaydı silinmiş olarak işaretler
/// ([softDeleteBlock]); yeniden engellemek ([block]) ve "Geri al"
/// ([restoreBlock]) aynı kaydı geri yükler. Engellenenlerin içerikleri
/// istemcide süzülür ([fetchActiveBlocks]).
///
/// Kimlik parametreleri dış girdi sayılır: geçersiz kimlik (boş, `/` içeren)
/// ve kullanıcının kendisi (`blockedId == blockerId`)
/// [FirestoreError.invalidArgument] döner.
abstract interface class BlockRepository {
  /// [blockerId] kullanıcısının yürürlükteki engellerinde yer alan
  /// kullanıcıların uid kümesi (oturum açılışı). Kaldırılmış engeller dahil
  /// değildir; engel yoksa boş küme döner.
  Future<FirestoreResult<Set<String>>> fetchActiveBlocks(String blockerId);

  /// [blockerId] kullanıcısının yürürlükteki engel kayıtları (SET-02);
  /// [fetchActiveBlocks] ile aynı sorgudur. Tek bir kayıt bile modele
  /// çevrilemezse [FirestoreError.parse].
  Future<FirestoreResult<List<BlockModel>>> listBlocked(String blockerId);

  /// [blockerId] adına [blockedId] kullanıcısını engeller.
  ///
  /// Kayıt yoksa oluşturulur; daha önce kaldırılmışsa aynı kayıt geri
  /// yüklenir (ilk engelleme anı `createdAt` korunur); engel zaten
  /// yürürlükteyse hiçbir şey yazılmadan başarı döner.
  Future<FirestoreResult<void>> block({
    required String blockerId,
    required String blockedId,
  });

  /// [blockerId] kullanıcısının [blockedId] engelini kaldırır: kayıt silinmiş
  /// olarak işaretlenir (`isDeleted`, `deletedAt`, `deletedBy: blockerId`),
  /// belge yerinde kalır. Kayıt yoksa [FirestoreError.notFound] (Security
  /// Rules açıkken var olmayan kaydın güncellemesi
  /// [FirestoreError.permissionDenied] olarak döner).
  Future<FirestoreResult<void>> softDeleteBlock({
    required String blockerId,
    required String blockedId,
  });

  /// Kaldırılmış [blockedId] engelini geri yükler (TST-09 "Geri al"). Kayıt
  /// yoksa [FirestoreError.notFound] (Security Rules açıkken
  /// [FirestoreError.permissionDenied]).
  Future<FirestoreResult<void>> restoreBlock({
    required String blockerId,
    required String blockedId,
  });
}
