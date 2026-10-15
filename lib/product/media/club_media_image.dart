import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/media/post_image_resolver.dart';

/// Kulübün yüklenmiş logosu (`clubs.logoPath`) ve kapağı (`clubs.coverPath`;
/// ikisi de `clubs/{clubId}/{file}`, T-36 `updateClubMedia`) → çizilecek
/// görsel. Tek yardımcıdır: CLB-01 kartları (`ClubCard`, `MyClubChip`),
/// CLB-02 sonuç kartı, CLB-03 başlığı (`ClubHeader`) ve MGT-09 önizlemesi
/// aynı yoldan çözer.
///
/// `null` döner (çağıran şablon kapağı / ikonlu amblemi çizer — K-C): kulüp
/// yok ya da silinmiş, görsel yüklenmemiş ya da indirme adresi henüz gelmedi
/// (adres gelince yalnızca o yolu izleyen widget yeniden çizilir —
/// [StorageImageRefX.storageImage]). Ortak widget'lar saf kalır: görseli
/// çağıran çözer ve `ImageProvider?` olarak verir.
///
/// Okuma yetkisi Storage Rules'tadır (`clubs/` — doğrulanmış kullanıcı, tek
/// dosya `get`; D-29).
extension ClubMediaResolverX on StorageImageResolver {
  /// [club] kulübünün logosu; yoksa `null`. [coverEdgePx] amblemin cihaz
  /// pikseli kenarıdır ([decodePx]).
  ImageProvider? clubLogo(ClubModel? club, {int? coverEdgePx}) =>
      club == null || club.isDeleted
      ? null
      : this(club.logoPath, coverEdgePx: coverEdgePx);

  /// [club] kulübünün kapağı; yoksa `null`.
  ImageProvider? clubCover(ClubModel? club, {int? coverEdgePx}) =>
      club == null || club.isDeleted
      ? null
      : this(club.coverPath, coverEdgePx: coverEdgePx);
}

/// `build` içinde kısa yol:
/// `ClubCard(club: club, coverImage: ref.clubCoverImage(club), …)`.
extension ClubMediaImageRefX on WidgetRef {
  /// [club] kulübünün logosu (yalnızca bu yolun sağlayıcısı izlenir).
  /// [displaySize] amblemin kenarıdır (dp; `GuEmblemSize.dimension`): logo
  /// bu boyutta çözülür.
  ImageProvider? clubLogoImage(ClubModel? club, {double? displaySize}) =>
      club == null || club.isDeleted
      ? null
      : this.storageImage(club.logoPath, displaySize: displaySize);

  /// [club] kulübünün kapağı (yalnızca bu yolun sağlayıcısı izlenir).
  /// [displaySize] verilmezse sınırlı tam boy (kart / başlık kapağı).
  ImageProvider? clubCoverImage(ClubModel? club, {double? displaySize}) =>
      club == null || club.isDeleted
      ? null
      : this.storageImage(club.coverPath, displaySize: displaySize);
}
