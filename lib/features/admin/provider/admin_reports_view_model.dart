import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/admin/provider/admin_reports_state.dart';
import 'package:gu_kulupler/features/admin/provider/report_group.dart';
import 'package:gu_kulupler/features/admin/provider/report_target_preview.dart';
import 'package:gu_kulupler/features/admin/view/widget/report_detail_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/navigation/admin_reports_tab.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'admin_reports_view_model.g.dart';

/// ADM-04 "Şikayetler" ViewModel'i (PLAN §12 `AdminReportsViewModel`;
/// prototip `Reports`, `screens-admin.js:61–66`) ve SHT-26 sahibi (PLAN
/// §4.5.2).
///
/// * Okuma: sekme başına `adminRepository.listReports(status, page)` (açık
///   sekme `listOpenReports` — CD-37), sayfalı ([loadMore]); satır
///   önizlemeleri toplu okunur (gönderi `getPost`, yorum `getComment` —
///   W-103, kullanıcı `getUsers`, kulüp `getClubs`, etkinlik `getEvents`;
///   silinmiş hedef → boş önizleme "İçerik kaldırıldı"). Gruplama ve hedef
///   türü süzgeci istemcidedir.
/// * SHT-26 ([openGroup]): grup listede yoksa (`?reportId=`) hedefin açık
///   şikayetleri `listReportsForTarget` ile okunur; hedef önizlemesi (yazar
///   dahil) ve şikayetçi profilleri okunur.
/// * Çözüm iyimserdir: grubun açık şikayetleri hemen "Çözüldü" sekmesine
///   geçer, yazım başarısızsa geri döner. `resolveReports` hedefin o anki
///   **tüm** açık şikayetlerini çözer ve her şikayetçiye `report_resolved`
///   üretir (T-37 §4 a.6). Askı ayrı çağrıdır ve çözümden **önce** yazılır
///   (CD-160): kullanıcı askısı DLG-30 → `suspendUser` + çözüm → TST-52;
///   kulüp askısı DLG-28 → `suspendClub` + çözüm → TST-50; içerik kaldırma
///   DLG-29 → `resolveReports(removed)` (gizleme aynı batch'te) → TST-51;
///   ihlal yok → `resolveReports(dismissed)` → TST-56.
/// * `permissionDenied` → claim sunucudan yenilenir
///   (`SessionViewModel.refreshClaims` — CD-160); süper admin hâlâ
///   geçerliyse çağrı bir kez yinelenir, değilse router guard'ı (`S`)
///   sekmeyi kapatır (yazımda TST-X18).
/// * Çevrimdışı yazım TST-24 (`WriteGuardMixin`).
///
/// Design: ADM-04, DLG-29
@riverpod
final class AdminReportsViewModel extends _$AdminReportsViewModel
    with ProjectDependencyMixin, WriteGuardMixin {
  /// Sekme başına okuma turu sayacı: eski turun geç gelen sonucu atılır.
  final Map<AdminReportsTab, int> _epochs = {
    for (final tab in AdminReportsTab.values) tab: 0,
  };

  @override
  AdminReportsState build() {
    unawaited(Future<void>.microtask(() => _load(AdminReportsTab.open)));
    return const AdminReportsState(isFetching: true);
  }

  /// "Yeniden dene" (`ADM-04.retry`): seçili sekmeyi iskeletle baştan okur.
  Future<void> fetch() async {
    if (!ref.mounted) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _load(state.tab);
  }

  /// Çek-yenile: içerik kalır, seçili sekme yeniden okunur.
  Future<void> refresh() async {
    if (!ref.mounted || state.isRefreshing) return;
    if (!state.isLoaded) return fetch();
    state = state.copyWith(isRefreshing: true);
    await _load(state.tab);
  }

  /// Seçili sekmenin sonraki sayfası (liste sonuna yaklaşınca).
  Future<void> loadMore() async {
    final tab = state.tab;
    final cursor = state.cursors[tab];
    if (!ref.mounted ||
        cursor == null ||
        state.isLoadingMore ||
        state.isFetching ||
        !state.isLoaded) {
      return;
    }
    final epoch = _epochs[tab];
    state = state.copyWith(isLoadingMore: true);
    final result = await _withClaims(
      () => _list(tab, PageRequest(after: cursor)),
    );
    if (!ref.mounted) return;
    if (epoch != _epochs[tab]) {
      state = state.copyWith(isLoadingMore: false);
      return;
    }
    switch (result) {
      case FirebaseSuccess(:final data):
        final known = {for (final r in state.reportsOf(tab)) r.id};
        final added = [
          for (final report in data.items)
            if (!known.contains(report.id)) report,
        ];
        final merged = [...state.reportsOf(tab), ...added];
        final fresh = [
          for (final group in ReportGroup.groupOf(added))
            if (!state.previews.containsKey(group.key)) group,
        ];
        final previews = await _readPreviews(fresh);
        if (!ref.mounted) return;
        state = _withReports(tab, merged).copyWith(
          cursors: _cursorsWith(tab, data.next),
          previews: {...state.previews, ...previews},
          isLoadingMore: false,
        );
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Şikayetlerin sonraki sayfası okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Sekme (`ADM-04.tab.<name>`); ilk kez açılan sekme okunur.
  void setTab(AdminReportsTab tab) {
    if (tab == state.tab) return;
    final loaded = state.loadedTabs.contains(tab);
    state = state.copyWith(
      tab: tab,
      isFetching: !loaded,
      isRefreshing: false,
      isLoadingMore: false,
      isError: false,
    );
    if (!loaded) unawaited(_load(tab));
  }

  /// Hedef türü süzgeci (`ADM-04.filter.<name>`).
  void setTypeFilter(ReportTargetFilter filter) {
    if (filter == state.typeFilter) return;
    state = state.copyWith(typeFilter: filter);
  }

  // ───────────────────────────────── SHT-26 ─────────────────────────────────

  /// SHT-26'yı [key] grubu için hazırlar ve grubu döndürür (önizleme ve
  /// şikayetçiler arkadan okunur). Grup listede yoksa (`?reportId=`) hedefin
  /// açık şikayetleri okunur; yoksa / okunamazsa `null`.
  Future<ReportGroup?> openGroup(String key) async {
    if (!ref.mounted) return null;
    final group = state.groupByKey(key) ?? await _readGroup(key);
    if (group == null || !ref.mounted) return null;
    state = state.copyWith(
      openGroupKey: group.key,
      detailGroup: group,
      clearTargetPreview: true,
    );
    unawaited(_readDetail(group));
    return group;
  }

  /// SHT-26 kapandı: açık grup bilgisi temizlenir ([key] hâlâ açıksa).
  void closeGroup(String key) {
    if (!ref.mounted || state.openGroupKey != key) return;
    state = state.copyWith(
      clearOpenGroupKey: true,
      clearDetailGroup: true,
      clearTargetPreview: true,
    );
  }

  // ───────────────────────────────── çözüm ──────────────────────────────────

  /// SHT-26 "Şikayeti kapat" — ihlal yok: [key] grubu `dismissed` ile
  /// çözülür (iyimser; başarı → TST-56). Yazıldıysa `true`.
  Future<bool> dismiss(String key) => _resolve(
    key,
    pending: ReportDetailAction.dismiss,
    action: ReportAction.dismissed,
    toast: ToastId.tst56,
  );

  /// DLG-29 "Kaldır" — [key] grubunun hedef gönderisi / yorumu gizlenir ve
  /// grup `removed` ile çözülür (tek batch; iyimser; başarı → TST-51).
  /// Yazıldıysa `true`.
  Future<bool> removeContent(String key) {
    final group = state.groupByKey(key);
    if (group == null ||
        (group.targetType != ReportTargetType.post &&
            group.targetType != ReportTargetType.comment)) {
      return Future.value(false);
    }
    return _resolve(
      key,
      pending: ReportDetailAction.removeContent,
      action: ReportAction.removed,
      toast: ToastId.tst51,
    );
  }

  /// DLG-30 "Askıya al" — [userId] hesabı [reason] gerekçesiyle askıya
  /// alınır, ardından [key] grubu `suspended` ile çözülür (iyimser; başarı
  /// → TST-52). Yazıldıysa `true`.
  Future<bool> suspendUser(
    String key, {
    required String userId,
    required String reason,
  }) {
    final trimmed = reason.trim();
    return _resolve(
      key,
      pending: ReportDetailAction.suspendUser,
      action: ReportAction.suspended,
      toast: ToastId.tst52,
      params: const ToastParams(suspended: true),
      before: (_) => adminRepository.suspendUser(userId, reason: trimmed),
    );
  }

  /// DLG-28 "Askıya al" — kulüp hedefi [reason] gerekçesiyle askıya alınır,
  /// ardından [key] grubu `suspended` ile çözülür (iyimser; başarı →
  /// TST-50). Yazıldıysa `true`.
  Future<bool> suspendClub(String key, {required String reason}) {
    final group = state.groupByKey(key);
    if (group == null || group.targetType != ReportTargetType.club) {
      return Future.value(false);
    }
    final trimmed = reason.trim();
    return _resolve(
      key,
      pending: ReportDetailAction.suspendClub,
      action: ReportAction.suspended,
      toast: ToastId.tst50,
      params: const ToastParams(suspended: true),
      before: (g) => adminRepository.suspendClub(g.targetId, reason: trimmed),
    );
  }

  Future<bool> _resolve(
    String key, {
    required ReportDetailAction pending,
    required ReportAction action,
    required ToastId toast,
    ToastParams params = const ToastParams(),
    Future<FirestoreResult<void>> Function(ReportGroup group)? before,
  }) async {
    final group = state.groupByKey(key);
    final actorId = ref.read(sessionViewModelProvider).uid;
    if (group == null ||
        !group.isOpen ||
        actorId == null ||
        state.pendingActions.containsKey(key)) {
      return false;
    }
    if (!ensureOnline()) return false;
    _applyResolved(group, action, actorId);
    state = state.copyWith(
      pendingActions: {...state.pendingActions, key: pending},
    );
    if (before != null) {
      final first = await _withClaims(() => before(group));
      if (!ref.mounted) return false;
      if (first case FirebaseFailure(:final error, :final message)) {
        _rollback(group);
        _onWriteFailure(error, message, 'Askı yazılamadı');
        return false;
      }
    }
    final result = await _withClaims(
      () => adminRepository.resolveReports(
        reportIds: group.openReportIds,
        action: action,
        actorId: actorId,
        target: (
          type: group.targetType,
          id: group.targetId,
          clubId: group.targetClubId,
        ),
      ),
    );
    if (!ref.mounted) return false;
    switch (result) {
      case FirebaseSuccess():
        state = state.copyWith(
          pendingActions: {...state.pendingActions}..remove(key),
        );
        feedback.showToast(toast, params: params);
        return true;
      case FirebaseFailure(:final error, :final message):
        _rollback(group);
        _onWriteFailure(error, message, 'Şikayet çözülemedi');
        return false;
    }
  }

  /// İyimser çözüm: grubun açık şikayetleri açık listeden çıkar, çözülmüş
  /// sekme okunmuşsa başına eklenir.
  void _applyResolved(ReportGroup group, ReportAction action, String actorId) {
    final ids = group.openReportIds.toSet();
    final now = appClock.nowUtc();
    final resolved = [
      for (final report in group.reports)
        if (ids.contains(report.id))
          report.copyWith(
            status: ReportStatus.resolved,
            action: action,
            resolvedAt: now,
            resolvedBy: actorId,
          ),
    ];
    state = state.copyWith(
      openReports: [
        for (final report in state.openReports)
          if (!ids.contains(report.id)) report,
      ],
      resolvedReports: state.loadedTabs.contains(AdminReportsTab.resolved)
          ? [
              ...resolved,
              for (final report in state.resolvedReports)
                if (!ids.contains(report.id)) report,
            ]
          : null,
    );
  }

  /// İyimser çözümün geri alınması: açık şikayetler listeye döner, çözülmüş
  /// kopyaları çıkar; bekleyen eylem temizlenir.
  void _rollback(ReportGroup group) {
    final ids = group.openReportIds.toSet();
    state = state.copyWith(
      openReports: [
        for (final report in state.openReports)
          if (!ids.contains(report.id)) report,
        for (final report in group.reports)
          if (ids.contains(report.id)) report,
      ],
      resolvedReports: [
        for (final report in state.resolvedReports)
          if (!ids.contains(report.id)) report,
      ],
      pendingActions: {...state.pendingActions}..remove(group.key),
    );
  }

  /// Yazma hatası: ağ TST-24 · yetki TST-X18; durum çakışması (başka süper
  /// admin çözdü) ya da kayıp belge → liste yenilenir; kalanı günlüğe.
  void _onWriteFailure(FirestoreError error, String? message, String what) {
    if (showWriteFailureToast(error)) return;
    AppLogger.warn('$what: ${error.name}', error: message);
    if (error == FirestoreError.conflict ||
        error == FirestoreError.notFound ||
        error == FirestoreError.ruleViolation) {
      unawaited(refresh());
    }
  }

  // ───────────────────────────────── okuma ──────────────────────────────────

  Future<FirestoreResult<PageResult<ReportModel>>> _list(
    AdminReportsTab tab,
    PageRequest page,
  ) => switch (tab) {
    AdminReportsTab.open => adminRepository.listOpenReports(page),
    AdminReportsTab.resolved => adminRepository.listReports(
      ReportStatus.resolved,
      page,
    ),
  };

  Future<void> _load(AdminReportsTab tab) async {
    final epoch = _epochs[tab] = _epochs[tab]! + 1;
    final result = await _withClaims(() => _list(tab, const PageRequest()));
    if (!_live(tab, epoch)) return;
    final current = tab == state.tab;
    switch (result) {
      case FirebaseSuccess(:final data):
        // Çözümü süren grubun iyimser hâli korunur.
        final pending = state.pendingActions;
        final reports = [
          for (final report in data.items)
            if (tab != AdminReportsTab.open ||
                !pending.containsKey(
                  FirestoreIds.reportGroupKey(
                    report.targetType.json,
                    report.targetId,
                  ),
                ))
              report,
        ];
        final previews = await _readPreviews(ReportGroup.groupOf(reports));
        if (!_live(tab, epoch)) return;
        final next = _withReports(tab, reports).copyWith(
          cursors: _cursorsWith(tab, data.next),
          previews: {...state.previews, ...previews},
          loadedTabs: {...state.loadedTabs, tab},
        );
        state = current
            ? next.copyWith(
                isFetching: false,
                isRefreshing: false,
                isError: false,
              )
            : next;
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Şikayetler okunamadı (${tab.name}): ${error.name}',
          error: message,
        );
        if (!current) return;
        // Çek-yenilemede eski içerik kalır; ilk açılışta hata görünümü.
        state = state.copyWith(
          isFetching: false,
          isRefreshing: false,
          isError: !state.isLoaded || state.isFetching,
        );
    }
  }

  AdminReportsState _withReports(
    AdminReportsTab tab,
    List<ReportModel> reports,
  ) => switch (tab) {
    AdminReportsTab.open => state.copyWith(openReports: reports),
    AdminReportsTab.resolved => state.copyWith(resolvedReports: reports),
  };

  Map<AdminReportsTab, PageCursor> _cursorsWith(
    AdminReportsTab tab,
    PageCursor? next,
  ) => {
    for (final entry in state.cursors.entries)
      if (entry.key != tab) entry.key: entry.value,
    tab: ?next,
  };

  /// [key] (`{targetType}_{targetId}`) hedefinin açık şikayetleri → grup;
  /// anahtar geçersizse, açık şikayet yoksa ya da okunamazsa `null`.
  Future<ReportGroup?> _readGroup(String key) async {
    final split = key.indexOf('_');
    if (split <= 0 || split == key.length - 1) return null;
    final prefix = key.substring(0, split);
    final type = ReportTargetType.values
        .where((value) => value.json == prefix)
        .firstOrNull;
    if (type == null) return null;
    final result = await _withClaims(
      () => adminRepository.listReportsForTarget(
        type: type,
        targetId: key.substring(split + 1),
      ),
    );
    switch (result) {
      case FirebaseSuccess(:final data):
        final groups = ReportGroup.groupOf(data);
        return groups.isEmpty ? null : groups.first;
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Şikayet grubu okunamadı ($key): ${error.name}',
          error: message,
        );
        return null;
    }
  }

  /// SHT-26 önizlemesi (yazar dahil) ve şikayetçi profilleri.
  Future<void> _readDetail(ReportGroup group) async {
    final key = group.key;
    final missing = [
      for (final uid in group.reporterIds)
        if (!state.reporters.containsKey(uid)) uid,
    ];
    final (preview, reporters) = await (
      _readTarget(group),
      missing.isEmpty
          ? Future.value(const <UserModel>[])
          : userRepository
                .getUsers(missing)
                .then((result) => result.dataOrNull ?? const <UserModel>[]),
    ).wait;
    if (!ref.mounted || state.openGroupKey != key) return;
    state = state.copyWith(
      targetPreview: preview,
      previews: {...state.previews, key: preview},
      reporters: {
        ...state.reporters,
        for (final user in reporters) user.uid: user,
      },
    );
  }

  /// Tek hedefin önizlemesi; okunamazsa satır önizlemesi, o da yoksa boş
  /// (silinmiş) önizleme.
  Future<ReportTargetPreview> _readTarget(ReportGroup group) async {
    final fallback = state.previews[group.key] ?? const ReportTargetPreview();
    final id = group.targetId;
    switch (group.targetType) {
      case ReportTargetType.post:
        switch (await postRepository.getPost(id)) {
          case FirebaseSuccess(:final data):
            // Yazar ve gönderinin kulübü (`PostCard` başlığı) birlikte.
            final (author, club) = await (
              userRepository.getUser(data.authorId),
              clubRepository.getClub(data.clubId),
            ).wait;
            return ReportTargetPreview(
              post: data,
              author: author.dataOrNull,
              club: club.dataOrNull,
            );
          case FirebaseFailure(:final error):
            return _gone(error) ? const ReportTargetPreview() : fallback;
        }
      case ReportTargetType.comment:
        // W-103: yorum metni + yazarı (SHT-26 önizlemesi; "Kullanıcıyı askıya
        // al" yazarın uid'si üzerinden — `suspendableUserId`).
        switch (await commentRepository.getComment(id)) {
          case FirebaseSuccess(:final data):
            final author = await userRepository.getUser(data.authorId);
            return ReportTargetPreview(
              comment: data,
              author: author.dataOrNull,
            );
          case FirebaseFailure(:final error):
            return _gone(error) ? const ReportTargetPreview() : fallback;
        }
      case ReportTargetType.user:
        return switch (await userRepository.getUser(id)) {
          FirebaseSuccess(:final data) => ReportTargetPreview(user: data),
          FirebaseFailure() => fallback,
        };
      case ReportTargetType.club:
        return switch (await clubRepository.getClub(id)) {
          FirebaseSuccess(:final data) => ReportTargetPreview(club: data),
          FirebaseFailure(:final error) =>
            _gone(error) ? const ReportTargetPreview() : fallback,
        };
      case ReportTargetType.event:
        return switch (await eventRepository.getEvent(id)) {
          FirebaseSuccess(:final data) => ReportTargetPreview(event: data),
          FirebaseFailure(:final error) =>
            _gone(error) ? const ReportTargetPreview() : fallback,
        };
    }
  }

  /// Satır önizlemeleri (toplu): okunamayan hedefin kaydı yoktur.
  Future<Map<String, ReportTargetPreview>> _readPreviews(
    List<ReportGroup> groups,
  ) async {
    final ids = <ReportTargetType, List<String>>{};
    for (final group in groups) {
      ids.putIfAbsent(group.targetType, () => []).add(group.targetId);
    }
    final parts = await Future.wait([
      _readPosts(ids[ReportTargetType.post] ?? const []),
      _readComments(ids[ReportTargetType.comment] ?? const []),
      _readMany<UserModel>(
        ReportTargetType.user,
        ids[ReportTargetType.user] ?? const [],
        userRepository.getUsers,
        (user) => user.uid,
        (user) => ReportTargetPreview(user: user),
      ),
      _readMany<ClubModel>(
        ReportTargetType.club,
        ids[ReportTargetType.club] ?? const [],
        clubRepository.getClubs,
        (club) => club.id,
        (club) => ReportTargetPreview(club: club),
      ),
      _readMany<EventModel>(
        ReportTargetType.event,
        ids[ReportTargetType.event] ?? const [],
        eventRepository.getEvents,
        (event) => event.id,
        (event) => ReportTargetPreview(event: event),
      ),
    ]);
    return {for (final part in parts) ...part};
  }

  Future<Map<String, ReportTargetPreview>> _readPosts(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final results = await Future.wait([
      for (final id in ids) postRepository.getPost(id),
    ]);
    return {
      for (var i = 0; i < ids.length; i++)
        _keyOf(ReportTargetType.post, ids[i]): ?switch (results[i]) {
          FirebaseSuccess(:final data) => ReportTargetPreview(post: data),
          FirebaseFailure(:final error) when _gone(error) =>
            const ReportTargetPreview(),
          FirebaseFailure() => null,
        },
    };
  }

  /// Yorum satırı önizlemeleri (W-103; ADM-04 satır başlığı yorum metni —
  /// tek satır, taşan kısım kısaltılır). Yazar SHT-26'da okunur.
  Future<Map<String, ReportTargetPreview>> _readComments(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    final results = await Future.wait([
      for (final id in ids) commentRepository.getComment(id),
    ]);
    return {
      for (var i = 0; i < ids.length; i++)
        _keyOf(ReportTargetType.comment, ids[i]): ?switch (results[i]) {
          FirebaseSuccess(:final data) => ReportTargetPreview(comment: data),
          FirebaseFailure(:final error) when _gone(error) =>
            const ReportTargetPreview(),
          FirebaseFailure() => null,
        },
    };
  }

  /// Toplu okuma: dönmeyen kimlik silinmiş sayılır; okuma başarısızsa boş.
  Future<Map<String, ReportTargetPreview>> _readMany<T>(
    ReportTargetType type,
    List<String> ids,
    Future<FirestoreResult<List<T>>> Function(List<String> ids) read,
    String Function(T item) idOf,
    ReportTargetPreview Function(T item) previewOf,
  ) async {
    if (ids.isEmpty) return const {};
    switch (await read(ids)) {
      case FirebaseSuccess(:final data):
        final byId = {for (final item in data) idOf(item): item};
        return {
          for (final id in ids)
            _keyOf(type, id): switch (byId[id]) {
              final item? => previewOf(item),
              null => const ReportTargetPreview(),
            },
        };
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Şikayet hedefleri okunamadı (${type.json}): ${error.name}',
          error: message,
        );
        return const {};
    }
  }

  static String _keyOf(ReportTargetType type, String id) =>
      FirestoreIds.reportGroupKey(type.json, id);

  /// Hedef yok / silinmiş (süper admin gizli belgeyi okur; olmayan belge
  /// Rules'ta `permissionDenied` döner — `PostRepository.getPost`).
  static bool _gone(FirestoreError error) =>
      error == FirestoreError.notFound ||
      error == FirestoreError.permissionDenied;

  /// [call]'ı koşar; `permissionDenied` alınırsa claim'i yeniler ve süper
  /// admin hâlâ geçerliyse bir kez yineler (CD-160).
  Future<FirestoreResult<T>> _withClaims<T>(
    Future<FirestoreResult<T>> Function() call,
  ) async {
    final result = await call();
    if (result.errorOrNull != FirestoreError.permissionDenied || !ref.mounted) {
      return result;
    }
    final session = ref.read(sessionViewModelProvider.notifier);
    await session.refreshClaims();
    if (!ref.mounted || !ref.read(sessionViewModelProvider).isSuperAdmin) {
      return result;
    }
    return call();
  }

  bool _live(AdminReportsTab tab, int epoch) =>
      ref.mounted && epoch == _epochs[tab];
}
