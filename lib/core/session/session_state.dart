import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';

/// Oturum ve rol çözümü (architecture §6, PLAN §12.2). `SessionViewModel`
/// üretir; router (`AppRedirect`), kabuk ve ekranlar **buradan** okur —
/// ekranlar rolü kendi başlarına hesaplamaz.
final class SessionState extends Equatable {
  /// Varsayılan: oturum çözülmedi ([AuthStatus.unknown]).
  const SessionState({
    this.status = AuthStatus.unknown,
    this.uid,
    this.user,
    this.isSuperAdmin = false,
    this.memberships = const <String, MembershipModel>{},
    this.blockedUserIds = const <String>{},
    this.onboardingSeen = false,
    this.isResolving = false,
    this.isError = false,
    this.sessionExpired = false,
  });

  /// Oturumun çözülmüş durumu.
  final AuthStatus status;

  /// Oturumdaki kullanıcının kimliği; oturum yoksa `null`.
  final String? uid;

  /// `users/{uid}` belgesi; çözülmediyse ya da oturum yoksa `null`.
  final UserModel? user;

  /// Kimlik jetonunda `superadmin == true` claim'i var mı (D-28)?
  final bool isSuperAdmin;

  /// Kullanıcının kendi üyelikleri: kulüp kimliği → üyelik (canlı akış).
  final Map<String, MembershipModel> memberships;

  /// Kullanıcının engellediği kullanıcı kimlikleri.
  final Set<String> blockedUserIds;

  /// Tanıtım (ONB-01) görüldü mü? `AppPreferencesStore.onboardingSeen`'in
  /// kopyasıdır (CD-52); yönlendirme R2 / R3 bunu okur.
  final bool onboardingSeen;

  /// Oturum çözülüyor mu? `true` iken SYS-01 bekler.
  final bool isResolving;

  /// Oturum çözülemedi mi? → SYS-02.
  final bool isError;

  /// Oturum sunucu tarafında sona erdi mi (jeton iptali)? → DLG-27.
  final bool sessionExpired;

  /// Kullanıcının [clubId] kulübündeki **aktif** rolü. Yalnızca `active`
  /// üyelik rol taşır (`RolePolicy.activeRole`, CD-129): başvuran, reddedilen
  /// ya da ayrılmış kullanıcı için `null`'dır.
  ClubRole? roleIn(String clubId) {
    final membership = memberships[clubId];
    return RolePolicy.activeRole(
      status: membership?.status,
      role: membership?.role,
    );
  }

  /// Kullanıcının [clubId] kulübüne erişim kipi (`RolePolicy.accessOf`);
  /// süper admin için üyelikten bağımsız olarak `ClubAccess.superAdmin`.
  ClubAccess accessTo(String clubId) {
    final membership = memberships[clubId];
    return RolePolicy.accessOf(
      isSuper: isSuperAdmin,
      status: membership?.status,
      role: membership?.role,
    );
  }

  /// [userId] bu kullanıcı tarafından engellenmiş mi?
  bool isBlocked(String userId) => blockedUserIds.contains(userId);

  @override
  List<Object?> get props => [
    status,
    uid,
    user,
    isSuperAdmin,
    memberships,
    blockedUserIds,
    onboardingSeen,
    isResolving,
    isError,
    sessionExpired,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearUid] ve [clearUser] ilgili
  /// alanı `null` yapar ve aynı adlı parametreden önce gelir.
  SessionState copyWith({
    AuthStatus? status,
    String? uid,
    bool clearUid = false,
    UserModel? user,
    bool clearUser = false,
    bool? isSuperAdmin,
    Map<String, MembershipModel>? memberships,
    Set<String>? blockedUserIds,
    bool? onboardingSeen,
    bool? isResolving,
    bool? isError,
    bool? sessionExpired,
  }) => SessionState(
    status: status ?? this.status,
    uid: clearUid ? null : uid ?? this.uid,
    user: clearUser ? null : user ?? this.user,
    isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
    memberships: memberships ?? this.memberships,
    blockedUserIds: blockedUserIds ?? this.blockedUserIds,
    onboardingSeen: onboardingSeen ?? this.onboardingSeen,
    isResolving: isResolving ?? this.isResolving,
    isError: isError ?? this.isError,
    sessionExpired: sessionExpired ?? this.sessionExpired,
  );
}
