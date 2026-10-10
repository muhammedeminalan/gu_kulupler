import 'package:gu_data/src/models/enums/club_role.dart';
import 'package:gu_data/src/models/enums/membership_status.dart';

/// Kullanıcının **tek bir kulübe** erişim kipi (PLAN §9.1; domain-model §3
/// "Rol çözümü"; prototip `sel.mode`).
///
/// Türetilmiş değerdir: Firestore'a yazılmaz, JSON karşılığı yoktur.
/// [RolePolicy.accessOf] üretir; ekranlar kipi kendi başlarına hesaplamaz
/// (architecture §6).
///
/// `removed` ayrı bir kip **değildir**: çıkarılmış üye [visitor]'dır; arayüzde
/// gereken ayrım (`ClubCta`) üyelik durumundan ayrıca okunur.
enum ClubAccess {
  /// Üyelik yok ya da durum `left` / `cancelled` / `removed`.
  visitor,

  /// Başvuru karar bekliyor (`status == 'pending'`).
  pending,

  /// Başvuru reddedildi (`status == 'rejected'`).
  rejected,

  /// Aktif üye (`role == 'member'`).
  member,

  /// Aktif yönetici (`role` ∈ `board`, `president`).
  manager,

  /// Aktif danışman — yönetim panelini görür, yazamaz (TST-26).
  advisor,

  /// Süper admin (global claim); üyelik durumundan bağımsız olarak önce gelir.
  superAdmin,
}

/// Kulüp bazlı izinler — domain-model §3 matrisinin satırları, belge sırasıyla.
///
/// Belgede aynı satırı paylaşan izinler (`comment`, `vote` gibi) ayrı üyelerdir;
/// hücre değerleri aynıdır. Kimin neye izinli olduğu yalnızca [RolePolicy.can]
/// ile sorulur.
enum ClubPermission {
  /// Tanıtım sayfası ve public etkinlikleri görme.
  viewPublic,

  /// Kulübe başvurma / katılma (yalnızca üyeliği olmayan öğrenci).
  apply,

  /// Kulüp içini görme: gönderi, üye listesi, members-only etkinlik.
  viewInside,

  /// Yorum yazma.
  comment,

  /// Ankette oy verme.
  vote,

  /// Gönderi / duyuru / anket oluşturma.
  createPost,

  /// Duyuruyu üyelere bildirim olarak gönderme (günde en çok
  /// `Limits.announcementDailyLimit`).
  sendAnnouncementPush,

  /// Etkinlik oluşturma, düzenleme, yayınlama, iptal.
  manageEvents,

  /// Yoklama alma (QR / elle).
  takeAttendance,

  /// Başvuruları onaylama / reddetme.
  decideApplications,

  /// Üyeyi kulüpten çıkarma (hedef kısıtı: [RolePolicy.canRemove]).
  removeMember,

  /// Başkasının gönderisini / yorumunu kaldırma.
  moderateContent,

  /// Kulüp ayarlarını düzenleme.
  editClubSettings,

  /// Üyelere rol atama (hedef kısıtı: [RolePolicy.canAssignRole]).
  assignRoles,

  /// Başkanlığı devretme (hedef kısıtı: [RolePolicy.canTransfer]).
  transferPresidency,

  /// Yönetim panelini görme (danışman için salt okunur).
  viewManagement,

  /// Kulüp oluşturma (ADM-03).
  createClub,

  /// Kulübü askıya alma.
  suspendClub,

  /// Kulübe başkan atama.
  assignPresident,

  /// Şikayetleri inceleme ve çözme (ADM-04).
  moderateReports,

  /// Kullanıcıyı askıya alma (ADM-05).
  suspendUser,
}

/// Rol / yetki matrisi — kodda **tek yer** (domain-model §3).
///
/// Saf Dart, durumsuz. Security Rules yardımcılarıyla (`isMember`, `isManager`,
/// `isPres`, `isAdvisor`, `seesInside`, `seesMgmt`, `isSuper`;
/// firestore-rules-spec §2) aynı kararı verir. Bu sınıf arayüzün neyi
/// göstereceğine ve repository ön koşullarına karar verir; yetkiyi **uygulayan**
/// Rules'tur (CLAUDE.md §9).
abstract final class RolePolicy {
  /// [role] rolündeki kullanıcı [permission] iznine sahip mi?
  ///
  /// - [role]: kullanıcının bu kulüpteki **aktif** üyeliğinin rolü. Aktif
  ///   üyelik yoksa `null` verilir (matristeki `student` sütunu). Üyelik
  ///   belgesindeki `role` alanı `pending` / `rejected` / `removed` / `left` /
  ///   `cancelled` durumlarında da doludur (Rules M1: başvuru `role: 'member'`
  ///   ile yazılır); bu durumlarda rol **verilmez** (`null`), aksi halde
  ///   başvuran üye gibi yetkilendirilir. Üyelik belgesinden gelen rol bu
  ///   yüzden doğrudan değil, [activeRole] üzerinden verilir.
  /// - [isSuper]: süper admin claim'i (matristeki `superadmin` sütunu).
  ///
  /// Süper admin, `superadmin` sütununun izinlerine sahiptir; ayrıca kulüpte
  /// aktif bir rolü varsa o rolün izinleri **eklenir** (Rules'taki
  /// `isSuper() || isManager(c)` birleşimi). Üyeliği olmayan süper admin
  /// öğrenci sayılmaz: `apply` izni yoktur.
  static bool can(
    ClubPermission permission,
    ClubRole? role, {
    bool isSuper = false,
  }) {
    final holders = _holdersOf(permission);
    if (isSuper && holders.contains(_Holder.superadmin)) return true;
    final holder = switch (role) {
      null => isSuper ? null : _Holder.student,
      ClubRole.member => _Holder.member,
      ClubRole.board => _Holder.board,
      ClubRole.president => _Holder.president,
      ClubRole.advisor => _Holder.advisor,
    };
    return holder != null && holders.contains(holder);
  }

