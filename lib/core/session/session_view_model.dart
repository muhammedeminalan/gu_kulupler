import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/product/init/app_gate_view_model.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_view_model.g.dart';

/// Oturumun kök ViewModel'i (architecture §6, PLAN §12.2): uygulama ömrü
/// boyunca yaşar; router `refreshListenable`'ı, `AppRedirect`, kabuk ve
/// ekranlar oturum ve rol bilgisini buradan okur.
///
/// Oturum akışını dinler ve [SessionState.status]'u çözer:
///
/// | Kimlik durumu | `status` |
/// |---|---|
/// | henüz olay gelmedi | `unknown` |
/// | oturum yok | `signedOut` |
/// | e-posta doğrulanmamış | `unverified` |
/// | doğrulanmış | `active` (+ `superadmin` claim'i) |
/// | hesap devre dışı (`AuthError.userDisabled`) | `suspended` |
///
/// T-11 kapsamı kimlik, claim ve tanıtım bayrağıdır. `users/{uid}` belgesi
/// (`profileIncomplete`, `users.status == 'suspended'`), üyelikler ve
/// engellenenler sonraki task'larda bağlanır (gövdedeki sahipli notlar); o
/// zamana kadar doğrulanmış her oturum `active` çözülür.
@Riverpod(keepAlive: true)
final class SessionViewModel extends _$SessionViewModel
    with ProjectDependencyMixin {
  /// Çözüm sırası: yavaş kalan eski bir çözüm yenisinin sonucunu ezmez.
  int _epoch = 0;

  @override
  SessionState build() {
    // TODO(T-12): `authRepository.watchAuthState()` (oturum akışının tek
    // dinleyicisi repository üzerinden).
    final authSubscription = authService.authStateChanges().listen(
      (user) => unawaited(_resolveFor(user)),
      onError: _onAuthStreamError,
    );
    final tokenSubscription = authService.tokenErrors.listen(_onTokenError);
    ref
      ..onDispose(authSubscription.cancel)
      ..onDispose(tokenSubscription.cancel);
    return SessionState(onboardingSeen: appPreferencesStore.onboardingSeen);
  }

  /// Oturumu güncel kimlik bilgisinden yeniden çözer (SYS-02 "Yeniden dene",
  /// AUT-03 "Doğruladım" sonrası).
  Future<void> resolve() => _resolveFor(authService.currentUser);

  /// `superadmin` claim'ini sunucudan yenileyerek okur. Oturum yoksa
  /// etkisizdir; okunamazsa mevcut değer korunur.
  Future<void> refreshClaims() async {
    if (state.uid == null) return;
    final epoch = _epoch;
    // TODO(T-12): `authRepository.isSuperAdmin(forceRefresh: true)`.
    final result = await authService.idTokenClaims(forceRefresh: true);
    if (!ref.mounted || epoch != _epoch) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(isSuperAdmin: _isSuper(data));
      case FirebaseFailure(:final error):
        AppLogger.warn('Claim yenilenemedi: ${error.name}');
    }
  }

  /// Tanıtımı (ONB-01) görüldü işaretler: önce depoya yazar, sonra bu state'i
  /// ve `AppPreferencesState`'i günceller (CD-52). Kalıcılık hatası yalnızca
  /// günlüğe düşer; bayrak oturum boyunca geçerlidir.
  Future<void> markOnboardingSeen() async {
    final saved = await appPreferencesStore.setOnboardingSeen(true);
    if (!saved) AppLogger.warn('Tanıtım bayrağı kalıcı yazılamadı');
    if (!ref.mounted) return;
    state = state.copyWith(onboardingSeen: true);
    ref.read(appPreferencesViewModelProvider.notifier).syncOnboardingSeen();
  }

  /// Kullanıcının [clubId] kulübündeki aktif rolü ([SessionState.roleIn]).
  ClubRole? roleIn(String clubId) => state.roleIn(clubId);

  /// Kullanıcının [clubId] kulübüne erişim kipi ([SessionState.accessTo]).
  ClubAccess accessTo(String clubId) => state.accessTo(clubId);

  /// [userId] engellenmiş mi ([SessionState.isBlocked])?
  bool isBlocked(String userId) => state.isBlocked(userId);

  /// Oturumu kapatır ve kapanıp kapanmadığını döndürür. State, oturum
  /// akışından gelen olayla `signedOut` olur.
  ///
  /// Kapatma başarısızsa oturum açık kalır, hata günlüğe düşer ve `false`
  /// döner: çağıran akışını sonuca göre sürdürür (DLG-27 kapısı açık kalır,
  /// `sessionExpired` inmez).
  Future<bool> signOut() async {
    // TODO(T-12): `authRepository.signOut()`.
    // TODO(T-23): `localReminderService.cancelAll()`.
    final result = await authService.signOut();
    switch (result) {
      case FirebaseSuccess():
        if (ref.mounted) state = state.copyWith(sessionExpired: false);
        return true;
      case FirebaseFailure(:final error):
        AppLogger.warn('Oturum kapatılamadı: ${error.name}');
        return false;
    }
  }

  /// Oturum sunucu tarafında sona erdi (`AuthError.sessionExpired`): bayrağı
  /// kaldırır ve kök kapıya bildirir (DLG-27). Oturumu kapatmak diyaloğun
  /// işidir.
  void onTokenExpired() {
    if (state.sessionExpired) return;
    state = state.copyWith(sessionExpired: true);
    ref.read(appGateViewModelProvider.notifier).onSessionExpired();
  }

  Future<void> _resolveFor(AuthUserInfo? user) async {
    final epoch = ++_epoch;
    // Tanıtım bayrağı her çözümün başında depodan okunur (CD-52).
    final onboardingSeen = appPreferencesStore.onboardingSeen;
    if (user == null) {
      state = _withoutUser(
        state,
      ).copyWith(status: AuthStatus.signedOut, onboardingSeen: onboardingSeen);
      return;
    }
    final base = user.uid == state.uid ? state : _withoutUser(state);
    if (!user.emailVerified) {
      state = base.copyWith(
        status: AuthStatus.unverified,
        uid: user.uid,
        onboardingSeen: onboardingSeen,
        isSuperAdmin: false,
        isResolving: false,
        isError: false,
        sessionExpired: false,
      );
      return;
    }
    state = base.copyWith(
      uid: user.uid,
      onboardingSeen: onboardingSeen,
      isResolving: true,
      isError: false,
    );
    // TODO(T-12): `authRepository.isSuperAdmin()` (girişte bir kez
    // `forceRefresh: true`, D-28).
    final claims = await authService.idTokenClaims();
    if (!ref.mounted || epoch != _epoch) return;
    switch (claims) {
      case FirebaseSuccess(:final data):
        _activate(isSuperAdmin: _isSuper(data));
      case FirebaseFailure(error: AuthError.sessionExpired):
        state = state.copyWith(isResolving: false);
        onTokenExpired();
      case FirebaseFailure(error: AuthError.userDisabled):
        _suspend();
      case FirebaseFailure(error: AuthError.network):
        // Çevrimdışı açılış kullanıcıyı kilitlemez (Q-12: okuma önbellekten).
        // Claim okunamadıysa mevcut değer korunur; yetkiyi Rules uygular.
        AppLogger.warn('Claim okunamadı (ağ); oturum claim olmadan çözüldü');
        _activate(isSuperAdmin: state.isSuperAdmin);
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Oturum çözülemedi: ${error.name}',
          error: message,
        );
        state = state.copyWith(isResolving: false, isError: true);
    }
  }

  void _activate({required bool isSuperAdmin}) {
    // TODO(T-12): `userRepository.getUser(uid)` → `user`; profil eksikse
    // `profileIncomplete`, `users.status == 'suspended'` ise `suspended`
    // (`refreshUser()` aynı task'ta eklenir).
    // TODO(T-15): `membershipRepository.watchMyMemberships(uid)` canlı akışı
    // → `memberships`; `blockRepository.fetchActiveBlocks(uid)` →
    // `blockedUserIds`.
    state = state.copyWith(
      status: AuthStatus.active,
      isSuperAdmin: isSuperAdmin,
      isResolving: false,
      isError: false,
      sessionExpired: false,
    );
  }

  void _suspend() {
    // Bekleyen çözümü geçersiz kılar: jeton hatası claim okuması sürerken
    // gelirse, önbellekteki jetonla başarı dönen eski çözüm askıyı `active`
    // ile ezmemelidir.
    _epoch++;
    // TODO(T-13): `onSuspended()` — oturumu kapat + DLG-01 (W-03). O zamana
    // kadar erişimi R6 keser (askıdaki kullanıcı `/login`'de tutulur).
    state = state.copyWith(
      status: AuthStatus.suspended,
      isResolving: false,
      isError: false,
    );
  }

  void _onTokenError(AuthError error) {
    switch (error) {
      case AuthError.sessionExpired:
        onTokenExpired();
      case AuthError.userDisabled:
        _suspend();
      // Diğer hatalar oturumu geçersiz kılmaz; servis bu akışa yazmaz.
      // Sözlük büyürse sessizce yutulmasın diye günlüğe düşer.
      // ignore: no_default_cases
      default:
        AppLogger.warn('Beklenmeyen jeton hatası: ${error.name}');
    }
  }

  void _onAuthStreamError(Object error, StackTrace stackTrace) {
    AppLogger.warn(
      'Oturum akışı hata verdi',
      error: error,
      stackTrace: stackTrace,
    );
    if (!ref.mounted) return;
    state = state.copyWith(isResolving: false, isError: true);
  }

  /// Kullanıcıya bağlı tüm alanları temizlenmiş kopya (oturum kapandığında ya
  /// da başka bir hesaba geçildiğinde).
  static SessionState _withoutUser(SessionState base) => base.copyWith(
    clearUid: true,
    clearUser: true,
    isSuperAdmin: false,
    memberships: const <String, MembershipModel>{},
    blockedUserIds: const <String>{},
    isResolving: false,
    isError: false,
  );

  static bool _isSuper(Map<String, Object?> claims) =>
      claims[RoleCodes.superadmin] == true;
}
