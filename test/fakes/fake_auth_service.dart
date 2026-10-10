// `AuthService` fake'i (PLAN §16.3): oturumu bellekte tutar.
//
//   final auth = FakeAuthService()..emailVerified = true;
//   await auth.signIn(email: email, password: password);
//   auth.failNext(AuthError.requiresRecentLogin);
//   auth.authStateController.add(null); // oturum dışarıdan düştü
//
// Gerçek servis gibi: oturum gerektiren çağrılar oturum yokken
// `AuthError.sessionExpired` döner; `authStateChanges()` dinleyene önce güncel
// durumu verir. Hesap silme yoktur (D-10, Q-11).
import 'dart:async';

import 'package:gu_data/gu_data.dart';

import 'fake_base.dart';

final class FakeAuthService extends FakeBase implements AuthService {
  /// Oturum olaylarının denetleyicisi; [signIn] / [register] / [signOut]
  /// buraya yazar, test de doğrudan yazabilir.
  final StreamController<AuthUserInfo?> authStateController =
      StreamController<AuthUserInfo?>.broadcast();

  /// [tokenErrors] akışının denetleyicisi.
  final StreamController<AuthError> tokenErrorController =
      StreamController<AuthError>.broadcast();

  /// Oturumdaki kullanıcı; `null` = oturum yok.
  @override
  AuthUserInfo? currentUser;

  /// Sunucudaki "e-posta doğrulandı" durumu: [signIn] ve [reload] bunu
  /// [currentUser]'a yansıtır ([register] her zaman doğrulanmamış açar).
  bool emailVerified = false;

  /// [signIn] / [register] ile açılan oturumun uid'i.
  String uid = 'fake-uid';

  /// [idTokenClaims] sonucu (`{'superadmin': true}` gibi).
  Map<String, Object?> claims = <String, Object?>{};

  @override
  Stream<AuthUserInfo?> authStateChanges() =>
      Stream<AuthUserInfo?>.multi((listener) {
        listener.add(currentUser);
        final subscription = authStateController.stream.listen(
          listener.add,
          onError: listener.addError,
          onDone: listener.close,
        );
        listener.onCancel = subscription.cancel;
      });

  @override
  Stream<AuthError> get tokenErrors => tokenErrorController.stream;

  @override
  Future<AuthResult<AuthUserInfo>> register({
    required String email,
    required String password,
  }) async {
    record('register', [email, password]);
    if (_failure() case final error?) return FirebaseFailure(error);
    return FirebaseSuccess(_open(email, verified: false));
  }

  @override
  Future<AuthResult<AuthUserInfo>> signIn({
    required String email,
    required String password,
  }) async {
    record('signIn', [email, password]);
    if (_failure() case final error?) return FirebaseFailure(error);
    return FirebaseSuccess(_open(email, verified: emailVerified));
  }

  @override
  Future<AuthResult<void>> signOut() async {
    record('signOut');
    if (_failure() case final error?) return FirebaseFailure(error);
    currentUser = null;
    authStateController.add(null);
    return const FirebaseSuccess(null);
  }

  @override
  Future<AuthResult<void>> sendEmailVerification() async {
    record('sendEmailVerification');
    return _session((_) {});
  }

  @override
  Future<AuthResult<AuthUserInfo>> reload() async {
    record('reload');
    return _session(
      (user) => currentUser = AuthUserInfo(
        uid: user.uid,
        email: user.email,
        emailVerified: emailVerified,
      ),
    );
  }

  @override
  Future<AuthResult<void>> sendPasswordReset({required String email}) async {
    record('sendPasswordReset', [email]);
    if (_failure() case final error?) return FirebaseFailure(error);
    return const FirebaseSuccess(null);
  }

  @override
  Future<AuthResult<void>> reauthenticate({required String password}) async {
    record('reauthenticate', [password]);
    return _session((_) {});
  }

  @override
  Future<AuthResult<void>> updatePassword({required String newPassword}) async {
    record('updatePassword', [newPassword]);
    return _session((_) {});
  }

  @override
  Future<AuthResult<Map<String, Object?>>> idTokenClaims({
    bool forceRefresh = false,
  }) async {
    record('idTokenClaims', [forceRefresh]);
    return _session((_) => Map<String, Object?>.of(claims));
  }

  AuthUserInfo _open(String email, {required bool verified}) {
    final user = AuthUserInfo(uid: uid, email: email, emailVerified: verified);
    currentUser = user;
    authStateController.add(user);
    return user;
  }

  /// Oturum gerektiren çağrı: bekleyen hata → hata; oturum yok →
  /// `sessionExpired`; aksi halde [body] sonucu.
  AuthResult<T> _session<T>(T Function(AuthUserInfo user) body) {
    if (_failure() case final error?) return FirebaseFailure(error);
    final user = currentUser;
    if (user == null) return const FirebaseFailure(AuthError.sessionExpired);
    return FirebaseSuccess(body(user));
  }

  AuthError? _failure() => switch (takeFailure()) {
    null => null,
    final AuthError error => error,
    _ => AuthError.unknown,
  };
}
