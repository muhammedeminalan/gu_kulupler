import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// FED-02 "Gönderi" ve SHT-09 "Yorumlar" durumu (PLAN §12.8).
///
/// İki canlı kaynak ayrı tutulur: [post] (`postRepository.watchPost`) ve
/// [comments] (`commentRepository.watchComments`, eskiden yeniye). Ekranda
/// çizilen yorumlar [visibleComments] ile türetilir: bu ekranda kaldırılanlar
/// ([removedCommentIds]) ve engellenen yazarların yorumları
/// ([blockedUserIds]) süzülür.
///
/// Kullanıcıya göre durum gönderi belgesinde değildir: [isSaved],
/// [myOptionId] (anket oyu), [pollResults] (seçenek → oy). Yazar adı ve
/// avatarı [users], kulüpteki rolü [roles] ile gelir.
final class PostDetailState extends Equatable {
  /// Varsayılan: içerik yok.
  const PostDetailState({
    this.post,
    this.club,
    this.comments = const [],
    this.users = const {},
    this.roles = const {},
    this.blockedUserIds = const {},
    this.removedCommentIds = const {},
    this.commentDraft = '',
    this.isSendingComment = false,
    this.isSaved = false,
    this.myOptionId,
    this.pollResults = const {},
    this.isFetching = false,
    this.isFetchingComments = false,
    this.isError = false,
    this.isNotFound = false,
    this.isCommentsError = false,
    this.isRemoved = false,
  });

  /// Gönderi (canlı); ilk olay gelmediyse `null`.
  final PostModel? post;

  /// Gönderinin kulübü (başlık çubuğunun alt başlığı, kart alt satırı, görsel
  /// yer tutucusu); okunamadıysa `null`.
  final ClubModel? club;

  /// Gönderinin yorumları (canlı), eskiden yeniye; silinmiş ve gizlenmişler
  /// sorguda süzülür.
  final List<CommentModel> comments;

  /// Kimlik → yazarın güncel kullanıcı belgesi (`userRepository.getUsers`).
  /// Anahtarı olmayan yazar "Silinmiş kullanıcı" çizilir ([authorOf]).
  final Map<String, UserModel> users;

  /// Kimlik → yazarın kulüpteki rolü (başkan / yönetim kurulu / danışman);
  /// anahtarı olmayan yazarda rozet çizilmez.
  final Map<String, ClubRole> roles;

  /// Oturumdaki kullanıcının engelledikleri (oturum + bu ekranda yapılan
  /// iyimser değişiklikler); yorumları listeden süzülür.
  final Set<String> blockedUserIds;

  /// Bu ekranda kaldırılan yorumlar: iyimser gizlenir; yazım başarısızsa ya
  /// da "Geri al" seçilirse kümeden çıkar.
  final Set<String> removedCommentIds;

  /// Yorum alanındaki metin (en çok `Limits.commentMax`).
  final String commentDraft;

  /// Yorum gönderiliyor (gönder düğmesi kapalı).
  final bool isSendingComment;

  /// Gönderi kullanıcının kaydedilenlerinde mi?
  final bool isSaved;

  /// Kullanıcının anket oyu; oy vermediyse (ya da okunmadıysa) `null`.
  final String? myOptionId;

  /// Anket sonuçları (seçenek → oy).
  final Map<String, int> pollResults;

  /// Gönderi ilk kez okunuyor / "Yeniden dene" sürüyor (iskelet).
  final bool isFetching;

  /// Yorumların ilk olayı bekleniyor (yorum bloğunda iskelet).
  final bool isFetchingComments;

  /// Gönderi okunamadı (hata görünümü).
  final bool isError;

  /// Gönderi yok, silinmiş, gizlenmiş ya da bu kulübe ait değil → SYS-04.
  final bool isNotFound;

  /// Yorumlar okunamadı (yorum bloğunda hata).
  final bool isCommentsError;

  /// Gönderi bu ekrandan kaldırıldı (SHT-08 "Sil"): ekran önceki sayfaya
  /// döner; bu sırada gelen "gönderi yok" olayı SYS-04 sayılmaz.
  final bool isRemoved;

  /// Ekranda çizilen yorumlar: kaldırılanlar ve engellenen yazarlarınkiler
  /// yok (`actions.js:59`).
  List<CommentModel> get visibleComments => [
    for (final comment in comments)
      if (!removedCommentIds.contains(comment.id) &&
          !blockedUserIds.contains(comment.authorId))
        comment,
  ];

  /// Yorum gönderilebilir mi: metin boş değil ve süren gönderim yok
  /// (`screens-clubs.js:177`).
  bool get canSendComment =>
      commentDraft.trim().isNotEmpty && !isSendingComment;

  /// [userId] yazarının çizilecek belgesi; belge yoksa ya da hesap silinmişse
  /// `null` ("Silinmiş kullanıcı").
  UserModel? authorOf(String userId) {
    final user = users[userId];
    if (user == null || user.isDeleted || user.isAnonymized) return null;
    return user;
  }

  /// [commentId] kimlikli yorum; listede yoksa `null`.
  CommentModel? commentById(String commentId) {
    for (final comment in comments) {
      if (comment.id == commentId) return comment;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    post,
    club,
    comments,
    users,
    roles,
    blockedUserIds,
    removedCommentIds,
    commentDraft,
    isSendingComment,
    isSaved,
    myOptionId,
    pollResults,
    isFetching,
    isFetchingComments,
    isError,
    isNotFound,
    isCommentsError,
    isRemoved,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearMyOptionId] oyu `null` yapar
  /// ve [myOptionId] parametresinden önce gelir.
  PostDetailState copyWith({
    PostModel? post,
    ClubModel? club,
    List<CommentModel>? comments,
    Map<String, UserModel>? users,
    Map<String, ClubRole>? roles,
    Set<String>? blockedUserIds,
    Set<String>? removedCommentIds,
    String? commentDraft,
    bool? isSendingComment,
    bool? isSaved,
    String? myOptionId,
    bool clearMyOptionId = false,
    Map<String, int>? pollResults,
    bool? isFetching,
    bool? isFetchingComments,
    bool? isError,
    bool? isNotFound,
    bool? isCommentsError,
    bool? isRemoved,
  }) => PostDetailState(
    post: post ?? this.post,
    club: club ?? this.club,
    comments: comments ?? this.comments,
    users: users ?? this.users,
    roles: roles ?? this.roles,
    blockedUserIds: blockedUserIds ?? this.blockedUserIds,
    removedCommentIds: removedCommentIds ?? this.removedCommentIds,
    commentDraft: commentDraft ?? this.commentDraft,
    isSendingComment: isSendingComment ?? this.isSendingComment,
    isSaved: isSaved ?? this.isSaved,
    myOptionId: clearMyOptionId ? null : myOptionId ?? this.myOptionId,
    pollResults: pollResults ?? this.pollResults,
    isFetching: isFetching ?? this.isFetching,
    isFetchingComments: isFetchingComments ?? this.isFetchingComments,
    isError: isError ?? this.isError,
    isNotFound: isNotFound ?? this.isNotFound,
    isCommentsError: isCommentsError ?? this.isCommentsError,
    isRemoved: isRemoved ?? this.isRemoved,
  );
}
