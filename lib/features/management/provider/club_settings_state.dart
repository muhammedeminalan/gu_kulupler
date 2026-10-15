import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

/// MGT-09 formunun hata taşıyabilen alanları (prototip `f.errors.*`,
/// `screens-manage.js:176`).
enum ClubSettingsField {
  /// Kısa açıklama (`MGT-09.summary`): ≤ `Limits.clubSummaryMax`.
  summary,

  /// Uzun açıklama (`MGT-09.about`): ≤ `Limits.clubAboutMax`.
  about,

  /// E-posta (`MGT-09.email`): boş ya da biçimce geçerli adres.
  email,

  /// Instagram (`MGT-09.instagram`): boş ya da
  /// `Limits.instagramHandlePattern`.
  instagram,

  /// Web sitesi (`MGT-09.web`): boş ya da `http(s)://` + alan adı.
  web,
}

/// `ClubSettingsViewModel.save` sonucu.
enum ClubSettingsOutcome {
  /// Çağrı yok sayıldı (süren gönderim, okunmamış kulüp, oturum yok).
  ignored,

  /// Form geçersiz; alan hataları state'e yazıldı.
  invalid,

  /// Yazılamaz: danışman (TST-26), çevrimdışı (TST-24) ya da değişiklik yok
  /// (TST-X9).
  blocked,

  /// Görsel yüklemesi ya da ayar yazımı başarısız (toast / hata bandı).
  failed,

  /// Kaydedildi (TST-21; başvuru durumu değiştiyse ardından TST-54).
  saved,
}

/// MGT-09 "Kulüp ayarları" ekranının durumu (PLAN §12.6
/// `ClubSettingsViewModel`; prototip `S['MGT-09']`,
/// `screens-manage.js:170–188`).
///
/// Form alanları kulüp belgesinden ([original]) kurulur; [isDirty] alanların
/// belgeyle farkından (yazılacak yama + seçilmiş görseller) hesaplanır —
/// değer eski haline dönünce form temizlenir. Kulüp adı ve kategori
/// kilitlidir (Rules §3.3: yönetici değiştiremez; TST-20).
final class ClubSettingsState extends Equatable {
  /// Varsayılan: kulüp okunuyor.
  const ClubSettingsState({
    this.role,
    this.original,
    this.summary = '',
    this.about = '',
    this.email = '',
    this.instagram = '',
    this.web = '',
    this.applicationsOpen = true,
    this.approvalRequired = true,
    this.requireNote = false,
    this.coverPalette = ClubPalette.red,
    this.coverPattern = ClubPattern.mountain,
    this.coverSeed = '',
    this.coverPath,
    this.pendingLogo,
    this.pendingCover,
    this.errors = const {},
    this.isDirty = false,
    this.isLoading = true,
    this.isError = false,
    this.isSubmitting = false,
    this.isSubmitError = false,
  });

  /// Oturumdaki kullanıcının bu kulüpteki **aktif** rolü
  /// (`SessionState.roleIn`); danışman → salt okunur.
  final ClubRole? role;

  /// Belgedeki kulüp; okunmadıysa `null`. Yazımdan sonra yazılanla
  /// güncellenir (yeniden denemede fark doğru kalsın).
  final ClubModel? original;

  /// Kısa açıklama (≤ `Limits.clubSummaryMax`; ViewModel keser).
  final String summary;

  /// Uzun açıklama (≤ `Limits.clubAboutMax`; ViewModel keser).
  final String about;

  /// İletişim e-postası (boş → yazılmaz).
  final String email;

  /// Instagram kullanıcı adı (`@` olmadan da girilebilir; yazımda eklenir).
  final String instagram;

  /// Web sitesi adresi.
  final String web;

  /// "Başvurular açık" (`MGT-09.toggle.applicationsOpen`).
  final bool applicationsOpen;

  /// "Yönetim onayı gerekli" (`MGT-09.toggle.approvalRequired`); kapalıyken
  /// "Herkes anında üye olur." uyarısı.
  final bool approvalRequired;

  /// "Başvuruda not iste" (`MGT-09.toggle.requireNote`).
  final bool requireNote;

  /// Şablon kapak paleti (SHT-31).
  final ClubPalette coverPalette;

  /// Şablon kapak deseni (SHT-31).
  final ClubPattern coverPattern;

  /// Şablon kapak tohumu (SHT-31 "Deseni karıştır").
  final String coverSeed;

