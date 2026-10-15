import 'package:equatable/equatable.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';

/// ADM-03 formunun hata taşıyabilen alanları (prototip `f.errors.*`,
/// `screens-admin.js:44`).
enum AdminClubField {
  /// Kulüp adı (`ADM-03.name`): zorunlu, `Limits.nameMin` –
  /// `Limits.clubNameMax`. Ad çakışması ayrıca [AdminClubFormState
  /// .isNameTaken] ile gösterilir.
  name,

  /// Kategori (`ADM-03.category`): zorunlu.
  category,

  /// Kısa açıklama (`ADM-03.summary`): ≤ `Limits.clubSummaryMax`.
  summary,

  /// Uzun açıklama (`ADM-03.about`): ≤ `Limits.clubAboutMax`.
  about,

  /// Başkan (`ADM-03.assignPresident`): zorunlu.
  president,

  /// Danışman adı (`ADM-03.advisorName`): unvan girildiyse ya da hesap
  /// bağlıysa zorunlu; `FieldValidators.name` (K-A).
  advisorName,
}

/// `AdminClubFormViewModel.save` sonucu.
enum AdminClubFormOutcome {
  /// Çağrı yok sayıldı (süren gönderim, okunmamış kulüp, oturum yok).
  ignored,

  /// Form geçersiz ya da ad alınmış; alan hataları state'e yazıldı.
  invalid,

  /// Yazılamaz: çevrimdışı (TST-24) ya da değişiklik yok (TST-X9).
  blocked,

  /// Yazım başarısız (toast / hata bandı); yarıda kalan yazım yeniden
  /// denenebilir.
  failed,

  /// Yeni kulüp oluşturuldu (TST-33).
  created,

  /// Düzenleme kaydedildi (TST-21).
  saved,
}

/// ADM-03 "Kulüp oluştur / düzenle" ekranının durumu (PLAN §12.6
/// `AdminClubFormViewModel`; prototip `S['ADM-03']`,
/// `screens-admin.js:39–56`).
///
/// Yeni kulüpte [original] `null`, alanlar prototip varsayılanıdır (ikon
/// `sparkles`, kapak `red` × `mountain`, iki anahtar açık). Düzenlemede form
/// kulüp belgesinden ([original]) ve başkanın kullanıcı belgesinden
/// ([president]) kurulur; [isDirty] alanların belgeyle farkından hesaplanır.
final class AdminClubFormState extends Equatable {
  /// Varsayılan: boş yeni kulüp formu.
  const AdminClubFormState({
    this.original,
    this.name = '',
    this.categoryId,
    this.summary = '',
    this.about = '',
    this.coverPalette = ClubPalette.red,
    this.coverPattern = ClubPattern.mountain,
    this.coverSeed = '',
    this.coverPath,
    this.pendingLogo,
    this.pendingCover,
    this.applicationsOpen = true,
    this.approvalRequired = true,
    this.presidentUserId,
    this.president,
    this.advisorName = '',
    this.advisorTitle = '',
    this.advisorUnlinked = false,
    this.createdClubId,
    this.errors = const {},
    this.isNameTaken = false,
    this.isDirty = false,
    this.isLoading = false,
    this.isError = false,
    this.isSubmitting = false,
    this.isSubmitError = false,
  });

  /// [club] belgesinden kurulmuş, temiz düzenleme formu; [president]
  /// başkanın kullanıcı belgesi (okunamadıysa `null`).
  factory AdminClubFormState.of(ClubModel club, {UserModel? president}) {
    final advisor = club.advisor;
    return AdminClubFormState(
      original: club,
      name: club.name,
      categoryId: club.categoryId,
      summary: club.summary,
      about: club.about,
      coverPalette: club.palette,
      coverPattern: club.pattern,
      coverSeed: club.coverSeed,
      coverPath: club.coverPath,
      applicationsOpen: club.applicationsOpen,
      approvalRequired: club.approvalRequired,
      presidentUserId: club.presidentId,
      president: president,
      advisorName: advisor?.name ?? '',
      advisorTitle: advisor?.title ?? '',
    );
  }

  /// Yeni kulübün ve kategorisiz formun amblem ikonu (prototip
  /// `iconName: 'sparkles'`).
  static const String defaultIconName = 'sparkles';

  /// Düzenlenen kulübün belgesi; yeni kulüpte `null`. Yazımdan sonra
  /// yazılanla güncellenir (yeniden denemede fark doğru kalsın).
  final ClubModel? original;

  /// Kulüp adı (≤ `Limits.clubNameMax`; ViewModel keser).
  final String name;

  /// Kategori kimliği (SHT-33); seçilmediyse `null`.
  final String? categoryId;

  /// Kısa açıklama (≤ `Limits.clubSummaryMax`).
  final String summary;

  /// Uzun açıklama (≤ `Limits.clubAboutMax`).
  final String about;

  /// Şablon kapak paleti (SHT-31).
  final ClubPalette coverPalette;

  /// Şablon kapak deseni (SHT-31).
  final ClubPattern coverPattern;

  /// Şablon kapak tohumu (SHT-31 "Deseni karıştır"); boş → kulüp
  /// kimliğinden türer (yeni kulüp).
  final String coverSeed;

  /// Yüklenmiş kapağın Storage yolu (düzenleme); yoksa `null`.
  final String? coverPath;

  /// Seçilmiş, henüz yüklenmemiş logo (SHT-16; CD-135).
  final PickedImage? pendingLogo;

  /// Seçilmiş, henüz yüklenmemiş kapak (SHT-31 "Galeriden seç").
  final PickedImage? pendingCover;

