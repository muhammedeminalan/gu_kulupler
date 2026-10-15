import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Kulübe yüklenecek tek görsel — logo ya da kapak (MGT-09; PLAN §10.4
/// `ManagementRepository.updateClubMedia` girdisi; T-36).
///
/// [bytes] **yeniden kodlanmış** görseldir (uygulamanın görsel seçicisinin
/// çıktısı — EXIF ayıklanmış, CD-135); özgün kamera / galeri dosyası buraya
/// verilmez. Eşitlik yapılmaz (megabaytlarca bayt karşılaştırılmaz).
final class ClubMediaUpload {
  /// [contentType] türünde [bytes] görseli.
  const ClubMediaUpload({required this.bytes, required this.contentType});

  /// Görselin baytları (boş değil, `Limits.imageMaxBytes` sınırının altında).
  final Uint8List bytes;

  /// İçerik türü (`StoragePaths.extensionByContentType` anahtarı:
  /// `image/jpeg`, `image/png`, `image/webp`).
  final String contentType;

  @override
  String toString() => 'ClubMediaUpload($contentType, ${bytes.length} bayt)';
}

/// `ManagementRepository.updateClubMedia` başarısının sonucu: yüklenip
/// kulübe yazılan yeni Storage yolları. Yalnızca verilen görselin yolu
/// doludur (logo verilmediyse [logoPath] `null` — alan değişmemiştir).
final class ClubMediaPaths extends Equatable {
  /// Yazılan yollar.
  const ClubMediaPaths({this.logoPath, this.coverPath});

  /// Yeni `clubs.logoPath` (`clubs/{clubId}/{file}`); logo verilmediyse
  /// `null`.
  final String? logoPath;

  /// Yeni `clubs.coverPath` (`clubs/{clubId}/{file}`); kapak verilmediyse
  /// `null`.
  final String? coverPath;

  @override
  List<Object?> get props => [logoPath, coverPath];
}
