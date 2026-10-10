import 'package:gu_data/src/core/auth_error.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/storage_error.dart';

/// Bir Firebase çağrısının sonucu (D-34, PLAN §10.1).
///
/// [T] başarı verisinin, [E] çağrıyı yapan servisin hata sözlüğünün tipidir
/// (`FirestoreError`, `StorageError`, `AuthError`). Servisler istisna
/// fırlatmaz; her çağrı [FirebaseSuccess] ya da [FirebaseFailure] döner ve
/// çağıran `switch` ile iki dalı da ele alır:
///
/// ```dart
/// state = switch (result) {
///   FirebaseSuccess(:final data) => state.copyWith(items: data),
///   FirebaseFailure() => state.copyWith(isError: true),
/// };
/// ```
sealed class FirebaseResult<T, E> {
  /// Alt sınıflar için sabit kurucu.
  const FirebaseResult();

  /// Sonuç [FirebaseSuccess] ise `true`.
  bool get isSuccess => this is FirebaseSuccess<T, E>;

  /// Başarıda veri, başarısızlıkta `null`.
  ///
  /// [T] null olabilen bir tipse (ör. "belge yok" = `null`) başarı da `null`
  /// dönebilir; ayrım için [isSuccess] ya da `switch` kullanılır.
  T? get dataOrNull => switch (this) {
    FirebaseSuccess<T, E>(:final data) => data,
    FirebaseFailure<T, E>() => null,
  };

  /// Başarısızlıkta hata, başarıda `null`.
  E? get errorOrNull => switch (this) {
    FirebaseSuccess<T, E>() => null,
    FirebaseFailure<T, E>(:final error) => error,
  };

  /// İki dalı tek değere indirger: başarıda [onSuccess], başarısızlıkta
  /// [onFailure] (hata ve ham SDK mesajıyla) çağrılır.
  R fold<R>(
    R Function(T data) onSuccess,
    R Function(E error, String? message) onFailure,
  ) => switch (this) {
    FirebaseSuccess<T, E>(:final data) => onSuccess(data),
    FirebaseFailure<T, E>(:final error, :final message) => onFailure(
      error,
      message,
    ),
  };

  /// Başarı verisini [f] ile dönüştürür; başarısızlığı (hata, mesaj ve ek
  /// bilgisiyle) olduğu gibi taşır ve [f]'yi çağırmaz.
  FirebaseResult<U, E> map<U>(U Function(T data) f) => switch (this) {
    FirebaseSuccess<T, E>(:final data) => FirebaseSuccess<U, E>(f(data)),
    FirebaseFailure<T, E>(:final error, :final message, :final detail) =>
      FirebaseFailure<U, E>(error, message: message, detail: detail),
  };
}

/// Başarılı sonuç; [data] çağrının verisidir.
final class FirebaseSuccess<T, E> extends FirebaseResult<T, E> {
  /// [data] ile başarı sonucu oluşturur.
  const FirebaseSuccess(this.data);

  /// Çağrının verisi.
  final T data;

  @override
  String toString() => 'FirebaseSuccess($data)';
}

/// Başarısız sonuç; [error] servisin hata sözlüğünden bir değerdir.
final class FirebaseFailure<T, E> extends FirebaseResult<T, E> {
  /// [error] ile başarısızlık sonucu oluşturur.
  const FirebaseFailure(this.error, {this.message, this.detail});

  /// Hata türü.
  final E error;

  /// Ham SDK mesajı. Yalnızca günlüğe (`AppLogger`) yazılır; kullanıcıya
  /// **asla** gösterilmez.
  final String? message;

  /// Ek bilgi; yalnızca `FirestoreError.ruleViolation` / `conflict` ile
  /// doludur (`FirestoreFailureDetail`).
  final Object? detail;

  @override
  String toString() =>
      'FirebaseFailure($error'
      '${message == null ? '' : ', message: $message'}'
      '${detail == null ? '' : ', detail: $detail'})';
}

/// `FirestoreService` ve Firestore repository'lerinin sonuç tipi.
typedef FirestoreResult<T> = FirebaseResult<T, FirestoreError>;

/// `StorageService` sonuç tipi.
typedef StorageResult<T> = FirebaseResult<T, StorageError>;

/// `AuthService` sonuç tipi.
typedef AuthResult<T> = FirebaseResult<T, AuthError>;
