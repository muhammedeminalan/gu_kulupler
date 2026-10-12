import 'package:equatable/equatable.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';

/// AUT-04 form alanları.
enum ResetField {
  /// Üniversite e-postası (`AUT-04.email`).
  email,
}

/// AUT-04 Şifre sıfırlama ekranının durumu (PLAN §12.5, §12.1 "Form State
/// kalıbı"; prototip `useForm('reset', …)`, `screens-auth.js:127`).
///
/// Ekranın iki görünümü vardır: form ([isSent] `false`) ve "Gelen kutunu
/// kontrol et" ([isSent] `true`). İkinci görünümdeki "Tekrar gönder" düğmesi
/// [resendAvailableAt] anına kadar geri sayar.
final class ResetPasswordState extends Equatable {
  /// Varsayılan: boş form.
  const ResetPasswordState({
    this.email = '',
    this.errors = const <ResetField, FormFieldError>{},
    this.isSubmitting = false,
    this.isSent = false,
    this.resendAvailableAt,
    this.submitError,
  });

  /// E-posta alanının değeri (yazıldığı gibi; gönderimde kırpılır).
  final String email;

  /// Alan doğrulama hataları; metne çeviri view'dadır.
  final Map<ResetField, FormFieldError> errors;

  /// Gönderim (ilk ya da yeniden) sürüyor mu? Sürerken yeni istek yok sayılır.
  final bool isSubmitting;

  /// Bağlantı istendi mi ("Gelen kutunu kontrol et" görünümü)?
  final bool isSent;

  /// Yeniden gönderimin açılacağı an (UTC); bekleme yoksa `null`. Geri sayım
  /// view'da `GuCountdown` ile saatten türetilir.
  final DateTime? resendAvailableAt;

  /// Son gönderimin alana bağlanamayan hatası; yoksa `null`.
  final SubmitError? submitError;

  /// Bağlantının gönderildiği adres ([email], kırpılmış).
  String get sentEmail => email.trim();

  /// [now] anında yeniden gönderime kalan süre; bekleme yoksa ya da dolduysa
  /// `Duration.zero`.
  Duration remainingResend(DateTime now) {
    final availableAt = resendAvailableAt;
    if (availableAt == null || !availableAt.isAfter(now)) return Duration.zero;
    return availableAt.difference(now);
  }

  @override
  List<Object?> get props => [
    email,
    errors,
    isSubmitting,
    isSent,
    resendAvailableAt,
    submitError,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearSubmitError] `true` ise
  /// gönderim hatası `null` olur (değerine üstün gelir).
  ResetPasswordState copyWith({
    String? email,
    Map<ResetField, FormFieldError>? errors,
    bool? isSubmitting,
    bool? isSent,
    DateTime? resendAvailableAt,
    SubmitError? submitError,
    bool clearSubmitError = false,
  }) => ResetPasswordState(
    email: email ?? this.email,
    errors: errors ?? this.errors,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    isSent: isSent ?? this.isSent,
    resendAvailableAt: resendAvailableAt ?? this.resendAvailableAt,
    submitError: clearSubmitError ? null : submitError ?? this.submitError,
  );
}
