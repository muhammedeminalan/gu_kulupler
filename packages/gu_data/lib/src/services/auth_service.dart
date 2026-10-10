import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gu_data/src/constants/limits.dart';
import 'package:gu_data/src/core/auth_error.dart';
import 'package:gu_data/src/core/firebase_result.dart';

/// Oturumdaki kullanıcının kimlik bilgisi (PLAN §10.2).
///
/// SDK `User` tipinin dışarı çıkan tek karşılığıdır; ViewModel yalnızca bunu
/// görür.
final class AuthUserInfo extends Equatable {
  /// Kimlik bilgisini oluşturur.
  const AuthUserInfo({
    required this.uid,
    required this.email,
    required this.emailVerified,
  });

  /// Firebase Auth kullanıcı kimliği (`users/{uid}` belge kimliği).
  final String uid;

  /// Hesabın e-posta adresi; e-posta/şifre hesaplarında doludur.
  final String? email;

  /// E-posta doğrulanmış mı? [AuthService.reload] sonrasında güncellenir.
  final bool emailVerified;

  @override
  List<Object?> get props => [uid, email, emailVerified];
}

/// Kimlik (Firebase Auth) erişiminin tek kapısı (PLAN §10.2, D-34).
///
/// Servis **hamdır**: e-posta alan adı denetimi, giriş kilidi ve yeniden
/// gönderme beklemesi `AuthRepository` içindedir. Sonuç döndüren her metot
/// istisna fırlatmaz; hata [AuthError.fromCode] ile [FirebaseFailure]'a
/// çevrilir, zaman aşımı ([Limits.authTimeout]) [AuthError.network] olur.
///
/// Oturum gerektiren çağrılar ([sendEmailVerification], [reload],
/// [reauthenticate], [updatePassword], [idTokenClaims]) oturum yokken
/// [AuthError.sessionExpired] döner.
///
/// **Hesap silme yoktur (D-10, Q-11):** arayüzde Auth kimliğini kaldıran bir
/// üye bulunmaz; hesap silme anonimleştirmedir (`AccountDeletionRepository`).
abstract interface class AuthService {
  /// Oturumdaki kullanıcı; oturum yoksa `null`.
  AuthUserInfo? get currentUser;

  /// Oturum açılış/kapanışlarını yayınlar (dinleyene önce güncel durum
  /// gelir). Claim yenilemeleri bu akışı tetiklemez; [idTokenClaims] ile
  /// açıkça okunur.
  Stream<AuthUserInfo?> authStateChanges();

  /// Oturumu geçersiz kılan hatalar: oturum gerektiren bir çağrı
  /// [AuthError.sessionExpired] ya da [AuthError.userDisabled] ile
  /// sonuçlandığında (jeton iptali, hesabın askıya alınması) ve SDK oturum
  /// akışı hata verdiğinde yayınlanır. Kök oturum katmanı dinler (DLG-27,
  /// DLG-01). Yayın akışıdır; geçmiş olaylar tekrar edilmez.
  Stream<AuthError> get tokenErrors;

  /// E-posta ve şifreyle yeni hesap açar; oturum açılmış olarak döner.
  Future<AuthResult<AuthUserInfo>> register({
    required String email,
    required String password,
  });

  /// E-posta ve şifreyle oturum açar.
  Future<AuthResult<AuthUserInfo>> signIn({
    required String email,
    required String password,
  });

  /// Oturumu kapatır.
  Future<AuthResult<void>> signOut();

  /// Oturumdaki kullanıcıya doğrulama e-postası gönderir (Firebase'in
  /// yerleşik bağlantısı, Q-04).
  Future<AuthResult<void>> sendEmailVerification();

  /// Oturumdaki kullanıcıyı sunucudan yeniler ve güncel bilgisini döndürür
  /// (AUT-03 "Doğruladım").
  Future<AuthResult<AuthUserInfo>> reload();

  /// [email] adresine şifre sıfırlama bağlantısı gönderir.
  Future<AuthResult<void>> sendPasswordReset({required String email});

  /// Oturumdaki kullanıcıyı [password] ile yeniden doğrular (hassas işlem
  /// öncesi; SHT-32, SET-03).
  Future<AuthResult<void>> reauthenticate({required String password});

  /// Oturumdaki kullanıcının şifresini [newPassword] yapar; SDK yakın zamanda
  /// giriş isterse [AuthError.requiresRecentLogin].
  Future<AuthResult<void>> updatePassword({required String newPassword});

  /// Oturumdaki kullanıcının kimlik jetonu claim'leri (`superadmin` buradan
  /// okunur, D-28). [forceRefresh] jetonu sunucudan yeniler.
  Future<AuthResult<Map<String, Object?>>> idTokenClaims({
    bool forceRefresh = false,
  });
}

/// [AuthService] uygulaması: `firebase_auth` SDK'sını sarar.
final class FirebaseAuthService implements AuthService {
  /// Verilen `FirebaseAuth` örneğini sarar; her ağ çağrısı `timeout`
  /// (varsayılan [Limits.authTimeout]) içinde dönmezse [AuthError.network]
  /// ile sonuçlanır.
  FirebaseAuthService(this._auth, {this._timeout = Limits.authTimeout});

  final FirebaseAuth _auth;
  final Duration _timeout;
  final StreamController<AuthError> _tokenErrors =
      StreamController<AuthError>.broadcast();