  /// [actorRole] rolündeki kullanıcı, [targetRole] rolündeki **aktif** üyeyi
  /// kulüpten çıkarabilir mi? (`active → removed`, DLG-19; Rules M9)
  ///
  /// Ön koşul [ClubPermission.removeMember]. Hiyerarşi: başkan ve süper admin
  /// `member` ve `board` üyeyi, yönetim kurulu üyesi yalnızca `member` üyeyi
  /// çıkarır. Başkan çıkarılamaz (önce devir). Danışman üyeliği bu yolla
  /// çıkarılmaz: `memberCount`'a dahil değildir (çıkarma sayacı −1 yapar),
  /// ataması ve kaldırılması süper adminin ayrı işlemidir (Rules M13). Rules
  /// M9 aynı kümeyi ister: `resource.data.role in ['member', 'board']`.
  static bool canRemove(
    ClubRole? actorRole,
    ClubRole targetRole, {
    bool isSuper = false,
  }) {
    if (!can(ClubPermission.removeMember, actorRole, isSuper: isSuper)) {
      return false;
    }
    return switch (targetRole) {
      ClubRole.member => true,
      ClubRole.board => isSuper || actorRole == ClubRole.president,
      ClubRole.president || ClubRole.advisor => false,
    };
  }

  /// [actorRole] rolündeki kullanıcı, [targetRole] rolündeki **aktif** üyenin
  /// rolünü [newRole] yapabilir mi? (SHT-22 → DLG-20; Rules M10)
  ///
  /// Ön koşul [ClubPermission.assignRoles] (başkan ya da süper admin). Yalnızca
  /// `member` ↔ `board` arasında atama yapılır: `president` rolü yalnızca
  /// devirle ([canTransfer]) verilir ve alınır; `advisor` rolü süper adminin
  /// ayrı işlemidir (Rules M13). [newRole] ile [targetRole] aynıysa da sonuç
  /// yetkiyi söyler; "değişiklik yok" denetimi çağırana aittir (TST-X9).
  static bool canAssignRole(
    ClubRole? actorRole,
    ClubRole targetRole,
    ClubRole newRole, {
    bool isSuper = false,
  }) =>
      can(ClubPermission.assignRoles, actorRole, isSuper: isSuper) &&
      _isAssignable(targetRole) &&
      _isAssignable(newRole);

  /// [actorRole] rolündeki kullanıcı, başkanlığı [targetRole] rolündeki
  /// **aktif** üyeye devredebilir mi? (SHT-25 → DLG-21; Rules M11)
  ///
  /// Ön koşul [ClubPermission.transferPresidency] (başkan ya da süper admin).
  /// Yeni başkan `member` ya da `board` olmalıdır; mevcut başkana ve danışmana
  /// devir yapılmaz.
  static bool canTransfer(
    ClubRole? actorRole,
    ClubRole targetRole, {
    bool isSuper = false,
  }) =>
      can(ClubPermission.transferPresidency, actorRole, isSuper: isSuper) &&
      _isAssignable(targetRole);

  /// Üyelik belgesinin [status] ve [role] alanlarından, [can] / [canRemove] /
  /// [canAssignRole] / [canTransfer] çağrılarına verilecek **aktif** rolü
  /// çözer (Rules `mActive`: `status == 'active'`).
  ///
  /// Yalnızca `active` üyelik rol taşır; `pending`, `rejected`, `removed`,
  /// `left`, `cancelled` ve belge yok (`null`) durumlarında sonuç
  /// `null`'dır — kullanıcı o kulüpte öğrenci (`student`) sütunundan
  /// yetkilendirilir. Üyelik belgesindeki rolü [can]'e **doğrudan vermek
  /// hatadır**: başvuran (`pending`, `role: 'member'`) üye sayılır, arayüz
  /// kulüp içini açar ve Rules `permission-denied` döner. Oturum katmanı
  /// (`SessionState.roleIn`) rolü yalnızca bu fonksiyonla türetir.
  ///
  /// - [status]: `memberships.status`; belge yoksa `null`.
  /// - [role]: `memberships.role`; `active` olup rolü okunamayan üyelik için
  ///   de sonuç `null`'dır (en az yetki).
  static ClubRole? activeRole({MembershipStatus? status, ClubRole? role}) =>
      status == MembershipStatus.active ? role : null;

