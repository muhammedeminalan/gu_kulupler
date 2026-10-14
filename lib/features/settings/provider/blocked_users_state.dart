import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';

/// Bir satır: engel kaydı + engellenen kullanıcı; kullanıcı belgesi yoksa
/// `null` → "Silinmiş kullanıcı" satırı.
typedef BlockedEntry = (BlockModel, UserModel?);

/// SET-02 "Engellenen kullanıcılar" ekranının durumu (PLAN §12.12).
///
/// * [items] yürürlükteki engellerdir (`blockRepository.listBlocked`, ilk
///   engellenen üstte — prototip `me.blocked` sırası); kullanıcılar toplu
///   okunur (`userRepository.getUsers`).
/// * [unblockedIds] engeli kaldırılan kullanıcılardır: satır iyimser
///   gizlenir; yazım reddedilirse ya da TST-09 "Geri al" seçilirse yerine
///   döner. "Geri al" kaydı `BlockUserMixin`'dedir (ayrı `pendingUndo` yok).
final class BlockedUsersState extends Equatable {
  /// Varsayılan: içerik yok.
  const BlockedUsersState({
    this.items = const [],
    this.unblockedIds = const {},
    this.isFetching = false,
    this.isRefreshing = false,
    this.isError = false,
  });

  /// Okunan engeller ve kullanıcıları.
  final List<BlockedEntry> items;

  /// Engeli kaldırılan (gizli) kullanıcı kimlikleri.
  final Set<String> unblockedIds;

  /// İlk okuma sürüyor (iskelet).
  final bool isFetching;

  /// Çek-yenile sürüyor.
  final bool isRefreshing;

  /// Engeller okunamadı ve gösterilecek içerik yok.
  final bool isError;

  /// Çizilen satırlar (engeli kaldırılanlar hariç).
  List<BlockedEntry> get visible => [
    for (final entry in items)
      if (!unblockedIds.contains(entry.$1.blockedId)) entry,
  ];

  /// [userId] kullanıcısının satırı; yoksa `null`.
  BlockedEntry? entryOf(String userId) {
    for (final entry in items) {
      if (entry.$1.blockedId == userId) return entry;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    items,
    unblockedIds,
    isFetching,
    isRefreshing,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya.
  BlockedUsersState copyWith({
    List<BlockedEntry>? items,
    Set<String>? unblockedIds,
    bool? isFetching,
    bool? isRefreshing,
    bool? isError,
  }) => BlockedUsersState(
    items: items ?? this.items,
    unblockedIds: unblockedIds ?? this.unblockedIds,
    isFetching: isFetching ?? this.isFetching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
  );
}
