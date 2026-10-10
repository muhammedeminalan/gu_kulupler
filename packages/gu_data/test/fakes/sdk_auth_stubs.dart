// El yazımı `firebase_auth` SDK çiftleri (mock kütüphanesi yok —
// docs/testing.md §1.2). `firebase_auth_mocks` hata betiklemek için geçişli
// bir pakete ihtiyaç duyduğundan hata eşleme ve zaman aşımı testleri bunları
// kullanır.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// Betiklenen çağrı sonucu: [error] doluysa o hatayla biter, boşsa **hiç
/// tamamlanmaz** (zaman aşımı testleri).
Future<T> _outcome<T>(Object? error) =>
    error == null ? Completer<T>().future : Future<T>.error(error);

/// `firebase_auth` kaynaklı hata.
FirebaseAuthException authException(String code, {String? message}) =>
    FirebaseAuthException(code: code, message: message);

/// Her ağ çağrısı [error] ile biten (ya da askıda kalan) kullanıcı.
final class StubUser implements User {
  /// [error] verilmezse çağrılar askıda kalır.
  StubUser({
    this.error,
    this.uid = 'u_ayse',
    this.email = 'ayse@ogr.gumushane.edu.tr',
    this.emailVerified = true,
  });

  /// Her çağrının fırlattığı hata; `null` ise çağrı tamamlanmaz.
  final Object? error;

  @override
  final String uid;

  @override
  final String? email;

  @override
  final bool emailVerified;

  /// [reauthenticateWithCredential] çağrısına verilen son kimlik bilgisi.
  AuthCredential? lastCredential;

  @override
  Future<void> reload() => _outcome(error);

  @override
  Future<void> sendEmailVerification([
    ActionCodeSettings? actionCodeSettings,
  ]) => _outcome(error);

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential credential,
  ) {
    lastCredential = credential;
    return _outcome(error);
  }

  @override
  Future<void> updatePassword(String newPassword) => _outcome(error);

  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) =>
      _outcome(error);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Her ağ çağrısı [error] ile biten (ya da askıda kalan) Auth örneği.
/// [stateEvents] ile oturum akışı olayları elle üretilir.
final class StubFirebaseAuth implements FirebaseAuth {
  /// [error] verilmezse çağrılar askıda kalır; [currentUser] oturumdaki
  /// kullanıcıdır.
  StubFirebaseAuth({this.error, this.currentUser});

  /// Her çağrının fırlattığı hata; `null` ise çağrı tamamlanmaz.
  final Object? error;

  @override
  final User? currentUser;

  /// [authStateChanges] akışının denetleyicisi.
  final StreamController<User?> stateEvents = StreamController<User?>();

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => _outcome(error);

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) => _outcome(error);

  @override
  Future<void> signOut() => _outcome(error);

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) => _outcome(error);

  @override
  Stream<User?> authStateChanges() => stateEvents.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
