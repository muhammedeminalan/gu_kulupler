// Betiklenebilir `AuthService` çifti: repository testleri servisin hangi
// sırayla, hangi değerlerle çağrıldığını ve betiklenen hatalara nasıl tepki
// verildiğini bununla sınar (mock kütüphanesi yok — docs/testing.md §1.2).
//
//   final auth = ScriptedAuthService()..failNext('signIn', AuthError.network);
//   await repository.signIn(email: email, password: password);
//   expect(auth.calls, ['signIn:$email']);
import 'dart:async';

import 'package:gu_data/gu_data.dart';

/// Bellekte oturum tutan, çağrıları kaydeden ve metot başına hata kuyruğu
/// betiklenebilen [AuthService].
final class ScriptedAuthService implements AuthService {
  /// Yapılan çağrılar, sırayla: `metot` ya da `metot:argüman`.
  final List<String> calls = [];

  /// Oturum akışının denetleyicisi.
  final StreamController<AuthUserInfo?> stateEvents =
      StreamController<AuthUserInfo?>.broadcast();

  /// [tokenErrors] akışının denetleyicisi.
  final StreamController<AuthError> tokenErrorEvents =
      StreamController<AuthError>.broadcast();

  final Map<String, List<AuthError>> _failures = {};

  @override
  AuthUserInfo? currentUser;

  /// [signIn] / [register] ile açılan oturumun uid'i.
  String uid = 'u_ayse';

  /// Sunucudaki "e-posta doğrulandı" durumu; [reload] bunu yansıtır.
  bool emailVerified = false;

  /// [idTokenClaims] sonucu.
  Map<String, Object?> claims = {};

  /// Sunucudaki görünen ad: [register] yazar; [signIn] ve [reload] oturuma
  /// yansıtır.
  String? displayName;

  /// [register] çağrılarına verilen görünen adlar, sırasıyla (`null` =
  /// verilmedi).
  final List<String?> registeredNames = [];

  /// [method] metodunun sonraki [times] çağrısı [error] ile biter.
  void failNext(String method, AuthError error, {int times = 1}) =>
      _failures.putIfAbsent(method, () => []).addAll(List.filled(times, error));

  /// [method] metodunun kaç kez çağrıldığı.
  int count(String method) => calls
      .where((call) => call == method || call.startsWith('$method:'))
      .length;

  /// Akış denetleyicilerini kapatır.
  Future<void> dispose() async {
    await stateEvents.close();
    await tokenErrorEvents.close();
  }

  @override
  Stream<AuthUserInfo?> authStateChanges() => stateEvents.stream;

  @override
  Stream<AuthError> get tokenErrors => tokenErrorEvents.stream;

  @override
  Future<AuthResult<AuthUserInfo>> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    registeredNames.add(displayName);
    return _run('register:$email', () {
      this.displayName = displayName;
      return _open(email, verified: false);
    });
  }

  @override
  Future<AuthResult<AuthUserInfo>> signIn({
    required String email,
    required String password,
  }) async =>
      _run('signIn:$email', () => _open(email, verified: emailVerified));

  @override
  Future<AuthResult<void>> signOut() async =>
      _run('signOut', () => currentUser = null);

  @override
  Future<AuthResult<void>> sendEmailVerification() async =>
      _session('sendEmailVerification', (_) {});

  @override
  Future<AuthResult<AuthUserInfo>> reload() async => _session(
    'reload',
    (user) => currentUser = AuthUserInfo(
      uid: user.uid,
      email: user.email,
      emailVerified: emailVerified,
      displayName: displayName,
    ),
  );

  @override
  Future<AuthResult<void>> sendPasswordReset({required String email}) async =>
      _run('sendPasswordReset:$email', () {});

  @override
  Future<AuthResult<void>> reauthenticate({required String password}) async =>
      _session('reauthenticate:$password', (_) {});

  @override
  Future<AuthResult<void>> updatePassword({
    required String newPassword,
  }) async => _session('updatePassword:$newPassword', (_) {});

  @override
  Future<AuthResult<Map<String, Object?>>> idTokenClaims({
    bool forceRefresh = false,
  }) async => _session('idTokenClaims:$forceRefresh', (_) => Map.of(claims));

  AuthUserInfo _open(String email, {required bool verified}) =>
      currentUser = AuthUserInfo(
        uid: uid,
        email: email,
        emailVerified: verified,
        displayName: displayName,
      );

  /// Çağrıyı kaydeder; betiklenmiş hata varsa onu, yoksa [body] sonucunu
  /// döndürür.
  AuthResult<T> _run<T>(String call, T Function() body) {
    calls.add(call);
    final queue = _failures[call.split(':').first];
    if (queue != null && queue.isNotEmpty) {
      return FirebaseFailure(queue.removeAt(0));
    }
    return FirebaseSuccess(body());
  }

  /// Oturum gerektiren çağrı: oturum yoksa `sessionExpired`.
  AuthResult<T> _session<T>(String call, T Function(AuthUserInfo user) body) {
    final user = currentUser;
    if (user == null) {
      calls.add(call);
      return const FirebaseFailure(AuthError.sessionExpired);
    }
    return _run(call, () => body(user));
  }
}
