import 'package:equatable/equatable.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/form/password_strength.dart';

/// Şifre değiştirme formunun alanları (SHT-32); sıra ekrandaki sıradır.
enum PasswordField {
  /// Mevcut şifre (`SHT-32.current`).
  current,

  /// Yeni şifre (`SHT-32.new`).
  newPassword,

  /// Yeni şifre tekrar (`SHT-32.repeat`).
  confirm,
}

/// Şifre değiştirmenin sunucu kaynaklı başarısızlığı (PLAN §12.12).
enum ChangePasswordError {
  /// Mevcut şifre hatalı (`AuthError.invalidCredentials`) — mevcut şifre
  /// alanının altında "Şifre hatalı".
  wrongPassword,

  /// Yeni şifre politikaya uymuyor (`AuthError.weakPassword`) — yeni şifre
  /// alanının altında.
  weak,

  /// Çok fazla deneme (`AuthError.tooManyRequests`) — form altı hata satırı.
  tooManyRequests,

  /// Ağ yok (TST-24).
  network,

  /// Diğer her hata — form altı hata satırı.
  unknown,
}

/// SHT-32 Şifre değiştir formunun durumu (PLAN §12.12).
final class ChangePasswordState extends Equatable {
  /// Boş form.
  const ChangePasswordState({
    this.currentPassword = '',
    this.newPassword = '',
    this.confirm = '',
    this.errors = const <PasswordField, FormFieldError>{},
    this.isSubmitting = false,
    this.isDone = false,
    this.submitError,
  });

  /// Mevcut şifre.
  final String currentPassword;

  /// Yeni şifre.
  final String newPassword;

  /// Yeni şifre tekrarı.
  final String confirm;

  /// Alan hataları (form sırasıyla).
  final Map<PasswordField, FormFieldError> errors;

  /// Gönderim sürüyor mu.
  final bool isSubmitting;

  /// Şifre değişti mi (TST-44 gösterildi; sayfa `true` ile kapanır).
  final bool isDone;

  /// Son gönderimin sunucu hatası; ilgili alan değişince temizlenir.
  final ChangePasswordError? submitError;

  /// Formda kaydedilmemiş değişiklik var mı (prototip
  /// `dirty = !!(f.cur || f.nw)`, `sheets.js:152`)? Başarıdan sonra `false`.
  bool get isDirty =>
      !isDone && (currentPassword.isNotEmpty || newPassword.isNotEmpty);

  /// Yeni şifrenin gücü, 0 – `PasswordStrength.max`.
  int get strength => PasswordStrength.of(newPassword);

  @override
  List<Object?> get props => [
    currentPassword,
    newPassword,
    confirm,
    errors,
    isSubmitting,
    isDone,
    submitError,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearSubmitError] sunucu
  /// hatasını siler ve [submitError]'dan önce gelir.
  ChangePasswordState copyWith({
    String? currentPassword,
    String? newPassword,
    String? confirm,
    Map<PasswordField, FormFieldError>? errors,
    bool? isSubmitting,
    bool? isDone,
    ChangePasswordError? submitError,
    bool clearSubmitError = false,
  }) => ChangePasswordState(
    currentPassword: currentPassword ?? this.currentPassword,
    newPassword: newPassword ?? this.newPassword,
    confirm: confirm ?? this.confirm,
    errors: errors ?? this.errors,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    isDone: isDone ?? this.isDone,
    submitError: clearSubmitError ? null : submitError ?? this.submitError,
  );
}
