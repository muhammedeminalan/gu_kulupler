import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/media_update_error.dart';
import 'package:gu_data/src/core/page_request.dart';
import 'package:gu_data/src/core/page_result.dart';
import 'package:gu_data/src/models/enums/post_type.dart';
import 'package:gu_data/src/models/post_draft.dart';
import 'package:gu_data/src/models/post_image_model.dart';
import 'package:gu_data/src/models/post_model.dart';

/// Kulüp akışı gönderileri — `posts/{postId}` ve `posts/{postId}/votes/{uid}`
/// (PLAN §10.4; rules-spec §3.5, domain-model §2.5).
///
/// Gönderiyi yalnızca kulübün etkin üyeleri (ve süper admin) okur; yalnızca
/// kulüp yönetimi (yönetim kurulu, başkan) yayınlar. **Belge silme yoktur
/// (D-10):** kaldırma [softDeletePost], geri alma [restorePost] iledir. Anket
/// oyu değiştirilemez ve silinemez.
///
/// Sayaçlar mutlak değerle yazılmaz: beğeni sayacı `likes` dizisiyle aynı
/// yazımda ±1 değişir; bildirimli duyurunun günlük sayacı gönderiyle **aynı
/// işlemde** artar (ya hepsi ya hiçbiri). Yetki arayüzde değil Security
/// Rules'ta uygulanır: yetkisiz çağrı [FirestoreError.permissionDenied]
/// döner. Kimlik parametreleri dış girdi sayılır: geçersiz kimlik (boş, `/`
/// içeren) [FirestoreError.invalidArgument] döner.
abstract interface class PostRepository {
  /// Yeni gönderi için istemcide üretilmiş belge kimliği.
  ///
  /// Görseller gönderiden **önce** yüklendiği için kimlik önceden gerekir:
  /// her görsel `StoragePaths.postImage(postId, file)` yoluna yüklenir ve
  /// [create] aynı kimlikle çağrılır (CD-39).
  String newPostId();

  /// [clubId] kulübünün henüz yayınlanmamış [postId] gönderisi için [images]
  /// görsellerini Storage'a yükler ve yüklenen görsellerin modellerini
  /// **girdi sırasıyla** döner (`PostDraft.images` / `PostEditPatch.images`
  /// değeri). Firestore'a hiçbir şey yazmaz (K-18: önce görseller, sonra
  /// [create] / [update]).
  ///
  /// Her görsel `posts/{postId}/{yeni dosya adı}` yoluna
  /// (`StoragePaths.postImage` + `StoragePaths.newFileName`; sabit ad yok),
  /// `customMetadata: {'clubId': clubId, 'uploaderId': uploaderId}` ile
  /// yüklenir: Storage Rules yükleyenin o kulübün yöneticisi olduğunu
  /// `clubId` üst verisinden doğrular (CD-39) ve `uploaderId` değerinin
  /// oturumdaki kullanıcı olmasını ister — [uploaderId] oturumdaki
  /// kullanıcının kimliğidir (dosyayı kimin yüklediği yalnızca bu alandan
  /// izlenir; başka kimlik `StorageError.unauthorized` alır). Var olan
  /// dosyanın üzerine yazılmaz, dosya silinmez (D-10).
  ///
  /// [images] yeniden kodlanmış baytlardır (`PostImageUpload` — CD-135).
  /// Çağrı başına en çok `Limits.postImagesMax` (4) görsel; her biri
  /// `image/jpeg`, `image/png` ya da `image/webp`, boş değil ve
  /// `Limits.imageMaxBytes` (5 MB) sınırının altında. Boş liste hiçbir şey
  /// yüklemeden başarı (boş liste) döner.
  ///
  /// **Ön denetim (hiçbir dosya gönderilmeden, tüm liste için):**
  /// - geçersiz [postId] / [clubId] / [uploaderId], 4'ten çok görsel ya da
  ///   boyutu (`width` / `height`) 1'den küçük görsel →
  ///   [MediaDocumentError] ([FirestoreError.invalidArgument]);
  /// - izinsiz tür → [MediaUploadError] (`StorageError.invalidType`); boş
  ///   bayt → `StorageError.noFile`; sınırda ya da üstünde boyut →
  ///   `StorageError.sizeLimit`.
  ///
  /// **Yükleme ve kısmi hata:** görseller sırayla, birer birer yüklenir. Her
  /// başarılı yüklemenin ardından [onUploaded] girdi sırasındaki `index` ve
  /// yüklenen model ile çağrılır. Bir yükleme başarısız olursa (ağ, zaman
  /// aşımı ya da Storage Rules reddi: yönetici olmayan yükleyici
  /// `StorageError.unauthorized` alır) kalanlar **gönderilmez** ve sonuç o
  /// hatayı taşıyan [MediaUploadError]'dır. O ana kadar yüklenen dosyalar
  /// yerinde kalır
  /// (silinmez); çağıran [onUploaded] ile öğrendiği modelleri saklar ve
  /// yeniden denemede **yalnızca kalan** görselleri gönderir (her çağrı yeni
  /// dosya adı üretir, üzerine yazma olmaz).
  Future<MediaUpdateResult<List<PostImageModel>>> uploadImages(
    String postId,
    List<PostImageUpload> images, {
    required String clubId,
    required String uploaderId,
    void Function(int index, PostImageModel image)? onUploaded,
  });

