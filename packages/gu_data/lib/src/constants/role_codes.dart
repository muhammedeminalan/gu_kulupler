/// Rol kodları — Firestore'daki `memberships.role` dizgileri ve süper admin
/// claim adı (PLAN §9.5; domain-model §2.4, §3).
///
/// `ClubRole.json` değerleri bu sabitlerden okunur; Security Rules'taki
/// `role in ['member','board','president']` listeleriyle parite testi yapılır
/// (`docs/testing.md §6` madde 11).
abstract final class RoleCodes {
  /// Sıradan üye.
  static const String member = 'member';

  /// Yönetim kurulu üyesi (yönetici).
  static const String board = 'board';

  /// Kulüp başkanı (yönetici; rol yalnızca devirle değişir).
  static const String president = 'president';

  /// Danışman (yönetim panelinde salt okunur; `memberCount`'a dahil değil).
  static const String advisor = 'advisor';

  /// Süper admin — kulüp rolü **değildir**; global Auth claim adıdır
  /// (`request.auth.token.superadmin == true`, D-28) ve `ClubRole` enum'unun
  /// dışında kalır.
  static const String superadmin = 'superadmin';
}

/// Üyelik durum kodları — Firestore'daki `memberships.status` dizgileri
/// (domain-model §2.4, §5).
///
/// `none` bir kod değildir: belge yoktur ya da durum [left] / [cancelled]'dır.
abstract final class MembershipStatusCodes {
  /// Başvuru karar bekliyor.
  static const String pending = 'pending';

  /// Aktif üye.
  static const String active = 'active';

  /// Başvuru reddedildi (`retryAfter` dolana kadar yeniden başvuramaz).
  static const String rejected = 'rejected';

  /// Üye kulüpten çıkarıldı (`retryAfter` dolana kadar yeniden başvuramaz).
  static const String removed = 'removed';

  /// Üye kendi isteğiyle ayrıldı.
  static const String left = 'left';

  /// Başvuran isteğini geri çekti.
  static const String cancelled = 'cancelled';
}
