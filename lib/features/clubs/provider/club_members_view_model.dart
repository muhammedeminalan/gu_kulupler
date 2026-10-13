import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/club_members_state.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/mixin/block_user_mixin.dart';
import 'package:gu_kulupler/product/mixin/report_received_mixin.dart';
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
///   (`ClubMembersState.groups`). Engellenenler oturumdan gelir; bu ekranda
///   yapılan engelleme oturuma yansıyana dek yerelde tutulur.
/// * Sheet açma ve gezinme view'dadır.
///
/// | İşlem | Sonuç | Geri bildirim |
/// |---|---|---|
/// | [fetch] / [refresh] | okunamadı | hata görünümü / içerik kalır |
/// | [loadMore] | okunamadı | liste olduğu gibi kalır (yeniden kaydırınca dener) |
/// | [block] | onaylandı | satır anında kaybolur, TST-09 (Geri al) |
/// | | yazılamadı / "Geri al" | satır geri gelir; toast `BlockUserMixin`'den |
/// | [submitReport] | yazıldı / zaten bildirilmiş | view → [showReportReceived] (DLG-12) |
/// | | yazılamadı | TST-24 · TST-X18 |
///
/// Design: CLB-06
@riverpod
final class ClubMembersViewModel extends _$ClubMembersViewModel
    with
        ProjectDependencyMixin,
        WriteGuardMixin,
        BlockUserMixin,
        ReportReceivedMixin {
  bool _isLoading = false;

  /// İçeriğin kuşağı: her tam okumada artar; eski kuşağın sayfası yazılmaz.
  int _generation = 0;

  /// Bu ekranda yapılan engel değişiklikleri; oturumdaki kümenin üstüne
  /// uygulanır.
  final BlockOverrides _blocks = BlockOverrides();

  /// Oturum ViewModel'i (uygulama boyunca yaşar); bu ViewModel kapandıktan
  /// sonra gelen "Geri al" için saklanır.
  late SessionViewModel _session;

  @override
  ClubMembersState build(String clubId) {
    ref.listen(sessionViewModelProvider, (previous, session) {
      if (previous?.blockedUserIds == session.blockedUserIds) return;
      state = state.copyWith(
        blockedUserIds: _blocks.applyTo(session.blockedUserIds),
      );
    });
    _session = ref.read(sessionViewModelProvider.notifier);
    // Üyeler ilk karede okunmaya başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    return ClubMembersState(
      blockedUserIds: ref.read(sessionViewModelProvider).blockedUserIds,
      isFetching: true,
    );
  }

  @override
  String? get blockerId => ref.read(sessionViewModelProvider).uid;

  /// [userId] kullanıcısının SHT-10 hedefi (kullanıcı şikayetinde kulüp
  /// yoktur — CD-33).
  ReportTarget reportTargetOf(String userId) =>
      (type: ReportTargetType.user, id: userId, clubId: null);

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

  /// SHT-27 "Engelle": DLG-13 → yazım → TST-09 (`BlockUserMixin`). Satır
  /// iyimser kaybolur; yazılamazsa ya da "Geri al" seçilirse geri gelir.
  Future<void> block(String userId) async {
    final name = state.nameOfUser(userId);
    if (name == null) return;
    await blockUser(userId: userId, name: name);
  }

  /// SHT-27 "Engeli kaldır": yazım → TST-09 (`BlockUserMixin`). Engellenenler
  /// listede çizilmediğinden yalnızca oturum henüz güncellenmemişken
  /// (ör. "Geri al" sonrası) görünür.
  Future<void> unblock(String userId) async {
    final name = state.nameOfUser(userId);
    if (name == null) return;
    await unblockUser(userId: userId, name: name);
  }

  @override
  void onBlockChanged(String userId, {required bool isBlocked}) {
    if (!ref.mounted) return;
    _blocks.mark(userId, isBlocked: isBlocked);
    final name = state.nameOfUser(userId);
    state = state.copyWith(
      blockedUserIds: _blocks.applyTo(
        ref.read(sessionViewModelProvider).blockedUserIds,
      ),
      pendingUndo: isBlocked && name != null
          ? BlockUndo(userId: userId, name: name)
          : null,
      clearPendingUndo: !isBlocked,
    );
  }

  /// Engel yazıldı / geri alındı: oturumdaki engel kümesi anında güncellenir
  /// ki öteki ekranlar da (CLB-07 bandı, SHT-27 satırı) güncel kümeyi görsün;
  /// yerel iyimser kayıt artık gerekmez. "Geri al" ekran kapandıktan sonra da
  /// gelebilir (TST-09 ekrandan uzun yaşar); oturum uygulama boyunca
  /// yaşadığından o durumda da eşitlenir.
  @override
  void onBlockSaved(String userId, {required bool isBlocked}) {
    _session.setBlocked(userId, isBlocked: isBlocked);
    _blocks.settle(userId);
  }

  /// SHT-10'da doğrulanan kullanıcı şikayetini yazar
  /// (`ReportReceivedMixin.sendReport`). `true` → sheet kapanır ve view
  /// [showReportReceived] çağırır; `false` → sheet açık kalır (TST-24 /
  /// TST-X18).
  Future<bool> submitReport(ReportReasonResult report) => sendReport(
    reporterId: ref.read(sessionViewModelProvider).uid,
    report: report,
  );

  /// DLG-12 "Şikayetin alındı"; "… kullanıcısını da engelle" seçilirse
  /// [block] (DLG-13 onayıyla).
  Future<void> showReportReceived(String userId) async {
    final wantsBlock = await showReportReceivedDialog(
      blockableUserName: state.blockedUserIds.contains(userId)
          ? null
          : state.nameOfUser(userId),
    );
    if (wantsBlock && ref.mounted) await block(userId);
  }

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
      clubRepository.getClub(clubId),
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