  /// "Başvurular açık" (`ADM-03.toggle.applicationsOpen`).
  final bool applicationsOpen;

  /// "Yönetim onayı gerekli" (`ADM-03.toggle.approvalRequired`).
  final bool approvalRequired;

  /// Seçili başkanın kimliği; seçilmediyse / kaldırıldıysa `null`.
  final String? presidentUserId;

  /// Seçili başkanın kullanıcı belgesi (kart satırı; oluşturmada
  /// `applicant` anlık görüntüsü); okunamadıysa `null`.
  final UserModel? president;

  /// Danışmanın adı soyadı (K-A).
  final String advisorName;

  /// Danışmanın unvanı (K-A).
  final String advisorTitle;

  /// Bağlı danışman hesabının bağı kayıtta ayrılacak (W-101 a — "Kaldır").
  final bool advisorUnlinked;

  /// Oluşturulmuş ama görselleri henüz yüklenememiş kulüp; yeniden denemede
  /// kulüp ikinci kez oluşturulmaz.
  final String? createdClubId;

  /// Alan hataları.
  final Map<AdminClubField, FormFieldError> errors;

  /// Son yazım adı alınmış buldu (`alreadyExists`, CD-63): "Bu adda bir
  /// kulüp zaten var". Ad değişince temizlenir.
  final bool isNameTaken;

  /// Kaydedilmemiş değişiklik var mı (DLG-25)?
  final bool isDirty;

  /// Düzenlenen kulüp okunuyor (iskelet).
  final bool isLoading;

  /// Düzenlenen kulüp okunamadı / silinmiş ("Yeniden dene").
  final bool isError;

  /// Yazım sürüyor ("Kaydet" döner, form kilitli).
  final bool isSubmitting;

  /// Son yazım alana bağlanamayan bir hatayla bitti (hata bandı).
  final bool isSubmitError;

  /// Düzenleme kipi mi (kulüp belgesi okundu)?
  bool get isEdit => original != null;

  /// Amblem ikonunun adı: kategori değişmediyse kulübün kendi ikonu, yoksa
  /// kategorinin ikonu (prototip `cat ? cat.icon : f.iconName`), kategori
  /// yoksa [defaultIconName].
  String get iconName {
    final club = original;
    if (club != null && club.categoryId == categoryId) return club.iconName;
    for (final category in StaticTables.categories) {
      if (category.id == categoryId) return category.icon;
    }
    return club?.iconName ?? defaultIconName;
  }

  /// Hesabı bağlı danışmanın kimliği (bağ ayrılmayacaksa); yoksa `null`.
  String? get linkedAdvisorId =>
      advisorUnlinked ? null : original?.advisor?.userId;

  @override
  List<Object?> get props => [
    original,
    name,
    categoryId,
    summary,
    about,
    coverPalette,
    coverPattern,
    coverSeed,
    coverPath,
    pendingLogo,
    pendingCover,
    applicationsOpen,
    approvalRequired,
    presidentUserId,
    president,
    advisorName,
    advisorTitle,
    advisorUnlinked,
    createdClubId,
    errors,
    isNameTaken,
    isDirty,
    isLoading,
    isError,
    isSubmitting,
    isSubmitError,
  ];

  /// Verilen alanları değiştirilmiş kopya. `clear…` bayrakları null olabilen
  /// alanı boşaltır.
  AdminClubFormState copyWith({
    ClubModel? original,
    String? name,
    String? categoryId,
    String? summary,
    String? about,
    ClubPalette? coverPalette,
    ClubPattern? coverPattern,
    String? coverSeed,
    String? coverPath,
    PickedImage? pendingLogo,
    bool clearPendingLogo = false,
    PickedImage? pendingCover,
    bool clearPendingCover = false,
    bool? applicationsOpen,
    bool? approvalRequired,
    String? presidentUserId,
    UserModel? president,
    bool clearPresident = false,
    String? advisorName,
    String? advisorTitle,
    bool? advisorUnlinked,
    String? createdClubId,
    Map<AdminClubField, FormFieldError>? errors,
    bool? isNameTaken,
    bool? isDirty,
    bool? isLoading,
    bool? isError,
    bool? isSubmitting,
    bool? isSubmitError,
  }) => AdminClubFormState(
    original: original ?? this.original,
    name: name ?? this.name,
    categoryId: categoryId ?? this.categoryId,
    summary: summary ?? this.summary,
    about: about ?? this.about,
    coverPalette: coverPalette ?? this.coverPalette,
    coverPattern: coverPattern ?? this.coverPattern,
    coverSeed: coverSeed ?? this.coverSeed,
    coverPath: coverPath ?? this.coverPath,
    pendingLogo: clearPendingLogo ? null : pendingLogo ?? this.pendingLogo,
    pendingCover: clearPendingCover ? null : pendingCover ?? this.pendingCover,
    applicationsOpen: applicationsOpen ?? this.applicationsOpen,
    approvalRequired: approvalRequired ?? this.approvalRequired,
    presidentUserId: clearPresident
        ? null
        : presidentUserId ?? this.presidentUserId,
    president: clearPresident ? null : president ?? this.president,
    advisorName: advisorName ?? this.advisorName,
    advisorTitle: advisorTitle ?? this.advisorTitle,
    advisorUnlinked: advisorUnlinked ?? this.advisorUnlinked,
    createdClubId: createdClubId ?? this.createdClubId,
    errors: errors ?? this.errors,
    isNameTaken: isNameTaken ?? this.isNameTaken,
    isDirty: isDirty ?? this.isDirty,
    isLoading: isLoading ?? this.isLoading,
    isError: isError ?? this.isError,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    isSubmitError: isSubmitError ?? this.isSubmitError,
  );
}
