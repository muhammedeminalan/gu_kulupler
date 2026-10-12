import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

/// Profil tamamlama adımları — **tasarımdaki sırayla** (`screens-auth.js:
/// 143–145`): fotoğraf → eğitim bilgisi → ilgi alanları.
enum SetupStep {
  /// 1 · "Bir fotoğraf ekle" (atlanabilir).
  photo,

  /// 2 · "Eğitim bilgin": bölüm + sınıf.
  info,

  /// 3 · "İlgi alanların": 1–5 seçim, sonunda gönderim.
  interests;

  /// Adım numarası, 1'den başlar ("Adım 1/3").
  int get number => index + 1;

  /// Son adım mı (birincil düğme "Tamamla" olur)?
  bool get isLast => this == values.last;
}

/// Profil tamamlama formunun hata taşıyabilen alanları (AUT-05).
enum SetupProfileField {
  /// Profil fotoğrafı (seçilen görsel okunamadı / işlenemedi).
  photo,

  /// Bölüm (`AUT-05.department` → SHT-02).
  department,

  /// Sınıf (`AUT-05.year` → SHT-03).
  year,

  /// İlgi alanları (`AUT-05.toggleInterest.<id>`).
  interests,
}

/// Gönderimin sunucu kaynaklı başarısızlığı.
enum SetupProfileError {
  /// Ağ yok / zaman aşımı (TST-24).
  network,

  /// Diğer (yetki, geçersiz veri, oturum).
  unknown,
}

/// `SetupProfileViewModel.next` / `submit` sonucu.
enum SetupProfileOutcome {
  /// Sonraki adıma geçildi.
  advanced,

  /// Profil tamamlandı; yönlendirme router'da (`active` → kabuk).
  success,

  /// Adımın doğrulaması geçmedi (alan hataları state'te).
  invalid,

  /// Cihaz çevrimdışı; hiçbir şey yazılmadı (TST-24).
  offline,

  /// Sunucu reddetti ya da ulaşılamadı (`submitError`).
  failed,

  /// Süren bir gönderim varken gelen çağrı; yok sayıldı.
  ignored,
}

/// Profil tamamlama ekranının durumu (AUT-05; PLAN §12.5, form State kalıbı
/// §12.1).
///
/// Ad formda sorulmaz (CD-134): kayıttaki ad kimlik hesabından gelir. Seçilen
/// fotoğraf gönderime kadar yalnızca bellektedir ([avatar]); profil belgesi
/// tamamlanmadan `avatarPath` yazılamaz (W-57).
final class SetupProfileState extends Equatable {
  /// Varsayılan: ilk adım, boş form.
  const SetupProfileState({
    this.step = SetupStep.photo,
    this.name = '',
    this.avatarSeed = '',
    this.isStaff = false,
    this.departmentId,
    this.year,
    this.interests = const {},
    this.avatar,
    this.uploadProgress,
    this.errors = const {},
    this.isDirty = false,
    this.isSubmitting = false,
    this.submitError,
  });

  /// Görünen adım.
  final SetupStep step;

  /// Kullanıcının adı (profil belgesi → kimlik hesabı → e-posta yerel kısmı);
  /// avatar baş harfleri ve karşılama toast'ı (TST-05) için.
  final String name;

  /// Avatar tohumu (`users.avatarSeed`; yeni profilde `uid`).
  final String avatarSeed;

  /// Personel hesabı mı (`users.staff`)? Personelde sınıf sorulmaz ve ilgi
  /// alanı zorunlu değildir (rules-spec §3.1 U).
  final bool isStaff;

  /// Seçilen bölüm kimliği (`d01`–`d24`).
  final String? departmentId;

  /// Seçilen sınıf / öğrenim düzeyi.
  final YearLevel? year;

  /// Seçilen ilgi alanı kimlikleri (en çok `Limits.interestsMax`).
  final Set<String> interests;

  /// Seçilen profil fotoğrafı (önizleme + gönderimde yükleme); seçilmediyse
  /// `null`.
  final PickedImage? avatar;

  /// Fotoğraf yüklemesinin ilerlemesi (`0.0–1.0`); yükleme yokken `null`.
  final double? uploadProgress;

  /// Alan hataları; hatasız alanın anahtarı yoktur.
  final Map<SetupProfileField, FormFieldError> errors;

  /// Formda kaydedilmemiş seçim var mı (fotoğraf, bölüm, sınıf, ilgi alanı)?
  /// Kapatırken DLG-25 buna göre sorulur.
  final bool isDirty;

  /// Gönderim sürüyor mu. Başarıdan sonra da `true` kalır: ekran
  /// yönlendirmeyle kapanana kadar form kilitlidir.
  final bool isSubmitting;

  /// Son gönderimin sunucu hatası; form değişince temizlenir.
  final SetupProfileError? submitError;

  /// Fotoğraf seçildi mi ("Fotoğraf eklendi" rozeti)?
  bool get hasPhoto => avatar != null;

  /// Bir ilgi alanı daha seçilebilir mi?
  bool get canAddInterest => interests.length < Limits.interestsMax;

  /// TST-05 "Hoş geldin, {name}!" için ilk ad (`screens-auth.js:140`).
  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  @override
  List<Object?> get props => [
    step,
    name,
    avatarSeed,
    isStaff,
    departmentId,
    year,
    interests,
    avatar,
    uploadProgress,
    errors,
    isDirty,
    isSubmitting,
    submitError,
  ];

  /// Verilen alanları değiştirilmiş kopya. `clear*` bayrakları ilgili alanı
  /// `null` yapar ve aynı adlı parametreden önce gelir.
  SetupProfileState copyWith({
    SetupStep? step,
    String? name,
    String? avatarSeed,
    bool? isStaff,
    String? departmentId,
    YearLevel? year,
    Set<String>? interests,
    PickedImage? avatar,
    bool clearAvatar = false,
    double? uploadProgress,
    bool clearUploadProgress = false,
    Map<SetupProfileField, FormFieldError>? errors,
    bool? isDirty,
    bool? isSubmitting,
    SetupProfileError? submitError,
    bool clearSubmitError = false,
  }) => SetupProfileState(
    step: step ?? this.step,
    name: name ?? this.name,
    avatarSeed: avatarSeed ?? this.avatarSeed,
    isStaff: isStaff ?? this.isStaff,
    departmentId: departmentId ?? this.departmentId,
    year: year ?? this.year,
    interests: interests ?? this.interests,
    avatar: clearAvatar ? null : avatar ?? this.avatar,
    uploadProgress: clearUploadProgress
        ? null
        : uploadProgress ?? this.uploadProgress,
    errors: errors ?? this.errors,
    isDirty: isDirty ?? this.isDirty,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    submitError: clearSubmitError ? null : submitError ?? this.submitError,
  );
}
