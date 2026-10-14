import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/management/provider/manage_applications_state.dart';
import 'package:gu_kulupler/features/management/provider/manage_view_model.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/navigation/applications_tab.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'manage_applications_view_model.g.dart';

/// MGT-02 "Başvurular" ViewModel'i (PLAN §12.6; prototip `Applications`,
/// `screens-manage.js:43–51`). Kulüp başına ayrı örnek (family `clubId`).
///
/// | Sekme | Kaynak |
/// |---|---|
/// | Bekleyen | `membershipRepository.listPending` (20 + imleç) + sayfadaki her başvurunun `readContact` belgesi (not ön izlemesi, CD-137) |
/// | Onaylanan | `listActiveMembers` (20 + imleç), yalnızca karar verilmiş (`decidedAt`) üyeler |
/// | Reddedilen | `listByStatus(rejected)` gu_data'da yok → yalnızca bu oturumda reddedilenler (W-98) |
///
/// Sekme ilk seçildiğinde okunur. Kararlar iyimserdir: satır anında sekme
/// değiştirir, yazılamazsa geri gelir.
///
/// | İşlem | Sonuç | Geri bildirim |
/// |---|---|---|
/// | [approve] / [reject] | yazıldı | TST-27 / TST-28 + "Geri al" (6 sn; pencere 30 sn → [undoDecision]) |
/// | | `conflict` (başka yönetici karar vermiş) | satır listeden kalkar, liste yenilenir, DLG-18 |
/// | | başka hata | satır geri gelir; TST-24 · TST-X18 |
/// | [undoDecision] | yazıldı | TST-X17 |
/// | | pencere dolmuş | yazım yok (`blocked`) |
/// | [bulkApprove] / [bulkReject] | `BulkResult` | başarılılar TST-27 / TST-28 ("n başvuru", Geri al), çakışanlar DLG-18 + yenile, başarısızlar geri gelir |
/// | [openApplications] | yazıldı | TST-54 |
/// | [copyEmail] | panoya kopyalandı | TST-08 |
///
/// Danışman (Q-09) hiçbir yazımı yapamaz: TST-26 ([ensureWritable]).
/// Karar sonrası MGT-01 paneli (yaşıyorsa) içerik kalarak yenilenir (KPI /
/// bekleyen sayısı tutarlılığı).
///
/// Design: MGT-02, DLG-17, DLG-18
@riverpod
final class ManageApplicationsViewModel extends _$ManageApplicationsViewModel
    with ProjectDependencyMixin, WriteGuardMixin {
  /// Geri al penceresinin bitişinde kaydı düşüren zamanlayıcılar.
  final Map<String, Timer> _undoTimers = <String, Timer>{};

  /// Sekme başına okuma turu: eski turun geç gelen sonucu atılır.
  final Map<ApplicationsTab, int> _epochs = <ApplicationsTab, int>{};

  @override
  ManageApplicationsState build(String clubId) {
    ref
      ..listen(sessionViewModelProvider, (_, session) {
        final access = session.accessTo(clubId);
        final role = session.roleIn(clubId);
        if (access == state.access && role == state.role) return;
        state = state.copyWith(
          access: access,
          role: role,
          clearRole: role == null,
        );
      })
      ..onDispose(() {
        for (final timer in _undoTimers.values) {
          timer.cancel();
        }
        _undoTimers.clear();
      });
    unawaited(
      Future<void>.microtask(() => _load(ApplicationsTab.pending, club: true)),
    );
    final session = ref.read(sessionViewModelProvider);
    return ManageApplicationsState(
      access: session.accessTo(clubId),
      role: session.roleIn(clubId),
      isFetching: true,
    );
  }

  String? get _actorId => ref.read(sessionViewModelProvider).uid;

  // ───────────────────────────────── okuma ──────────────────────────────────

  /// "Yeniden dene": seçili sekmeyi iskeletle baştan okur.
  Future<void> fetch() async {
    if (!ref.mounted) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _load(state.tab, club: true);
  }

  /// Çek-yenile: seçili sekme ve kulüp yeniden okunur (içerik kalır); öteki
  /// sekmeler bir sonraki seçilişte okunur.
  Future<void> refresh() async {
    if (!ref.mounted || state.isRefreshing) return;
    if (!state.loadedTabs.contains(state.tab)) return fetch();
    state = state.copyWith(
      isRefreshing: true,
      loadedTabs: {state.tab},
    );
    await _load(state.tab, club: true);
  }

  /// Seçili sekmenin sonraki sayfası (liste sonuna yaklaşınca). Okunamazsa
  /// liste olduğu gibi kalır.
  Future<void> loadMore() async {
    final tab = state.tab;
    final cursor = state.cursors[tab];
    if (!ref.mounted ||
        cursor == null ||
        state.isLoadingMore ||
        state.isFetching ||
        state.isError) {
      return;
    }
    final epoch = _epochs[tab] ?? 0;
    state = state.copyWith(isLoadingMore: true);
    final result = await _readPage(tab, PageRequest(after: cursor));
    if (!ref.mounted) return;
    if (epoch != (_epochs[tab] ?? 0)) {
      state = state.copyWith(isLoadingMore: false);
      return;
    }
    switch (result) {
      case FirebaseSuccess(:final data):
        final known = {for (final m in state.itemsOf(tab)) m.userId};
        final fresh = [
          for (final m in _kept(tab, data.items))
            if (known.add(m.userId)) m,
        ];
        state = state.copyWith(
          lists: {
            ...state.lists,
            tab: [...state.itemsOf(tab), ...fresh],
          },
          cursors: _withCursor(tab, data.next),
          isLoadingMore: false,
        );
        await _loadDetails(tab, fresh);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Başvuruların sonraki sayfası okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isLoadingMore: false);
    }
  }

  /// [userId] başvuranının iletişim belgesi (SHT-19 e-posta + not); bir kez
  /// okunur, okunamazsa sheet "Not eklenmemiş" gösterir.
  Future<void> loadContact(String userId) async {
    if (!ref.mounted || state.contacts.containsKey(userId)) return;
    final result = await membershipRepository.readContact(clubId, userId);
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data?):
        state = state.copyWith(contacts: {...state.contacts, userId: data});
      case FirebaseSuccess():
        break;
      case FirebaseFailure(:final error):
        AppLogger.warn('Başvuru iletişim kaydı okunamadı: ${error.name}');
    }
  }

  /// SHT-19 e-posta satırı "Kopyala": başvuranın e-postası (D-29 —
  /// yalnızca yönetimin okuduğu `contact` belgesi) panoya → TST-08.
  Future<void> copyEmail(String userId) async {
    final email = state.contacts[userId]?.email.trim() ?? '';
    if (email.isEmpty) return;
    if (await shareService.copyText(email)) feedback.showToast(ToastId.tst08);
  }

  /// W-28 / SHT-19: [userId] başvurusu (listede yoksa tek okuma; bekleyense
  /// listeye eklenir). Başvuru yoksa ya da başvuranın hesabı silinmişse
  /// `null` (SHT-19 "Bu başvuru artık yok").
  Future<MembershipModel?> resolveApplication(String userId) async {
    final known = state.find(userId);
    if (known != null) return known;
    final result = await membershipRepository.getMembership(clubId, userId);
    final membership = result.dataOrNull;
    if (!ref.mounted ||
        membership == null ||
        state.isDeletedApplicant(membership)) {
      return null;
    }
    // Henüz okunmamış sayfadaki bekleyen başvuru listeye eklenir ki SHT-19
    // kararı (iyimser akış) onu bulsun.
    if (membership.status == MembershipStatus.pending &&
        state.find(userId) == null) {
      state = state.copyWith(
        lists: {
          ...state.lists,
          ApplicationsTab.pending: [
            membership,
            ...state.itemsOf(ApplicationsTab.pending),
          ],
        },
      );
    }
    return membership;
  }

  // ─────────────────────────────── gezinme ──────────────────────────────────

  /// Sekme (`MGT-02.tab.<id>`): seçim kipi kapanır; ilk seçilişte okunur.
  void setTab(ApplicationsTab tab) {
    if (!ref.mounted) return;
    final loaded = state.loadedTabs.contains(tab);
    state = state.copyWith(
      tab: tab,
      selecting: false,
      selectedIds: const {},
      isFetching: !loaded,
      isError: false,
    );
    if (!loaded) unawaited(_load(tab));
  }

  /// Arama alanı (`MGT-02.search`): ad, Türkçe küçük harfle süzülür.
  void setQuery(String query) {
    if (query == state.query) return;
    state = state.copyWith(query: query);
  }

  /// Sıralama (`MGT-02.sort`): en yeni ↔ en eski.
  void toggleSort() => state = state.copyWith(
    sort: state.sort == ApplicationSort.newest
        ? ApplicationSort.oldest
        : ApplicationSort.newest,
  );

  /// Satır seçimi (uzun basış / onay kutusu / seçim kipinde satır): seçim
  /// kipini açar ve [userId]'yi seçer ya da seçimini kaldırır.
  void toggleSelect(String userId) {
    final selected = {...state.selectedIds};
    if (!selected.remove(userId)) selected.add(userId);
    state = state.copyWith(selecting: true, selectedIds: selected);
  }

  /// "Hepsini seç" (`MGT-02.selectAll`): görünen satırların hepsi.
  void selectAll() => state = state.copyWith(
    selecting: true,
    selectedIds: state.visibleIds,
  );

  /// Seçim çubuğunu kapat (`MGT-02.cancelSelect`).
  void clearSelection() =>
      state = state.copyWith(selecting: false, selectedIds: const {});

  // ───────────────────────────────── yazma ──────────────────────────────────

  /// Danışman bakışında yazan eyleme dokunuldu → TST-26.
  void onReadOnlyTap() => feedback.showToast(ToastId.tst26);

  /// Yazan eylemden önce: danışmansa TST-26 ve `false`.
  bool ensureWritable() {
    if (!state.isReadOnly) return true;
    onReadOnlyTap();
    return false;
  }

  /// M5 — tek dokunuş onay (`MGT-02.approve.<id>`, SHT-19 "Onayla").
  Future<DecisionOutcome> approve(String userId) => _decide(userId);

  /// M6 — SHT-20'de seçilen [reason] ve [note] ile ret (`retryAfter`
  /// repository'de yazılır — 7 gün).
  Future<DecisionOutcome> reject(
    String userId,
    RejectReason reason,
    String note,
  ) => _decide(userId, reason: reason, note: note);

  /// M12 (a) — TST-27 / TST-28 "Geri al" ya da SHT-19 "Geri al": karar
  /// `Limits.managerUndoWindow` içindeyse başvuru yeniden beklemeye döner
  /// (TST-X17); pencere dolmuşsa hiçbir şey yazılmaz.
  Future<DecisionOutcome> undoDecision(String userId) => _undo([userId]);

  /// Seçili bekleyen başvuruların toplu onayı (`MGT-02.bulkApprove`): DLG-17
  /// onayı → `managementRepository.approveMany` (her başvuru ayrı işlem).
  /// Seçim boşsa, vazgeçildiyse ya da yazılamıyorsa `null`.
  Future<BulkResult?> bulkApprove() => _bulk();

  /// Toplu ret (`MGT-02.bulkReject`): DLG-17 onayı → `rejectMany` (prototip
  /// nedeni `quota`, `screens-manage.js:49`; SHT-20 açılmaz).
  Future<BulkResult?> bulkReject({RejectReason reason = RejectReason.quota}) =>
      _bulk(reason: reason);

  /// "Başvuruları aç" anahtarı (`MGT-02.toggleOpen`): kulübü başvurulara
  /// açar → TST-54.
  Future<bool> openApplications() async {
    final actorId = _actorId;
    if (actorId == null || !ensureWritable() || !ensureOnline()) return false;
    final result = await managementRepository.updateClubSettings(
      clubId,
      const ClubSettingsPatch(applicationsOpen: true),
      actorId: actorId,
    );
    if (!ref.mounted) return false;
    switch (result) {
      case FirebaseSuccess():
        final club = state.club;
        if (club != null) {
          state = state.copyWith(club: club.copyWith(applicationsOpen: true));
        }
        feedback.showToast(
          ToastId.tst54,
          params: const ToastParams(open: true),
        );
        return true;
      case FirebaseFailure(:final error):
        if (!showWriteFailureToast(error)) {
          AppLogger.warn('Başvurular açılamadı: ${error.name}');
        }
        return false;
    }
  }

  Future<DecisionOutcome> _decide(
    String userId, {
    RejectReason? reason,
    String note = '',
  }) async {
    final actorId = _actorId;
    final original = _pendingOf(userId);
    if (actorId == null || original == null) return DecisionOutcome.blocked;
    if (!ensureWritable() || !ensureOnline()) return DecisionOutcome.blocked;
    final approved = reason == null;
    final now = appClock.nowUtc();
    _apply([original], [_decided(original, actorId, now, reason, note)]);
    final result = approved
        ? await managementRepository.approveApplication(
            clubId: clubId,
            userId: userId,
            actorId: actorId,
          )
        : await managementRepository.rejectApplication(
            clubId: clubId,
            userId: userId,
            actorId: actorId,
            reason: reason,
            rejectNote: note,
          );
    if (!ref.mounted) return DecisionOutcome.failed;
    switch (result) {
      case FirebaseSuccess():
        _markUndoable([userId], now);
        feedback.showToast(
          approved ? ToastId.tst27 : ToastId.tst28,
          params: ToastParams(name: state.nameOf(original)),
          onAction: () => unawaited(undoDecision(userId)),
        );
        _refreshPanel();
        return DecisionOutcome.done;
      case FirebaseFailure(error: FirestoreError.conflict):
        _drop({userId});
        await _showConflict(userId);
        return DecisionOutcome.conflict;
      case FirebaseFailure(:final error):
        _restore([original]);
        _reportFailure(error, 'Başvuru kararı yazılamadı');
        return DecisionOutcome.failed;
    }
  }

  Future<DecisionOutcome> _undo(List<String> userIds) async {
    final actorId = _actorId;
    if (actorId == null || userIds.isEmpty) return DecisionOutcome.blocked;
    if (!ensureWritable() || !ensureOnline()) return DecisionOutcome.blocked;
    final now = appClock.nowUtc();
    final decided = [
      for (final id in userIds)
        if (state.find(id) case final m? when state.canUndo(m, actorId, now)) m,
    ];
    final expired = userIds.toSet().difference({
      for (final m in decided) m.userId,
    });
    if (expired.isNotEmpty) _forgetUndo(expired);
    if (decided.isEmpty) return DecisionOutcome.blocked;
    _restore(decided, reopen: true);
    final failed = <MembershipModel>[];
    FirestoreError? lastError;
    for (final m in decided) {
      final result = await managementRepository.undoDecision(
        clubId: clubId,
        userId: m.userId,
        actorId: actorId,
      );
      if (result case FirebaseFailure(:final error)) {
        failed.add(m);
        lastError = error;
      }
      if (!ref.mounted) return DecisionOutcome.failed;
    }
    _forgetUndo({for (final m in decided) m.userId});
    if (failed.length < decided.length) {
      feedback.showToast(ToastId.tstX17);
      _refreshPanel();
    }
    if (lastError == null) return DecisionOutcome.done;
    // Geri alınamayanlar (pencere sunucuda dolmuş, durum değişmiş): liste
    // sunucudan yeniden okunur.
    if (!showWriteFailureToast(lastError)) {
      AppLogger.warn('Karar geri alınamadı: ${lastError.name}');
    }
    _reinstate(failed);
    unawaited(refresh());
    return DecisionOutcome.failed;
  }

  Future<BulkResult?> _bulk({RejectReason? reason}) async {
    final actorId = _actorId;
    final originals = [
      for (final m in state.itemsOf(ApplicationsTab.pending))
        if (state.selectedIds.contains(m.userId) &&
            !state.isDeletedApplicant(m))
          m,
    ];
    if (actorId == null || originals.isEmpty) return null;
    if (!ensureWritable()) return null;
    final approved = reason == null;
    final confirmed = await feedback.showDialog<bool>(
      DialogId.dlg17,
      params: {
        DialogParamKeys.kind: approved
            ? BulkActionKind.approve
            : BulkActionKind.reject,
        DialogParamKeys.count: originals.length,
      },
    );
    if (confirmed != true || !ref.mounted || !ensureOnline()) return null;
    final now = appClock.nowUtc();
    final ids = [for (final m in originals) m.userId];
    _apply(originals, [
      for (final m in originals) _decided(m, actorId, now, reason, ''),
    ]);
    state = state.copyWith(selecting: false, selectedIds: const {});
    final result = approved
        ? await managementRepository.approveMany(
            clubId: clubId,
            userIds: ids,
            actorId: actorId,
          )
        : await managementRepository.rejectMany(
            clubId: clubId,
            userIds: ids,
            actorId: actorId,
            reason: reason,
          );
    if (!ref.mounted) return result.dataOrNull;
    switch (result) {
      case FirebaseSuccess(:final data):
        final failedIds = data.failed.toSet();
        _restore([
          for (final m in originals)
            if (failedIds.contains(m.userId)) m,
        ]);
        _drop(data.conflicted.toSet());
        if (data.succeeded.isNotEmpty) {
          final succeeded = [...data.succeeded];
          _markUndoable(succeeded, now);
          feedback.showToast(
            approved ? ToastId.tst27 : ToastId.tst28,
            params: ToastParams(applicants: succeeded.length),
            onAction: () => unawaited(_undo(succeeded)),
          );
          _refreshPanel();
        }
        if (data.conflicted.isNotEmpty) {
          await _showConflict(data.conflicted.first);
        } else if (data.failed.isNotEmpty && data.succeeded.isEmpty) {
          feedback.showToast(ToastId.tstX18);
        }
        return data;
      case FirebaseFailure(:final error):
        _restore(originals);
        _reportFailure(error, 'Toplu karar yazılamadı');
        return null;
    }
  }

  // ─────────────────────────────── yardımcılar ──────────────────────────────

  MembershipModel? _pendingOf(String userId) {
    for (final m in state.itemsOf(ApplicationsTab.pending)) {
      if (m.userId == userId && !state.isDeletedApplicant(m)) return m;
    }
    return null;
  }

  static MembershipModel _decided(
    MembershipModel m,
    String actorId,
    DateTime now,
    RejectReason? reason,
    String note,
  ) => reason == null
      ? m.copyWith(
          status: MembershipStatus.active,
          role: ClubRole.member,
          decidedAt: now,
          decidedBy: actorId,
        )
      : m.copyWith(
          status: MembershipStatus.rejected,
          decidedAt: now,
          decidedBy: actorId,
          rejectReason: reason,
          rejectNote: note,
          retryAfter: now.add(Limits.reapplyCooldown),
        );

  static ApplicationsTab _tabOf(MembershipModel m) => switch (m.status) {
    MembershipStatus.active => ApplicationsTab.approved,
    MembershipStatus.rejected => ApplicationsTab.rejected,
    _ => ApplicationsTab.pending,
  };

  /// İyimser karar: [originals] bekleyenlerden çıkar, [decided] karşılık
  /// gelen sekmenin başına eklenir.
  void _apply(List<MembershipModel> originals, List<MembershipModel> decided) {
    final ids = {for (final m in originals) m.userId};
    final lists = {
      for (final MapEntry(:key, :value) in state.lists.entries)
        key: [
          for (final m in value)
            if (!ids.contains(m.userId)) m,
        ],
    };
    for (final m in decided) {
      final tab = _tabOf(m);
      lists[tab] = [m, ...?lists[tab]];
    }
    state = state.copyWith(
      lists: lists,
      selectedIds: state.selectedIds.difference(ids),
    );
  }

  /// [items] yeniden bekleyenlere döner (yazılamayan karar; [reopen] →
  /// geri alınan karar, karar alanları boşaltılır).
  void _restore(List<MembershipModel> items, {bool reopen = false}) {
    if (items.isEmpty) return;
    _apply(items, [
      for (final m in items)
        reopen
            ? m.copyWith(
                status: MembershipStatus.pending,
                role: ClubRole.member,
                clearDecidedAt: true,
                clearDecidedBy: true,
                clearRetryAfter: true,
                clearRejectReason: true,
                clearRejectNote: true,
              )
            : m,
    ]);
  }

  /// Geri alınamayan kararlar eski sekmelerine döner.
  void _reinstate(List<MembershipModel> decided) {
    if (decided.isEmpty) return;
    _apply(decided, decided);
  }

  /// Çakışan başvurular bütün listelerden kalkar (sunucudaki durum
  /// yenilemeyle gelir).
  void _drop(Set<String> userIds) {
    if (userIds.isEmpty) return;
    state = state.copyWith(
      lists: {
        for (final MapEntry(:key, :value) in state.lists.entries)
          key: [
            for (final m in value)
              if (!userIds.contains(m.userId)) m,
          ],
      },
    );
  }

  /// DLG-18: liste yenilenir, sonra başka yöneticinin kararı gösterilir.
  Future<void> _showConflict(String userId) async {
    final (current, _) = await (
      membershipRepository.getMembership(clubId, userId),
      refresh(),
    ).wait;
    if (!ref.mounted) return;
    final status = current.dataOrNull?.status ?? MembershipStatus.rejected;
    await feedback.showDialog<bool>(
      DialogId.dlg18,
      params: {DialogParamKeys.result: status},
    );
  }

  void _reportFailure(FirestoreError error, String what) {
    if (showWriteFailureToast(error)) return;
    AppLogger.warn('$what: ${error.name}');
    unawaited(refresh());
  }

  void _markUndoable(List<String> userIds, DateTime decidedAt) {
    state = state.copyWith(
      undoable: {...state.undoable, for (final id in userIds) id: decidedAt},
    );
    for (final id in userIds) {
      _undoTimers.remove(id)?.cancel();
      _undoTimers[id] = Timer(
        Limits.managerUndoWindow,
        () => _forgetUndo({id}),
      );
    }
  }

  void _forgetUndo(Set<String> userIds) {
    for (final id in userIds) {
      _undoTimers.remove(id)?.cancel();
    }
    if (!ref.mounted || !userIds.any(state.undoable.containsKey)) return;
    state = state.copyWith(
      undoable: {
        for (final MapEntry(:key, :value) in state.undoable.entries)
          if (!userIds.contains(key)) key: value,
      },
    );
  }

  /// MGT-01 paneli yaşıyorsa göstergeleri (bekleyen, toplam üye) içerik
  /// kalarak yenilenir.
  void _refreshPanel() {
    final panel = manageViewModelProvider(clubId);
    if (!ref.exists(panel)) return;
    unawaited(ref.read(panel.notifier).refresh());
  }

  Future<FirestoreResult<PageResult<MembershipModel>>> _readPage(
    ApplicationsTab tab,
    PageRequest page,
  ) => switch (tab) {
    ApplicationsTab.pending => membershipRepository.listPending(clubId, page),
    ApplicationsTab.approved => membershipRepository.listActiveMembers(
      clubId,
      page,
    ),
    // TODO(T-33): `MembershipRepository.listByStatus(clubId, rejected, page)`
    // (PLAN §10.4; indeks `clubId, status, appliedAt↓` mevcut) gu_data'da
    // yok (W-98). O zamana dek sekme yalnızca bu oturumda reddedilenleri
    // gösterir.
    ApplicationsTab.rejected => Future.value(
      const FirebaseSuccess(PageResult<MembershipModel>(items: [])),
    ),
  };

  /// [tab] sekmesinde listelenecek kayıtlar: "Onaylanan" yalnızca karar
  /// verilmiş (başvurusu onaylanmış) üyeler (`actions.js` `approvedApps`).
  static List<MembershipModel> _kept(
    ApplicationsTab tab,
    List<MembershipModel> items,
  ) => switch (tab) {
    ApplicationsTab.approved => [
      for (final m in items)
        if (m.decidedAt != null && m.role != ClubRole.advisor) m,
    ],
    _ => items,
  };

  Map<ApplicationsTab, PageCursor> _withCursor(
    ApplicationsTab tab,
    PageCursor? next,
  ) => {
    for (final MapEntry(:key, :value) in state.cursors.entries)
      if (key != tab) key: value,
    tab: ?next,
  };

  /// [tab] sekmesinin ilk sayfasını (ve [club] ise kulübü) okur.
  Future<void> _load(ApplicationsTab tab, {bool club = false}) async {
    final epoch = (_epochs[tab] ?? 0) + 1;
    _epochs[tab] = epoch;
    final (clubResult, page) = await (
      club
          ? clubRepository.getClub(clubId)
          : Future<FirestoreResult<ClubModel>?>.value(),
      _readPage(tab, const PageRequest()),
    ).wait;
    if (!ref.mounted || _epochs[tab] != epoch) return;
    final current = state.tab == tab;
    if (clubResult case FirebaseFailure(:final error)) {
      AppLogger.warn('Başvurular: kulüp okunamadı: ${error.name}');
    }
    final clubModel = clubResult?.dataOrNull;
    switch (page) {
      case FirebaseSuccess(:final data):
        final kept = _kept(tab, data.items);
        // Okuma sürerken verilen iyimser kararlar kaybolmasın: bu sekmeye
        // taşınmış (henüz sunucu sayfasında olmayan) kayıtlar korunur.
        final ids = {for (final m in kept) m.userId};
        final local = [
          for (final m in state.itemsOf(tab))
            if (!ids.contains(m.userId) && state.undoable.containsKey(m.userId))
              m,
        ];
        state = state.copyWith(
          club: clubModel,
          lists: {
            ...state.lists,
            tab: [...local, ...kept],
          },
          cursors: _withCursor(tab, data.next),
          loadedTabs: {...state.loadedTabs, tab},
          isFetching: current ? false : null,
          isRefreshing: current ? false : null,
          isLoadingMore: current ? false : null,
          isError: current ? false : null,
        );
        await _loadDetails(tab, kept, reread: true);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn('Başvurular okunamadı: ${error.name}', error: message);
        state = state.copyWith(
          club: clubModel,
          isFetching: current ? false : null,
          isRefreshing: current ? false : null,
          isError: current && !state.loadedTabs.contains(tab) ? true : null,
        );
    }
  }

  /// [items] sahiplerinin güncel kullanıcı belgeleri ve (bekleyenlerde)
  /// iletişim belgeleri; okunamayanlar anlık görüntüyle / notsuz kalır.
  Future<void> _loadDetails(
    ApplicationsTab tab,
    List<MembershipModel> items, {
    bool reread = false,
  }) async {
    final userIds = [
      for (final m in items)
        if (reread || !state.users.containsKey(m.userId)) m.userId,
    ];
    final contactIds = tab == ApplicationsTab.pending
        ? [
            for (final m in items)
              if (reread || !state.contacts.containsKey(m.userId)) m.userId,
          ]
        : const <String>[];
    if (userIds.isEmpty && contactIds.isEmpty) return;
    final (users, contacts) = await (
      userIds.isEmpty
          ? Future<FirestoreResult<List<UserModel>>>.value(
              const FirebaseSuccess(<UserModel>[]),
            )
          : userRepository.getUsers(userIds),
      Future.wait([
        for (final id in contactIds)
          membershipRepository.readContact(clubId, id),
      ]),
    ).wait;
    if (!ref.mounted) return;
    final read = <String, MembershipContactModel>{
      for (final (index, result) in contacts.indexed)
        contactIds[index]: ?result.dataOrNull,
    };
    if (users case FirebaseFailure(:final error)) {
      AppLogger.warn('Başvuran profilleri okunamadı: ${error.name}');
    }
    state = state.copyWith(
      users: {
        ...state.users,
        for (final user in users.dataOrNull ?? const <UserModel>[])
          user.uid: user,
      },
      contacts: {...state.contacts, ...read},
    );
  }
}
