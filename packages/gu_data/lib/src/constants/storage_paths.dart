import 'dart:math';

import 'package:gu_data/src/core/app_clock.dart';

/// Storage nesne yolları — **tek** yol sınıfı (PLAN §9.4, §10.2; D-10).
///
/// Her yol `<kök>/<kimlik>/<dosya>` biçimindedir ve dosya adı daima
/// [newFileName] şemasındandır: `<UTC yyyyMMddTHHmmssZ>_<16 hex>.<uzantı>`.
/// Sabit ad (`avatar.jpg`, `logo.jpg`, `cover.jpg`, `0.jpg`) hiçbir yolda
/// kullanılmaz: Storage Rules her yolda üzerine yazmayı ve silmeyi reddeder,
/// değiştirme = yeni dosya + Firestore yol alanı (`avatarPath`, `logoPath`,
/// `coverPath`, `images[].path`, `attachmentPaths[]`); eski dosya yetim kalır.
///
/// Üreticiler geçersiz girdide [ArgumentError] fırlatır (boş, `/` içeren ya
/// da `.` / `..` olan kimlik, şemaya uymayan dosya adı); doğrulayıcılar hiçbir
/// zaman fırlatmaz.
abstract final class StoragePaths {
  /// Kullanıcı avatarlarının kökü: `users/{uid}/{file}`.
  static const String usersRoot = 'users';

  /// Kulüp logo ve kapaklarının kökü: `clubs/{clubId}/{file}`.
  static const String clubsRoot = 'clubs';

  /// Etkinlik kapaklarının kökü: `events/{eventId}/{file}` (CD-47).
  static const String eventsRoot = 'events';

  /// Gönderi görsellerinin kökü: `posts/{postId}/{file}` (CD-39).
  static const String postsRoot = 'posts';

  /// Destek eklerinin kökü: `support/{ticketNo}/{file}`.
  static const String supportRoot = 'support';

  /// İzinli içerik türü → dosya uzantısı. Yüklenebilen tek türler bunlardır
  /// (`StorageError.invalidType`); uzantı içerik türünden türetilir.
  static const Map<String, String> extensionByContentType = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  /// Dosya adı deseni (`RegExp` kaynağı; yol ayırıcı içermez):
  /// `yyyyMMddTHHmmssZ_<16 küçük hex>.(jpg|png|webp)`.
  static const String fileNamePattern =
      r'\d{8}T\d{6}Z_[0-9a-f]{16}\.(?:jpg|png|webp)';

  /// Avatar yolu: `users/{uid}/{file}`.
  static String userAvatar(String uid, String file) =>
      _path(usersRoot, uid, file);

  /// Kulüp logosu yolu: `clubs/{clubId}/{file}` (logo/kapak ayrımı Firestore
  /// alanıyladır: `logoPath`).
  static String clubLogo(String clubId, String file) =>
      _path(clubsRoot, clubId, file);

  /// Kulüp kapağı yolu: `clubs/{clubId}/{file}` (`coverPath`).
  static String clubCover(String clubId, String file) =>
      _path(clubsRoot, clubId, file);

  /// Etkinlik kapağı yolu: `events/{eventId}/{file}`.
  static String eventCover(String eventId, String file) =>
      _path(eventsRoot, eventId, file);

  /// Gönderi görseli yolu: `posts/{postId}/{file}`.
  static String postImage(String postId, String file) =>
      _path(postsRoot, postId, file);

  /// Destek eki yolu: `support/{ticketNo}/{file}`.
  static String supportAttachment(String ticketNo, String file) =>
      _path(supportRoot, ticketNo, file);

  /// Yeni, benzersiz dosya adı: `<UTC yyyyMMddTHHmmssZ>_<16 hex>.<ext>`
  /// (örnek `20261008T201501Z_3f9a1c2b7d4e5f60.jpg`).
  ///
  /// Damga [clock] saatinden, 16 hex karakter (8 bayt) [random] kaynağından
  /// gelir; üretimde kaynak `Random.secure()` olmalıdır (ad tahmin edilemez,
  /// üzerine yazma olmaz). [ext] içerik türünden türetilir
  /// ([extensionByContentType]) ve `jpg`, `png`, `webp` dışında olamaz
  /// ([ArgumentError]).
  static String newFileName(AppClock clock, Random random, String ext) {
    if (!extensionByContentType.containsValue(ext)) {
      throw ArgumentError.value(ext, 'ext', 'jpg, png ya da webp olmalı');
    }
    final now = clock.nowUtc().toUtc();
    final stamp =
        '${_pad(now.year, 4)}${_pad(now.month, 2)}${_pad(now.day, 2)}'
        'T${_pad(now.hour, 2)}${_pad(now.minute, 2)}${_pad(now.second, 2)}Z';
    final hex = StringBuffer();
    for (var i = 0; i < _randomBytes; i++) {
      hex.write(_pad(random.nextInt(_byteRange), 2, radix: 16));
    }
    return '${stamp}_$hex.$ext';
  }

  /// [path], [uid] kullanıcısının avatar yolu mu (`users/{uid}/{file}`)?
  static bool isUserAvatar(String path, String uid) =>
      _matches(usersRoot, uid, path);

  /// [path], [clubId] kulübünün logo ya da kapak yolu mu
  /// (`clubs/{clubId}/{file}`)?
  static bool isClubFile(String path, String clubId) =>
      _matches(clubsRoot, clubId, path);

  /// [path], [eventId] etkinliğinin kapak yolu mu (`events/{eventId}/{file}`)?
  static bool isEventCover(String path, String eventId) =>
      _matches(eventsRoot, eventId, path);

  /// [path], [postId] gönderisinin görsel yolu mu (`posts/{postId}/{file}`)?
  static bool isPostImage(String path, String postId) =>
      _matches(postsRoot, postId, path);

  /// [path], [ticketNo] destek talebinin ek yolu mu
  /// (`support/{ticketNo}/{file}`)?
  static bool isSupportFile(String path, String ticketNo) =>
      _matches(supportRoot, ticketNo, path);

  static String _path(String root, String id, String file) {
    if (!_isSegment(id)) {
      throw ArgumentError.value(id, 'id', 'tek yol parçası olmalı');
    }
    if (!_fileName.hasMatch(file)) {
      throw ArgumentError.value(
        file,
        'file',
        'StoragePaths.newFileName şemasında olmalı',
      );
    }
    return '$root/$id/$file';
  }

  static bool _matches(String root, String id, String path) =>
      _isSegment(id) &&
      RegExp(
        '^${RegExp.escape(root)}/${RegExp.escape(id)}/$fileNamePattern\$',
      ).hasMatch(path);

  /// Tek yol parçası: boş değil, `/` içermez, `.` ya da `..` değil.
  static bool _isSegment(String value) =>
      value.isNotEmpty && !value.contains('/') && value != '.' && value != '..';

  static String _pad(int value, int width, {int radix = 10}) =>
      value.toRadixString(radix).padLeft(width, '0');

  static final RegExp _fileName = RegExp('^$fileNamePattern\$');
  static const int _randomBytes = 8;
  static const int _byteRange = 256;
}
