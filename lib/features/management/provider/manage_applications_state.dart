import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/navigation/applications_tab.dart';
import 'package:gu_ui/gu_ui.dart' show TurkishCaseX;

/// MGT-02 sıralama düğmesi (`MGT-02.sort`): başvuru zamanına göre en yeni ↔
/// en eski (prototip `desc` anahtarı, `screens-manage.js:44–46`; tasarımda
/// ada göre sıralama yoktur).
enum ApplicationSort {
  /// En yeni başvuru üstte (varsayılan).
  newest,

  /// En eski başvuru üstte.
  oldest,
}

/// Tek başvuru kararının sonucu (`ManageApplicationsViewModel.approve` /
/// `reject` / `undoDecision`).
enum DecisionOutcome {
  /// Yazıldı (TST-27 / TST-28 / TST-X17).
  done,

  /// Başvuru başka bir yönetici tarafından sonuçlandırılmış (DLG-18 + liste
  /// yenilendi).
  conflict,

  /// Yazılamadı; satır geri geldi (TST-24 / TST-X18).
  failed,

  /// Hiçbir şey yazılmadı: danışman (TST-26), çevrimdışı (TST-24), satır yok
  /// ya da geri al penceresi geçmiş.
  blocked,
}

/// MGT-02 "Başvurular" ekranının durumu (PLAN §12.6
/// `ManageApplicationsViewModel`).
///
/// * Sekme başına ayrı liste ([lists]) ve imleç ([cursors]); sekme ilk
///   açılışta okunur ([loadedTabs]). Görünen liste [visible]: hesabı
///   silinmiş başvuran (W-92), aramaya uymayanlar süzülür, [sort]'a göre
///   sıralanır.
/// * Ad, bölüm, sınıf üyelik belgesindeki `applicant` anlık görüntüsünden
///   gelir (D-29); [users] okunabildiyse güncel belge kullanılır. Başvuru
///   notu ve e-posta [contacts]'tadır (yalnızca yöneticiye okunur — CD-137).
/// * [undoable]: bu oturumda verilen kararların zamanı (kullanıcı → an);
///   `Limits.managerUndoWindow` (30 sn) dolunca kaydı düşer.
/// * [access] `advisor` → [isReadOnly] (Q-09: salt okunur bant, yazma
///   eylemleri TST-26).
final class ManageApplicationsState extends Equatable {
  /// Varsayılan: içerik yok, "Bekleyen" sekmesi.
  const ManageApplicationsState({
    this.access = ClubAccess.visitor,
    this.role,
    this.club,
    this.tab = ApplicationsTab.pending,
    this.lists = const {},
    this.cursors = const {},
    this.loadedTabs = const {},
    this.users = const {},
    this.contacts = const {},
    this.query = '',
    this.sort = ApplicationSort.newest,
    this.selecting = false,
    this.selectedIds = const {},
    this.undoable = const {},
    this.isFetching = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isError = false,
  });

  /// Oturumdaki kullanıcının kulübe erişimi.
  final ClubAccess access;

  /// Oturumdaki kullanıcının kulüpteki rolü (başlık rozeti).
  final ClubRole? role;

  /// Kulüp (başlık, `applicationsOpen` bandı); okunamadıysa `null`.
  final ClubModel? club;

  /// Seçili sekme.
  final ApplicationsTab tab;

  /// Sekme → okunan başvurular (sayfa sırasıyla).
  final Map<ApplicationsTab, List<MembershipModel>> lists;

  /// Sekme → sonraki sayfanın imleci; anahtar yoksa liste bitti.
  final Map<ApplicationsTab, PageCursor> cursors;

  /// En az bir kez okunmuş sekmeler.
  final Set<ApplicationsTab> loadedTabs;

  /// Kimlik → güncel kullanıcı belgesi (`userRepository.getUsers`).
  final Map<String, UserModel> users;

  /// Kimlik → `private/contact` (e-posta + başvuru notu; CD-137).
  final Map<String, MembershipContactModel> contacts;

  /// Arama alanındaki metin (yazıldığı gibi).
  final String query;

  /// Sıralama yönü.
  final ApplicationSort sort;

  /// Çoklu seçim kipi (onay kutuları; başlıkta seçim çubuğu).
  final bool selecting;

  /// Seçili başvuranlar (DLG-17 toplu işlem).
  final Set<String> selectedIds;

  /// Bu oturumda verilen ve hâlâ geri alınabilen kararlar (kullanıcı →
  /// karar anı).
  final Map<String, DateTime> undoable;

  /// Seçili sekmenin ilk okuması / "Yeniden dene" sürüyor (iskelet).
  final bool isFetching;

  /// Çek-yenile sürüyor (içerik ekranda kalır).
  final bool isRefreshing;

  /// Sonraki sayfa okunuyor.
  final bool isLoadingMore;

  /// Seçili sekme okunamadı (hata görünümü).
  final bool isError;

  /// Danışman bakışı (Q-09).
  bool get isReadOnly => access == ClubAccess.advisor;

  /// Süper admin bakışı (başlık rozeti).
  bool get isSuperAdmin => access == ClubAccess.superAdmin;

