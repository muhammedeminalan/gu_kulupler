import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_ui/gu_ui.dart' show TurkishCaseX;

/// MGT-03 rol süzgeci — çip başına bir değer (`MGT-03.filter.<id>`; prototip
/// `screens-manage.js:69`, sıra tasarımdaki gibi).
enum ManageRoleFilter {
  /// "Tümü".
  all,

  /// "Başkan".
  president,

  /// "Yönetim Kurulu".
  board,

  /// "Danışman".
  advisor,

  /// "Üye".
  member;

  /// [role] bu süzgeçte görünür mü?
  bool includes(ClubRole role) => switch (this) {
    ManageRoleFilter.all => true,
    ManageRoleFilter.president => role == ClubRole.president,
    ManageRoleFilter.board => role == ClubRole.board,
    ManageRoleFilter.advisor => role == ClubRole.advisor,
    ManageRoleFilter.member => role == ClubRole.member,
  };
}

/// MGT-03 sıralama menüsü (`MGT-03.sort.<id>`). Tasarımdaki üçüncü seçenek
/// "Katılım oranına göre"nin üye başına veri kaynağı yoktur; yerine rol
/// sıralaması gelir (T-33 sapması).
enum MemberSort {
  /// Ada göre (Türkçe alfabe; varsayılan — referans görüntü "Ada göre").
  name,

  /// Katılım tarihine göre, en yeni üstte (`decidedAt` → `appliedAt`;
  /// `screens-manage.js:65`).
  joined,

  /// Role göre: başkan · yönetim kurulu · danışman · üye, rol içinde ada göre.
  role,
}

/// MGT-03 "Üye yönetimi" ekranının durumu (PLAN §12.6
/// `ManageMembersViewModel`).
///
/// * Üç kaynak ayrı tutulur (CLB-06 kalıbı): [managers] (başkan + yönetim
///   kurulu) ve [advisors] açılışta tek seferde okunur; [members] (sıradan
///   üyeler) 20'lik sayfalarla gelir ([cursor]). Görünen liste [visible]:
///   rol süzgeci, arama (ad, Türkçe küçük harf) ve hesabı silinmişler
///   istemcide süzülür, [sort]'a göre sıralanır.
/// * Ad, bölüm, sınıf üyelik belgesindeki `applicant` anlık görüntüsünden
///   gelir (D-29); [users] okunabildiyse güncel belge kullanılır. E-postalar
///   [emails]'tadır (yalnızca yönetimin okuduğu `private/contact`, CSV).
/// * [access] `advisor` → [isReadOnly] (Q-09: salt okunur bant, satır menüsü
///   yok, yazma eylemleri TST-26).
final class ManageMembersState extends Equatable {
  /// Varsayılan: içerik yok, süzgeç "Tümü", ada göre.
  const ManageMembersState({
    this.access = ClubAccess.visitor,
    this.role,
    this.club,
    this.managers = const [],
    this.advisors = const [],
    this.members = const [],
    this.users = const {},
    this.emails = const {},
    this.roleFilter = ManageRoleFilter.all,
    this.query = '',
    this.sort = MemberSort.name,
    this.cursor,
    this.isExporting = false,
    this.isFetching = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isError = false,
  });

  /// Rol sıralamasının sırası (CLB-06 grup sırası).
  static const List<ClubRole> roleOrder = [
    ClubRole.president,
    ClubRole.board,
    ClubRole.advisor,
    ClubRole.member,
  ];

  /// Oturumdaki kullanıcının kulübe erişimi.
  final ClubAccess access;

  /// Oturumdaki kullanıcının kulüpteki aktif rolü (başlık rozeti, hiyerarşi).
  final ClubRole? role;

  /// Kulüp (başlık, `presidentId`, üye sayacı); okunamadıysa `null`.
  final ClubModel? club;

  /// Başkan ve yönetim kurulu (`membershipRepository.listManagers`).
  final List<MembershipModel> managers;

  /// Danışmanlar (`listActiveMembers(role: advisor)`).
  final List<MembershipModel> advisors;

  /// Okunan sıradan üyeler (`listActiveMembers(role: member)`), sayfa
  /// sırasıyla.
  final List<MembershipModel> members;

  /// Kimlik → güncel kullanıcı belgesi (`userRepository.getUsers`).
  final Map<String, UserModel> users;

  /// Kimlik → e-posta (`readContact`; CSV dışa aktarımında okunur — D-29).
  final Map<String, String> emails;

  /// Seçili rol çipi.
  final ManageRoleFilter roleFilter;

  /// Arama alanındaki metin (yazıldığı gibi).
  final String query;

  /// Sıralama.
  final MemberSort sort;

  /// Sıradan üyelerin sonraki sayfasının imleci; liste bittiyse `null`.
  final PageCursor? cursor;

  /// CSV hazırlanıyor (menü öğesi ikinci kez çalışmaz).
  final bool isExporting;

  /// İlk yükleme / "Yeniden dene" sürüyor (iskelet).
  final bool isFetching;

  /// Çek-yenile sürüyor (içerik ekranda kalır).
  final bool isRefreshing;

  /// Sonraki sayfa okunuyor.
  final bool isLoadingMore;

  /// Üyeler okunamadı (hata görünümü).
  final bool isError;

  /// Danışman bakışı (Q-09).
  bool get isReadOnly => access == ClubAccess.advisor;

  /// Süper admin bakışı (başlık rozeti, hiyerarşide başkan yetkisi).
  bool get isSuperAdmin => access == ClubAccess.superAdmin;

  /// Yazma yetkili yönetim bakışı (yönetici ya da süper admin).
  bool get canManage => access == ClubAccess.manager || isSuperAdmin;

