import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_ui/gu_ui.dart' show TurkishCaseX;

/// MGT-08 "İçerik yönetimi" ekranının durumu (PLAN §12.6
/// `ManageContentViewModel`; prototip `screens-manage.js:159–167`).
///
/// * [items] kulübün silinmemiş gönderileridir — gizlenmişler dahil
///   (`postRepository.listForManagement`, `createdAt ↓`, 20'lik sayfalar,
///   [cursor]). Sekme ([tab]: gönderi / duyuru / anket — `PostType`) ve
///   arama ([query]) istemcidedir ([visible]).
/// * [access] `advisor` → [isReadOnly] (Q-09: salt okunur bant, FAB yok,
///   menü satırları devre dışı).
/// * Kulüpte en çok bir sabit gönderi vardır ([pinned]); yeni sabitleme
///   öncekini iyimser kaldırır (`PostActionsMixin.togglePostPin`).
final class ManageContentState extends Equatable {
  /// Varsayılan: içerik yok, "Gönderiler" sekmesi.
  const ManageContentState({
    this.access = ClubAccess.visitor,
    this.role,
    this.uid,
    this.club,
    this.tab = PostType.post,
    this.query = '',
    this.items = const [],
    this.cursor,
    this.isFetching = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.isError = false,
  });

  /// Oturumdaki kullanıcının kulübe erişimi.
  final ClubAccess access;

  /// Oturumdaki kullanıcının kulüpteki aktif rolü (başlık rozeti).
  final ClubRole? role;

  /// Oturumdaki kullanıcı (düzenleme yalnızca yazara — CD-141 (5)).
  final String? uid;

  /// Kulüp (başlıktaki ad); okunamadıysa `null`.
  final ClubModel? club;

  /// Seçili sekme (`MGT-08.tab.<posts|announcements|polls>`).
  final PostType tab;

  /// Arama alanı (`MGT-08.search`).
  final String query;

  /// Okunan sayfaların gönderileri (silinmemiş; gizlenmişler dahil),
  /// `createdAt ↓`.
  final List<PostModel> items;

  /// Sonraki sayfanın imleci; `null` → son sayfa okundu.
  final PageCursor? cursor;

  /// İlk yükleme / "Yeniden dene" sürüyor (iskelet).
  final bool isFetching;

  /// Sonraki sayfa okunuyor.
  final bool isLoadingMore;

  /// Çek-yenile sürüyor (içerik ekranda kalır).
  final bool isRefreshing;

  /// İlk yükleme başarısız (hata görünümü).
  final bool isError;

  /// Danışman bakışı (Q-09).
  bool get isReadOnly => access == ClubAccess.advisor;

  /// Süper admin bakışı (başlık rozeti).
  bool get isSuperAdmin => access == ClubAccess.superAdmin;

  /// Okunmamış sayfa var.
  bool get hasMore => cursor != null;

  /// Liste sonuna gelince sonraki sayfa istenebilir.
  bool get wantsMore => hasMore && !isLoadingMore && !isError && !isFetching;

  /// Aranan terim: kırpılmış, Türkçe küçük harf (CD-11).
  String get needle => query.trim().trLower();

  /// Ekranda listelenen gönderiler: [tab] türünde ve aramaya (başlık ya da
  /// metin) uyanlar.
  List<PostModel> get visible {
    final term = needle;
    return [
      for (final post in items)
        if (post.type == tab && (term.isEmpty || _matches(post, term))) post,
    ];
  }

  /// Okunan sayfalardaki sabit gönderi; yoksa `null`.
  PostModel? get pinned {
    for (final post in items) {
      if (post.pinned) return post;
    }
    return null;
  }

  /// [id] kimlikli gönderi; yoksa `null`.
  PostModel? postById(String id) {
    for (final post in items) {
      if (post.id == id) return post;
    }
    return null;
  }

  /// [post] düzenlenebilir mi: danışman değil ve gönderinin yazarı (CD-141
  /// (5): düzenleme `yazar && yönetici`; Rules başkasının gönderisini
  /// reddeder).
  bool canEdit(PostModel post) =>
      !isReadOnly && uid != null && post.authorId == uid;

  static bool _matches(PostModel post, String term) =>
      (post.title ?? '').trLower().contains(term) ||
      post.text.trLower().contains(term);

  /// Verilen alanları değiştirilmiş kopya. [clearRole] rolü, [clearCursor]
  /// imleci siler.
  ManageContentState copyWith({
    ClubAccess? access,
    ClubRole? role,
    bool clearRole = false,
    String? uid,
    ClubModel? club,
    PostType? tab,
    String? query,
    List<PostModel>? items,
    PageCursor? cursor,
    bool clearCursor = false,
    bool? isFetching,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? isError,
  }) => ManageContentState(
    access: access ?? this.access,
    role: clearRole ? null : role ?? this.role,
    uid: uid ?? this.uid,
    club: club ?? this.club,
    tab: tab ?? this.tab,
    query: query ?? this.query,
    items: items ?? this.items,
    cursor: clearCursor ? null : cursor ?? this.cursor,
    isFetching: isFetching ?? this.isFetching,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
  );

  @override
  List<Object?> get props => [
    access,
    role,
    uid,
    club,
    tab,
    query,
    items,
    cursor,
    isFetching,
    isLoadingMore,
    isRefreshing,
    isError,
  ];
}
