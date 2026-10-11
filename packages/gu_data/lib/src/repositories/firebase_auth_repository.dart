import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/app_clock.dart';
import 'package:gu_data/src/core/auth_error.dart';
import 'package:gu_data/src/core/auth_failure_detail.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/repositories/auth_repository.dart';
import 'package:gu_data/src/services/auth_service.dart';
import 'package:gu_data/src/utils/email_domain_validator.dart';
import 'package:gu_data/src/utils/login_throttle.dart';

/// [AuthRepository] uygulaması: [AuthService] + uygulama kuralları
/// (PLAN §10.4).
///
/// Giriş kilidi ve yeniden gönderme beklemesi **bellekte** tutulur (bu
/// nesnenin ömrü = uygulama ömrü) ve zamanı yalnızca [AppClock]'tan okur.
final class FirebaseAuthRepository implements AuthRepository {
  /// [_auth] servisini sarar. `loginThrottle` verilmezse `Limits`
  /// sınırlarıyla yenisi kurulur.
  FirebaseAuthRepository(
    this._auth,
    this._clock, {
    LoginThrottle? loginThrottle,
  }) : _throttle = loginThrottle ?? LoginThrottle(_clock);

  final AuthService _auth;
  final AppClock _clock;
  final LoginThrottle _throttle;

  /// Son doğrulama e-postasının gönderildiği an ve alıcısı.
  DateTime? _verificationSentAt;
  String? _verificationSentUid;

  /// ID token'daki süper admin claim'inin adı (D-28; Rules `isSuper()`).
  static const String superAdminClaim = 'superadmin';

  static final RegExp _passwordPolicy = RegExp(
    Limits.passwordPattern,
    unicode: true,
  );

  @override
  Stream<AuthUserInfo?> watchAuthState() => _auth.authStateChanges();

  @override
  AuthUserInfo? get currentUser => _auth.currentUser;

  @override
  Stream<AuthError> get tokenErrors => _auth.tokenErrors;

  @override
  Future<AuthResult<AuthUserInfo>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final address = email.trim();
    if (_rejectAddress(address) case final error?) {
      return FirebaseFailure(error);
    }
    if (!_passwordPolicy.hasMatch(password)) {
      return const FirebaseFailure(AuthError.weakPassword);
    }
    final result = await _auth.register(
      email: address,
      password: password,
      displayName: name.trim(),
    );
    if (result case FirebaseSuccess(data: final user)) {
      final sent = await _auth.sendEmailVerification();
      if (sent.isSuccess) _markVerificationSent(user.uid);
    }
    return result;
  }

  @override
  Future<AuthResult<AuthUserInfo>> signIn({
    required String email,
    required String password,
  }) async {
    final address = email.trim();
    if (_rejectAddress(address) case final error?) {
      return FirebaseFailure(error);
    }
    final now = _clock.nowUtc();
    if (_throttle.check(address) case final lockedUntil?) {
      return _waitFailure(AuthError.lockedOut, lockedUntil, now);
    }
    final result = await _auth.signIn(email: address, password: password);
    switch (result) {
      case FirebaseSuccess():
        _throttle.reset(address);
      case FirebaseFailure(error: AuthError.invalidCredentials):
        _throttle.recordFailure(address);
      case FirebaseFailure():
        break;
    }
    return result;
  }

  @override
  Duration? loginLockRemaining(String email) => _throttle.remaining(email);

  @override
  Future<AuthResult<void>> signOut() => _auth.signOut();

  @override
  Future<AuthResult<void>> sendEmailVerification() async {
    final now = _clock.nowUtc();
    if (_resendAvailableAt(now) case final availableAt?) {
      return _waitFailure(AuthError.resendCooldown, availableAt, now);
    }
    final uid = _auth.currentUser?.uid;
    final result = await _auth.sendEmailVerification();
    if (result.isSuccess && uid != null) _markVerificationSent(uid);
    return result;
  }

  @override
  Duration? get resendCooldownRemaining {
    final now = _clock.nowUtc();
    return _resendAvailableAt(now)?.difference(now);
  }

  @override
  Future<AuthResult<AuthUserInfo>> reloadUser() async {
    final result = await _auth.reload();
    if (result case FirebaseSuccess(data: final user)) {
      if (!user.emailVerified) {
        return const FirebaseFailure(AuthError.emailNotVerified);
      }
      // Rules `email_verified` bilgisini jetondan okur: doğrulama sonrası
      // jeton yenilenmezse Firestore çağrıları reddedilir.
      final refreshed = await _auth.idTokenClaims(forceRefresh: true);
      if (refreshed case FirebaseFailure(:final error, :final message)) {
        return FirebaseFailure(error, message: message);
      }
    }
    return result;
  }

  @override
  Future<AuthResult<void>> sendPasswordReset({required String email}) async {
    final result = await _auth.sendPasswordReset(email: email.trim());
    // Hesabın var olup olmadığı sızdırılmaz.
    return result.errorOrNull == AuthError.invalidCredentials
        ? const FirebaseSuccess(null)
        : result;
  }

  @override
  Future<AuthResult<void>> reauthenticate({required String password}) =>
      _auth.reauthenticate(password: password);

  @override
  Future<AuthResult<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!_passwordPolicy.hasMatch(newPassword)) {
      return const FirebaseFailure(AuthError.weakPassword);
    }
    final verified = await _auth.reauthenticate(password: currentPassword);
    if (!verified.isSuccess) return verified;
    return _auth.updatePassword(newPassword: newPassword);
  }

  @override
  Future<AuthResult<bool>> isSuperAdmin({bool forceRefresh = false}) async {
    final claims = await _auth.idTokenClaims(forceRefresh: forceRefresh);
    return claims.map((data) => data[superAdminClaim] == true);
  }

  /// [address] kayıt/giriş için kabul edilemezse hatası, edilebilirse
  /// `null`: biçim → [AuthError.invalidEmail], alan adı →
  /// [AuthError.domainNotAllowed] (D-27).
  static AuthError? _rejectAddress(String address) {
    if (!EmailDomainValidator.isWellFormed(address)) {
      return AuthError.invalidEmail;
    }
    if (!EmailDomainValidator.isAllowedDomain(address)) {
      return AuthError.domainNotAllowed;
    }
    return null;
  }

  void _markVerificationSent(String uid) {
    _verificationSentAt = _clock.nowUtc();
    _verificationSentUid = uid;
  }

  /// Oturumdaki kullanıcı için yeniden göndermenin serbest kalacağı an;
  /// [now] anında bekleme yoksa (ya da son gönderim başka bir hesaba aitse)
  /// `null`.
  DateTime? _resendAvailableAt(DateTime now) {
    final sentAt = _verificationSentAt;
    if (sentAt == null || _verificationSentUid != _auth.currentUser?.uid) {
      return null;
    }
    final availableAt = sentAt.add(Limits.verificationResendCooldown);
    return now.isBefore(availableAt) ? availableAt : null;
  }

  /// [now] anında, [retryAfter] anına kadar beklenmesi gereken [error]
  /// başarısızlığı.
  static AuthResult<T> _waitFailure<T>(
    AuthError error,
    DateTime retryAfter,
    DateTime now,
  ) => FirebaseFailure(
    error,
    detail: AuthFailureDetail(
      retryAfter: retryAfter,
      remaining: retryAfter.difference(now),
    ),
  );
}
