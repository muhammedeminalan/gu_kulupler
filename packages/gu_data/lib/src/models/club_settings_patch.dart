import 'package:equatable/equatable.dart';
import 'package:gu_data/src/constants/firestore_fields.dart';
import 'package:gu_data/src/models/club_social_model.dart';
import 'package:gu_data/src/models/enums/club_palette.dart';
import 'package:gu_data/src/models/enums/club_pattern.dart';

/// `clubs/{clubId}` belgesinde kulüp yönetiminin (başkan, yönetim kurulu)
/// değiştirebildiği alanların yaması (PLAN §10.4
/// `ManagementRepository.updateClubSettings`; rules-spec §3.3 U(yönetim);
/// MGT-09).
///
/// Yalnızca **verilen** alanlar yazılır ([toJson]); verilmeyen alan belgede
/// olduğu gibi kalır. Kilitli alanlar (`name`, `nameLower`, `categoryId`,
/// `iconName`, `founded`, `status`, `presidentId`), sayaç ve sabitleme alanları
/// bu yamayla **değiştirilemez** (tipte yoktur; Rules da reddeder). Logo ve
/// kapak dosyası (`logoPath`, `coverPath`) ayrı akıştır (T-36
/// `updateClubMedia`); burada yalnızca hazır kapak şablonu ([palette],
/// [pattern], [coverSeed]) seçilir.
final class ClubSettingsPatch extends Equatable {
  /// Verilen alanları taşıyan yama.
  const ClubSettingsPatch({
    this.summary,
    this.about,
    this.conditions,
    this.social,
    this.approvalRequired,
    this.applicationsOpen,
    this.requireNote,
    this.palette,
    this.pattern,
    this.coverSeed,
  });

  /// Kısa tanıtım (≤ `Limits.clubSummaryMax`).
  final String? summary;

  /// Hakkında metni (≤ `Limits.clubAboutMax`).
  final String? about;

  /// Katılım koşulları (≤ `Limits.conditionsMax` madde).
  final List<String>? conditions;

  /// İletişim bağlantıları (nesnenin tamamı yazılır).
  final ClubSocialModel? social;

  /// Başvurular yönetici onayı gerektiriyor mu?
  final bool? approvalRequired;

  /// Kulüp başvuruya / katılıma açık mı? (`false` → TST-54)
  final bool? applicationsOpen;

  /// Başvuruda not zorunlu mu?
  final bool? requireNote;

  /// Kapak şablonunun renk paleti (SHT-31).
  final ClubPalette? palette;

  /// Kapak şablonunun deseni (SHT-31).
  final ClubPattern? pattern;

  /// Kapak şablonunun tohumu (boş olamaz).
  final String? coverSeed;

  /// Yama hiçbir alan taşımıyor mu?
  bool get isEmpty => toJson().isEmpty;

  /// Firestore `update` yükü: yalnızca verilen alanlar. `updatedAt` servis
  /// tarafından eklenir.
  Map<String, Object?> toJson() => {
    FirestoreFields.summary: ?summary,
    FirestoreFields.about: ?about,
    FirestoreFields.conditions: ?conditions,
    FirestoreFields.social: ?social?.toJson(),
    FirestoreFields.approvalRequired: ?approvalRequired,
    FirestoreFields.applicationsOpen: ?applicationsOpen,
    FirestoreFields.requireNote: ?requireNote,
    FirestoreFields.palette: ?palette?.json,
    FirestoreFields.pattern: ?pattern?.json,
    FirestoreFields.coverSeed: ?coverSeed,
  };

  @override
  List<Object?> get props => [
    summary,
    about,
    conditions,
    social,
    approvalRequired,
    applicationsOpen,
    requireNote,
    palette,
    pattern,
    coverSeed,
  ];
}
