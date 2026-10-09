/// Ürün adı ve dış adresler için TEK kaynak (D-01, K-D, K-N, CD-75, CD-76).
///
/// Başka hiçbir dosyada ürün adı, alan adı, URL ya da destek adresi literal
/// olarak yazılmaz; ARB metinleri `{appName}` / `{appNameDative}` yer
/// tutucularını bu sabitlerden alır.
abstract final class AppConstants {
  /// Ürün adı (brief K1; `CFBundleDisplayName` ve `android:label` ile parite testi).
  static const String appName = 'GÜ Kulüpler';

  /// Türkçe yönelme hâli ("…’e hoş geldin"); ad değişince `appName` ile birlikte güncellenir.
  static const String appNameDative = 'GÜ Kulüpler’e';

  /// İzinli e-posta alan adları (D-27). T-08'de `gu_data` `EmailDomainPolicy`
  /// tek kaynak olur ve bu alan ona delege eder (CD-76).
  static const List<String> allowedEmailDomains = <String>[
    'ogr.gumushane.edu.tr',
    'gumushane.edu.tr',
  ];

  /// Paylaşım bağlantısı kökü (K-09 yer tutucu; yalnızca kopyala/paylaş, App Links yok).
  static const String shareBaseUrl = 'https://kulupler.gumushane.edu.tr';

  /// Destek e-postası (DLG-01 mailto, SET-04; yer tutucu — K-N).
  static const String supportEmail = 'kulupler-destek@gumushane.edu.tr';
}
