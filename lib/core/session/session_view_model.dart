import 'dart:async';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/product/init/app_gate_view_model.dart';
import 'package:gu_kulupler/product/init/app_preferences_view_model.dart';
import 'package:gu_kulupler/product/mixin/suspended_account_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_view_model.g.dart';

/// Oturumun kök ViewModel'i (architecture §6, PLAN §12.2): uygulama ömrü
/// boyunca yaşar; router `refreshListenable`'ı, `AppRedirect`, kabuk ve
/// ekranlar oturum ve rol bilgisini buradan okur.
///
/// Oturum akışını (`AuthRepository.watchAuthState`, tek dinleyici) dinler ve
/// [SessionState.status]'u kimlik + `users/{uid}` belgesinden çözer:
///
/// | Kimlik / kullanıcı belgesi | `status` |
/// |---|---|
/// | henüz olay gelmedi | `unknown` |
/// | oturum yok | `signedOut` |
/// | e-posta doğrulanmamış | `unverified` |
/// | doğrulanmış; belge yok ya da profil eksik | `profileIncomplete` |
/// | doğrulanmış; profil tamam | `active` (+ `superadmin` claim'i) |
/// | `users.status == suspended` | `suspended` (+ gerekçe, CD-133) → [onSuspended] |
/// | hesap devre dışı (`AuthError.userDisabled`) | `suspended` → [onSuspended] |
/// | `users.status == deleted` / `isDeleted` | oturum kapanır → `signedOut` |
///
/// Çözüm tamamlanana kadar `status` önceki değerinde kalır
/// ([SessionState.isResolving]): doğrulanmış oturum, belgesi okunmadan
/// `active` görünmez.
///
/// **Üyelikler (T-15):** oturum `active` çözülünce kullanıcının üyelikleri
/// canlı dinlenir (`MembershipRepository.watchMyMemberships`, PLAN §10.6 #1)
/// ve [SessionState.memberships]'e (kulüp kimliği → üyelik) yazılır; rol ve
/// erişim ([roleIn], [accessTo]) buradan çözülür. Oturum kapanınca, hesap
/// değişince ya da askıya alınınca dinleyici bırakılır. **Engellenenler**
/// tek seferlik okunur (`BlockRepository.fetchActiveBlocks`): oturum
/// çözülünce ve [refreshUser] ile.
@Riverpod(keepAlive: true)
final class SessionViewModel extends _$SessionViewModel
    with ProjectDependencyMixin, SuspendedAccountMixin {
  /// Çözüm sırası: yavaş kalan eski bir çözüm yenisinin sonucunu ezmez.
  int _epoch = 0;

  /// Askı bildirimi (DLG-01) gösterilmeyi bekliyor mu
  /// ([showPendingSuspendedNotice])?
  bool _suspendedNoticePending = false;

  /// Askıdaki oturumun kapatılması sürüyor mu ([onSuspended])?
  bool _isClosingSuspended = false;

  /// Kimlik jetonu bu oturumda sunucudan yenilenmiş kullanıcı (D-28: girişte
  /// bir kez). Oturum kapanınca sıfırlanır.
  String? _claimsRefreshedFor;

  /// Üyelik akışının aboneliği ve dinlenen kullanıcı ([_watchMemberships]).
  StreamSubscription<FirestoreResult<List<MembershipModel>>>?
  _membershipSubscription;
  String? _membershipsFor;

  @override
  SessionState build() {
    final authSubscription = authRepository.watchAuthState().listen(
      (user) => unawaited(_resolveFor(user)),
      onError: _onAuthStreamError,
    );
    final tokenSubscription = authRepository.tokenErrors.listen(_onTokenError);
    ref
      ..onDispose(authSubscription.cancel)
      ..onDispose(tokenSubscription.cancel)
      ..onDispose(_stopMembershipWatch);
    return SessionState(onboardingSeen: appPreferencesStore.onboardingSeen);
  }

  /// Oturumu güncel kimlik bilgisinden yeniden çözer (SYS-02 "Yeniden dene",
  /// AUT-03 "Doğruladım" sonrası).
  Future<void> resolve() => _resolveFor(authRepository.currentUser);

  /// `users/{uid}` belgesini yeniden okur ve durumu ona göre yeniden çözer
  /// (AUT-05 bitişi, profil düzenleme sonrası): `profileIncomplete` ↔
  /// `active`, askı, silinmiş hesap. Aktif oturumda engellenenler de yeniden
  /// okunur (engelle / engeli kaldır sonrası) ve kopmuş üyelik akışı yeniden
  /// bağlanır.
  ///
  /// Oturum henüz çözülmediyse, doğrulanmamışsa ya da bir çözüm sürüyorsa tam
  /// çözüm çalışır ([resolve]). Çözülmüş oturumda belge okunamazsa mevcut
  /// durum korunur (geçici bir okuma hatası oturumu düşürmez).
  Future<void> refreshUser() async {
    final user = authRepository.currentUser;
    final isSettled =
        state.status == AuthStatus.active ||
        state.status == AuthStatus.profileIncomplete;
    if (user == null ||
        user.uid != state.uid ||
        !isSettled ||
        state.isResolving) {
      return resolve();
    }
    final epoch = ++_epoch;
    final result = await userRepository.getUser(user.uid);
    if (!_isCurrent(epoch)) return;
    if (result case FirebaseFailure(
      :final error,
    ) when error != FirestoreError.unauthenticated) {
      AppLogger.warn('Kullanıcı belgesi yenilenemedi: ${error.name}');
    } else {
      await _applyUser(
        result,
        epoch,
        isSuperAdmin: state.isSuperAdmin,
        isFullResolve: false,
      );
    }
    await _refreshBlocks(user.uid, epoch);
  }

  /// `superadmin` claim'ini sunucudan yenileyerek okur. Oturum yoksa
  /// etkisizdir; okunamazsa mevcut değer korunur.
  Future<void> refreshClaims() async {
    if (state.uid == null) return;
    final epoch = _epoch;
    final result = await authRepository.isSuperAdmin(forceRefresh: true);
    if (!_isCurrent(epoch)) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(isSuperAdmin: data);
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

  /// [userId] için engel yazımı sunucuya işlendi: oturumdaki engel kümesi
  /// yeniden okunmadan güncellenir (`BlockUserMixin.onBlockSaved` — engelle,
  /// engeli kaldır ve TST-09 "Geri al"). Aktif oturum yoksa ya da küme zaten
  /// bu durumdaysa etkisizdir.
  void setBlocked(String userId, {required bool isBlocked}) {
    if (state.status != AuthStatus.active ||
        state.isBlocked(userId) == isBlocked) {
      return;
    }
    state = state.copyWith(
      blockedUserIds: {
        for (final id in state.blockedUserIds)
          if (id != userId) id,
        if (isBlocked) userId,
      },
    );
  }

  /// Oturumu kapatır ve kapanıp kapanmadığını döndürür. State, oturum
  /// akışından gelen olayla `signedOut` olur.
  ///
  /// Kapatma başarısızsa oturum açık kalır, hata günlüğe düşer ve `false`
  /// döner: çağıran akışını sonuca göre sürdürür (DLG-27 kapısı açık kalır,
  /// `sessionExpired` inmez).
  Future<bool> signOut() async {
    // TODO(T-23): `localReminderService.cancelAll()`.
    // Üyelik dinleyicisi çıkıştan önce bırakılır: kapanan oturumun açık
    // dinleyicisi yetki hatası üretir.
    final watched = _membershipsFor;
    _stopMembershipWatch();
    final result = await authRepository.signOut();
    switch (result) {
      case FirebaseSuccess():
        if (ref.mounted) state = state.copyWith(sessionExpired: false);
        return true;
      case FirebaseFailure(:final error):
        AppLogger.warn('Oturum kapatılamadı: ${error.name}');
        // Oturum açık kaldı: aktifse üyelikler yeniden dinlenir.
        if (ref.mounted &&
            watched != null &&
            watched == state.uid &&
            state.status == AuthStatus.active) {
          _watchMemberships(watched);
        }
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

  /// Hesap askıya alındı (PLAN §13.4 R6'nın yan etkisi; W-03): oturumu
  /// kapatır ve askı bildirimini (DLG-01) sıraya alır.
  ///
  /// Bildirim burada **gösterilmez**: yönlendirme (R6 → `/login`) alttaki
  /// sayfayı değiştirirken kök gezgine itilen dialog sayfayla birlikte düşer.
  /// Giriş ekranı yerleşince [showPendingSuspendedNotice] çağırır.
  ///
  /// Oturum kapatılamazsa durum `suspended` kalır (R6 kullanıcıyı `/login`'de
  /// tutar); bildirim yine gösterilir.
  Future<void> onSuspended() {
    _suspendedNoticePending = true;
    return _closeSuspendedSession();
  }

  /// Askıdaki oturumu kapatır; süren kapatma varken ikinci kez çağrılmaz.
  Future<void> _closeSuspendedSession() async {
    if (_isClosingSuspended) return;
    _isClosingSuspended = true;
    try {
      await signOut();
    } finally {
      _isClosingSuspended = false;
    }
  }

  /// Bekleyen askı bildirimini (DLG-01 "Hesabın askıya alındı") gösterir ve
  /// kapanana kadar bekler; bekleyen bildirim yoksa etkisizdir. Giriş ekranı
  /// (AUT-01) açılışta ve oturum durumu değişince çağırır.
  Future<void> showPendingSuspendedNotice() async {
    if (!_suspendedNoticePending) return;
    _suspendedNoticePending = false;
    await showSuspendedAccountDialog();
  }

  bool _isCurrent(int epoch) => ref.mounted && epoch == _epoch;

  Future<void> _resolveFor(AuthUserInfo? user) async {
    final epoch = ++_epoch;
    // Tanıtım bayrağı her çözümün başında depodan okunur (CD-52).
    final onboardingSeen = appPreferencesStore.onboardingSeen;
    if (user == null) {
      _claimsRefreshedFor = null;
      _stopMembershipWatch();
      state = _withoutUser(
        state,
      ).copyWith(status: AuthStatus.signedOut, onboardingSeen: onboardingSeen);
      return;
    }
    final base = user.uid == state.uid ? state : _withoutUser(state);
    // Başka hesabın dinleyicisi yeni hesabın çözümünü beklemeden bırakılır.
    if (_membershipsFor != user.uid) _stopMembershipWatch();
    if (!user.emailVerified) {
      _stopMembershipWatch();
      state = base.copyWith(
        status: AuthStatus.unverified,
        uid: user.uid,
        onboardingSeen: onboardingSeen,
        isSuperAdmin: false,
        memberships: const <String, MembershipModel>{},
        blockedUserIds: const <String>{},
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
    final isSuperAdmin = await _readSuperAdmin(user.uid, epoch);
    if (isSuperAdmin == null) return;
    final result = await userRepository.getUser(user.uid);
    if (!_isCurrent(epoch)) return;
    await _applyUser(
      result,
      epoch,
      isSuperAdmin: isSuperAdmin,
      isFullResolve: true,
    );
    await _refreshBlocks(user.uid, epoch);
  }

  /// [uid] oturumunun `superadmin` claim'i. Çözüm bittiyse `null`: sonuç
  /// eskidi ya da hata state'e yazıldı (çağıran devam etmez).
  ///
  /// Oturumun ilk çözümünde jeton sunucudan yenilenir (D-28): yeni atanmış
  /// claim ve doğrulama sonrası `email_verified` jetona işler (Rules ikisini
  /// de jetondan okur). Ağ yoksa önbellekteki jetona düşülür; o da yoksa
  /// oturum claim'siz çözülür — çevrimdışı açılış kullanıcıyı kilitlemez
  /// (Q-12), yetkiyi Rules uygular.
  Future<bool?> _readSuperAdmin(String uid, int epoch) async {
    final refresh = _claimsRefreshedFor != uid;
    var result = await authRepository.isSuperAdmin(forceRefresh: refresh);
    if (!_isCurrent(epoch)) return null;
    if (refresh) {
      if (result.isSuccess) {
        _claimsRefreshedFor = uid;
      } else if (result.errorOrNull == AuthError.network) {
        result = await authRepository.isSuperAdmin();
        if (!_isCurrent(epoch)) return null;
      }
    }
    switch (result) {
      case FirebaseSuccess(:final data):
        return data;
      case FirebaseFailure(error: AuthError.sessionExpired):
        state = state.copyWith(isResolving: false);
        onTokenExpired();
        return null;
      case FirebaseFailure(error: AuthError.userDisabled):
        _suspend();
        return null;
      case FirebaseFailure(error: AuthError.network):
        AppLogger.warn('Claim okunamadı (ağ); oturum claim olmadan çözüldü');
        return state.isSuperAdmin;
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn('Oturum çözülemedi: ${error.name}', error: message);
        state = state.copyWith(isResolving: false, isError: true);
        return null;
    }
  }

  /// `users/{uid}` okumasının [result] sonucunu duruma çevirir.
  /// [isFullResolve] tam çözümde (`_resolveFor`) `true`'dur: yalnızca yeni
  /// çözülen oturum "oturum sona erdi" bayrağını indirir.
  Future<void> _applyUser(
    FirestoreResult<UserModel?> result,
    int epoch, {
    required bool isSuperAdmin,
    required bool isFullResolve,
  }) async {
    // Bayrak yalnızca tam çözümde iner; yenilemede olduğu gibi kalır.
    final sessionExpired = isFullResolve ? false : null;
    switch (result) {
      case FirebaseSuccess(data: null):
        // Belge henüz yok: profil akışı (AUT-05) oluşturur. Kayıt sırasında
        // oluşturulamaz — Rules doğrulanmış e-posta ister (rules-spec §3.1 C).
        _settle(
          AuthStatus.profileIncomplete,
          isSuperAdmin: isSuperAdmin,
          sessionExpired: sessionExpired,
        );
      case FirebaseSuccess(data: final user?)
          when user.isDeleted || user.status == UserStatus.deleted:
        await _closeDeletedAccount(epoch);
      case FirebaseSuccess(data: final user?)
          when user.status == UserStatus.suspended:
        await _suspendWithReason(user, epoch);
      case FirebaseSuccess(data: final user?):
        _settle(
          user.profileComplete
              ? AuthStatus.active
              : AuthStatus.profileIncomplete,
          isSuperAdmin: isSuperAdmin,
          sessionExpired: sessionExpired,
          user: user,
        );
      case FirebaseFailure(error: FirestoreError.unauthenticated):
        state = state.copyWith(isResolving: false);
        onTokenExpired();
      case FirebaseFailure(:final error, :final message):
        AppLogger.warn(
          'Kullanıcı belgesi okunamadı: ${error.name}',
          error: message,
        );
        state = state.copyWith(isResolving: false, isError: true);
    }
  }

  void _settle(
    AuthStatus status, {
    required bool isSuperAdmin,
    required bool? sessionExpired,
    UserModel? user,
  }) {
    final uid = state.uid;
    final isActive = status == AuthStatus.active && uid != null;
    // Profili eksik kullanıcının üyeliği olamaz (Rules `activeUser()` ister):
    // dinleyici yalnızca aktif oturumda açıktır.
    if (!isActive) _stopMembershipWatch();
    state = state.copyWith(
      status: status,
      user: user,
      clearUser: user == null,
      clearSuspendReason: true,
      isSuperAdmin: isSuperAdmin,
      memberships: isActive ? null : const <String, MembershipModel>{},
      blockedUserIds: isActive ? null : const <String>{},
      isResolving: false,
      isError: false,
      sessionExpired: sessionExpired,
    );
    if (isActive) _watchMemberships(uid);
  }

  /// [uid] kullanıcısının üyeliklerini canlı dinlemeye başlar (PLAN §10.6
  /// #1). Aynı kullanıcı zaten dinleniyorsa etkisizdir; başka kullanıcının
  /// dinleyicisi önce bırakılır.
  void _watchMemberships(String uid) {
    if (_membershipsFor == uid && _membershipSubscription != null) return;
    _stopMembershipWatch();
    _membershipsFor = uid;
    _membershipSubscription = membershipRepository
        .watchMyMemberships(uid)
        .listen((event) => _onMemberships(uid, event));
  }

  void _stopMembershipWatch() {
    unawaited(_membershipSubscription?.cancel());
    _membershipSubscription = null;
    _membershipsFor = null;
  }

  /// Üyelik akışının olayı. Kapanmış ya da değişmiş oturumun geç gelen olayı
  /// yok sayılır.
  void _onMemberships(
    String uid,
    FirestoreResult<List<MembershipModel>> event,
  ) {
    if (!ref.mounted || _membershipsFor != uid || state.uid != uid) return;
    switch (event) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(
          memberships: {
            for (final membership in data) membership.clubId: membership,
          },
        );
      case FirebaseFailure(:final error):
        // Son bilinen üyelikler korunur (yetkiyi Rules uygular). Firestore
        // dinleyicisi hatadan sonra olay üretmez: abonelik bırakılır, bir
        // sonraki çözüm ([resolve] / [refreshUser]) yeniden bağlar.
        AppLogger.warn('Üyelik akışı hata verdi: ${error.name}');
        _stopMembershipWatch();
        if (error == FirestoreError.unauthenticated) onTokenExpired();
    }
  }

  /// Aktif oturumun engellediği kullanıcıları okur (tek seferlik). Okunamazsa
  /// mevcut küme korunur; eskimiş çözümün sonucu yazılmaz.
  Future<void> _refreshBlocks(String uid, int epoch) async {
    if (!_isCurrent(epoch) ||
        state.uid != uid ||
        state.status != AuthStatus.active) {
      return;
    }
    final result = await blockRepository.fetchActiveBlocks(uid);
    if (!_isCurrent(epoch) || state.uid != uid) return;
    switch (result) {
      case FirebaseSuccess(:final data):
        state = state.copyWith(blockedUserIds: data);
      case FirebaseFailure(:final error):
        AppLogger.warn('Engellenenler okunamadı: ${error.name}');
    }
  }

  /// Hesabı silinmiş (anonimleştirilmiş) kullanıcının oturumunu kapatır;
  /// state, oturum akışından gelen olayla `signedOut` olur.
  ///
  /// Oturum kapatılamazsa hesap uygulamada **kalmaz**: durum `unknown` +
  /// hata olur (R1 → SYS-01 → SYS-02 "Yeniden dene" kapatmayı yeniden dener).
  Future<void> _closeDeletedAccount(int epoch) async {
    // TODO(T-29): `accountDeletionRepository.resumeCleanup(uid)` + TST-22.
    _stopMembershipWatch();
    final result = await authRepository.signOut();
    if (result.isSuccess || !_isCurrent(epoch)) return;
    AppLogger.warn(
      'Silinmiş hesabın oturumu kapatılamadı: ${result.errorOrNull?.name}',
    );
    state = state.copyWith(
      status: AuthStatus.unknown,
      clearUser: true,
      isSuperAdmin: false,
      memberships: const <String, MembershipModel>{},
      blockedUserIds: const <String>{},
      isResolving: false,
      isError: true,
    );
  }

  /// Askıdaki kullanıcının gerekçesini okuyup oturumu askıya alır. Gerekçe
  /// yalnızca sahibine açık belgededir (CD-133) ve oturum kapandıktan sonra
  /// okunamaz; okunamazsa askı gerekçesiz uygulanır.
  Future<void> _suspendWithReason(UserModel user, int epoch) async {
    final account = await userRepository.getPrivateAccount(user.uid);
    if (!_isCurrent(epoch)) return;
    if (account case FirebaseFailure(:final error)) {
      AppLogger.warn('Askı gerekçesi okunamadı: ${error.name}');
    }
    _suspend(user: user, reason: account.dataOrNull?.suspendReason);
  }

  void _suspend({UserModel? user, String? reason}) {
    // Bekleyen çözümü geçersiz kılar: jeton hatası claim okuması sürerken
    // gelirse, önbellekteki jetonla başarı dönen eski çözüm askıyı `active`
    // ile ezmemelidir.
    _epoch++;
    // Bildirim bayrağı durumdan önce kalkar: durumu dinleyen giriş ekranı
    // bildirimi aynı anda isteyebilir.
    _suspendedNoticePending = true;
    _stopMembershipWatch();
    state = state.copyWith(
      status: AuthStatus.suspended,
      user: user,
      suspendReason: reason,
      isResolving: false,
      isError: false,
    );
    unawaited(_closeSuspendedSession());
  }

  void _onTokenError(AuthError error) {
    switch (error) {
      case AuthError.sessionExpired:
        onTokenExpired();
      case AuthError.userDisabled:
        // Askı zaten işlendiyse (durum `suspended`) ya da oturum bu arada
        // kapandıysa geç gelen olay yok sayılır: oturum iki kez kapatılmaz,
        // bildirim iki kez gösterilmez.
        if (state.uid != null && state.status != AuthStatus.suspended) {
          _suspend();
        }
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
    clearSuspendReason: true,
    isSuperAdmin: false,
    memberships: const <String, MembershipModel>{},
    blockedUserIds: const <String>{},
    isResolving: false,
    isError: false,
  );
}
