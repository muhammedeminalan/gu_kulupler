import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// FED-01 tür süzgeci — çip başına bir değer (`FED-01.filter.<id>`; prototip
/// `screens-clubs.js:63, 67`). Değerlerin sırası çiplerin ekrandaki sırasıdır.
enum FeedFilter {
  /// "Tümü": bütün gönderiler.
  all,

  /// "Duyurular": yalnızca duyurular.
  announcements,

  /// "Anketler": yalnızca anketler.
  polls,

  /// "Görseller": en az bir görseli olan gönderiler (tür fark etmez).
  images;

  /// [post] bu süzgeçte görünür mü?
  bool includes(PostModel post) => switch (this) {
    FeedFilter.all => true,
    FeedFilter.announcements => post.isAnnouncement,
    FeedFilter.polls => post.isPoll,
    FeedFilter.images => post.images.isNotEmpty,
  };
}

/// FED-01 "Akış" (CLB-03 "Gönderiler" sekmesi) durumu (PLAN §12.6).
///
/// İki kaynak ayrı tutulur: [posts] akışın okunan sayfalarıdır (en yeni
/// üstte, 20 + imleç — [cursor], [hasMore]); [pinned] kulübün sabit
/// gönderisidir (`clubs.pinnedPostId`) ve okunan sayfaların dışında da
/// olabilir. Ekranda görünen liste [visible] ile türetilir: sabit gönderi en
/// üstte, tür süzgeci ve engellenen yazarlar istemcide süzülür.
///
/// Kullanıcıya göre durum gönderi belgesinde değildir: kaydedilenler
/// [savedPostIds], anket oyları [myVotes], oy sayıları [pollResults]. Yazar
/// adı ve avatarı [users], kulüpteki rolü [roles] ile gelir.
final class ClubFeedState extends Equatable {
  /// Varsayılan: içerik yok, süzgeç "Tümü".
  const ClubFeedState({
    this.posts = const [],
    this.pinned,
    this.filter = FeedFilter.all,
    this.club,
    this.users = const {},
    this.roles = const {},
    this.savedPostIds = const {},
    this.myVotes = const {},
    this.pollResults = const {},
    this.blockedUserIds = const {},
    this.cursor,
    this.isFetching = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.isError = false,
  });

  /// Akışın okunan gönderileri, en yeni üstte (sabit gönderi sayfasındaysa
  /// burada da yer alır; [visible] onu bir kez çizer).
  final List<PostModel> posts;

  /// Kulübün sabit gönderisi; yoksa (ya da okunamadıysa / gizlendiyse)
  /// `null`.
  final PostModel? pinned;

  /// Seçili tür çipi.
  final FeedFilter filter;

  /// Kulüp (görsel yer tutucusunun paleti); okunamadıysa `null`.
  final ClubModel? club;

  /// Kimlik → yazarın güncel kullanıcı belgesi (`userRepository.getUsers`).
  /// Anahtarı olmayan yazar "Silinmiş kullanıcı" çizilir.
  final Map<String, UserModel> users;

  /// Kimlik → yazarın kulüpteki rolü (başkan / yönetim kurulu —
  /// `membershipRepository.listManagers`); anahtarı olmayan yazarda rozet
  /// çizilmez.
  final Map<String, ClubRole> roles;

  /// Kullanıcının kaydettiği gönderiler (yalnızca okunan gönderiler arasında).
  final Set<String> savedPostIds;

  /// Kullanıcının anket oyları: gönderi → seçenek kimliği.
  final Map<String, String> myVotes;

  /// Anket sonuçları: gönderi → (seçenek → oy sayısı).
  final Map<String, Map<String, int>> pollResults;

  /// Oturumdaki kullanıcının engelledikleri (oturum + bu ekranda yapılan
  /// iyimser değişiklikler); gönderileri akıştan süzülür.
  final Set<String> blockedUserIds;

  /// Sonraki sayfanın imleci; akış bittiyse `null`.
  final PageCursor? cursor;

  /// İlk yükleme / "Yeniden dene" sürüyor (iskelet).
  final bool isFetching;

  /// Sonraki sayfa okunuyor (liste sonunda iskelet).
  final bool isLoadingMore;

  /// Yenileme sürüyor (içerik ekranda kalır).
  final bool isRefreshing;

  /// Akış okunamadı (hata görünümü).
  final bool isError;

  /// Okunmamış sayfa var mı?
  bool get hasMore => cursor != null;

  /// Ekranda çizilen gönderiler: sabit gönderi en üstte, ardından akış;
  /// süzgece uymayanlar ve engellenen yazarların gönderileri yok
  /// (`actions.js:57`, `screens-clubs.js:63`).
  List<PostModel> get visible {
    final pinned = this.pinned;
    return [
      if (pinned != null && _shown(pinned)) pinned,
      for (final post in posts)
        if (post.id != pinned?.id && _shown(post)) post,
    ];
  }

  /// [postId] gönderisinin state'teki kopyası; yoksa `null`.
  PostModel? postById(String postId) {
    if (pinned?.id == postId) return pinned;
    for (final post in posts) {
      if (post.id == postId) return post;
    }
    return null;
  }

  /// [authorId] yazarının görünen adı; belgesi yoksa ya da hesabı silinmişse
  /// `null`.
  String? authorName(String authorId) {
    final user = users[authorId];
    return user == null || user.isAnonymized ? null : user.name;
  }

  @override
  List<Object?> get props => [
    posts,
    pinned,
    filter,
    club,
    users,
    roles,
    savedPostIds,
    myVotes,
    pollResults,
    blockedUserIds,
    cursor,
    isFetching,
    isLoadingMore,
    isRefreshing,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearPinned] ve [clearCursor]
  /// ilgili alanı `null` yapar ve aynı adlı parametreden önce gelir.
  ClubFeedState copyWith({
    List<PostModel>? posts,
    PostModel? pinned,
    bool clearPinned = false,
    FeedFilter? filter,
    ClubModel? club,
    Map<String, UserModel>? users,
    Map<String, ClubRole>? roles,
    Set<String>? savedPostIds,
    Map<String, String>? myVotes,
    Map<String, Map<String, int>>? pollResults,
    Set<String>? blockedUserIds,
    PageCursor? cursor,
    bool clearCursor = false,
    bool? isFetching,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? isError,
  }) => ClubFeedState(
    posts: posts ?? this.posts,
    pinned: clearPinned ? null : pinned ?? this.pinned,
    filter: filter ?? this.filter,
    club: club ?? this.club,
    users: users ?? this.users,
    roles: roles ?? this.roles,
    savedPostIds: savedPostIds ?? this.savedPostIds,
    myVotes: myVotes ?? this.myVotes,
    pollResults: pollResults ?? this.pollResults,
    blockedUserIds: blockedUserIds ?? this.blockedUserIds,
    cursor: clearCursor ? null : cursor ?? this.cursor,
    isFetching: isFetching ?? this.isFetching,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
  );

  bool _shown(PostModel post) =>
      filter.includes(post) && !blockedUserIds.contains(post.authorId);
}
