// `AuthRepository` fake'i (PLAN §16.3): gerçek `FirebaseAuthRepository`'yi
// bellekteki `FakeAuthService` üzerinde çalıştırır — giriş kilidi (5 hatalı
// deneme / 30 sn), doğrulama e-postası beklemesi (60 sn), alan adı ve şifre
// ön denetimleri gerçek repository ile **aynı koddur** (`FakeFirestoreService`
// kalıbı); üstüne çağrı günlüğü, tek seferlik hata (`failNext`) ve test
// yüzeyi ekler.
//
//   final auth = FakeAuthRepository(clock)..service.emailVerified = true;
//   await auth.register(email: email, password: password, name: 'Ayşe Yılmaz');
//   auth.currentUser!.displayName;             // 'Ayşe Yılmaz' (CD-134)
//   auth.service.displayName = 'Ayşe Yılmaz';  // başka cihazda kayıt olmuş
//   await auth.signIn(email: email, password: password);
//   auth.isSuperAdminResult = true;
//   auth.failNext(AuthError.network);          // repository düzeyinde hata
//   auth.service.failNext(AuthError.invalidCredentials); // SDK cevabı (sayılır)
//   auth.watchAuthStateController.add(null);   // oturum dışarıdan düştü
//
// Zaman yalnızca verilen saatten okunur: kilit ve bekleme `FakeAppClock`
// ilerletilerek sınanır. Hesap silme yoktur (D-10, Q-11).
import 'dart:async';

import 'package:gu_data/gu_data.dart';

import 'fake_auth_service.dart';
import 'fake_base.dart';

/// Giriş çağrısının kimlik bilgisi.
typedef FakeCredentials = ({String email, String password});

/// Başarıyla açılan hesabın kayıt bilgisi (form değerleri, kırpılmadan).
typedef FakeRegistration = ({String email, String password, String name});

final class FakeAuthRepository extends FakeBase implements AuthRepository {
  /// [clock] kilit ve bekleme sürelerinin saatidir. [service] verilmezse yeni
  /// bir `FakeAuthService` kurulur; `registerDefaultFakes` GetIt'teki servis
  /// fake'ini verir (ikisi aynı oturumu görür).
  FakeAuthRepository(AppClock clock, {FakeAuthService? service})
    : service = service ?? FakeAuthService() {
    _real = FirebaseAuthRepository(this.service, clock);
  }

  /// Alttaki kimlik servisi fake'i: sunucu durumu (`emailVerified`, `uid`) ve
  /// SDK cevabı olarak sayılan hatalar (`service.failNext`) buradan kurulur.
  final FakeAuthService service;

  late final AuthRepository _real;

  /// Başarıyla açılan hesaplar, sırasıyla.
  final List<FakeRegistration> registered = <FakeRegistration>[];

  /// Tüm giriş denemeleri (başarısız ve kilide takılanlar dahil), sırasıyla.
  final List<FakeCredentials> signInAttempts = <FakeCredentials>[];

  /// Şifre sıfırlama bağlantısı istenen adresler (başarılı çağrılar).
  final List<String> resetSent = <String>[];

  /// Oturum olaylarının denetleyicisi (`service.authStateController`).
  StreamController<AuthUserInfo?> get watchAuthStateController =>
      service.authStateController;

  /// [tokenErrors] akışının denetleyicisi.
  StreamController<AuthError> get tokenErrorController =>
      service.tokenErrorController;

  /// [isSuperAdmin] sonucu (jetondaki `superadmin` claim'i).
  bool get isSuperAdminResult =>
      service.claims[FirebaseAuthRepository.superAdminClaim] == true;

  set isSuperAdminResult(bool value) => service.claims = <String, Object?>{
    FirebaseAuthRepository.superAdminClaim: value,
  };

  /// Verilirse [isSuperAdmin] sonuç dönmeden önce bunu bekler: çözüm sürerken
  /// araya giren olayların (yarış) sırası testte elle kurulur.
  Completer<void>? get superAdminGate => service.claimsGate;

  set superAdminGate(Completer<void>? gate) => service.claimsGate = gate;

  @override
  AuthUserInfo? get currentUser => _real.currentUser;

  /// Oturumu olay yayınlamadan kurar (açılışta hazır oturum).
  set currentUser(AuthUserInfo? user) => service.currentUser = user;

  @override
  Stream<AuthUserInfo?> watchAuthState() => _real.watchAuthState();

  @override
  Stream<AuthError> get tokenErrors => _real.tokenErrors;

  @override
  Future<AuthResult<AuthUserInfo>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    record('register', [email, password, name]);
    if (_failure() case final error?) return FirebaseFailure(error);
    final result = await _real.register(
      email: email,
      password: password,
      name: name,
    );
    if (result.isSuccess) {
      registered.add((email: email, password: password, name: name));
    }
    return result;
  }

  @override
  Future<AuthResult<AuthUserInfo>> signIn({
    required String email,
    required String password,
  }) async {
    record('signIn', [email, password]);
    signInAttempts.add((email: email, password: password));
    if (_failure() case final error?) return FirebaseFailure(error);
    return _real.signIn(email: email, password: password);
  }

  @override
  Duration? loginLockRemaining(String email) => _real.loginLockRemaining(email);

  @override
  Future<AuthResult<void>> signOut() async {
    record('signOut');
    if (_failure() case final error?) return FirebaseFailure(error);
    return _real.signOut();
  }

  @override
  Future<AuthResult<void>> sendEmailVerification() async {
    record('sendEmailVerification');
    if (_failure() case final error?) return FirebaseFailure(error);
    return _real.sendEmailVerification();
  }

  @override
  Duration? get resendCooldownRemaining => _real.resendCooldownRemaining;

  @override
  Future<AuthResult<AuthUserInfo>> reloadUser() async {
    record('reloadUser');
    if (_failure() case final error?) return FirebaseFailure(error);
    return _real.reloadUser();
  }

  @override
  Future<AuthResult<void>> sendPasswordReset({required String email}) async {
    record('sendPasswordReset', [email]);
    if (_failure() case final error?) return FirebaseFailure(error);
    final result = await _real.sendPasswordReset(email: email);
    if (result.isSuccess) resetSent.add(email);
    return result;
  }

  @override
  Future<AuthResult<void>> reauthenticate({required String password}) async {
    record('reauthenticate', [password]);
    if (_failure() case final error?) return FirebaseFailure(error);
    return _real.reauthenticate(password: password);
  }

  @override
  Future<AuthResult<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    record('changePassword', [currentPassword, newPassword]);
    if (_failure() case final error?) return FirebaseFailure(error);
    return _real.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  @override
  Future<AuthResult<bool>> isSuperAdmin({bool forceRefresh = false}) async {
    record('isSuperAdmin', [forceRefresh]);
    if (_failure() case final error?) return FirebaseFailure(error);
    return _real.isSuperAdmin(forceRefresh: forceRefresh);
  }

  AuthError? _failure() => switch (takeFailure()) {
    null => null,
    final AuthError error => error,
    _ => AuthError.unknown,
  };
}
