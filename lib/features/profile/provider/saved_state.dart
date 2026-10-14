import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// Bir satır: kayıt + gönderisi; gönderi okunamadıysa (silinmiş, gizlenmiş,
/// erişim kalkmış) `null` → "İçerik kaldırıldı" satırı.
typedef SavedEntry = (SavedPostModel, PostModel?);

/// PRF-04 "Kaydedilenler" ekranının durumu (PLAN §12.6).
///
/// * [items] kayıtlardır (`savedPostRepository.listSaved`, en son
///   kaydedilen üstte; 20'lik sayfa + [cursor]). Gönderiler sayfa başına
///   tek tek okunur (`postRepository.getPost`); silinmiş / gizlenmiş /
///   görünmeyen gönderi süzülmez, "İçerik kaldırıldı" satırı olarak kalır
///   (prototip `screens-profile.js:55–56`) ve kaydı kaldırılabilir.
/// * [clubNames] kart başlığındaki kulüp adlarıdır (`getClubs`, toplu).
/// * [unsavedIds] kaydı kaldırılan gönderilerdir: satır iyimser gizlenir;
///   yazım reddedilirse ya da TST-11 "Geri al" seçilirse yerine döner.
final class SavedState extends Equatable {
  /// Varsayılan: içerik yok.
  const SavedState({
    this.items = const [],
    this.clubNames = const {},
    this.cursor,
    this.hasMore = false,
    this.unsavedIds = const {},
    this.isFetching = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.isError = false,
  });

  /// Okunan kayıtlar ve gönderileri (`savedAt ↓`).
  final List<SavedEntry> items;

  /// Kulüp adları, kulüp kimliğine göre.
  final Map<String, String> clubNames;

  /// Sonraki sayfanın imleci; `null` → baştan.
  final PageCursor? cursor;

  /// Okunmamış kayıt var mı?
  final bool hasMore;

  /// Kaydı kaldırılan (gizli) gönderi kimlikleri.
  final Set<String> unsavedIds;

  /// İlk okuma sürüyor (iskelet).
  final bool isFetching;

  /// Sonraki sayfa okunuyor.
  final bool isLoadingMore;

  /// Çek-yenile sürüyor.
  final bool isRefreshing;

  /// Kayıtlar okunamadı ve gösterilecek içerik yok.
  final bool isError;

  /// [post] kart olarak çizilir mi? Okunamayan, silinmiş ya da gizlenmiş
  /// gönderi "kaldırıldı" satırıdır.
  static bool isRemoved(PostModel? post) =>
      post == null || post.isDeleted || post.isHidden;

  /// Çizilen satırlar (kaydı kaldırılanlar hariç).
  List<SavedEntry> get visible => [
    for (final entry in items)
      if (!unsavedIds.contains(entry.$1.postId)) entry,
  ];

  /// Sonraki sayfa istenebilir mi (başka okuma sürmüyor)?
  bool get wantsMore =>
      hasMore && !isFetching && !isRefreshing && !isLoadingMore && !isError;

  /// [postId] gönderisinin satırı; yoksa `null`.
  SavedEntry? entryOf(String postId) {
    for (final entry in items) {
      if (entry.$1.postId == postId) return entry;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    items,
    clubNames,
    cursor,
    hasMore,
    unsavedIds,
    isFetching,
    isLoadingMore,
    isRefreshing,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya; [clearCursor] imleci siler.
  SavedState copyWith({
    List<SavedEntry>? items,
    Map<String, String>? clubNames,
    PageCursor? cursor,
    bool clearCursor = false,
    bool? hasMore,
    Set<String>? unsavedIds,
    bool? isFetching,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? isError,
  }) => SavedState(
    items: items ?? this.items,
    clubNames: clubNames ?? this.clubNames,
    cursor: clearCursor ? null : cursor ?? this.cursor,
    hasMore: hasMore ?? this.hasMore,
    unsavedIds: unsavedIds ?? this.unsavedIds,
    isFetching: isFetching ?? this.isFetching,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
  );
}
