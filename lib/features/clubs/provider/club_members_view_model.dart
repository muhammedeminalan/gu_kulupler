import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_state.dart';
import 'package:gu_kulupler/product/mixin/manage_member_actions_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'club_members_view_model.g.dart';

/// Açılışta / yenilemede okunan içerik.
typedef _Loaded = ({
  ClubModel? club,
  List<MembershipModel> managers,
  List<MembershipModel> advisors,
  PageResult<MembershipModel> members,
});

/// CLB-06 "Üyeler" ekranının ViewModel'i (PLAN §12.6; prototip
/// `S['CLB-06']`, `screens-clubs.js:141–148`).
///
/// * Açılışta dört okuma birlikte yapılır: kulüp, yöneticiler
///   (`listManagers`), danışmanlar ve sıradan üyelerin ilk sayfası
///   (`listActiveMembers`, 20 + imleç). Sıradan üyelerin kalan sayfaları
///   [loadMore] ile gelir. Güncel kullanıcı belgeleri toplu okunur
///   (`userRepository.getUsers`); okunamazsa satırlar üyelik belgesindeki
///   anlık görüntüyle çizilir (D-29).
/// * Rol süzgeci, arama ve engellenenlerin süzülmesi istemcidedir
///   (`ClubMembersState.groups`). Engellenenler oturumdan gelir.
/// * Sheet açma ve gezinme view'dadır.
///
/// | İşlem | Sonuç | Geri bildirim |
/// |---|---|---|
/// | [fetch] / [refresh] | okunamadı | hata görünümü / içerik kalır |
/// | [loadMore] | okunamadı | liste olduğu gibi kalır (yeniden kaydırınca dener) |
/// | [openMemberMenu] (yönetici "⋮", W-20) | SHT-21 → profil / SHT-22 → DLG-20 / DLG-19 | `ManageMemberActionsMixin`: rol iyimser (grup değişir) → TST-46; satır iyimser düşer → TST-47 "Geri al" |
///
/// Design: CLB-06
@riverpod
final class ClubMembersViewModel extends _$ClubMembersViewModel
    with ProjectDependencyMixin, WriteGuardMixin, ManageMemberActionsMixin {
  bool _isLoading = false;

  /// İçeriğin kuşağı: her tam okumada artar; eski kuşağın sayfası yazılmaz.
  int _generation = 0;

  @override
  ClubMembersState build(String clubId) {
    ref.listen(sessionViewModelProvider, (previous, session) {
      if (previous?.blockedUserIds == session.blockedUserIds) return;
      state = state.copyWith(blockedUserIds: session.blockedUserIds);
    });
    // Üyeler ilk karede okunmaya başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    return ClubMembersState(
      blockedUserIds: ref.read(sessionViewModelProvider).blockedUserIds,
      isFetching: true,
    );
  }

  /// Üyeleri yeniden okur — hata görünümündeki "Yeniden dene". Süren okuma
  /// varken gelen çağrı yok sayılır.
  Future<void> fetch() async {
    if (!ref.mounted || _isLoading) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _load();
  }

  /// Çek-yenile: listeyi iskelet göstermeden baştan okur. Okunamazsa var
  /// olan içerik kalır; içerik yoksa hata görünümü.
  Future<void> refresh() async {
    if (!ref.mounted || _isLoading || state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true);
    await _load();
  }

  /// Sıradan üyelerin sonraki sayfası (liste sonuna yaklaşınca). Okunamazsa
  /// liste olduğu gibi kalır; imleç korunur.
  Future<void> loadMore() async {
    final cursor = state.cursor;
    if (!ref.mounted ||
        cursor == null ||
        _isLoading ||
        state.isLoadingMore ||
        state.isError) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true);
    final result = await membershipRepository.listActiveMembers(
      clubId,
      PageRequest(after: cursor),
      role: ClubRole.member,
    );
    if (!ref.mounted) return;
    if (generation != _generation) {
      // Liste bu arada baştan okundu: sayfa eski kuşağa aittir.
      state = state.copyWith(isLoadingMore: false);
      return;
    }
    switch (result) {
      case FirebaseSuccess(:final data):
        final known = {for (final member in state.members) member.userId};
        final fresh = [
          for (final member in data.items)
            if (known.add(member.userId)) member,
        ];
        state = state.copyWith(
          members: [...state.members, ...fresh],
          cursor: data.next,
          clearCursor: data.next == null,
          isLoadingMore: false,
        );
        await _loadUsers(fresh, generation);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Üyelerin sonraki sayfası okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Rol çipi (`CLB-06.filter.<id>`).
  void setRoleFilter(MemberRoleFilter filter) {
    if (filter == state.roleFilter) return;
    state = state.copyWith(roleFilter: filter);
  }

  /// Arama alanı (`CLB-06.search`): ad, Türkçe küçük harfle süzülür
  /// (`ClubMembersState.needle`).
  void setQuery(String query) {
    if (query == state.query) return;
    state = state.copyWith(query: query);
  }

  // ─────────────────────── yönetici menüsü (SHT-21, W-20) ───────────────────────

  @override
  SessionState? get memberSession =>
      ref.mounted ? ref.read(sessionViewModelProvider) : null;

  /// Satır menüsü (`CLB-06.menu.<userId>`): SHT-21 → profil / rol değiştir /
  /// çıkar (`ManageMemberActionsMixin`). "Profili gör" view'a döner.
  Future<MemberMenuOutcome> openMemberMenu(MembershipModel membership) =>
      openMemberActions(
        clubId,
        membership,
        name: state.nameOf(membership),
      );

  @override
  void onMemberRemoved(MembershipModel membership) {
    if (!ref.mounted) return;
    final club = state.club;
    state = state.copyWith(
      managers: _without(state.managers, membership.userId),
      members: _without(state.members, membership.userId),
      club: club?.copyWith(memberCount: club.memberCount - 1),
    );
  }

  @override
  void onMemberRestored(MembershipModel membership) {
    if (!ref.mounted) return;
    final known = [
      ...state.managers,
      ...state.members,
    ].any((m) => m.userId == membership.userId);
    if (known) return;
    final club = state.club;
    state = _placed(
      membership,
    ).copyWith(club: club?.copyWith(memberCount: club.memberCount + 1));
  }

  @override
  void onMemberRoleChanged(MembershipModel membership) {
    if (!ref.mounted) return;
    state = _placed(membership);
  }

  @override
  void onMemberListStale(String clubId) {
    if (ref.mounted) unawaited(refresh());
  }

  /// [membership] rolünün grubuna yerleşmiş durum (yönetim kurulu →
  /// [ClubMembersState.managers], üye → [ClubMembersState.members]).
  ClubMembersState _placed(MembershipModel membership) {
    final managers = _without(state.managers, membership.userId);
    final members = _without(state.members, membership.userId);
    return membership.role == ClubRole.member
        ? state.copyWith(managers: managers, members: [...members, membership])
        : state.copyWith(managers: [...managers, membership], members: members);
  }

  static List<MembershipModel> _without(
    List<MembershipModel> list,
    String userId,
  ) => [
    for (final m in list)
      if (m.userId != userId) m,
  ];

  /// İçeriği baştan okur ve ilk yüklemeyi / yenilemeyi bitirir.
  Future<void> _load() async {
    if (!ref.mounted || _isLoading) return;
    _isLoading = true;
    final loaded = await _read();
    _isLoading = false;
    if (!ref.mounted) return;
    if (loaded == null) {
      state = state.copyWith(
        isFetching: false,
        isRefreshing: false,
        isError: state.managers.isEmpty && state.members.isEmpty,
      );
      return;
    }
    final generation = ++_generation;
    state = state.copyWith(
      club: loaded.club,
      managers: loaded.managers,
      advisors: loaded.advisors,
      members: loaded.members.items,
      cursor: loaded.members.next,
      clearCursor: loaded.members.next == null,
      isFetching: false,
      isRefreshing: false,
      isLoadingMore: false,
      isError: false,
    );
    await _loadUsers(
      [...loaded.managers, ...loaded.advisors, ...loaded.members.items],
      generation,
      reread: true,
    );
  }

  /// Kulüp, yöneticiler, danışmanlar ve sıradan üyelerin ilk sayfası. Üyelik
  /// okumalarından biri başarısızsa `null`; kulüp okunamazsa liste yine
  /// gösterilir (alt başlık ve toplam sayaç olmadan).
  Future<_Loaded?> _read() async {
    final (club, managers, advisors, members) = await (
      // Çek-yenile bellek önbelleğini atlar (T-44 · D3-01).
      clubRepository.getClub(clubId, forceRefresh: state.isRefreshing),
      membershipRepository.listManagers(clubId),
      membershipRepository.listActiveMembers(
        clubId,
        const PageRequest(),
        role: ClubRole.advisor,
      ),
      membershipRepository.listActiveMembers(
        clubId,
        const PageRequest(),
        role: ClubRole.member,
      ),
    ).wait;
    if (club case FirebaseFailure(:final error)) {
      AppLogger.warn('Üyeler: kulüp okunamadı: ${error.name}');
    }
    if (managers case FirebaseFailure(:final error, :final message)) {
      AppLogger.warn('Yöneticiler okunamadı: ${error.name}', error: message);
      return null;
    }
    if (advisors case FirebaseFailure(:final error, :final message)) {
      AppLogger.warn('Danışmanlar okunamadı: ${error.name}', error: message);
      return null;
    }
    if (members case FirebaseFailure(:final error, :final message)) {
      AppLogger.warn('Üyeler okunamadı: ${error.name}', error: message);
      return null;
    }
    return (
      club: club.dataOrNull,
      managers: managers.dataOrNull ?? const [],
      advisors: advisors.dataOrNull?.items ?? const [],
      members: members.dataOrNull ?? const PageResult(items: []),
    );
  }

  /// [memberships] sahiplerinin güncel belgelerini toplu okur; okunamazsa
  /// satırlar anlık görüntüyle kalır. [reread] `false` iken yalnızca belgesi
  /// henüz okunmamış olanlar okunur (sonraki sayfa).
  Future<void> _loadUsers(
    List<MembershipModel> memberships,
    int generation, {
    bool reread = false,
  }) async {
    final missing = [
      for (final membership in memberships)
        if (reread || !state.users.containsKey(membership.userId))
          membership.userId,
    ];
    if (missing.isEmpty) return;
    final result = await userRepository.getUsers(missing);
    if (!ref.mounted || generation != _generation) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(
          users: {
            ...state.users,
            for (final user in data) user.uid: user,
          },
        );
      case FirebaseFailure(:final error):
        AppLogger.warn('Üye profilleri okunamadı: ${error.name}');
    }
  }
}
