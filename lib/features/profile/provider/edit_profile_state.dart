import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

/// "Profili düzenle" formunun hata taşıyabilen alanları (PRF-02).
enum EditProfileField {
  /// Profil fotoğrafı (seçilen görsel okunamadı / işlenemedi).
  photo,

  /// Ad soyad (`PRF-02.name`; `Limits.nameMin`–`Limits.nameMax`).
  name,

  /// İlgi alanları (`PRF-02.toggleInterest.<id>`; en az
  /// `Limits.interestsMin`).
  interests,
}

/// Kaydetmenin alana bağlanamayan başarısızlığı (ağ ve yetki hatası toast
/// ile bildirilir; bu değer formun altında hata satırı çizer).
enum EditProfileError {
  /// Diğer (geçersiz veri, belge yok, Storage reddi…).
  unknown,
}

/// `EditProfileViewModel.save` sonucu.
enum EditProfileOutcome {
  /// Profil yazıldı (TST-21 / TST-57); ekran kapanır.
  saved,

  /// Değişiklik yok; hiçbir şey yazılmadı (TST-X9).
  noChanges,

  /// Doğrulama geçmedi (alan hataları state'te).
  invalid,

  /// Cihaz çevrimdışı; hiçbir şey yazılmadı (TST-24).
  offline,

  /// Sunucu reddetti ya da ulaşılamadı.
  failed,

  /// Süren bir kaydetme varken ya da form kurulmadan gelen çağrı.
  ignored,
}

/// "Profili düzenle" ekranının durumu (PRF-02; PLAN §12.6, form State kalıbı
/// §12.1).
///
/// Form oturumdaki profilden ([original]) kurulur; "kirli" olmak bir alanın
/// özgün değerinden farklı olmasıdır (prototip `dirty`,
/// `screens-profile.js:23`) — değer geri alınınca form temizlenir. Seçilen
/// fotoğraf kaydetmeye kadar yalnızca bellektedir ([avatar]). E-posta salt
/// okunurdur ve sahibinin gizli hesap belgesinden okunur (D-29).
final class EditProfileState extends Equatable {
  /// Varsayılan: form kurulmadı.
  const EditProfileState({
    this.original,
    this.name = '',
    this.departmentId,
    this.year,
    this.interests = const {},
    this.bio = '',
    this.email = '',
    this.avatar,
    this.uploadProgress,
    this.errors = const {},
    this.isSubmitting = false,
    this.submitError,
    this.isError = false,
  });

  /// Formun kurulduğu profil (oturumdaki `users/{uid}`); kaydetme başarısında
  /// yazılan değerlere çekilir. `null` → profil okunamadı ([isError]).
  final UserModel? original;

  /// Ad soyad (ham girdi; doğrulama ve yazım kırpılmış değerle).
  final String name;

  /// Seçilen bölüm kimliği (`d01`–`d24`).
  final String? departmentId;

  /// Seçilen sınıf / öğrenim düzeyi.
  final YearLevel? year;

  /// Seçilen ilgi alanı kimlikleri (en çok `Limits.interestsMax`).
  final Set<String> interests;

  /// Kısa biyografi (en çok `Limits.bioMax`; fazlası girilirken kesilir).
  final String bio;

  /// Üniversite e-postası (`users/{uid}/private/account.email`; salt
  /// okunur). Okunana kadar boştur.
  final String email;

  /// Seçilen yeni profil fotoğrafı (önizleme + kaydetmede yükleme); seçim
  /// yoksa `null`.
  final PickedImage? avatar;

  /// Fotoğraf yüklemesinin ilerlemesi (`0.0–1.0`); yükleme yokken `null`.
  final double? uploadProgress;

  /// Alan hataları; hatasız alanın anahtarı yoktur.
  final Map<EditProfileField, FormFieldError> errors;

  /// Kaydetme sürüyor mu.
  final bool isSubmitting;

  /// Son kaydetmenin alana bağlanamayan hatası; form değişince temizlenir.
  final EditProfileError? submitError;

  /// Profil okunamadı mı (oturumda profil yok)? Hata durumu çizilir.
  final bool isError;

  /// Personel hesabı mı? Personelde sınıf sorulmaz ve ilgi alanı zorunlu
  /// değildir (AUT-05 ile aynı, rules-spec §3.1 U).
  bool get isStaff => original?.staff ?? false;

  /// Bir ilgi alanı daha seçilebilir mi?
  bool get canAddInterest => interests.length < Limits.interestsMax;

  /// Kırpılmış ad.
  String get trimmedName => name.trim();

  /// Kırpılmış biyografi.
  String get trimmedBio => bio.trim();

  /// Profil alanlarından (fotoğraf hariç) en az biri özgün değerinden farklı
  /// mı?
  bool get hasProfileChanges {
    final original = this.original;
    if (original == null) return false;
    return trimmedName != original.name ||
        departmentId != original.department ||
        year != original.year ||
        trimmedBio != original.bio ||
        !_sameInterests(original.interests);
  }

  /// Kaydedilmemiş değişiklik var mı (profil alanı ya da yeni fotoğraf)?
  /// "Kaydet" düğmesi ve DLG-25 buna bakar.
  bool get isDirty => original != null && (avatar != null || hasProfileChanges);

  bool _sameInterests(List<String> other) =>
      interests.length == other.length && interests.containsAll(other);

  @override
  List<Object?> get props => [
    original,
    name,
    departmentId,
    year,
    interests,
    bio,
    email,
    avatar,
    uploadProgress,
    errors,
    isSubmitting,
    submitError,
    isError,
  ];

  /// Verilen alanları değiştirilmiş kopya. `clear*` bayrakları ilgili alanı
  /// `null` yapar ve aynı adlı parametreden önce gelir.
  EditProfileState copyWith({
    UserModel? original,
    String? name,
    String? departmentId,
    YearLevel? year,
    Set<String>? interests,
    String? bio,
    String? email,
    PickedImage? avatar,
    bool clearAvatar = false,
    double? uploadProgress,
    bool clearUploadProgress = false,
    Map<EditProfileField, FormFieldError>? errors,
    bool? isSubmitting,
    EditProfileError? submitError,
    bool clearSubmitError = false,
    bool? isError,
  }) => EditProfileState(
    original: original ?? this.original,
    name: name ?? this.name,
    departmentId: departmentId ?? this.departmentId,
    year: year ?? this.year,
    interests: interests ?? this.interests,
    bio: bio ?? this.bio,
    email: email ?? this.email,
    avatar: clearAvatar ? null : avatar ?? this.avatar,
    uploadProgress: clearUploadProgress
        ? null
        : uploadProgress ?? this.uploadProgress,
    errors: errors ?? this.errors,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    submitError: clearSubmitError ? null : submitError ?? this.submitError,
    isError: isError ?? this.isError,
  );
}
