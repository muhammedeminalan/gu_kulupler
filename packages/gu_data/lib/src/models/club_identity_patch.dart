import 'package:equatable/equatable.dart';
import 'package:gu_data/src/models/club_create_input.dart';
import 'package:gu_data/src/models/enums/club_palette.dart';
import 'package:gu_data/src/models/enums/club_pattern.dart';

/// Süper adminin var olan kulüpte (ADM-03 düzenleme) değiştirdiği alanların
/// yaması — PLAN §10.4 `AdminRepository.updateClubIdentity`; rules-spec §3.3
/// U(süper) (T-37, sözleşme `docs/plans/T-37.md` §4 a).
///
/// Yalnızca **verilen** alanlar yazılır; verilmeyen alan belgede olduğu gibi
/// kalır. Kimlik alanları ([name] + [nameLower], [categoryId], [iconName],
/// [founded]) yalnızca süper admine açıktır; ADM-03 formunun öteki alanları
/// ([summary], [about], kapak şablonu, iki anahtar) da aynı yamayla yazılır
/// çünkü kulüp ayarları dalı (`ManagementRepository.updateClubSettings`)
/// süper admine kapalıdır (Q-09). `status` / `suspendReason`
/// (`suspendClub` / `activateClub`), `presidentId` (`assignPresident`),
/// `advisor.userId` (`MembershipRepository.setAdvisor`), sayaç, sabitleme ve
/// logo / kapak dosyasının **yeni** yolu (`AdminRepository.updateClubMedia`)
/// bu yamayla **değiştirilemez** (tipte yoktur; Rules da reddeder). Yüklenmiş
/// kapak ise bırakılabilir ([clearCoverPath] → `coverPath: null`; dosya
/// silinmez — D-10; yönetici dalındaki `ClubSettingsPatch.clearCoverPath` ile
/// aynı kalıp, W-102).
///
/// [name] ve [nameLower] birlikte verilir (CD-11; çağıran `trLower()` ile
/// üretir). [advisor] danışmanın adını / ünvanını yazar, bağlı hesabı
/// (`advisor.userId`) korur; [clearAdvisor] danışmanı kaldırır (`advisor:
/// null`) ve yalnızca hesabı bağlanmamış danışmanda geçerlidir.
final class ClubIdentityPatch extends Equatable {
  /// Verilen alanları taşıyan yama.
  const ClubIdentityPatch({
    this.name,
    this.nameLower,
    this.categoryId,
    this.iconName,
    this.founded,
    this.summary,
    this.about,
    this.palette,
    this.pattern,
    this.coverSeed,
    this.applicationsOpen,
    this.approvalRequired,
    this.advisor,
    this.clearAdvisor = false,
    this.clearCoverPath = false,
  }) : assert(
         !clearAdvisor || advisor == null,
         'clearAdvisor ile advisor birlikte verilemez',
       );

  /// Kulüp adı (`FieldValidators.clubName`); [nameLower] ile birlikte.
  final String? name;

  /// [name]'in Türkçe küçük harfli karşılığı (CD-11).
  final String? nameLower;

  /// Kategori kimliği (`FieldValidators.categoryId`).
  final String? categoryId;

  /// Amblem ikonunun adı.
  final String? iconName;

  /// Kuruluş yılı (`FieldValidators.founded`).
  final int? founded;

  /// Kısa tanıtım (≤ `Limits.clubSummaryMax`).
  final String? summary;

  /// Hakkında metni (≤ `Limits.clubAboutMax`).
  final String? about;

  /// Kapak şablonunun renk paleti.
  final ClubPalette? palette;

  /// Kapak şablonunun deseni.
  final ClubPattern? pattern;

  /// Kapak şablonunun tohumu (boş olamaz).
  final String? coverSeed;

  /// Kulüp başvuruya / katılıma açık mı?
  final bool? applicationsOpen;

  /// Başvurular yönetici onayı gerektiriyor mu?
  final bool? approvalRequired;

  /// Danışmanın adı ve ünvanı (bağlı hesap korunur).
  final AdvisorInput? advisor;

  /// Danışman kaldırılıyor mu (`advisor: null`)?
  final bool clearAdvisor;

  /// Yüklenmiş kapak bırakılıp şablona dönülüyor mu (ADM-03 → SHT-31
  /// "Kullan")? `true` → `coverPath: null` yazılır (Rules §3.3 U(süper)
  /// yalnızca `null`'a izin verir; yeni yol yalnızca `updateClubMedia`
  /// dalındadır).
  final bool clearCoverPath;

  /// Yama hiçbir alan taşımıyor mu?
  bool get isEmpty =>
      name == null &&
      nameLower == null &&
      categoryId == null &&
      iconName == null &&
      founded == null &&
      summary == null &&
      about == null &&
      palette == null &&
      pattern == null &&
      coverSeed == null &&
      applicationsOpen == null &&
      approvalRequired == null &&
      advisor == null &&
      !clearAdvisor &&
      !clearCoverPath;

  @override
  List<Object?> get props => [
    name,
    nameLower,
    categoryId,
    iconName,
    founded,
    summary,
    about,
    palette,
    pattern,
    coverSeed,
    applicationsOpen,
    approvalRequired,
    advisor,
    clearAdvisor,
    clearCoverPath,
  ];
}
