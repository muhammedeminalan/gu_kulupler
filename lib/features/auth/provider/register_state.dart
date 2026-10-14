import 'package:equatable/equatable.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/form/password_strength.dart';

/// Kayıt formunun alanları (AUT-02); sıra ekrandaki sıradır — ilk hatalı alan
/// bu sırayla bulunur ([RegisterState.firstInvalidField]).
enum RegisterField {
  /// Ad Soyad (`AUT-02.name`).
  name,

  /// Üniversite e-postası (`AUT-02.email`).
  email,

  /// Şifre (`AUT-02.password`).
  password,

  /// Şifre tekrar (`AUT-02.password2`).
  passwordConfirm,

  /// KVKK + gizlilik onayı (`AUT-02.legalCheck`).
  legal,
}

/// Kayıt gönderiminin sunucu kaynaklı başarısızlığı.
enum RegisterError {
  /// E-posta zaten kayıtlı (e-posta alanının altında gösterilir).
  emailInUse,

  /// Alan adı izinli listede değil (D-27).
  domainNotAllowed,

  /// Sunucu şifreyi zayıf buldu.
  weakPassword,

  /// Ağ yok / zaman aşımı (TST-24).
  network,

  /// Diğer.
  unknown,
}

/// `RegisterViewModel.submit` sonucu.
enum RegisterOutcome {
  /// Hesap açıldı; oturum (doğrulanmamış) kuruldu, yönlendirme router'da.
  success,

  /// Form doğrulaması geçmedi (alan hataları state'te).
  invalid,

  /// Cihaz çevrimdışı; istek gönderilmedi (TST-24).
  offline,

  /// Sunucu reddetti ya da ulaşılamadı (alan hatası / `submitError`).
  failed,

  /// Süren bir gönderim varken gelen ikinci çağrı; yok sayıldı.
  ignored,
}

/// Kayıt ekranının durumu (AUT-02; PLAN §12.5, form State kalıbı §12.1).
///
/// Tasarımda tek onay kutusu vardır (`screens-auth.js:101`: KVKK ve gizlilik
/// metinleri tek kutuyla kabul edilir); bu yüzden onay tek alandır
/// ([acceptedLegal]).
final class RegisterState extends Equatable {
  /// Varsayılan: boş form.
  const RegisterState({
    this.name = '',
    this.email = '',
    this.password = '',
    this.passwordConfirm = '',
    this.isPasswordVisible = false,
    this.acceptedLegal = false,
    this.errors = const {},
    this.isDirty = false,
    this.isSubmitting = false,
    this.submitError,
  });

  /// Ad Soyad (yazıldığı gibi; gönderimde kırpılır).
  final String name;

  /// E-posta (yazıldığı gibi; doğrulama ve gönderimde kırpılır).
  final String email;

  /// Şifre.
  final String password;

  /// Şifre tekrarı.
  final String passwordConfirm;

  /// Şifre alanları düz metin mi gösteriliyor (iki alan birlikte).
  final bool isPasswordVisible;

  /// KVKK aydınlatma metni ve gizlilik politikası kabul edildi mi.
  final bool acceptedLegal;

  /// Alan hataları; hatasız alanın anahtarı yoktur.
  final Map<RegisterField, FormFieldError> errors;

  /// Form en az bir kez değiştirildi mi.
  final bool isDirty;

  /// Gönderim sürüyor mu. Başarılı kayıttan sonra da `true` kalır: ekran
  /// yönlendirmeyle kapanana kadar form kilitlidir.
  final bool isSubmitting;

  /// Son gönderimin sunucu hatası; form değişince temizlenir.
  final RegisterError? submitError;

  /// Şifre kuralı: en az `Limits.passwordMinLength` karakter.
  bool get hasMinLength => PasswordStrength.hasMinLength(password);

  /// Şifre kuralı: en az bir büyük harf (Türkçe harfler dahil).
  bool get hasUppercase => PasswordStrength.hasUppercase(password);

  /// Şifre kuralı: en az bir rakam.
  bool get hasDigit => PasswordStrength.hasDigit(password);

  /// Şifre gücü, 0 – [passwordStrengthMax]: karşılanan ölçüt sayısı
  /// (`PasswordStrength.of`; `screens-auth.js:82`).
  int get passwordStrength => PasswordStrength.of(password);

  /// [passwordStrength] üst sınırı (güç çubuğundaki dilim sayısı).
  static const int passwordStrengthMax = PasswordStrength.max;

  /// Odağın taşınacağı ilk hatalı alan (form sırasıyla); hata yoksa `null`.
  /// Kayıtlı e-posta hatası ([RegisterError.emailInUse]) e-posta alanına
  /// aittir.
  RegisterField? get firstInvalidField {
    for (final field in RegisterField.values) {
      if (errors.containsKey(field)) return field;
      if (field == RegisterField.email &&
          submitError == RegisterError.emailInUse) {
        return field;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [
    name,
    email,
    password,
    passwordConfirm,
    isPasswordVisible,
    acceptedLegal,
    errors,
    isDirty,
    isSubmitting,
    submitError,
  ];

  /// Verilen alanları değiştirilmiş kopya; [clearSubmitError] `true` ise
  /// [submitError] `null` olur.
  RegisterState copyWith({
    String? name,
    String? email,
    String? password,
    String? passwordConfirm,
    bool? isPasswordVisible,
    bool? acceptedLegal,
    Map<RegisterField, FormFieldError>? errors,
    bool? isDirty,
    bool? isSubmitting,
    RegisterError? submitError,
    bool clearSubmitError = false,
  }) => RegisterState(
    name: name ?? this.name,
    email: email ?? this.email,
    password: password ?? this.password,
    passwordConfirm: passwordConfirm ?? this.passwordConfirm,
    isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
    acceptedLegal: acceptedLegal ?? this.acceptedLegal,
    errors: errors ?? this.errors,
    isDirty: isDirty ?? this.isDirty,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    submitError: clearSubmitError ? null : submitError ?? this.submitError,
  );
}