  /// [authorId] adına [clubId] kulübünde [draft] gönderisini [postId]
  /// kimliğiyle yayınlar ve yazılan modeli döner.
  ///
  /// Tek işlemde yazılır:
  /// - `posts/{postId}` — sayaçlar sıfır, `likes` boş, `pinned` ve `isHidden`
  ///   `false`; `pushSent` yalnızca duyuruda taslaktaki değeri alır; ankette
  ///   seçenek kimlikleri `o1`–`o4`, bitiş `nowUtc + durationDays`;
  /// - `activity/{clubId}_{authorId}_{kind}_{postId}` günlük kaydı (tür:
  ///   `post_created`, `announcement` ya da `poll`);
  /// - yalnızca **bildirimli duyuruda**: o Istanbul gününün sayacı
  ///   `announcementCounters/{clubId}_{yyyyMMdd}` bir artar ve bu gönderiyi
  ///   gösterir.
  ///
  /// Bildirim dağıtımı burada **yapılmaz** (çağıran yapar — PLAN §10.5).
  ///
  /// Dönen modelin zaman alanları istemci saatinden yaklaşık değerdir.
  ///
  /// Hatalar:
  /// - taslak tür kurallarına uymuyor (metin / başlık / görsel sayısı ve
  ///   yolu / anket) → [FirestoreError.invalidArgument];
  /// - bildirimli duyuruda günün hakkı dolmuş →
  ///   [FirestoreRuleCode.announcementLimit] (hiçbir şey yazılmaz);
  /// - cihaz saati Istanbul gün sınırına `Limits.clockSkewTolerance`
  ///   içindeyken yazım [FirestoreError.permissionDenied] alırsa işlem komşu
  ///   günün sayacıyla **bir kez** yeniden denenir (CD-129); o da reddedilirse
  ///   sonuç ikinci denemenin hatasıdır.
  Future<FirestoreResult<PostModel>> create(
    PostDraft draft, {
    required String authorId,
    required String clubId,
    required String postId,
  });