  @override
  AuthUserInfo? get currentUser => _infoOrNull(_auth.currentUser);

  @override
  Stream<AuthUserInfo?> authStateChanges() =>
      _auth.authStateChanges().transform(
        StreamTransformer<User?, AuthUserInfo?>.fromHandlers(
          handleData: (user, sink) => sink.add(_infoOrNull(user)),
          handleError: (error, _, _) => _emitTokenError(_errorOf(error)),
        ),
      );

  @override
  Stream<AuthError> get tokenErrors => _tokenErrors.stream;

  @override
  Future<AuthResult<AuthUserInfo>> register({
    required String email,
    required String password,
  }) => _guard(
    () async => _info(
      (await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      )).user,
    ),
  );

  @override
  Future<AuthResult<AuthUserInfo>> signIn({
    required String email,
    required String password,
  }) => _guard(
    () async => _info(
      (await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      )).user,
    ),
  );

  @override
  Future<AuthResult<void>> signOut() => _guard(_auth.signOut);

  @override
  Future<AuthResult<void>> sendEmailVerification() =>
      _withUser((user) => user.sendEmailVerification());

  @override
  Future<AuthResult<AuthUserInfo>> reload() => _withUser((user) async {
    await user.reload();
    return _info(_auth.currentUser);
  });

  @override
  Future<AuthResult<void>> sendPasswordReset({required String email}) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email));

  @override
  Future<AuthResult<void>> reauthenticate({required String password}) =>
      _withUser((user) async {
        final email = user.email;
        if (email == null) {
          throw FirebaseAuthException(
            code: _operationNotAllowed,
            message: 'reauthenticate: kullanıcının e-posta adresi yok',
          );
        }
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
      });

  @override
  Future<AuthResult<void>> updatePassword({required String newPassword}) =>
      _withUser((user) => user.updatePassword(newPassword));

  @override
  Future<AuthResult<Map<String, Object?>>> idTokenClaims({
    bool forceRefresh = false,
  }) => _withUser(
    (user) async => Map<String, Object?>.unmodifiable(
      (await user.getIdTokenResult(forceRefresh)).claims ?? const {},
    ),
  );

  /// [tokenErrors] akışını kapatır. Servis uygulama ömrü boyunca yaşar;
  /// yalnızca DI sıfırlanırken (test, yeniden kurulum) çağrılır.
  Future<void> dispose() => _tokenErrors.close();

  /// Oturumdaki kullanıcıyla [action] çalıştırır; oturum yoksa
  /// [AuthError.sessionExpired]. Oturumu geçersiz kılan hatalar ayrıca
  /// [tokenErrors] akışına yazılır.
  Future<AuthResult<T>> _withUser<T>(Future<T> Function(User user) action) =>
      _guard(() {
        final user = _auth.currentUser;
        if (user == null) throw const _NoSessionException();
        return action(user);
      }, sessionBound: true);

  /// [action] çağrısını zaman aşımıyla sarar ve her hatayı [FirebaseFailure]'a
  /// çevirir (PLAN §10.1).
  Future<AuthResult<T>> _guard<T>(
    Future<T> Function() action, {
    bool sessionBound = false,
  }) async {
    try {
      return FirebaseSuccess(await action().timeout(_timeout));
    } on _NoSessionException {
      return const FirebaseFailure(AuthError.sessionExpired);
    } on Object catch (error) {
      final mapped = _errorOf(error, sessionBound: sessionBound);
      if (sessionBound && _invalidatesSession(mapped)) _emitTokenError(mapped);
      return FirebaseFailure(mapped, message: _messageOf(error));
    }
  }

  void _emitTokenError(AuthError error) {
    if (!_tokenErrors.isClosed) _tokenErrors.add(error);
  }

  static bool _invalidatesSession(AuthError error) =>
      error == AuthError.sessionExpired || error == AuthError.userDisabled;

  /// SDK hatasını sözlüğe çevirir. Oturum gerektiren çağrıda `user-not-found`
  /// "hatalı giriş" değil, hesabın artık var olmadığı anlamına gelir →
  /// [AuthError.sessionExpired].
  static AuthError _errorOf(Object error, {bool sessionBound = false}) =>
      switch (error) {
        TimeoutException() => AuthError.network,
        FirebaseException(code: _userNotFound) when sessionBound =>
          AuthError.sessionExpired,
        FirebaseException(:final code) => AuthError.fromCode(code),
        _ => AuthError.unknown,
      };

  static String? _messageOf(Object error) => switch (error) {
    TimeoutException(:final message) => message,
    FirebaseException(:final message) => message,
    _ => error.toString(),
  };

  static AuthUserInfo? _infoOrNull(User? user) => user == null
      ? null
      : AuthUserInfo(
          uid: user.uid,
          email: user.email,
          emailVerified: user.emailVerified,
        );

  /// SDK başarılı dönüp kullanıcı vermediyse oturum yoktur.
  static AuthUserInfo _info(User? user) =>
      _infoOrNull(user) ?? (throw const _NoSessionException());

  static const String _userNotFound = 'user-not-found';
  static const String _operationNotAllowed = 'operation-not-allowed';
}

/// Oturum gerektiren çağrı oturum yokken yapıldı.
final class _NoSessionException implements Exception {
  const _NoSessionException();
}
