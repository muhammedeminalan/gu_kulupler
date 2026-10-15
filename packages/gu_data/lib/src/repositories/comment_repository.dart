import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/models/comment_model.dart';

/// Gönderi yorumları — `comments/{commentId}` (PLAN §10.4; rules-spec §3.6,
/// domain-model §2.6).
///
/// Yorumu kulübün yazma yetkili üyeleri (üye, yönetim kurulu, başkan) yazar;
/// danışman ve süper admin yazamaz. **Belge silme yoktur (D-10):** kaldırma
/// [softDeleteComment], geri alma [restoreComment] iledir.
///
/// Gönderinin `commentCount` sayacı yorumla **aynı işlemde** ±1 değişir (ya
/// hepsi ya hiçbiri) ve gönderinin `lastCommentRef` alanı sayacı değiştiren
/// yorumu gösterir (`comments/{commentId}`; Security Rules eşliği bununla
/// doğrular). Yorum kimliği rastgele üretilir, kullanıcı kimliği taşımaz.
///
/// Engellenen kullanıcıların yorumları burada süzülmez (çağıran süzer).
/// Kimlik parametreleri dış girdi sayılır: geçersiz kimlik
/// [FirestoreError.invalidArgument] döner.
abstract interface class CommentRepository {
  /// [authorId] adına [postId] gönderisine [text] yorumunu yazar ve yazılan
  /// modeli döner.
  ///
  /// Tek işlemde yazılır: `comments/{yeniKimlik}` (`isHidden: false`) ve
  /// `posts/{postId}` — `commentCount` bir artar, `lastCommentRef` yeni
  /// yorumu gösterir. [clubId] gönderinin kulübüdür (Security Rules
  /// gönderideki değerle eşitliğini denetler).
  ///
  /// Dönen modelin zaman alanları istemci saatinden yaklaşık değerdir.
  /// Boş ya da `Limits.commentMax`'ı aşan [text]
  /// [FirestoreError.invalidArgument]; silinmiş / gizlenmiş gönderiye yorum
  /// Security Rules'ta reddedilir.
  Future<FirestoreResult<CommentModel>> add({
    required String postId,
    required String clubId,
    required String authorId,
    required String text,
  });

  /// [commentId] yorumunu [actorId] adına kaldırır.
  ///
  /// Tek işlemde yazılır: yorum silinmiş olarak işaretlenir (belge yerinde
  /// kalır) ve `posts/{postId}` — `commentCount` bir azalır, `lastCommentRef`
  /// bu yorumu gösterir. Önce okuma yapılmaz: yorum yoksa
  /// [FirestoreError.notFound]; Security Rules açıkken var olmayan ya da
  /// zaten silinmiş yorum [FirestoreError.permissionDenied] alır — sayaç
  /// ikinci kez azalmaz.
  Future<FirestoreResult<void>> softDeleteComment(
    String commentId, {
    required String postId,
    required String actorId,
  });

  /// Kaldırılmış [commentId] yorumunu geri yükler (TST-45 "Geri al").
  ///
  /// Tek işlemde yazılır: silme alanları geri alınır ve `posts/{postId}` —
  /// `commentCount` bir artar, `lastCommentRef` bu yorumu gösterir. Security
  /// Rules yalnızca kaldıranın kendisine (ve süper admine) izin verir. Önce
  /// okuma yapılmaz: yorum yoksa [FirestoreError.notFound]; Security Rules
  /// açıkken var olmayan ya da silinmemiş yorum
  /// [FirestoreError.permissionDenied] alır — sayaç ikinci kez artmaz.
  Future<FirestoreResult<void>> restoreComment(
    String commentId, {
    required String postId,
  });

  /// [postId] gönderisinin yorumlarını eskiden yeniye canlı dinler — yalnızca
  /// gönderi detayı açıkken (FED-02; PLAN §10.6).
  ///
  /// Silinmiş ve gizlenmiş yorumlar dönmez (sorgu süzgeci; [clubId] Security
  /// Rules'ın sorguyu kabul etmesi için zorunludur). Hata olayı akışı
  /// kapatmaz; geçersiz kimlik tek bir [FirestoreError.invalidArgument] olayı
  /// yayar.
  ///
  /// Yorumlar gönderinin görünürlüğünü izler (CD-141 madde 11): gönderi
  /// gizlenmiş ya da silinmişse Security Rules sorguyu yalnızca gönderinin
  /// yazarına, kulüp yönetimine ve süper admine açar; diğer üyeler — dinleme
  /// sürerken gönderi gizlenirse de — [FirestoreError.permissionDenied] olayı
  /// alır (çağıran bunu "içerik yok" sayar).
  Stream<FirestoreResult<List<CommentModel>>> watchComments(
    String postId, {
    required String clubId,
  });

  /// [commentId] yorumu (W-103: ADM-04 satır başlığı / SHT-26 yorum hedefi
  /// önizlemesi — `PostRepository.getPost` ile aynı sözleşme).
  ///
  /// Okunan belge silinmişse [FirestoreError.notFound]. Gizlenmiş ve
  /// silinmiş yorumu Security Rules yalnızca yazarına, kulüp yönetimine ve
  /// süper admine verir (rules-spec §6.d; süper admin gönderiye bakılmadan
  /// okur): gizlenmiş yorum bu okuyuculara **döner**; diğerleri ve var
  /// olmayan yorumu soranlar [FirestoreError.permissionDenied] alır (çağıran
  /// ikisini de "bulunamadı" sayar). Security Rules kapalıyken var olmayan
  /// belge [FirestoreError.notFound]. Geçersiz kimlik
  /// [FirestoreError.invalidArgument].
  Future<FirestoreResult<CommentModel>> getComment(String commentId);

  /// [commentId] yorumunu moderasyonla gizler (süper admin; şikayet çözümü
  /// "kaldırıldı"): tek yazımda `isHidden: true`, `hiddenBy: actorId`,
  /// `hiddenAt` sunucu zamanı. `commentCount` **değişmez** (sayaç silinmemiş
  /// yorumları sayar).
  Future<FirestoreResult<void>> hide(
    String commentId, {
    required String actorId,
  });
}
