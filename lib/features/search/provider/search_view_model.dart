import 'dart:async';
import 'dart:ui' show VoidCallback;

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/search/provider/search_scope.dart';
import 'package:gu_kulupler/features/search/provider/search_state.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/club_join_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_ui/gu_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_view_model.g.dart';

/// CLB-02 "Arama" ekranının ViewModel'i (rota başına bir örnek: `initialScope`
/// = rotanın başlangıç sekmesi; PLAN §12.6, prototip `S['CLB-02']`,
/// `screens-clubs.js:37–55`).
///
/// * Arama istemci tarafındadır: havuz ([loadPools]) açılışta bir kez okunur,
///   sorgu `Limits.searchDebounce` (250 ms) sonra havuzda aranır. Eşleşme
///   Türkçe küçük harfle (`trLower`, CD-11): kulüpte ad + özet + tanıtım +
///   kategori adı, etkinlikte başlık + açıklama + serbest metin mekân.
/// * Son aramalar cihazda tutulur (`AppPreferencesStore.recentSearches`);
///   yazım hatası kullanıcıya gösterilmez, günlüğe düşer.
/// * Sheet açma ve gezinme view'dadır; [join] hangisinin gerektiğini sonuç
///   değeriyle söyler.
///
/// | İşlem | Sonuç | Geri bildirim |
/// |---|---|---|
/// | [clearRecent] | liste boşalır | TST-06 ("Geri al" → [undoClearRecent]) |
/// | [join] | katıldı | TST-34 ("Kulübe git") |
/// | | kapalı · bekleme · başvuru gerekli | TST-X1 · view → CLB-05 · view → SHT-05 |
/// | | çevrimdışı / ağ · yetki yok | TST-24 · TST-X18 |
///
/// Design: CLB-02
@riverpod
final class SearchViewModel extends _$SearchViewModel
    with ProjectDependencyMixin, WriteGuardMixin, ClubJoinMixin {
  /// "Sizin için önerilen kulüpler" sayısı (`screens-clubs.js:41`
  /// `slice(0, 3)`).
  static const int suggestedMax = 3;

  /// Aranan alanların birleştirme ayracı.
  static const String _fieldSeparator = ' ';

  Timer? _debounce;
  bool _isLoading = false;
  Map<String, String> _categoryLabels = const <String, String>{};

  @override
  SearchState build(SearchScope initialScope) {
    ref.onDispose(() => _debounce?.cancel());
    // Havuz ilk karede okunmaya başlar; view ayrıca çağırmaz.
    unawaited(Future<void>.microtask(_load));
    return SearchState(
      scope: initialScope,
      recent: appPreferencesStore.recentSearches,
      popular: StaticTables.popularSearches,
      isFetching: true,
    );
  }

  /// Arama havuzlarını yeniden okur — hata görünümündeki "Yeniden dene".
  /// Süren okuma varken gelen çağrı yok sayılır.
  Future<void> loadPools() async {
    if (!ref.mounted || _isLoading) return;
    state = state.copyWith(isFetching: true, isError: false);
    await _load();
  }

  /// Kategori adları (`k01` → "Teknoloji"), ekranın dilinde. Kulüp araması
  /// kategori adını da tarar; adlar ARB'dedir, bu yüzden view verir (açılışta
  /// ve dil değişince).
  void setCategoryLabels(Map<String, String> labels) {
    _categoryLabels = labels;
    if (!ref.mounted || !state.hasTerm || state.isSearching) return;
    _search();
  }

  /// Arama alanındaki metin değişti (`CLB-02.input`, son arama / popüler
  /// arama çipi). Terim boşsa varsayılan görünüme hemen dönülür; doluysa
  /// sonuçlar `Limits.searchDebounce` sonra hesaplanır.
  void setQuery(String q) {
    if (q == state.query) return;
    final previousTerm = state.searchTerm;
    final term = q.trim();
    if (term.isEmpty) {
      _debounce?.cancel();
      state = state.copyWith(
        query: q,
        isSearching: false,
        clubResults: const [],
        eventResults: const [],
      );
      return;
    }
    if (term == previousTerm && !state.isSearching) {
      // Yalnızca baştaki / sondaki boşluk değişti: sonuçlar aynı.
      state = state.copyWith(query: q);
      return;
    }
    _debounce?.cancel();
    state = state.copyWith(query: q, isSearching: true);
    _debounce = Timer(Limits.searchDebounce, _search);
  }

  /// Sonuç sekmesi değişti (`CLB-02.tab.clubs` / `.tab.events`).
  void setScope(SearchScope scope) {
    if (scope == state.scope) return;
    state = state.copyWith(scope: scope);
  }

  /// [term] aramasını son aramaların başına yazar (klavyede "Ara", sonuca
  /// dokunma — `screens-clubs.js:44`). Aynı terim (Türkçe harf duyarsız)
  /// listede varsa öne taşınır; liste `Limits.recentSearchesMax`'te kesilir.
  Future<void> commitRecent(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return;
    final lower = trimmed.trLower();
    final next = [
      trimmed,
      for (final recent in state.recent)
        if (recent.trLower() != lower) recent,
    ].take(Limits.recentSearchesMax).toList(growable: false);
    state = state.copyWith(recent: next);
    await _persistRecent(next);
  }

  /// [term] son aramasını listeden çıkarır (`CLB-02.removeRecent.<i>`).
  Future<void> removeRecent(String term) async {
    if (!state.recent.contains(term)) return;
    final next = [
      for (final recent in state.recent)
        if (recent != term) recent,
    ];
    state = state.copyWith(recent: next);
    await _persistRecent(next);
  }

  /// "Temizle" (`CLB-02.clearRecent`): son aramalar boşalır, TST-06
  /// gösterilir; "Geri al" 6 sn içinde listeyi geri getirir
  /// ([undoClearRecent]).
  Future<void> clearRecent() async {
    final previous = state.recent;
    if (previous.isEmpty) return;
    state = state.copyWith(recent: const [], recentBackup: previous);
    feedback.showToast(
      ToastId.tst06,
      onAction: () => unawaited(undoClearRecent()),
    );
    await _persistRecent(const []);
  }

  /// TST-06 "Geri al": temizlenen son aramaları geri yazar.
  Future<void> undoClearRecent() async {
    if (!ref.mounted) return;
    final backup = state.recentBackup;
    if (backup.isEmpty) return;
    state = state.copyWith(recent: backup, recentBackup: const []);
    await _persistRecent(backup);
  }

  /// "Katıl" (`CLB-02.join.<clubId>`): katılım akışının girişi
  /// (`ClubJoinMixin.joinGate`). Başvurular kapalı → TST-X1; bekleme sürüyor
  /// → [JoinOutcome.waiting] (view CLB-05'e gider); kulüp onay istiyor ya da
  /// kullanıcının eski kaydı var → [JoinOutcome.needsApplication]; aksi
  /// halde kulübe doğrudan katılınır (TST-34) ve üye sayısı bir artar.
  ///
  /// [formatDate] TST-X4'ün `{date}` metnini üretir; [onOpenClub] TST-34'ün
  /// "Kulübe git" eylemidir. Aynı kulüpte süren katılım varken gelen çağrı
  /// yok sayılır.
  Future<JoinOutcome> join(
    String clubId, {
    required String Function(DateTime retryAfter) formatDate,
    VoidCallback? onOpenClub,
  }) async {
    final club = _clubOf(clubId);
    if (club == null ||
        club.isSuspended ||
        state.pendingJoinIds.contains(clubId)) {
      return JoinOutcome.failed;
    }
    final session = ref.read(sessionViewModelProvider);
    final membership = session.memberships[clubId];
    if (joinGate(club, membership) case final outcome?) return outcome;
    if (!ensureOnline()) return JoinOutcome.failed;
    final applicant = session.user;
    final email = authRepository.currentUser?.email;
    if (applicant == null || email == null) {
      AppLogger.warn('Kulübe katılınamadı: oturumda profil / e-posta yok');
      return JoinOutcome.failed;
    }

    state = state.copyWith(pendingJoinIds: {...state.pendingJoinIds, clubId});
    final result = await membershipRepository.joinInstant(
      clubId: clubId,
      applicant: applicant,
      email: email,
    );
    if (!ref.mounted) {
      return result.isSuccess ? JoinOutcome.joined : JoinOutcome.failed;
    }
    state = state.copyWith(
      pendingJoinIds: {...state.pendingJoinIds}..remove(clubId),
    );
    switch (result) {
      case FirebaseSuccess():
        feedback.showToast(ToastId.tst34, onAction: onOpenClub);
        _replaceClub(club.copyWith(memberCount: club.memberCount + 1));
        return JoinOutcome.joined;
      case FirebaseFailure(:final error, :final message, :final detail):
        final outcome = await joinRuleOutcome(
          error: error,
          detail: detail,
          membership: membership,
          formatDate: formatDate,
          reloadClub: () => _reloadClub(clubId),
        );
        if (outcome != null) return outcome;
        if (!showWriteFailureToast(error)) {
          AppLogger.warn('Kulübe katılınamadı: ${error.name}', error: message);
        }
        return JoinOutcome.failed;
    }
  }

  /// SHT-05 onaysız kulüpte katılımla kapandı: TST-34 ([onOpenClub] "Kulübe
  /// git") ve karttaki üye sayısı.
  void showJoined(String clubId, {VoidCallback? onOpenClub}) {
    feedback.showToast(ToastId.tst34, onAction: onOpenClub);
    final club = _clubOf(clubId);
    if (club != null) {
      _replaceClub(club.copyWith(memberCount: club.memberCount + 1));
    }
  }

  /// Havuzları okur ve ilk yüklemeyi bitirir.
  Future<void> _load() async {
    if (!ref.mounted || _isLoading) return;
    _isLoading = true;
    final result = await clubRepository.fetchActiveClubs();
    // TODO(T-23): `eventRepository.listPublicUpcoming(fromUtc:
    // appClock.nowUtc())` → `eventPool` (`EventRepository` T-22'de gelir).
    _isLoading = false;
    if (!ref.mounted) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        final pool = [
          for (final club in data)
            if (!club.isSuspended) club,
        ];
        final suggested = _suggest(pool);
        state = state.copyWith(
          clubPool: pool,
          suggested: suggested,
          isFetching: false,
          isError: false,
        );
        if (state.hasTerm && !state.isSearching) _search();
        await _loadPreviews(suggested);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn('Arama havuzu okunamadı: ${error.name}', error: message);
        state = state.copyWith(isFetching: false, isError: true);
    }
  }

  /// Bekleme doldu: terimi havuzlarda arar.
  void _search() {
    if (!ref.mounted) return;
    final needle = state.searchTerm.trLower();
    state = state.copyWith(
      isSearching: false,
      clubResults: [
        for (final club in state.clubPool)
          if (_clubText(club).contains(needle)) club,
      ],
      eventResults: [
        for (final event in state.eventPool)
          if (_eventText(event).contains(needle)) event,
      ],
    );
  }

  /// Kulübün aranan metni (`screens-clubs.js:42`).
  String _clubText(ClubModel club) => [
    club.name,
    club.summary,
    club.about,
    _categoryLabels[club.categoryId] ?? '',
  ].join(_fieldSeparator).trLower();

  /// Etkinliğin aranan metni (`screens-clubs.js:43`).
  // TODO(T-23): kayıtlı mekân adı (`placeId` → ARB) da taranır.
  String _eventText(EventModel event) => [
    event.title,
    event.desc,
    event.placeText ?? '',
  ].join(_fieldSeparator).trLower();

  /// Önerilen kulüpler: kullanıcının aktif üyesi olmadığı kulüpler, ilgi
  /// alanlarının kategorileri önde; her grupta havuz sırası korunur.
  List<ClubModel> _suggest(List<ClubModel> pool) {
    final session = ref.read(sessionViewModelProvider);
    final interests = session.user?.interests ?? const <String>[];
    final categories = {
      for (final interest in StaticTables.interests)
        if (interests.contains(interest.id)) interest.categoryId,
    };
    final candidates = [
      for (final club in pool)
        if (session.roleIn(club.id) == null) club,
    ];
    return [
      for (final club in candidates)
        if (categories.contains(club.categoryId)) club,
      for (final club in candidates)
        if (!categories.contains(club.categoryId)) club,
    ].take(suggestedMax).toList(growable: false);
  }

  /// Önerilen kulüplerin yöneticilerini okur (kart avatar grubu — CD-139).
  /// Okuma hatası kartı bozmaz: o kulübün avatar grubu çizilmez.
  Future<void> _loadPreviews(List<ClubModel> clubs) async {
    if (clubs.isEmpty) return;
    final results = await Future.wait([
      for (final club in clubs) membershipRepository.listManagers(club.id),
    ]);
    if (!ref.mounted) return;
    state = state.copyWith(
      managerPreviews: {
        ...state.managerPreviews,
        for (final (index, result) in results.indexed)
          if (result case FirebaseSuccess(:final data)) clubs[index].id: data,
      },
    );
  }

  ClubModel? _clubOf(String clubId) {
    for (final club in state.clubPool) {
      if (club.id == clubId) return club;
    }
    return null;
  }

  /// [club] kulübünün güncel halini havuza, önerilenlere ve sonuçlara yazar.
  void _replaceClub(ClubModel club) {
    List<ClubModel> swap(List<ClubModel> list) => [
      for (final item in list) item.id == club.id ? club : item,
    ];
    state = state.copyWith(
      clubPool: swap(state.clubPool),
      suggested: swap(state.suggested),
      clubResults: swap(state.clubResults),
    );
  }

  /// Kulübü yeniden okur (katılım çakışması / başvurular kapandı). Okunamazsa
  /// ya da ViewModel kapandıysa `null`.
  Future<ClubModel?> _reloadClub(String clubId) async {
    final result = await clubRepository.getClub(clubId);
    if (!ref.mounted) return null;
    switch (result) {
      case FirebaseSuccess(:final data):
        _replaceClub(data);
        return data;
      case FirebaseFailure():
        return null;
    }
  }

  Future<void> _persistRecent(List<String> terms) async {
    if (await appPreferencesStore.setRecentSearches(terms)) return;
    AppLogger.warn('Son aramalar yazılamadı');
  }
}
