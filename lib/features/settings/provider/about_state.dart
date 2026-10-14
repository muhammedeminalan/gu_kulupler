import 'package:equatable/equatable.dart';
import 'package:gu_kulupler/features/settings/constants/about_content.dart';

/// SET-04 "Hakkında" ekranının durumu (PLAN §12.12).
///
/// * [version] / [buildNumber] uygulama paketinden okunur
///   (`AppInfoService`, `package_info_plus`; açılışta yüklenmiş — CD-08).
/// * [openLicenses] ve [isReleaseNotesOpen] açılır satırlardır (prototip
///   `open` haritası); ekran açılışında hepsi kapalıdır.
final class AboutState extends Equatable {
  /// Varsayılan: sürüm bilinmiyor, satırlar kapalı.
  const AboutState({
    this.version = '',
    this.buildNumber = '',
    this.openLicenses = const {},
    this.isReleaseNotesOpen = false,
  });

  /// Uygulama sürümü (`1.0.0`).
  final String version;

  /// Derleme numarası.
  final String buildNumber;

  /// Açık lisans satırları.
  final Set<AboutLicense> openLicenses;

  /// "Sürüm notları" açık mı?
  final bool isReleaseNotesOpen;

  /// [license] satırı açık mı?
  bool isLicenseOpen(AboutLicense license) => openLicenses.contains(license);

  @override
  List<Object?> get props => [
    version,
    buildNumber,
    openLicenses,
    isReleaseNotesOpen,
  ];

  /// Verilen alanları değiştirilmiş kopya.
  AboutState copyWith({
    String? version,
    String? buildNumber,
    Set<AboutLicense>? openLicenses,
    bool? isReleaseNotesOpen,
  }) => AboutState(
    version: version ?? this.version,
    buildNumber: buildNumber ?? this.buildNumber,
    openLicenses: openLicenses ?? this.openLicenses,
    isReleaseNotesOpen: isReleaseNotesOpen ?? this.isReleaseNotesOpen,
  );
}
