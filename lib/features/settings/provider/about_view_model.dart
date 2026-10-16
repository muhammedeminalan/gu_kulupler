import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/features/settings/constants/about_content.dart';
import 'package:gu_kulupler/features/settings/provider/about_state.dart';
import 'package:gu_kulupler/product/mixin/external_link_mixin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'about_view_model.g.dart';

/// SET-04 "Hakkında" ekranının ViewModel'i (PLAN §12.12; prototip
/// `S['SET-04']`, `screens-profile.js:95–103`).
///
/// | İşlem | Sonuç |
/// |---|---|
/// | [toggleLicense] (`SET-04.license.<k>`) | satır açılır / kapanır |
/// | [toggleReleaseNotes] (`SET-04.releaseNotes`) | sürüm notları açılır / kapanır |
/// | [openLicense] (`SET-04.licenseLink.<k>`) | DLG-32 → "Aç" → adres cihazda açılır |
/// | [openTeamGithub] (`SET-04.team.github`) | DLG-32 → "Aç" → GitHub profili cihazda açılır |
///
/// Sürüm ve derleme numarası `AppInfoService`'ten eşzamanlı okunur (servis
/// açılışta yüklenir); ayrı yükleme adımı yoktur. Gezinme (koşullar,
/// gizlilik, destek, geri) view'dadır.
///
/// Design: SET-04
@riverpod
final class AboutViewModel extends _$AboutViewModel
    with ProjectDependencyMixin, ExternalLinkMixin {
  @override
  AboutState build() => AboutState(
    version: appInfoService.version,
    buildNumber: appInfoService.buildNumber,
  );

  /// [license] satırını açar / kapar.
  void toggleLicense(AboutLicense license) {
    final open = {...state.openLicenses};
    if (!open.remove(license)) open.add(license);
    state = state.copyWith(openLicenses: open);
  }

  /// "Sürüm notları" satırını açar / kapar.
  void toggleReleaseNotes() =>
      state = state.copyWith(isReleaseNotesOpen: !state.isReleaseNotesOpen);

  /// "Lisansı görüntüle": DLG-32 onayı → [license] adresi cihazda açılır.
  Future<ExternalLinkResult> openLicense(AboutLicense license) =>
      openExternalLink(license.uri);

  /// Ekip satırı: DLG-32 onayı → [member]'ın GitHub profili cihazda açılır
  /// (kullanıcı kararı 2026-10-16).
  Future<ExternalLinkResult> openTeamGithub(AboutTeamMember member) =>
      openExternalLink(member.githubUrl);
}
