import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/models/saved_post_model.dart';

/// Kaydedilen gönderiler — `savedPosts/{userId}_{postId}` (PLAN §10.4;
/// rules-spec §3.14, domain-model §2.14).
///
/// Kaydı yalnızca sahibi okur ve yazar. **Belge silme yoktur (D-10):** kaydı
/// kaldırmak belgeyi silinmiş olarak işaretler ([softDeleteSaved]); yeniden
/// kaydetmek ([save]) ve "Geri al" ([restoreSaved]) aynı belgeyi geri
/// yükler. Sayaç ya da yan yazım yoktur.
///
/// Kimlik parametreleri dış girdi sayılır: geçersiz kimlik
/// [FirestoreError.invalidArgument] döner.
abstract interface class SavedPostRepository {
  /// [userId] adına [clubId] kulübünün [postId] gönderisini kaydeder.
  ///
  /// Kayıt yoksa oluşturulur (`savedAt` sunucu zamanı). Daha önce
  /// kaldırılmışsa aynı belge geri yüklenir ve `savedAt` **yenilenir**
  /// (liste en son kaydedileni üstte gösterir). Kayıt zaten yürürlükteyse
  /// hiçbir şey yazılmadan başarı döner.
  ///
  /// Security Rules yeni kayıtta gönderinin var, silinmemiş ve [clubId]
  /// kulübüne ait olduğunu, kullanıcının da o kulübün içeriğini
  /// görebildiğini denetler.
  Future<FirestoreResult<void>> save({
    required String userId,
    required String postId,
    required String clubId,
  });

  /// [userId] kullanıcısının [postId] kaydını kaldırır (TST-11): belge
  /// silinmiş olarak işaretlenir (`deletedBy: userId`), yerinde kalır. Kayıt
  /// yoksa [FirestoreError.notFound] (Security Rules açıkken var olmayan
  /// kaydın güncellemesi [FirestoreError.permissionDenied] olarak döner).
  Future<FirestoreResult<void>> softDeleteSaved({
    required String userId,
    required String postId,
  });

  /// Kaldırılmış [postId] kaydını geri yükler (TST-11 "Geri al"): yalnızca
  /// silme alanları geri alınır, `savedAt` **değişmez** (kayıt listedeki eski
  /// yerine döner). Kayıt yoksa [FirestoreError.notFound].
  Future<FirestoreResult<void>> restoreSaved({
    required String userId,
    required String postId,
  });

  /// [userId] kullanıcısının yürürlükteki kayıtlarından bir sayfa, en son
  /// kaydedilen üstte (PRF-04). Kaldırılmış kayıtlar dönmez.
  Future<FirestoreResult<PageResult<SavedPostModel>>> listSaved(
    String userId,
    PageRequest page,
  );

  /// [userId] kullanıcısı [postId] gönderisini kaydetmiş mi? Kayıt yoksa ya
  /// da kaldırılmışsa başarı `false`.
  Future<FirestoreResult<bool>> isSaved({
    required String userId,
    required String postId,
  });

  /// [postIds] içinden [userId]'nin yürürlükteki kayıtları (FED-01 sayfası —
  /// T-44 · D3-03); kaldırılmış kayıt dönmez. Gönderi başına tekil okuma
  /// yerine en çok 30'luk parçalarla `postId in […]` sorgusu; tekrarlar
  /// tekilleştirilir, boş liste sorgu yapmadan boş döner. Parçalardan biri
  /// başarısız olursa ilk hata döner.
  Future<FirestoreResult<Set<String>>> savedAmong({
    required String userId,
    required List<String> postIds,
  });
}
