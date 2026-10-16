/// SET-04 "Hakkında" ekranının sabit içeriği — prototip `S['SET-04']`
/// (`screens-profile.js:95–103`): ekip satırı, açık kaynak lisansları ve
/// ekrana özgü iki ölçü.
///
/// Ad, ürün adı, lisans adı ve GitHub kullanıcı adı özel addır, çevrilmez
/// (ARB'de yok); lisans açıklamaları ve erişilebilirlik etiketleri
/// ARB'dedir (`aboutLicense*`, `aboutTeamGithub`).
library;

/// "Ekip" kartının satırı.
///
/// Kullanıcı kararı 2026-10-16: prototipin üç örnek kişisi (rol etiketli)
/// yerine tek geliştirici; rol etiketi yerine adın altında GitHub bağlantısı
/// (DLG-32 → [githubUrl]), avatar olarak profil fotoğrafı ([avatarAsset]).
final class AboutTeamMember {
  /// [githubUser] GitHub kullanıcı adıdır (`github.com/<githubUser>`).
  const AboutTeamMember({
    required this.name,
    required this.githubUser,
    this.avatarAsset,
  });

  /// Ad soyad (avatar baş harfleri ve renk tohumu da buradan).
  final String name;

  /// GitHub kullanıcı adı.
  final String githubUser;

  /// Profil fotoğrafı (uygulama varlığı); `null` ya da yüklenemezse baş
  /// harfler görünür.
  final String? avatarAsset;

  /// GitHub alan adı.
  static const String _githubHost = 'github.com';

  /// Profil adresi (`https://github.com/<githubUser>`).
  Uri get githubUrl => Uri.https(_githubHost, githubUser);

  /// Satırda görünen kısa adres (`github.com/<githubUser>`).
  String get githubLabel => '$_githubHost/$githubUser';
}

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
  /// "Ekip" kartı (kullanıcı kararı 2026-10-16: yalnızca geliştirici).
  static const List<AboutTeamMember> team = [
    AboutTeamMember(
      name: 'Muhammed Emin Alan',
      githubUser: 'muhammedeminalan',
      avatarAsset: 'assets/team/muhammed-emin-alan.jpg',
    ),
  ];

  /// Açıklama paragrafının en büyük genişliği (`max-width:300px`).
  static const double descriptionMaxWidth = 300;

  /// Uygulama adının harf aralığı, yazı boyutunun katı
  /// (`letter-spacing:.04em`).
  static const double titleLetterSpacingEm = 0.04;
}