  /// Kullanıcının bir kulübe erişim kipini çözer (prototip `sel.mode`).
  ///
  /// - [isSuper]: süper admin claim'i; `true` ise üyelikten bağımsız olarak
  ///   [ClubAccess.superAdmin].
  /// - [status]: üyelik belgesinin durumu; belge yoksa `null`.
  /// - [role]: üyelik belgesinin rolü; belge yoksa `null`.
  ///
  /// `pending` → [ClubAccess.pending], `rejected` → [ClubAccess.rejected];
  /// `active` iken role göre ([activeRole]) [ClubAccess.member] /
  /// [ClubAccess.manager] (`board`, `president`) / [ClubAccess.advisor]. Diğer
  /// her durum — belge yok, `left`, `cancelled`, `removed`, `active` olup
  /// rolü verilmemiş üyelik — [ClubAccess.visitor]'dır (en az yetki).
  static ClubAccess accessOf({
    required bool isSuper,
    MembershipStatus? status,
    ClubRole? role,
  }) {
    if (isSuper) return ClubAccess.superAdmin;
    return switch (status) {
      MembershipStatus.pending => ClubAccess.pending,
      MembershipStatus.rejected => ClubAccess.rejected,
      _ => switch (activeRole(status: status, role: role)) {
        ClubRole.member => ClubAccess.member,
        ClubRole.board || ClubRole.president => ClubAccess.manager,
        ClubRole.advisor => ClubAccess.advisor,
        null => ClubAccess.visitor,
      },
    };
  }

  /// Rol atama ve devirde hedef olabilen roller (`member`, `board`).
  static bool _isAssignable(ClubRole role) =>
      role == ClubRole.member || role == ClubRole.board;

  /// [permission] satırında ✓ olan sütunlar — domain-model §3 tablosu.
  ///
  /// `switch` tüketicidir: yeni bir [ClubPermission] satırsız derlenmez.
  static Set<_Holder> _holdersOf(ClubPermission permission) =>
      switch (permission) {
        ClubPermission.viewPublic => _everyone,
        ClubPermission.apply => _studentOnly,
        ClubPermission.viewInside => _insiders,
        ClubPermission.comment || ClubPermission.vote => _writers,
        ClubPermission.createPost ||
        ClubPermission.sendAnnouncementPush ||
        ClubPermission.manageEvents ||
        ClubPermission.takeAttendance ||
        ClubPermission.decideApplications ||
        ClubPermission.editClubSettings => _managers,
        ClubPermission.removeMember ||
        ClubPermission.moderateContent => _managersAndSuper,
        ClubPermission.assignRoles ||
        ClubPermission.transferPresidency => _presidentAndSuper,
        ClubPermission.viewManagement => _managementViewers,
        ClubPermission.createClub ||
        ClubPermission.suspendClub ||
        ClubPermission.assignPresident ||
        ClubPermission.moderateReports ||
        ClubPermission.suspendUser => _superOnly,
      };

  /// Herkes (`viewPublic`).
  static const Set<_Holder> _everyone = {
    _Holder.student,
    _Holder.member,
    _Holder.board,
    _Holder.president,
    _Holder.advisor,
    _Holder.superadmin,
  };

  /// Yalnızca üyeliği olmayan öğrenci (`apply`).
  static const Set<_Holder> _studentOnly = {_Holder.student};

  /// Rules `seesInside`: aktif her üyelik + süper admin.
  static const Set<_Holder> _insiders = {
    _Holder.member,
    _Holder.board,
    _Holder.president,
    _Holder.advisor,
    _Holder.superadmin,
  };

  /// Rules `isMember`: yazma yetkili üye (danışman ve süper admin hariç).
  static const Set<_Holder> _writers = {
    _Holder.member,
    _Holder.board,
    _Holder.president,
  };

  /// Rules `isManager`.
  static const Set<_Holder> _managers = {_Holder.board, _Holder.president};

  /// Rules `isManager(c) || isSuper()`.
  static const Set<_Holder> _managersAndSuper = {
    _Holder.board,
    _Holder.president,
    _Holder.superadmin,
  };

  /// Rules `isPres(c) || isSuper()`.
  static const Set<_Holder> _presidentAndSuper = {
    _Holder.president,
    _Holder.superadmin,
  };

  /// Rules `seesMgmt`: yönetici + danışman (salt okunur) + süper admin.
  static const Set<_Holder> _managementViewers = {
    _Holder.board,
    _Holder.president,
    _Holder.advisor,
    _Holder.superadmin,
  };

  /// Rules `isSuper()`.
  static const Set<_Holder> _superOnly = {_Holder.superadmin};
}

/// domain-model §3 matrisinin sütunları.
enum _Holder { student, member, board, president, advisor, superadmin }