  /// [authorId] yazarının [postId] gönderisinde [patch] alanlarını değiştirir
  /// ve `editedAt` alanını sunucu zamanına çeker (tek yazım).
  ///
  /// Anket seçenekleri, tür ve sayaçlar değişmez. Boş yama ya da sınır dışı
  /// alan [FirestoreError.invalidArgument]. Gönderi yoksa
  /// [FirestoreError.notFound]; Security Rules açıkken var olmayan ya da
  /// silinmiş gönderinin güncellemesi [FirestoreError.permissionDenied]
  /// olarak döner.
  ///
  /// Security Rules iki düzenlemeyi daha reddeder
  /// ([FirestoreError.permissionDenied]; CD-141 madde 11):
  /// - **anket sorusu** (ankette `text`) yayından sonra değişmez — oylar
  ///   değiştirilemediği için başka soruya taşınamaz; ankette `text` yalnızca
  ///   aynı değerle gönderilebilir;
  /// - **askıdaki ya da silinmiş kulüpte** gönderi düzenlenemez (düzenleme de
  ///   yayındır).
  Future<FirestoreResult<void>> update(
    String postId,
    PostEditPatch patch, {
    required String authorId,
  });

  /// [postId] gönderisini [actorId] adına kaldırır: belge silinmiş olarak
  /// işaretlenir, yerinde kalır.
  ///
  /// Gönderi sabitliyse **aynı işlemde** `pinned: false` olur ve
  /// `clubs/{clubId}.pinnedPostId` boşaltılır. Yorumlar, oylar ve sayaçlar
  /// değişmez. Gönderi yoksa ya da zaten silinmişse
  /// [FirestoreError.notFound].
  Future<FirestoreResult<void>> softDeletePost(
    String postId, {
    required String actorId,
    required String clubId,
  });

  /// Kaldırılmış [postId] gönderisini geri yükler (TST-45 "Geri al").
  ///
  /// Yalnızca silme alanları geri alınır; gönderi yeniden **sabitlenmez**.
  /// Security Rules yalnızca kaldıranın kendisine (ve süper admine) izin
  /// verir.
  Future<FirestoreResult<void>> restorePost(String postId);

  /// [postId] gönderisini [clubId] kulübünün akışında sabitler.
  ///
  /// Kulüpte en çok bir sabit gönderi olur; tek işlemde yazılır: önceki sabit
  /// gönderi (varsa) `pinned: false`, bu gönderi `pinned: true`,
  /// `clubs/{clubId}.pinnedPostId = postId`. Gönderi zaten sabitse hiçbir şey
  /// yazılmadan başarı döner. Gönderi yoksa / silinmişse / gizlenmişse
  /// [FirestoreError.notFound]; başka kulübün gönderisiyse
  /// [FirestoreError.invalidArgument].
  Future<FirestoreResult<void>> pin(String postId, {required String clubId});

  /// [postId] gönderisinin sabitlemesini kaldırır (TST-53): tek işlemde
  /// `pinned: false` ve `clubs/{clubId}.pinnedPostId` boş. Gönderi sabit
  /// değilse hiçbir şey yazılmadan başarı döner.
  Future<FirestoreResult<void>> unpin(String postId, {required String clubId});

  /// [uid] kullanıcısının beğenisini ekler: tek yazımda `likes` dizisine
  /// [uid] eklenir ve `likeCount` bir artar (`updatedAt` **yazılmaz**).
  ///
  /// Tek yazımdır, önce okuma yapılmaz: kullanıcı zaten beğenmişse Security
  /// Rules yazımı reddeder ([FirestoreError.permissionDenied]) — sayaç ikinci
  /// kez artmaz.
  Future<FirestoreResult<void>> like(String postId, {required String uid});

  /// [uid] kullanıcısının beğenisini geri alır: tek yazımda `likes` dizisinden
  /// [uid] çıkar ve `likeCount` bir azalır (`updatedAt` **yazılmaz**).
  ///
  /// Tek yazımdır, önce okuma yapılmaz: kullanıcı beğenmemişse Security
  /// Rules yazımı reddeder ([FirestoreError.permissionDenied]) — sayaç
  /// azalmaz.
  Future<FirestoreResult<void>> unlike(String postId, {required String uid});

