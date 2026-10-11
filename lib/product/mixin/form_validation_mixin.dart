import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';

/// Form ViewModel'lerinin ortak doğrulama parçası (PLAN §12.1 "Form State
/// kalıbı"; design-analysis §G).
///
/// Alan kuralları `gu_data`'dadır (`FieldValidators`, `EmailDomainValidator`,
/// `Limits`); bu mixin sonuçlarını `FormFieldError`'a çevirir ve State'in
/// `errors: Map<F, FormFieldError>` haritasını kurar. Metne çeviri view
/// katmanındadır (ViewModel ARB görmez).
///
/// ```dart
/// bool validate() {
///   final errors = validateFields({
///     RegisterField.email: () => emailError(state.email),
///     RegisterField.password: () => passwordError(state.password),
///   });
///   state = state.copyWith(errors: errors);
///   return errors.isEmpty;
/// }
/// ```
mixin FormValidationMixin<F extends Enum> on ProjectDependencyMixin {
  static final RegExp _passwordPolicy = RegExp(
    Limits.passwordPattern,
    unicode: true,
  );

  /// [rules] kurallarını sırayla çalıştırır; hata dönen alanları (sırayı
  /// koruyarak) toplar.
  Map<F, FormFieldError> validateFields(
    Map<F, FormFieldError? Function()> rules,
  ) => <F, FormFieldError>{
    for (final MapEntry(key: field, value: rule) in rules.entries)
      field: ?rule(),
  };

  /// `gu_data` alan hatasının form karşılığı.
  FormFieldError? fromFieldError(FieldError? error) => switch (error) {
    null => null,
    FieldError.empty => FormFieldError.required,
    FieldError.tooShort => FormFieldError.tooShort,
    FieldError.tooLong => FormFieldError.tooLong,
    FieldError.invalidFormat => FormFieldError.invalidFormat,
    FieldError.outOfRange => FormFieldError.limitExceeded,
  };

  /// E-posta kuralı (prototip `screens-auth.js:57`): zorunlu → biçim → izinli
  /// alan adı (D-27). [value] kırpılarak denetlenir.
  FormFieldError? emailError(String value) {
    final address = value.trim();
    if (address.isEmpty) return FormFieldError.required;
    if (!EmailDomainValidator.isWellFormed(address)) {
      return FormFieldError.invalidEmail;
    }
    if (!EmailDomainValidator.isAllowedDomain(address)) {
      return FormFieldError.domainNotAllowed;
    }
    return null;
  }

  /// Yeni şifre kuralı (`Limits.passwordPattern`: en az 8 karakter + büyük
  /// harf + rakam). Boş şifre de politikaya uymaz (prototip
  /// `screens-auth.js:88`).
  FormFieldError? passwordError(String value) =>
      _passwordPolicy.hasMatch(value) ? null : FormFieldError.passwordWeak;

  /// Şifre tekrarı kuralı: [confirm], [password] ile aynı olmalıdır.
  FormFieldError? confirmError(String password, String confirm) =>
      confirm == password ? null : FormFieldError.passwordMismatch;

  /// Metin uzunluğu kuralı ([value] kırpılarak): boş → zorunlu (yalnızca
  /// [min] > 0 ise), [min]'den kısa, [max]'tan uzun.
  FormFieldError? lengthError(
    String value, {
    required int min,
    required int max,
  }) {
    final length = value.trim().runes.length;
    if (length == 0) return min > 0 ? FormFieldError.required : null;
    if (length < min) return FormFieldError.tooShort;
    if (length > max) return FormFieldError.tooLong;
    return null;
  }

  /// [order] sırasındaki ilk hatalı alan; hata yoksa `null`.
  F? firstErrorField(Map<F, FormFieldError> errors, List<F> order) {
    for (final field in order) {
      if (errors.containsKey(field)) return field;
    }
    return null;
  }

  /// Gönderim kilidi (prototip `useBusy`, `core.js:653`): [isSubmitting] ise
  /// çağrı yok sayılır; değilse [setSubmitting] ile kilit kurulur, [body]
  /// çalışır ve kilit — [body] fırlatsa bile — kaldırılır.
  Future<void> guardedSubmit({
    required bool isSubmitting,
    required void Function({required bool isSubmitting}) setSubmitting,
    required Future<void> Function() body,
  }) async {
    if (isSubmitting) return;
    setSubmitting(isSubmitting: true);
    try {
      await body();
    } finally {
      setSubmitting(isSubmitting: false);
    }
  }
}