  /// Kulüp başvurulara kapalı mı (bilgi bandı + aç anahtarı)?
  bool get applicationsClosed => club?.applicationsOpen == false;

  /// [tab] sekmesinin okunan listesi.
  List<MembershipModel> itemsOf(ApplicationsTab tab) => lists[tab] ?? const [];

  /// Seçili sekmede okunmamış sayfa var mı?
  bool get hasMore => cursors.containsKey(tab);

  /// Aranan terim: kırpılmış, Türkçe küçük harf (CD-11).
  String get needle => query.trim().trLower();

  /// "Bekleyen" sekmesinin sayacı: okunan, hesabı silinmemiş bekleyen
  /// başvurular (prototip `pendingApps(club).length`).
  int get pendingCount => itemsOf(
    ApplicationsTab.pending,
  ).where((m) => !isDeletedApplicant(m)).length;

  /// Ekranda listelenen başvurular: silinmiş başvuran ve aramaya uymayanlar
  /// süzülür, başvuru zamanına göre [sort] yönünde sıralanır
  /// (`screens-manage.js:46`).
  List<MembershipModel> get visible {
    final term = needle;
    final rows = [
      for (final m in itemsOf(tab))
        if (!isDeletedApplicant(m) &&
            (term.isEmpty || nameOf(m).trLower().contains(term)))
          m,
    ];
    final sign = sort == ApplicationSort.newest ? -1 : 1;
    return rows..sort(
      (a, b) =>
          sign *
          _appliedMillis(a).compareTo(
            _appliedMillis(b),
          ),
    );
  }

  /// Seçim çubuğu "Hepsini seç" hedefi: görünen satırların kimlikleri.
  Set<String> get visibleIds => {for (final m in visible) m.userId};

  /// [m] sahibinin görünen adı (güncel belge → anlık görüntü).
  String nameOf(MembershipModel m) => users[m.userId]?.name ?? m.applicant.name;

  /// Başvuranın hesabı silinmiş mi (W-92; `users.status == deleted` ya da
  /// anonimleşmiş anlık görüntü)? Böyle başvuruya karar verilemez (W-89 a),
  /// listede çizilmez.
  bool isDeletedApplicant(MembershipModel m) =>
      (users[m.userId]?.isAnonymized ?? false) ||
      m.applicant.name == Anonymization.deletedUserName;

  /// [userId] başvuranının herhangi bir sekmedeki kaydı; yoksa `null`.
  MembershipModel? find(String userId) {
    for (final list in lists.values) {
      for (final m in list) {
        if (m.userId == userId) return m;
      }
    }
    return null;
  }

  /// [m] kararı [actorId] tarafından [nowUtc] anında geri alınabilir mi
  /// (SHT-19 "Geri al"): karar verilmiş, kararı [actorId] vermiş ve
  /// `Limits.managerUndoWindow` dolmamış; danışman geri alamaz.
  bool canUndo(MembershipModel m, String? actorId, DateTime nowUtc) {
    if (isReadOnly || actorId == null) return false;
    if (m.status != MembershipStatus.active &&
        m.status != MembershipStatus.rejected) {
      return false;
    }
    final decidedAt =
        undoable[m.userId] ?? (m.decidedBy == actorId ? m.decidedAt : null);
    return decidedAt != null &&
        nowUtc.isBefore(decidedAt.add(Limits.managerUndoWindow));
  }

  static int _appliedMillis(MembershipModel m) =>
      (m.appliedAt ?? m.createdAt)?.millisecondsSinceEpoch ?? 0;

  @override
  List<Object?> get props => [
    access,
    role,
    club,
    tab,
    lists,
    cursors,
    loadedTabs,
    users,
    contacts,
    query,
    sort,
    selecting,
    selectedIds,
    undoable,
    isFetching,
    isRefreshing,
    isLoadingMore,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearRole] rolü `null` yapar ve
  /// [role]'den önce gelir.
  ManageApplicationsState copyWith({
    ClubAccess? access,
    ClubRole? role,
    bool clearRole = false,
    ClubModel? club,
    ApplicationsTab? tab,
    Map<ApplicationsTab, List<MembershipModel>>? lists,
    Map<ApplicationsTab, PageCursor>? cursors,
    Set<ApplicationsTab>? loadedTabs,
    Map<String, UserModel>? users,
    Map<String, MembershipContactModel>? contacts,
    String? query,
    ApplicationSort? sort,
    bool? selecting,
    Set<String>? selectedIds,
    Map<String, DateTime>? undoable,
    bool? isFetching,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isError,
  }) => ManageApplicationsState(
    access: access ?? this.access,
    role: clearRole ? null : role ?? this.role,
    club: club ?? this.club,
    tab: tab ?? this.tab,
    lists: lists ?? this.lists,
    cursors: cursors ?? this.cursors,
    loadedTabs: loadedTabs ?? this.loadedTabs,
    users: users ?? this.users,
    contacts: contacts ?? this.contacts,
    query: query ?? this.query,
    sort: sort ?? this.sort,
    selecting: selecting ?? this.selecting,
    selectedIds: selectedIds ?? this.selectedIds,
    undoable: undoable ?? this.undoable,
    isFetching: isFetching ?? this.isFetching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isError: isError ?? this.isError,
  );
}
