import 'package:equatable/equatable.dart';
import 'package:gu_data/src/models/enums/club_palette.dart';
import 'package:gu_data/src/models/enums/club_pattern.dart';

/// Süper adminin yeni kulüp formu (ADM-03) girdisi — PLAN §10.4
/// `AdminRepository.createClub`; rules-spec §3.3 C (T-37, sözleşme
/// `docs/plans/T-37.md` §4).
///
/// Yalnızca kulübün **kendi** alanlarını taşır; başkan, danışman ve logo /
/// kapak dosyası ayrı parametrelerdir (`createClub` başkanı ve danışmanı
/// alır, dosyalar oluşturmadan sonra `AdminRepository.updateClubMedia` ile
/// yüklenir). Sayaç (`memberCount: 1`), `status: active`, `presidentId`,
/// `createdBy` ve BaseFields repository tarafından yazılır.
///
/// [nameLower] değerini çağıran üretir (ViewModel `name.trLower()`, CD-11);
/// `gu_data` Türkçe harf dönüşümü yapmaz. Ad benzersizliği çağıranın
/// `ClubRepository.isNameTaken` sorgusuyla denetlenir (CD-63; kilit belgesi
/// yok, yarış kabul) — repository oluşturmadan önce aynı sorguyu bir kez
/// daha koşar.
final class ClubCreateInput extends Equatable {
  /// Yeni kulübün alanları.
  const ClubCreateInput({
    required this.name,
    required this.nameLower,
    required this.categoryId,
    required this.iconName,
    required this.founded,
    required this.palette,
    required this.pattern,
    this.coverSeed,
    this.summary = '',
    this.about = '',
    this.applicationsOpen = true,
    this.approvalRequired = true,
    this.requireNote = false,
  });

  /// Kulüp adı (`FieldValidators.clubName`, ≤ `Limits.clubNameMax`).
  final String name;

  /// [name]'in Türkçe küçük harfli karşılığı (CD-11).
  final String nameLower;

  /// Kategori kimliği (`FieldValidators.categoryId` — statik tablo).
  final String categoryId;

  /// Amblem ikonunun adı (`GuIcons` adı; gu_data yalnızca dizgi taşır).
  final String iconName;

  /// Kuruluş yılı (`FieldValidators.founded`).
  final int founded;

  /// Kapak şablonunun renk paleti.
  final ClubPalette palette;

  /// Kapak şablonunun deseni.
  final ClubPattern pattern;

  /// Kapak şablonunun tohumu; `null` ise kulüp kimliğinden türer
  /// (`ClubModel.coverSeed`).
  final String? coverSeed;

  /// Kısa tanıtım (≤ `Limits.clubSummaryMax`).
  final String summary;

  /// Hakkında metni (≤ `Limits.clubAboutMax`).
  final String about;

  /// Kulüp başvuruya / katılıma açık mı?
  final bool applicationsOpen;

  /// Başvurular yönetici onayı gerektiriyor mu?
  final bool approvalRequired;

  /// Başvuruda not zorunlu mu?
  final bool requireNote;

  @override
  List<Object?> get props => [
    name,
    nameLower,
    categoryId,
    iconName,
    founded,
    palette,
    pattern,
    coverSeed,
    summary,
    about,
    applicationsOpen,
    approvalRequired,
    requireNote,
  ];
}

/// Kulüp danışmanının adı ve ünvanı (ADM-03 `advisorName` / `advisorTitle`;
/// K-A) — `clubs.advisor{name, title, userId?}` girdisi.
///
/// Hesap bağlama (`advisor.userId` + `advisor` üyeliği) bu nesneyle
/// **yapılmaz**: yalnızca `MembershipRepository.setAdvisor` (uygulama içi
/// süper admin) ya da `tool/admin/set_advisor.js` (Admin SDK) bağlar.
final class AdvisorInput extends Equatable {
  /// [name] adlı, [title] ünvanlı danışman.
  const AdvisorInput({required this.name, this.title = ''});

  /// Ad soyad (`FieldValidators.name`; `Limits.nameMin` –
  /// `Limits.nameMax`).
  final String name;

  /// Akademik ünvan; boş olabilir.
  final String title;

  @override
  List<Object?> get props => [name, title];
}
