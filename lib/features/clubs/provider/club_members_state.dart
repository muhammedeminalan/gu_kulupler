import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/mixin/block_user_mixin.dart';
import 'package:gu_ui/gu_ui.dart' show TurkishCaseX;

/// CLB-06 rol süzgeci — çip başına bir değer (`CLB-06.filter.<id>`; prototip
/// `screens-clubs.js:144, 146`).
enum MemberRoleFilter {
  /// "Tümü": bütün gruplar.
  all,

  /// "Yönetim": başkan + yönetim kurulu.
  board,

  /// "Üye": yalnızca sıradan üyeler.
  member;

  /// [role] bu süzgeçte görünür mü?
  bool includes(ClubRole role) => switch (this) {
    MemberRoleFilter.all => true,
    MemberRoleFilter.board =>
      role == ClubRole.board || role == ClubRole.president,
    MemberRoleFilter.member => role == ClubRole.member,
  };
}

/// Ekrandaki bir rol grubu: başlık rolü, toplam sayı ve çizilen satırlar.
typedef MemberGroup = ({ClubRole role, int count, List<MembershipModel> rows});

/// CLB-06 "Üyeler" ekranının durumu (PLAN §12.6).
///
/// Üç kaynak ayrı tutulur: [managers] (başkan + yönetim kurulu) ve
/// [advisors] açılışta tek seferde okunur; [members] (sıradan üyeler) 20'lik
/// sayfalarla gelir ([cursor], [hasMore]). Ekranda görünen liste [groups] /
/// [visible] ile türetilir: rol süzgeci, arama ve engellenenler istemcide
/// süzülür.
///
/// Ad, bölüm ve sınıf üyelik belgesindeki `applicant` anlık görüntüsünden
/// gelir (D-29); [users] okunabildiyse güncel belge kullanılır.
final class ClubMembersState extends Equatable {
  /// Varsayılan: içerik yok, süzgeç "Tümü".
  const ClubMembersState({
    this.club,
    this.managers = const [],
    this.advisors = const [],
    this.members = const [],
    this.users = const {},
    this.blockedUserIds = const {},
    this.roleFilter = MemberRoleFilter.all,
    this.query = '',
    this.cursor,
    this.pendingUndo,
    this.isFetching = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.isError = false,
  });

  /// Grupların ekrandaki sırası (`screens-clubs.js:145`).
  static const List<ClubRole> groupOrder = [
    ClubRole.president,
    ClubRole.board,
    ClubRole.advisor,
    ClubRole.member,
  ];

  /// Kulüp (başlık çubuğunun alt başlığı, toplam üye sayısı); okunamadıysa
  /// `null`.
  final ClubModel? club;

  /// Başkan ve yönetim kurulu (`membershipRepository.listManagers`).
  final List<MembershipModel> managers;

  /// Danışmanlar (`role == advisor`; ayrı grup).
  final List<MembershipModel> advisors;

  /// Okunan sıradan üyeler (`role == member`), sayfa sırasıyla.
  final List<MembershipModel> members;

  /// Kimlik → güncel kullanıcı belgesi (`userRepository.getUsers`). Anahtarı
  /// olmayan üyenin satırı `applicant` anlık görüntüsüyle çizilir.
  final Map<String, UserModel> users;

  /// Oturumdaki kullanıcının engelledikleri (oturum + bu ekranda yapılan
  /// iyimser değişiklikler); listeden süzülürler.
  final Set<String> blockedUserIds;

  /// Seçili rol çipi.
  final MemberRoleFilter roleFilter;

  /// Arama alanındaki metin (yazıldığı gibi).
  final String query;

  /// Sıradan üyelerin sonraki sayfasının imleci; liste bittiyse `null`.
  final PageCursor? cursor;

  /// TST-09 "Geri al" ile geri alınabilecek son engel; yoksa `null`.
  final BlockUndo? pendingUndo;

  /// İlk yükleme / "Yeniden dene" sürüyor (iskelet).
  final bool isFetching;

  /// Sonraki sayfa okunuyor (liste sonunda iskelet satırları).
  final bool isLoadingMore;

  /// Çek-yenile sürüyor (içerik ekranda kalır).
  final bool isRefreshing;

  /// Üyeler okunamadı (hata görünümü).
  final bool isError;

  /// Okunmamış sıradan üye sayfası var mı?
  bool get hasMore => cursor != null;

  /// Sonraki sayfa görünen listeyi değiştirir mi ("Yönetim" süzgecinde
  /// sıradan üyeler çizilmez)?
  bool get wantsMore => hasMore && roleFilter != MemberRoleFilter.board;

  /// Aranan terim: kırpılmış, Türkçe küçük harf (CD-11).
  String get needle => query.trim().trLower();

  /// [membership] sahibinin görünen adı (güncel belge → anlık görüntü).
  String nameOf(MembershipModel membership) =>
      users[membership.userId]?.name ?? membership.applicant.name;