  /// Başkanlığı devredebilir mi ("Başkanlığı devret" kartı;
  /// `RolePolicy.canTransfer` aktörü — başkan ya da süper admin).
  bool get canTransfer =>
      !isReadOnly &&
      RolePolicy.can(
        ClubPermission.transferPresidency,
        role,
        isSuper: isSuperAdmin,
      );

  /// Okunmamış sıradan üye sayfası var mı?
  bool get hasMore => cursor != null;

  /// Sonraki sayfa görünen listeyi değiştirir mi (yalnızca "Tümü" ve "Üye"
  /// süzgeçlerinde sıradan üyeler çizilir)?
  bool get wantsMore =>
      hasMore &&
      (roleFilter == ManageRoleFilter.all ||
          roleFilter == ManageRoleFilter.member);

  /// Aranan terim: kırpılmış, Türkçe küçük harf (CD-11).
  String get needle => query.trim().trLower();

  /// Okunan bütün etkin üyelikler (başkan, yönetim kurulu, danışman, üye).
  List<MembershipModel> get all => [...managers, ...advisors, ...members];

  /// Kulübün başkanının kimliği: kulüp belgesi → yönetici listesi.
  String? get presidentId {
    final fromClub = club?.presidentId;
    if (fromClub != null && fromClub.isNotEmpty) return fromClub;
    for (final m in managers) {
      if (m.role == ClubRole.president) return m.userId;
    }
    return null;
  }

  /// Ekranda listelenen üyelikler: süzgece ve aramaya uyan, hesabı
  /// silinmemiş üyeler, [sort]'a göre.
  List<MembershipModel> get visible {
    final term = needle;
    final rows = [
      for (final m in all)
        if (roleFilter.includes(m.role) &&
            !isDeletedUser(m) &&
            (term.isEmpty || nameOf(m).trLower().contains(term)))
          m,
    ];
    return rows..sort(_compare);
  }

  /// "{count} kişi": görünen satırlar; sayfalama sürerken ve arama yokken
  /// sıradan üyeler kulübün üye sayacından türetilir (`memberCount` başkan +
  /// yönetim kurulu + üyeleri sayar, danışmanı saymaz).
  int get totalCount {
    final shown = visible.length;
    final club = this.club;
    if (club == null || !wantsMore || needle.isNotEmpty) return shown;
    final memberTotal = club.memberCount - managers.length;
    final estimate = roleFilter == ManageRoleFilter.all
        ? managers.length + advisors.length + memberTotal
        : memberTotal;
    return math.max(shown, estimate);
  }

  /// [m] sahibinin görünen adı (güncel belge → anlık görüntü).
  String nameOf(MembershipModel m) => users[m.userId]?.name ?? m.applicant.name;

  /// [m] sahibinin hesabı silinmiş mi (anonimleşmiş belge / anlık görüntü)?
  /// Böyle üye listelenmez.
  bool isDeletedUser(MembershipModel m) =>
      (users[m.userId]?.isAnonymized ?? false) ||
      m.applicant.name == Anonymization.deletedUserName;

  /// [userId] kimlikli etkin üyelik; listede yoksa `null`.
  MembershipModel? find(String userId) {
    for (final m in all) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  /// [m] üyesinin katılım anı (`decidedAt` → `appliedAt` → `createdAt`).
  static DateTime? joinedAt(MembershipModel m) =>
      m.decidedAt ?? m.appliedAt ?? m.createdAt;

  int _compare(MembershipModel a, MembershipModel b) => switch (sort) {
    MemberSort.name => _byName(a, b),
    MemberSort.joined => _millis(b).compareTo(_millis(a)),
    MemberSort.role => switch (roleOrder
        .indexOf(a.role)
        .compareTo(roleOrder.indexOf(b.role))) {
      0 => _byName(a, b),
      final order => order,
    },
  };

  int _byName(MembershipModel a, MembershipModel b) =>
      nameOf(a).trCompareTo(nameOf(b));

  static int _millis(MembershipModel m) =>
      joinedAt(m)?.millisecondsSinceEpoch ?? 0;

  @override
  List<Object?> get props => [
    access,
    role,
    club,
    managers,
    advisors,
    members,
    users,
    emails,
    roleFilter,
    query,
    sort,
    cursor,
    isExporting,
    isFetching,
    isRefreshing,
    isLoadingMore,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearRole] ve [clearCursor]
  /// ilgili alanı `null` yapar ve aynı adlı parametreden önce gelir.
  ManageMembersState copyWith({
    ClubAccess? access,
    ClubRole? role,
    bool clearRole = false,
    ClubModel? club,
    List<MembershipModel>? managers,
    List<MembershipModel>? advisors,
    List<MembershipModel>? members,
    Map<String, UserModel>? users,
    Map<String, String>? emails,
    ManageRoleFilter? roleFilter,
    String? query,
    MemberSort? sort,
    PageCursor? cursor,
    bool clearCursor = false,
    bool? isExporting,
    bool? isFetching,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isError,
  }) => ManageMembersState(
    access: access ?? this.access,
    role: clearRole ? null : role ?? this.role,
    club: club ?? this.club,
    managers: managers ?? this.managers,
    advisors: advisors ?? this.advisors,
    members: members ?? this.members,
    users: users ?? this.users,
    emails: emails ?? this.emails,
    roleFilter: roleFilter ?? this.roleFilter,
    query: query ?? this.query,
    sort: sort ?? this.sort,
    cursor: clearCursor ? null : cursor ?? this.cursor,
    isExporting: isExporting ?? this.isExporting,
    isFetching: isFetching ?? this.isFetching,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isError: isError ?? this.isError,
  );
}
