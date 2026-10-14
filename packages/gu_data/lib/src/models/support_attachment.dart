import 'dart:typed_data';

/// Destek talebine eklenen tek görsel (SET-05 "Ekran görüntüsü ekle"; PLAN
/// §10.4 `SupportAttachment{bytes, contentType}`).
///
/// Baytlar seçicinin yeniden kodladığı görseldir (CD-135); yükleme
/// `SupportRepository.createTicket` içinde yapılır (PLAN §6.1).
final class SupportAttachment {
  /// [contentType] türünde [bytes] görseli.
  const SupportAttachment({required this.bytes, required this.contentType});

  /// Görselin baytları (boş değil, `Limits.imageMaxBytes` sınırının altında).
  final Uint8List bytes;

  /// İçerik türü (`StoragePaths.extensionByContentType` anahtarı:
  /// `image/jpeg`, `image/png`, `image/webp`).
  final String contentType;

  @override
  String toString() => 'SupportAttachment($contentType, ${bytes.length} bayt)';
}
