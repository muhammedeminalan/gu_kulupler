import 'package:equatable/equatable.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';

/// AUT-01 form alanları (odak ve hata sırası: e-posta → şifre).
enum LoginField {
  /// E-posta (`AUT-01.email`).
  email,

  /// Şifre (`AUT-01.password`).
  password,
}

/// Giriş gönderiminin alana bağlanamayan başarısızlık türü (PLAN §12.5).
enum LoginError {
  /// E-posta ya da şifre hatalı (TST-01; şifre alanında `auth.err.wrong`).
  invalidCredential,

  /// Hesap askıda (DLG-01).
  suspended,

  /// Ağ yok / çevrimdışı (TST-24).
  network,

  /// Diğer (ekran içi hata bandı).
  unknown,
}

/// `LoginViewModel.submit` sonucu: view yalnızca bu değere göre davranır
/// (kilit → DLG-02); yönlendirme router'dadır.
enum LoginOutcome {
  /// Oturum açıldı; nereye gidileceğine router karar verir.
  success,

  /// Giriş kilitli (yeni kilitlendi ya da kilit sürüyor) → DLG-02.
  locked,

  /// E-posta ya da şifre hatalı (kilit yok).
  invalid,

  /// Hesap askıda (DLG-01 ViewModel'de gösterildi).
  suspended,

  /// Gönderilemedi: doğrulama hatası, çevrimdışı, ağ, süren gönderim, diğer.
  failed,
}

/// AUT-01 Giriş formunun durumu (PLAN §12.5, §12.1 "Form State kalıbı").
final class LoginState extends Equatable {
  /// Varsayılan: boş form.
  const LoginState({
    this.email = '',
    this.password = '',
    this.isPasswordVisible = false,
    this.errors = const <LoginField, FormFieldError>{},
    this.isDirty = false,
    this.isSubmitting = false,
    this.failedAttempts = 0,
    this.lockedUntil,
    this.submitError,
  });

  /// E-posta alanının değeri (yazıldığı gibi; gönderimde kırpılır).
  final String email;

  /// Şifre alanının değeri.
  final String password;

  /// Şifre açık metin mi gösteriliyor (`AUT-01.togglePassword`)?
  final bool isPasswordVisible;

  /// Alan doğrulama hataları; metne çeviri view'dadır.
  final Map<LoginField, FormFieldError> errors;

  /// Kullanıcı forma dokundu mu?
  final bool isDirty;

  /// Giriş isteği sürüyor mu (düğme meşgul, yeni gönderim yok sayılır)?
  final bool isSubmitting;

  /// Bu ekranda art arda hatalı giriş sayısı (her artışta form sallanır).
  final int failedAttempts;

  /// Giriş kilidinin açılacağı an (UTC); kilit yoksa `null`. Geri sayım view'da
  /// `GuCountdown` ile saatten türetilir.
  final DateTime? lockedUntil;

  /// Son gönderimin alana bağlanamayan hatası; yoksa `null`.
  final LoginError? submitError;

  /// [now] anında giriş kilitli mi?
  bool isLockedAt(DateTime now) => lockedUntil?.isAfter(now) ?? false;

  @override
  List<Object?> get props => [
    email,
    password,
    isPasswordVisible,
    errors,
    isDirty,
    isSubmitting,
    failedAttempts,
    lockedUntil,
    submitError,
  ];

  /// Verilen alanları değiştirilmiş kopya. [clearLockedUntil] ve
  /// [clearSubmitError] ilgili alanı `null` yapar (değerine üstün gelir).
  LoginState copyWith({
    String? email,
    String? password,
    bool? isPasswordVisible,
    Map<LoginField, FormFieldError>? errors,
    bool? isDirty,
    bool? isSubmitting,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
    LoginError? submitError,
    bool clearSubmitError = false,
  }) => LoginState(
    email: email ?? this.email,
    password: password ?? this.password,
    isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
    errors: errors ?? this.errors,
    isDirty: isDirty ?? this.isDirty,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockedUntil: clearLockedUntil ? null : lockedUntil ?? this.lockedUntil,
    submitError: clearSubmitError ? null : submitError ?? this.submitError,
  );
}
