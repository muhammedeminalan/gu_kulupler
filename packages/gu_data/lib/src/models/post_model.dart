import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/base_fields.dart';
import 'package:gu_data/src/models/enums/post_type.dart';
import 'package:gu_data/src/models/poll_model.dart';
import 'package:gu_data/src/models/post_image_model.dart';
import 'package:gu_data/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'post_model.g.dart';

/// Kulüp akışı gönderisi — `posts/{postId}` (PLAN §9.6.6, domain-model §2.5).
///
/// Üç türü vardır ([PostType]): sıradan gönderi, duyuru ([title] zorunlu) ve
/// anket ([poll] zorunlu; soru [text] alanındadır). `createdBy` taşımaz;
/// yazar [authorId] alanındadır.
///
/// Sayaçlar ([likeCount], [commentCount]) istemcide hesaplanıp yazılmaz;
/// ilgili değişiklikle aynı yazımda artırılır/azaltılır (domain-model §4).
/// Zaman alanları UTC'dir (D-26).
@JsonSerializable()
final class PostModel extends Equatable with BaseFields {
  /// Gönderi oluşturur. [id] verilmezse boş dizgidir; okunan belgelerde
  /// [PostModel.fromJson] belge kimliğini verir.
  const PostModel({
    required this.clubId,
    required this.authorId,
    required this.text,
    this.id = '',
    this.type = PostType.post,
    this.title,
    this.images = const [],
    this.poll,
    this.pinned = false,
    this.pushSent = false,
    this.likes = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.lastCommentRef,
    this.isHidden = false,
    this.hiddenBy,
    this.hiddenAt,
    this.editedAt,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  /// Firestore belge verisinden model üretir; [id] belge kimliğidir (JSON'da
  /// yer almaz).
  ///
  /// Eksik anahtarlar kurucu varsayılanlarını alır; tanınmayan anahtarlar yok
  /// sayılır. Eksik zorunlu alan ([clubId], [authorId], [text]) ve bilinmeyen
  /// [type] `CheckedFromJsonException` fırlatır.
  factory PostModel.fromJson(Map<String, Object?> json, {required String id}) =>
      _$PostModelFromJson(json).copyWith(id: id);

  /// Belge kimliği (`posts/{postId}`). JSON'a yazılmaz.
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String id;

  /// Gönderinin ait olduğu kulüp.
  @JsonKey(name: FirestoreFields.clubId)
  final String clubId;

  /// Yazarın uid'i.
  @JsonKey(name: FirestoreFields.authorId)
  final String authorId;

  /// Gönderi türü.
  @JsonKey(name: FirestoreFields.type)
  final PostType type;

  /// Duyuru başlığı (1 – `Limits.postTitleMax`); diğer türlerde `null`.
  @JsonKey(name: FirestoreFields.title)
  final String? title;

  /// Gönderi metni (1 – `Limits.postTextMax`); ankette soru metni.
  @JsonKey(name: FirestoreFields.text)
  final String text;

  /// Görseller (en çok `Limits.postImagesMax`).
  @JsonKey(name: FirestoreFields.images)
  final List<PostImageModel> images;

  /// Anket; yalnızca `type == poll` iken dolu.
  @JsonKey(name: FirestoreFields.poll)
  final PollModel? poll;

  /// Kulüp akışında sabit mi? `clubs.pinnedPostId` alanının kopyasıdır.
  @JsonKey(name: FirestoreFields.pinned)
  final bool pinned;

  /// Duyuru bildirimiyle mi yayınlandı? Günlük duyuru limiti bunu sayar;
  /// yalnızca duyuruda `true` olabilir.
  @JsonKey(name: FirestoreFields.pushSent)
  final bool pushSent;

  /// Beğenen kullanıcıların uid'leri (tekrarsız).
  @JsonKey(name: FirestoreFields.likes)
  final List<String> likes;

  /// Beğeni sayacı ([likes] uzunluğu).
  @JsonKey(name: FirestoreFields.likeCount)
  final int likeCount;

  /// Yorum sayacı (silinmemiş yorumlar).
  @JsonKey(name: FirestoreFields.commentCount)
  final int commentCount;

  /// [commentCount] değişikliğine yol açan son yorumun belge yolu
  /// (`comments/{commentId}`; CD-41). Sayaç hiç değişmediyse `null`.
  @JsonKey(name: FirestoreFields.lastCommentRef)
  final String? lastCommentRef;

  /// Moderasyonla gizlendi mi? (süper admin)
  @JsonKey(name: FirestoreFields.isHidden)
  final bool isHidden;

  /// Gizleyen süper adminin uid'i; gizli değilse `null`.
  @JsonKey(name: FirestoreFields.hiddenBy)
  final String? hiddenBy;

  /// Gizlenme anı (sunucu zamanı, UTC); gizli değilse `null`.
  @JsonKey(name: FirestoreFields.hiddenAt)
  @TimestampConverter()
  final DateTime? hiddenAt;

  /// Yazarın son düzenleme anı (sunucu zamanı, UTC); düzenlenmediyse `null`.
  @JsonKey(name: FirestoreFields.editedAt)
  @TimestampConverter()
  final DateTime? editedAt;

  @override
  @JsonKey(name: FirestoreFields.createdAt)
  @TimestampConverter()
  final DateTime? createdAt;

  @override
  @JsonKey(name: FirestoreFields.updatedAt)
  @TimestampConverter()
  final DateTime? updatedAt;

  @override
  @JsonKey(name: FirestoreFields.isDeleted)
  final bool isDeleted;

  @override
  @JsonKey(name: FirestoreFields.deletedAt)
  @TimestampConverter()
  final DateTime? deletedAt;

  @override
  @JsonKey(name: FirestoreFields.deletedBy)
  final String? deletedBy;

  /// Gönderi `createdBy` taşımaz; yazar [authorId] alanındadır.
  @override
  String? get createdBy => null;

  /// Gönderi anket mi?
  bool get isPoll => type == PostType.poll;

  /// Gönderi duyuru mu?
  bool get isAnnouncement => type == PostType.announcement;

  /// [uid] kullanıcısı gönderiyi beğenmiş mi?
  bool likedBy(String uid) => likes.contains(uid);

  /// Anket kapandı mı? Anket yoksa `false`.
  ///
  /// Bitiş anı kapalı sayılır: Security Rules oyu yalnızca
  /// `request.time < poll.endsAt` iken kabul eder.
  bool pollEnded(AppClock clock) {
    final endsAt = poll?.endsAt;
    return endsAt != null && !clock.nowUtc().isBefore(endsAt);
  }

  /// [uid] kullanıcısının beğenisi eklenmiş ([liked] `true`) ya da
  /// kaldırılmış kopya; iyimser arayüz güncellemesi içindir.
  ///
  /// Sunucudaki yazımı yansıtır: [likes] ve [likeCount] yalnızca durum
  /// gerçekten değişiyorsa (±1) değişir, aksi halde aynı değerler döner.
  PostModel withLike(String uid, {required bool liked}) {
    if (liked == likedBy(uid)) return this;
    return copyWith(
      likes: liked
          ? [...likes, uid]
          : [
              for (final id in likes)
                if (id != uid) id,
            ],
      likeCount: likeCount + (liked ? 1 : -1),
    );
  }

  /// Firestore'a yazılacak map. Belge kimliği ve `null` alanlar yer almaz;
  /// zaman alanları `Timestamp` olur (yazarken servis sunucu zamanı
  /// alanlarını ezer).
  Map<String, Object?> toJson() => _$PostModelToJson(this);

  /// Verilen alanları değiştirilmiş kopya. `null` olabilen bir alanı `null`
  /// yapmak için ilgili `clear…` bayrağı verilir.
  PostModel copyWith({
    String? id,
    String? clubId,
    String? authorId,
    PostType? type,
    String? title,
    String? text,
    List<PostImageModel>? images,
    PollModel? poll,
    bool? pinned,
    bool? pushSent,
    List<String>? likes,
    int? likeCount,
    int? commentCount,
    String? lastCommentRef,
    bool? isHidden,
    String? hiddenBy,
    DateTime? hiddenAt,
    DateTime? editedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    bool clearTitle = false,
    bool clearPoll = false,
    bool clearLastCommentRef = false,
    bool clearHiddenBy = false,
    bool clearHiddenAt = false,
    bool clearEditedAt = false,
    bool clearCreatedAt = false,
    bool clearUpdatedAt = false,
    bool clearDeletedAt = false,
    bool clearDeletedBy = false,
  }) => PostModel(
    id: id ?? this.id,
    clubId: clubId ?? this.clubId,
    authorId: authorId ?? this.authorId,
    type: type ?? this.type,
    title: clearTitle ? null : (title ?? this.title),
    text: text ?? this.text,
    images: images ?? this.images,
    poll: clearPoll ? null : (poll ?? this.poll),
    pinned: pinned ?? this.pinned,
    pushSent: pushSent ?? this.pushSent,
    likes: likes ?? this.likes,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount ?? this.commentCount,
    lastCommentRef: clearLastCommentRef
        ? null
        : (lastCommentRef ?? this.lastCommentRef),
    isHidden: isHidden ?? this.isHidden,
    hiddenBy: clearHiddenBy ? null : (hiddenBy ?? this.hiddenBy),
    hiddenAt: clearHiddenAt ? null : (hiddenAt ?? this.hiddenAt),
    editedAt: clearEditedAt ? null : (editedAt ?? this.editedAt),
    createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
    updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    deletedBy: clearDeletedBy ? null : (deletedBy ?? this.deletedBy),
  );

  @override
  List<Object?> get props => [
    id,
    clubId,
    authorId,
    type,
    title,
    text,
    images,
    poll,
    pinned,
    pushSent,
    likes,
    likeCount,
    commentCount,
    lastCommentRef,
    isHidden,
    hiddenBy,
    hiddenAt,
    editedAt,
    createdAt,
    updatedAt,
    isDeleted,
    deletedAt,
    deletedBy,
  ];
}