  /// [uid] kullanıcısının [postId] anketindeki oyunu [optionId] seçeneğine
  /// verir: `posts/{postId}/votes/{uid}` belgesi oluşturulur (`optionId`,
  /// `createdAt`). Sayaç alanı yoktur; sonuç [countVotes] ile sayılır.
  ///
  /// Oy **değiştirilemez**: kullanıcı daha önce oy verdiyse
  /// [FirestoreError.alreadyExists] (TST-10). Kapanmış anket, anket olmayan
  /// gönderi ya da bilinmeyen seçenek Security Rules'ta reddedilir.
  Future<FirestoreResult<void>> vote(
    String postId, {
    required String uid,
    required String optionId,
  });

  /// [uid] kullanıcısının [postId] anketinde seçtiği seçeneğin kimliği; oy
  /// vermediyse başarı `null`.
  Future<FirestoreResult<String?>> myVote(
    String postId, {
    required String uid,
  });

  /// [postId] anketinin [optionIds] seçeneklerine verilen oy sayıları
  /// (seçenek başına bir sayım sorgusu — en çok `Limits.pollOptionsMax`).
  ///
  /// Her istenen seçenek sonuçta yer alır (oy yoksa `0`).
  Future<FirestoreResult<Map<String, int>>> countVotes(
    String postId,
    List<String> optionIds,
  );

  /// [clubId] kulübünün akışından bir sayfa, en yeni üstte (FED-01).
  ///
  /// Silinmiş ve gizlenmiş gönderiler dönmez (sorgu süzgeci). [type]
  /// verilirse sayfa **istemcide** o türe süzülür (ek indeks açılmaz); bu
  /// yüzden sayfa `limit`'ten az öğe taşıyabilir, sonraki sayfa imleci
  /// süzülmemiş sayfaya göre hesaplanır.
  Future<FirestoreResult<PageResult<PostModel>>> listFeed(
    String clubId,
    PageRequest page, {
    PostType? type,
  });

  /// [clubId] kulübünün içerik yönetimi listesinden bir sayfa, en yeni üstte
  /// (MGT-08): silinmişler hariç, **gizlenmişler dahil**. Yalnızca kulüp
  /// yönetimi ve süper admin okuyabilir.
  Future<FirestoreResult<PageResult<PostModel>>> listForManagement(
    String clubId,
    PageRequest page,
  );

  /// [postId] gönderisi.
  ///
  /// Okunan belge silinmişse [FirestoreError.notFound] (SYS-04). Silinmiş ve
  /// gizlenmiş gönderiyi Security Rules yalnızca yazarına, kulüp yönetimine
  /// ve süper admine verir: gizlenmiş gönderi bu okuyuculara **döner**; diğer
  /// üyeler, kulübün üyesi olmayanlar ve var olmayan gönderiyi soranlar
  /// [FirestoreError.permissionDenied] alır (çağıran ikisini de "bulunamadı"
  /// sayar). Security Rules kapalıyken var olmayan belge
  /// [FirestoreError.notFound].
  Future<FirestoreResult<PostModel>> getPost(String postId);

  /// [postId] gönderisini canlı dinler — yalnızca gönderi detayı açıkken
  /// (FED-02; PLAN §10.6).
  ///
  /// Belge yoksa ya da silinmişse olay başarı `null`'dır. Hata olayı akışı
  /// kapatmaz; geçersiz [postId] tek bir [FirestoreError.invalidArgument]
  /// olayı yayar.
  Stream<FirestoreResult<PostModel?>> watchPost(String postId);

  /// [postId] gönderisini moderasyonla gizler (süper admin; şikayet çözümü
  /// "kaldırıldı"): tek yazımda `isHidden: true`, `hiddenBy: actorId`,
  /// `hiddenAt` sunucu zamanı. Sayaçlar ve sabitleme değişmez.
  Future<FirestoreResult<void>> hide(String postId, {required String actorId});

  /// Gizlenmiş [postId] gönderisini yeniden görünür yapar (süper admin): tek
  /// yazımda `isHidden: false`, `hiddenBy` ve `hiddenAt` boş.
  Future<FirestoreResult<void>> unhide(String postId);
}
