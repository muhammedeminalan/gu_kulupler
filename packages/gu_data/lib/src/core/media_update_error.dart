import 'package:equatable/equatable.dart';
import 'package:gu_data/src/core/firebase_result.dart';
import 'package:gu_data/src/core/firestore_error.dart';
import 'package:gu_data/src/core/storage_error.dart';

/// Görsel yükleyip Firestore yol alanını yazan repository metotlarının hata
/// türü (`UserRepository.updateAvatar`; D-34).
///
/// İşlem iki adımdır ve her adımın kendi hata sözlüğü vardır; hata hangi
/// adımda oluştuysa o sözlüğün değerini taşır:
///
/// ```dart
/// switch (result) {
///   case FirebaseSuccess(data: final path): …
///   case FirebaseFailure(error: MediaUploadError(:final error)): …
///   case FirebaseFailure(error: MediaDocumentError(:final error)): …
/// }
/// ```
sealed class MediaUpdateError extends Equatable {
  const MediaUpdateError();

  /// Yükleme adımının hatası; hata belge adımındaysa `null`.
  StorageError? get storage => switch (this) {
    MediaUploadError(:final error) => error,
    MediaDocumentError() => null,
  };

  /// Belge adımının (ön koşul okuması ya da yol alanı yazımı) hatası; hata
  /// yükleme adımındaysa `null`.
  FirestoreError? get firestore => switch (this) {
    MediaUploadError() => null,
    MediaDocumentError(:final error) => error,
  };
}

/// Dosya Storage'a yüklenemedi; Firestore'a hiçbir şey yazılmadı.
final class MediaUploadError extends MediaUpdateError {
  /// [error] yükleme hatasıyla.
  const MediaUploadError(this.error);

  /// `StorageService.upload` hatası.
  final StorageError error;

  @override
  List<Object?> get props => [error];

  @override
  String toString() => 'MediaUploadError(${error.name})';
}

/// Belge adımı başarısız: kimlik / yama geçersiz, ön koşul tutmadı ya da yol
/// alanı yazılamadı.
///
/// Yazım adımında oluştuysa dosya yüklenmiştir ve yerinde kalır (D-10: dosya
/// silinmez); Firestore alanı eski değerindedir, yeniden deneme yeni bir
/// dosya adı üretir.
final class MediaDocumentError extends MediaUpdateError {
  /// [error] Firestore hatasıyla.
  const MediaDocumentError(this.error);

  /// Okuma / yazma hatası ya da ön koşul reddi.
  final FirestoreError error;

  @override
  List<Object?> get props => [error];

  @override
  String toString() => 'MediaDocumentError(${error.name})';
}

/// Yükleme + yol alanı yazımı yapan repository metotlarının sonuç tipi.
typedef MediaUpdateResult<T> = FirebaseResult<T, MediaUpdateError>;