  /// [userId] kimlikli üyenin adı; listede yoksa `null`.
  String? nameOfUser(String userId) {
    for (final membership in [...managers, ...advisors, ...members]) {
      if (membership.userId == userId) return nameOf(membership);
    }
    return users[userId]?.name;
  }

  /// Ekrandaki gruplar, tasarım sırasıyla; boş grup çizilmez. Sıradan üyeler
  /// ada göre sıralıdır (`screens-clubs.js:145`).
  ///
  /// Grup sayısı çizilen satır sayısıdır; tek istisna sayfalaması süren
  /// üyelerdir: arama yokken kulübün üye sayacından türetilir ki başlık
  /// okunan sayfa kadar değil gerçek toplam kadar göstersin.
  List<MemberGroup> get groups {
    final byRole = <ClubRole, List<MembershipModel>>{
      ClubRole.president: _shown(
        managers.where((m) => m.role == ClubRole.president),
      ),
      ClubRole.board: _shown(managers.where((m) => m.role == ClubRole.board)),
      ClubRole.advisor: _shown(advisors),
      ClubRole.member: _shown(members)..sort(_byName),
    };
    return [
      for (final role in groupOrder)
        if (byRole[role] case final rows? when rows.isNotEmpty)
          (
            role: role,
            count: role == ClubRole.member
                ? _memberTotal(rows.length)
                : rows.length,
            rows: rows,
          ),
    ];
  }

  /// Ekranda listelenen üyelikler, grup sırasıyla (engellenenler, silinmiş
  /// hesaplar ve aramaya / süzgece uymayanlar yok).
  List<MembershipModel> get visible => [
    for (final group in groups) ...group.rows,
  ];

  /// "{count} kişi": grupların toplamı.
  int get totalCount => groups.fold(0, (total, group) => total + group.count);

  @override
  List<Object?> get props => [
    club,
    managers,
    advisors,
    members,
    users,
    blockedUserIds,
    roleFilter,
    query,
    cursor,
    pendingUndo,
    isFetching,
    isLoadingMore,
    isRefreshing,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearCursor] ve
  /// [clearPendingUndo] ilgili alanı `null` yapar ve aynı adlı parametreden
  /// önce gelir.
  ClubMembersState copyWith({
    ClubModel? club,
    List<MembershipModel>? managers,
    List<MembershipModel>? advisors,
    List<MembershipModel>? members,
    Map<String, UserModel>? users,
    Set<String>? blockedUserIds,
    MemberRoleFilter? roleFilter,
    String? query,
    PageCursor? cursor,
    bool clearCursor = false,
    BlockUndo? pendingUndo,
    bool clearPendingUndo = false,
    bool? isFetching,
    bool? isLoadingMore,
    bool? isRefreshing,
    bool? isError,
  }) => ClubMembersState(
    club: club ?? this.club,
    managers: managers ?? this.managers,
    advisors: advisors ?? this.advisors,
    members: members ?? this.members,
    users: users ?? this.users,
    blockedUserIds: blockedUserIds ?? this.blockedUserIds,
    roleFilter: roleFilter ?? this.roleFilter,
    query: query ?? this.query,
    cursor: clearCursor ? null : cursor ?? this.cursor,
    pendingUndo: clearPendingUndo ? null : pendingUndo ?? this.pendingUndo,
    isFetching: isFetching ?? this.isFetching,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isRefreshing: isRefreshing ?? this.isRefreshing,
    isError: isError ?? this.isError,
  );

  /// [source] içinden ekranda çizilecekler: süzgece uyan, engellenmemiş,
  /// hesabı silinmemiş ve adı aranan terimi içeren üyelikler.
  List<MembershipModel> _shown(Iterable<MembershipModel> source) {
    final term = needle;
    return [
      for (final membership in source)
        if (roleFilter.includes(membership.role) &&
            !blockedUserIds.contains(membership.userId) &&
            !(users[membership.userId]?.isAnonymized ?? false) &&
            (term.isEmpty || nameOf(membership).trLower().contains(term)))
          membership,
    ];
  }

  int _byName(MembershipModel a, MembershipModel b) =>
      nameOf(a).trLower().compareTo(nameOf(b).trLower());

  /// Sıradan üye grubunun sayısı. Okunmamış sayfa varken ve arama yokken
  /// kulüp sayacından türetilir: `memberCount` başkan + yönetim kurulu +
  /// üyeleri sayar (danışman sayılmaz); okunan sayfalarda gizlenenler
  /// (engellenen, silinmiş) düşülür.
  int _memberTotal(int shown) {
    final club = this.club;
    if (club == null || !hasMore || needle.isNotEmpty) return shown;
    final hidden = members.length - shown;
    return math.max(shown, club.memberCount - managers.length - hidden);
  }
}
