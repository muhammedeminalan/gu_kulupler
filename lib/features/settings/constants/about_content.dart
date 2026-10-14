/// SET-04 "Hakkında" ekranının sabit içeriği — prototip `S['SET-04']`
/// (`screens-profile.js:95–103`): ekip satırları, açık kaynak lisansları ve
/// ekrana özgü iki ölçü.
///
/// Ad, ürün adı ve lisans adı özel addır, çevrilmez (ARB'de yok); rol
/// etiketleri ve lisans açıklamaları ARB'dedir (`aboutTeam*`,
/// `aboutLicense*`).
library;

/// Ekip satırındaki rol (`about.team.pm` / `.design` / `.dev`).
enum AboutTeamRole {
  /// "Ürün".
  pm,

  /// "Tasarım".
  design,

  /// "Geliştirme".
  dev,
}

/// Ekip satırı: ad (avatar tohumu da adın kendisidir — `seed=${n}`) + rol.
typedef AboutTeamMember = ({String name, AboutTeamRole role});

/// "Açık kaynak lisansları" kartının satırları (sıra tasarımdaki gibi).
/// Satır açılınca lisans açıklaması ve "Lisansı görüntüle" (DLG-32 → [uri])
/// görünür.
enum AboutLicense {
  /// Lucide ikon seti.
  lucide('Lucide', 'ISC', 'https://lucide.dev/license'),

  /// Montserrat yazı tipi.
  montserrat(
    'Montserrat',
    'SIL OFL 1.1',
    'https://fonts.google.com/specimen/Montserrat/license',
  ),

  /// Inter yazı tipi.
  inter(
    'Inter',
    'SIL OFL 1.1',
    'https://fonts.google.com/specimen/Inter/license',
  );

  const AboutLicense(this.title, this.licenseName, this._url);

  /// Satır başlığı (ürün adı).
  final String title;

  /// Alt satır (lisans adı).
  final String licenseName;

  final String _url;

  /// Lisans metninin adresi ("Lisansı görüntüle").
  Uri get uri => Uri.parse(_url);
}

/// Ekip ve ekrana özgü ölçüler.
abstract final class AboutContent {
  /// "Ekip" kartı (sıra tasarımdaki gibi).
  static const List<AboutTeamMember> team = [
    (name: 'Ekin Yurdakul', role: AboutTeamRole.pm),
    (name: 'Lale Korkut', role: AboutTeamRole.design),
    (name: 'Baran Çelik', role: AboutTeamRole.dev),
  ];

  /// Açıklama paragrafının en büyük genişliği (`max-width:300px`).
  static const double descriptionMaxWidth = 300;

  /// Uygulama adının harf aralığı, yazı boyutunun katı
  /// (`letter-spacing:.04em`).
  static const double titleLetterSpacingEm = 0.04;
}
