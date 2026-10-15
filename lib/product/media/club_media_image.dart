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
/// ([storageImageResolver] adres gelince yeni çözücü yayar, izleyen widget
/// yeniden çizilir). Ortak widget'lar saf kalır: görseli çağıran çözer ve
/// `ImageProvider?` olarak verir.
///
/// Okuma yetkisi Storage Rules'tadır (`clubs/` — doğrulanmış kullanıcı, tek
/// dosya `get`; D-29).
extension ClubMediaResolverX on StorageImageResolver {
  /// [club] kulübünün logosu; yoksa `null`.
  ImageProvider? clubLogo(ClubModel? club) =>
      club == null || club.isDeleted ? null : this(club.logoPath);

  /// [club] kulübünün kapağı; yoksa `null`.
  ImageProvider? clubCover(ClubModel? club) =>
      club == null || club.isDeleted ? null : this(club.coverPath);
}

/// `build` içinde kısa yol:
/// `ClubCard(club: club, coverImage: ref.clubCoverImage(club), …)`.
extension ClubMediaImageRefX on WidgetRef {
  /// [club] kulübünün logosu ([storageImageResolverProvider] izlenir).
  ImageProvider? clubLogoImage(ClubModel? club) =>
      watch(storageImageResolverProvider).clubLogo(club);

  /// [club] kulübünün kapağı ([storageImageResolverProvider] izlenir).
  ImageProvider? clubCoverImage(ClubModel? club) =>
      watch(storageImageResolverProvider).clubCover(club);
}
