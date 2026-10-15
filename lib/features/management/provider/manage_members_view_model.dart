import 'dart:async';
import 'dart:math' as math;

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_members_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_view_model.dart';
import 'package:gu_kulupler/features/management/provider/members_csv.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/president_picker_sheet.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/manage_member_actions_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'manage_members_view_model.g.dart';

/// Açılışta / yenilemede okunan içerik.
typedef _Loaded = ({
  ClubModel? club,
  List<MembershipModel> managers,
  List<MembershipModel> advisors,
  PageResult<MembershipModel> members,
});

/// MGT-03 "Üye yönetimi" ViewModel'i (PLAN §12.6; prototip `MgtMembers`,
/// `screens-manage.js:61–74`). Kulüp başına ayrı örnek (family `clubId`).
///
/// * Okuma CLB-06 kalıbıdır: kulüp + yöneticiler (`listManagers`) +
///   danışmanlar + sıradan üyelerin ilk sayfası (`listActiveMembers`, 20 +
///   imleç) birlikte; kalan sayfalar [loadMore] ile. Güncel kullanıcı
///   belgeleri toplu okunur (`userRepository.getUsers`; D-29 anlık görüntü
///   yedeği).
/// * Süzgeç / arama / sıralama istemcidedir (`ManageMembersState.visible`).
/// * Üye işlemleri (SHT-21 → SHT-22 → DLG-20 · DLG-19 · SHT-25 → DLG-21)
///   CLB-06 / CLB-07 / SET-03 ile **ortak** `ManageMemberActionsMixin`'dedir;
///   bu ViewModel yalnızca kancalarla listeyi iyimser günceller. Hiyerarşi
///   `RolePolicy` ile yazımdan önce denetlenir (TST-X18); son karar Rules'un.
///
/// | İşlem | Sonuç | Geri bildirim |
/// |---|---|---|
/// | [openMemberMenu] → çıkar (DLG-19) | yazıldı | satır anında düşer → TST-47 "Geri al" |
/// | [openMemberMenu] → rol (SHT-22 → DLG-20) | yazıldı | rozet anında değişir → TST-46 |
/// | [startTransfer] (SHT-25 → DLG-21) | yazıldı | roller güncellenir (eski başkan yönetim kurulu) → TST-49 |
/// | hepsi | yetki / hiyerarşi / çakışma | iyimser değişiklik geri alınır → TST-X18 (+ liste yenilenir) · ağ → TST-24 |
/// | [exportCsv] | paylaşım açıldı | TST-29 |
///
/// Danışman (Q-09) hiçbir yazımı ve dışa aktarmayı yapamaz: TST-26
/// ([ensureWritable]).
///
/// Design: MGT-03
@riverpod
final class ManageMembersViewModel extends _$ManageMembersViewModel
    with ProjectDependencyMixin, WriteGuardMixin, ManageMemberActionsMixin {
  /// CSV'de iletişim belgelerinin aynı anda okunan parça boyu (okuma
  /// sayısı üye sayısı kadardır; eşzamanlılık sınırlanır).
  static const int contactBatchSize = 10;

  /// [loadAll]'ın en çok okuduğu sayfa (1 000 üye).
  static const int maxPages = 50;

  /// Süren tam okuma (ilk yükleme / yenileme).
  Future<void>? _loading;

  /// İçeriğin kuşağı: her tam okumada artar; eski kuşağın sayfası yazılmaz.
  int _generation = 0;

  @override
  ManageMembersState build(String clubId) {
    ref.listen(sessionViewModelProvider, (_, session) {
      final access = session.accessTo(clubId);
      final role = session.roleIn(clubId);
      if (access == state.access && role == state.role) return;
      state = state.copyWith(
        access: access,
        role: role,
        clearRole: role == null,
      );
    });
    // Üyeler ilk karede okunmaya başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_startLoad));
    final session = ref.read(sessionViewModelProvider);
    return ManageMembersState(
      access: session.accessTo(clubId),
      role: session.roleIn(clubId),
      isFetching: true,
    );
  }

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// "Yeniden dene" (`MGT-03.retry`): iskeletle baştan okur.
  Future<void> fetch() async {
    if (!ref.mounted || _loading != null) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _startLoad();
  }

  /// Çek-yenile: içerik kalarak baştan okur.
  Future<void> refresh() async {
    if (!ref.mounted || _loading != null || state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true);
    await _startLoad();
  }

  /// Sıradan üyelerin sonraki sayfası (liste sonuna yaklaşınca). Okunamazsa
  /// liste olduğu gibi kalır.
  Future<void> loadMore() async {
    final cursor = state.cursor;
    if (!ref.mounted ||
        cursor == null ||
        _loading != null ||
        state.isLoadingMore ||
        state.isError) {
      return;
    }
    state = state.copyWith(isLoadingMore: true);
    await _readNext(cursor, _generation);
    if (ref.mounted) state = state.copyWith(isLoadingMore: false);
  }

  /// Bütün sayfalar okunana dek okur (CSV, devir adayları). Süren ilk
  /// okuma beklenir. Liste tamamsa `true`; bir sayfa okunamadıysa `false`.
  Future<bool> loadAll() async {
    final pending = _loading;
    if (pending != null) await pending;
    if (!ref.mounted || state.isError) return false;
    final generation = _generation;
    for (var page = 0; page < maxPages; page++) {
      final cursor = state.cursor;
      if (cursor == null) return true;
      if (!await _readNext(cursor, generation)) return false;
      if (!ref.mounted || generation != _generation) return false;
    }
    return state.cursor == null;
  }

  // ─────────────────────────────── gezinme ──────────────────────────────────

  /// Rol çipi (`MGT-03.filter.<id>`).
  void setRoleFilter(ManageRoleFilter filter) {
    if (filter == state.roleFilter) return;
    state = state.copyWith(roleFilter: filter);
  }

  /// Arama alanı (`MGT-03.search`): ad, Türkçe küçük harfle süzülür.
  void setQuery(String query) {
    if (query == state.query) return;
    state = state.copyWith(query: query);
  }

  /// Sıralama menüsü (`MGT-03.sort.<id>`).
  void setSort(MemberSort sort) {
    if (sort == state.sort) return;
    state = state.copyWith(sort: sort);
  }

  /// Devir adayları (SHT-25): bütün sayfalar okunduktan sonra etkin `member`
  /// / `board` üyeler (hesabı silinmişler hariç).
  Future<List<MembershipModel>> transferCandidates() async {
    await loadAll();
    if (!ref.mounted) return const [];
    return [
      for (final m in state.all)
        if ((m.role == ClubRole.member || m.role == ClubRole.board) &&
            !state.isDeletedUser(m))
          m,
    ];
  }

  // ───────────────────────────────── yazma ──────────────────────────────────

  /// Danışman bakışında yazan eyleme dokunuldu → TST-26.
  void onReadOnlyTap() => feedback.showToast(ToastId.tst26);

  /// Yazan eylemden önce: danışmansa TST-26 ve `false`.
  bool ensureWritable() {
    if (!state.isReadOnly) return true;
    onReadOnlyTap();
    return false;
  }

  @override
  SessionState? get memberSession =>
      ref.mounted ? ref.read(sessionViewModelProvider) : null;

  /// Satır menüsü (`MGT-03.menu.<id>`): SHT-21 → "Profili gör" (view'a
  /// döner) · "Rolü değiştir" (SHT-22 → DLG-20 → TST-46) · "Üyelikten
  /// çıkar" (DLG-19 → TST-47 "Geri al") — `ManageMemberActionsMixin`.
  Future<MemberMenuOutcome> openMemberMenu(MembershipModel membership) =>
      openMemberActions(clubId, membership, name: state.nameOf(membership));

  /// "Başkanlığı devret" (`MGT-03.transfer`; `?transfer=true` açılışı):
  /// danışman → TST-26; bütün sayfalar okunur → SHT-25 → DLG-21 ("DEVRET")
  /// → TST-49 (`ManageMemberActionsMixin.transferPresidency`; iyimser
  /// değil — geri alınamaz). Devredildiyse `true`.
  Future<bool> startTransfer() async {
    if (!ref.mounted || !ensureWritable() || !state.canTransfer) return false;
    final members = await transferCandidates();
    if (!ref.mounted) return false;
    return transferPresidency(
      clubId,
      members: members,
      fromUserId: state.presidentId,
    );
  }

  /// SHT-25 adayı: güncel kullanıcı belgesi → üyelikteki anlık görüntü.
  @override
  PresidentCandidate memberCandidateOf(MembershipModel membership) {
    final user = ref.mounted ? state.users[membership.userId] : null;
    if (user == null) return PresidentCandidate.fromMembership(membership);
    return PresidentCandidate(
      userId: membership.userId,
      name: user.name,
      avatarSeed: user.avatarSeed.isEmpty ? membership.userId : user.avatarSeed,
      department: user.department,
      year: user.year,
    );
  }

  @override
  Future<bool> removeMember(
    String clubId,
    MembershipModel membership, {
    required String name,
  }) async {
    final done = await super.removeMember(clubId, membership, name: name);
    if (done) _refreshPanel();
    return done;
  }

  @override
  Future<bool> undoMemberRemoval(
    String clubId,
    MembershipModel membership, {
    required String actorId,
  }) async {
    final done = await super.undoMemberRemoval(
      clubId,
      membership,
      actorId: actorId,
    );
    if (done) _refreshPanel();
    return done;
  }

  @override
  void onMemberRemoved(MembershipModel membership) {
    if (!ref.mounted) return;
    _put(remove: membership.userId);
    _bumpMemberCount(-1);
  }

  @override
  void onMemberRestored(MembershipModel membership) {
    if (!ref.mounted || state.find(membership.userId) != null) return;
    _put(insert: membership);
    _bumpMemberCount(1);
  }

  @override
  void onMemberRoleChanged(MembershipModel membership) {
    if (ref.mounted) _put(insert: membership);
  }

  /// Devir yazıldı: yeni başkan `president`, eski başkan `board`; aktör eski
  /// başkansa kendi rolü de yönetim kurulu olur (devir kartı kalkar).
  @override
  void onPresidencyTransferred(
    String clubId, {
    required String fromUserId,
    required String toUserId,
  }) {
    if (!ref.mounted) return;
    final target = state.find(toUserId);
    final previous = state.find(fromUserId);
    if (target != null) _put(insert: target.copyWith(role: ClubRole.president));
    if (previous != null) _put(insert: previous.copyWith(role: ClubRole.board));
    state = state.copyWith(
      club: state.club?.copyWith(presidentId: toUserId),
      role: memberActorId == fromUserId ? ClubRole.board : null,
    );
    _refreshPanel();
  }

  @override
  void onMemberListStale(String clubId) {
    if (ref.mounted) unawaited(refresh());
  }

  /// "Üye listesini dışa aktar (CSV)" (`MGT-03.export`): bütün sayfalar ve
  /// görünen satırların e-postaları (`readContact`, en çok
  /// [contactBatchSize] eşzamanlı) okunur → [MembersCsv] metni →
  /// `fileService.writeTemp` → `shareService.shareFile` → TST-29. Görünen
  /// liste (süzgeç, arama, sıralama) dışa aktarılır (prototip `list`).
  /// Paylaşım açıldıysa `true`.
  Future<bool> exportCsv(MembersCsvLabels labels) async {
    if (!ref.mounted || state.isExporting || !ensureWritable()) return false;
    state = state.copyWith(isExporting: true);
    try {
      if (!await loadAll()) {
        if (ref.mounted) feedback.showToast(ToastId.tst24);
        return false;
      }
      if (!ref.mounted) return false;
      final rows = state.visible;
      await _loadEmails([for (final m in rows) m.userId]);
      if (!ref.mounted) return false;
      final text = MembersCsv.build([
        for (final m in rows) _csvRow(m),
      ], labels);
      final path = await fileService.writeTemp(
        MembersCsv.fileName,
        MembersCsv.encode(text),
      );
      if (path == null) {
        AppLogger.warn('Üye listesi dosyası yazılamadı ($clubId)');
        return false;
      }
      final shared = await shareService.shareFile(
        path,
        mimeType: MembersCsv.mimeType,
      );
      if (shared && ref.mounted) feedback.showToast(ToastId.tst29);
      return shared;
    } finally {
      if (ref.mounted) state = state.copyWith(isExporting: false);
    }
  }

  // ─────────────────────────────── yardımcılar ──────────────────────────────

  MembersCsvRow _csvRow(MembershipModel m) {
    final user = state.users[m.userId];
    final applicant = m.applicant;
    return (
      name: state.nameOf(m),
      email: state.emails[m.userId] ?? '',
      department: user == null ? applicant.department : user.department,
      year: user == null ? applicant.year : user.year,
      role: m.role,
      joinedAt: ManageMembersState.joinedAt(m),
    );
  }

  /// [remove] kimlikli satırı bütün listelerden çıkarır; [insert] verilirse
  /// (aynı kimliğin eskisi çıkarılarak) rolüne göre listenin başına konur.
  void _put({String? remove, MembershipModel? insert}) {
    final id = remove ?? insert?.userId;
    if (id == null) return;
    List<MembershipModel> without(List<MembershipModel> list) => [
      for (final m in list)
        if (m.userId != id) m,
    ];
    final managers = without(state.managers);
    final advisors = without(state.advisors);
    final members = without(state.members);
    if (insert != null) {
      switch (insert.role) {
        case ClubRole.president || ClubRole.board:
          managers.insert(0, insert);
        case ClubRole.advisor:
          advisors.insert(0, insert);
        case ClubRole.member:
          members.insert(0, insert);
      }
    }
    state = state.copyWith(
      managers: managers,
      advisors: advisors,
      members: members,
    );
  }

  /// Kulüp üye sayacını yerelde [delta] kadar değiştirir ("{n} kişi"
  /// tahmini sunucu sayacıyla tutarlı kalsın).
  void _bumpMemberCount(int delta) {
    final club = state.club;
    if (club == null) return;
    state = state.copyWith(
      club: club.copyWith(memberCount: math.max(0, club.memberCount + delta)),
    );
  }

  /// MGT-01 paneli yaşıyorsa göstergeleri (toplam üye) içerik kalarak
  /// yenilenir.
  void _refreshPanel() {
    if (!ref.mounted) return;
    final panel = manageViewModelProvider(clubId);
    if (!ref.exists(panel)) return;
    unawaited(ref.read(panel.notifier).refresh());
  }

  Future<void> _startLoad() {
    final running = _loading;
    if (running != null) return running;
    final future = _load().whenComplete(() => _loading = null);
    return _loading = future;
  }

  /// İçeriği baştan okur ve ilk yüklemeyi / yenilemeyi bitirir.
  Future<void> _load() async {
    final loaded = await _read();
    if (!ref.mounted) return;
    if (loaded == null) {
      state = state.copyWith(
        isFetching: false,
        isRefreshing: false,
        isError: state.all.isEmpty,
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
      [
        ...loaded.managers,
        ...loaded.advisors,
        ...loaded.members.items,
      ],
      generation,
      reread: true,
    );
  }

  /// Kulüp, yöneticiler, danışmanlar ve sıradan üyelerin ilk sayfası.
  /// Üyelik okumalarından biri başarısızsa `null`; kulüp okunamazsa liste
  /// yine gösterilir.
  Future<_Loaded?> _read() async {
    final (club, managers, advisors, members) = await (
      clubRepository.getClub(clubId, forceRefresh: true),
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
      AppLogger.warn('Üye yönetimi: kulüp okunamadı: ${error.name}');
    }
    for (final (what, result) in [
      ('Yöneticiler', managers),
      ('Danışmanlar', advisors),
      ('Üyeler', members),
    ]) {
      if (result case FirebaseFailure(:final error, :final message)) {
        AppLogger.warn('$what okunamadı: ${error.name}', error: message);
        return null;
      }
    }
    return (
      club: club.dataOrNull,
      managers: managers.dataOrNull ?? const [],
      advisors: advisors.dataOrNull?.items ?? const [],
      members: members.dataOrNull ?? const PageResult(items: []),
    );
  }

  /// [cursor]'dan sonraki sıradan üye sayfası; okunduysa `true`.
  Future<bool> _readNext(PageCursor cursor, int generation) async {
    final result = await membershipRepository.listActiveMembers(
      clubId,
      PageRequest(after: cursor),
      role: ClubRole.member,
    );
    if (!ref.mounted || generation != _generation) return false;
    switch (result) {
      case FirebaseSuccess(:final data):
        final known = {for (final m in state.all) m.userId};
        final fresh = [
          for (final m in data.items)
            if (known.add(m.userId)) m,
        ];
        state = state.copyWith(
          members: [...state.members, ...fresh],
          cursor: data.next,
          clearCursor: data.next == null,
        );
        await _loadUsers(fresh, generation);
        return true;
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Üyelerin sonraki sayfası okunamadı: ${error.name}',
          error: message,
        );
        return false;
    }
  }

  /// [memberships] sahiplerinin güncel belgeleri; okunamazsa satırlar anlık
  /// görüntüyle kalır.
  Future<void> _loadUsers(
    List<MembershipModel> memberships,
    int generation, {
    bool reread = false,
  }) async {
    final missing = [
      for (final m in memberships)
        if (reread || !state.users.containsKey(m.userId)) m.userId,
    ];
    if (missing.isEmpty) return;
    final result = await userRepository.getUsers(missing, forceRefresh: true);
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

  /// [userIds] üyelerinin henüz okunmamış e-postaları, [contactBatchSize]'lık
  /// parçalarla; okunamayan boş kalır.
  Future<void> _loadEmails(List<String> userIds) async {
    final missing = [
      for (final id in userIds)
        if (!state.emails.containsKey(id)) id,
    ];
    for (var start = 0; start < missing.length; start += contactBatchSize) {
      final batch = missing.sublist(
        start,
        math.min(start + contactBatchSize, missing.length),
      );
      final results = await Future.wait([
        for (final id in batch) membershipRepository.readContact(clubId, id),
      ]);
      if (!ref.mounted) return;
      state = state.copyWith(
        emails: {
          ...state.emails,
          for (final (index, result) in results.indexed)
            batch[index]: result.dataOrNull?.email.trim() ?? '',
        },
      );
    }
  }
}