  /// Gösterilen yüklenmiş kapağın Storage yolu; şablon seçilince `null`.
  final String? coverPath;

  /// Seçilmiş, henüz yüklenmemiş logo (SHT-16 → yeniden kodlanmış görsel,
  /// CD-135); kaydette `updateClubMedia` ile yüklenir.
  final PickedImage? pendingLogo;

  /// Seçilmiş, henüz yüklenmemiş kapak (SHT-31 "Galeriden seç").
  final PickedImage? pendingCover;

  /// Alan hataları.
  final Map<ClubSettingsField, FormFieldError> errors;

  /// Kaydedilmemiş değişiklik var mı (DLG-25; "Kaydet" etkin)?
  final bool isDirty;

  /// Kulüp okunuyor (iskelet).
  final bool isLoading;

  /// Kulüp okunamadı / silinmiş (hata durumu, "Yeniden dene").
  final bool isError;

  /// Yazım sürüyor ("Kaydet" döner, form kilitli).
  final bool isSubmitting;

  /// Son yazım alana bağlanamayan bir hatayla bitti (hata bandı).
  final bool isSubmitError;

  /// Danışman bakışı: alanlar kapalı, yazan dokunuşlar TST-26 (Q-09).
  bool get isReadOnly => role == ClubRole.advisor;

  /// Ayarları düzenleyebilir mi (`ClubPermission.editClubSettings`:
  /// başkan / yönetim kurulu — Rules §3.3; süper admin yetkisi sayılmaz).
  bool get canEdit => RolePolicy.can(ClubPermission.editClubSettings, role);

  /// Ekranı görebilir mi: yönetici ya da danışman (salt okunur). Rolsüz
  /// süper admin ayarları buradan yazamaz (ADM-03, T-39).
  bool get canView => canEdit || isReadOnly;

  @override
  List<Object?> get props => [
    role,
    original,
    summary,
    about,
    email,
    instagram,
    web,
    applicationsOpen,
    approvalRequired,
    requireNote,
    coverPalette,
    coverPattern,
    coverSeed,
    coverPath,
    pendingLogo,
    pendingCover,
    errors,
    isDirty,
    isLoading,
    isError,
    isSubmitting,
    isSubmitError,
  ];

  /// Verilen alanları değiştirilmiş kopya. `clear…` bayrakları null olabilen
  /// alanı boşaltır.
  ClubSettingsState copyWith({
    ClubRole? role,
    bool clearRole = false,
    ClubModel? original,
    String? summary,
    String? about,
    String? email,
    String? instagram,
    String? web,
    bool? applicationsOpen,
    bool? approvalRequired,
    bool? requireNote,
    ClubPalette? coverPalette,
    ClubPattern? coverPattern,
    String? coverSeed,
    String? coverPath,
    bool clearCoverPath = false,
    PickedImage? pendingLogo,
    bool clearPendingLogo = false,
    PickedImage? pendingCover,
    bool clearPendingCover = false,
    Map<ClubSettingsField, FormFieldError>? errors,
    bool? isDirty,
    bool? isLoading,
    bool? isError,
    bool? isSubmitting,
    bool? isSubmitError,
  }) => ClubSettingsState(
    role: clearRole ? null : role ?? this.role,
    original: original ?? this.original,
    summary: summary ?? this.summary,
    about: about ?? this.about,
    email: email ?? this.email,
    instagram: instagram ?? this.instagram,
    web: web ?? this.web,
    applicationsOpen: applicationsOpen ?? this.applicationsOpen,
    approvalRequired: approvalRequired ?? this.approvalRequired,
    requireNote: requireNote ?? this.requireNote,
    coverPalette: coverPalette ?? this.coverPalette,
    coverPattern: coverPattern ?? this.coverPattern,
    coverSeed: coverSeed ?? this.coverSeed,
    coverPath: clearCoverPath ? null : coverPath ?? this.coverPath,
    pendingLogo: clearPendingLogo ? null : pendingLogo ?? this.pendingLogo,
    pendingCover: clearPendingCover ? null : pendingCover ?? this.pendingCover,
    errors: errors ?? this.errors,
    isDirty: isDirty ?? this.isDirty,
    isLoading: isLoading ?? this.isLoading,
    isError: isError ?? this.isError,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    isSubmitError: isSubmitError ?? this.isSubmitError,
  );
}
