import 'dart:convert';

import 'package:gu_data/src/models/enums/event_status.dart';
import 'package:gu_data/src/models/event_model.dart';

/// Etkinliği iCalendar (`.ics`, RFC 5545) metnine çeviren saf Dart üretici
/// (PLAN §4.3, K-15; CD-08).
///
/// SHT-14 "Cihaz takvimi": `IcsBuilder.build` → `FileService.writeTemp`
/// (`path_provider`) → `ShareService.shareFile(mimeType: 'text/calendar')`.
/// Ayrı `CalendarExportService` sınıfı yoktur.
///
/// * Zamanlar UTC'dir (`DTSTART:20261012T163000Z`, D-26); yerel saat
///   dönüşümünü takvim uygulaması yapar.
/// * [build]'in `location` parametresi mekânın **gösterilen** adıdır
///   (`placeId` → ARB etiketi uygulama katmanında çözülür; `gu_data`
///   yerelleştirme bilmez). Verilmezse `placeText` kullanılır; ikisi de
///   boşsa `LOCATION` satırı yazılmaz.
/// * `DTSTAMP` saatten değil belgeden türetilir (`updatedAt` → `createdAt`
///   → `startsAt`): aynı etkinlik aynı metni üretir (test edilebilir).
/// * Düzenleyen kulüp `DESCRIPTION`'ın ilk satırıdır: `ORGANIZER` bir takvim
///   adresi (`mailto:`) ister, kulübün kayıtlı adresi yoktur.
/// * Metin değerleri kaçışlanır (`\\`, `\;`, `\,`, `\n`; RFC 5545 §3.3.11),
///   satırlar 75 oktette katlanır (çok baytlı UTF-8 karakter bölünmez;
///   devam satırı tek boşlukla başlar — §3.1), satır sonu CRLF'dir.
/// * İptal edilmiş etkinlik `STATUS:CANCELLED` taşır.
abstract final class IcsBuilder {
  /// Paylaşılan dosyanın içerik türü.
  static const String mimeType = 'text/calendar';

  /// Dosya uzantısı (prototip `GU.slug(ev.title) + '.ics'`).
  static const String fileExtension = '.ics';

  /// `UID` alan adı (`<eventId>@kulupler.gumushane.edu.tr`, prototip
  /// `sheets.js:72`).
  static const String uidDomain = 'kulupler.gumushane.edu.tr';

  /// `PRODID` değeri (prototip `sheets.js:72`).
  static const String productId = '-//GU Kulupler//TR';

  /// Satır sonu (RFC 5545 §3.1).
  static const String crlf = '\r\n';

  /// Bir satırın en çok oktet sayısı (CRLF hariç; RFC 5545 §3.1).
  static const int maxLineOctets = 75;

  /// [event] için tek `VEVENT`'li takvim metni; [clubName] düzenleyen kulüp
  /// (açıklamanın ilk satırı), [location] mekânın gösterilen adı.
  static String build(
    EventModel event, {
    required String clubName,
    String? location,
  }) {
    final place = (location ?? event.placeText ?? '').trim();
    final description = [
      clubName.trim(),
      event.desc.trim(),
    ].where((part) => part.isNotEmpty).join(_paragraph);
    final stamp = event.updatedAt ?? event.createdAt ?? event.startsAt;
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:$productId',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:${event.id}@$uidDomain',
      'DTSTAMP:${formatUtc(stamp)}',
      'DTSTART:${formatUtc(event.startsAt)}',
      'DTEND:${formatUtc(event.endsAt)}',
      'SUMMARY:${escapeText(event.title)}',
      if (place.isNotEmpty) 'LOCATION:${escapeText(place)}',
      if (description.isNotEmpty) 'DESCRIPTION:${escapeText(description)}',
      if (event.status == EventStatus.cancelled) 'STATUS:CANCELLED',
      'END:VEVENT',
      'END:VCALENDAR',
    ];
    final buffer = StringBuffer();
    for (final line in lines) {
      buffer
        ..write(foldLine(line))
        ..write(crlf);
    }
    return buffer.toString();
  }

  /// [event] dosyasının adı: başlığın ASCII kısaltması + `.ics`
  /// (`yapay-zekaya-giris-atolyesi.ics`, prototip `GU.slug`); başlıktan ad
  /// çıkmazsa etkinlik kimliği.
  static String fileNameFor(EventModel event) {
    final slug = slugOf(event.title);
    return '${slug.isEmpty ? event.id : slug}$fileExtension';
  }

  /// [text] metninin dosya adına uygun biçimi (prototip `GU.slug`,
  /// `core.js:423`): Türkçe harfler ASCII'ye, harf / rakam dışı diziler `-`
  /// işaretine çevrilir; baştaki ve sondaki `-` atılır.
  static String slugOf(String text) {
    final folded = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      folded.write(_asciiFold[char] ?? char.toLowerCase());
    }
    return folded
        .toString()
        .replaceAll(_nonSlug, '-')
        .replaceAll(_edgeDashes, '');
  }

  /// [instant] anının UTC temel biçimi: `20261009T150000Z`.
  static String formatUtc(DateTime instant) {
    final utc = instant.toUtc();
    return '${_pad(utc.year, 4)}${_pad(utc.month, 2)}${_pad(utc.day, 2)}'
        'T${_pad(utc.hour, 2)}${_pad(utc.minute, 2)}${_pad(utc.second, 2)}Z';
  }

  /// RFC 5545 §3.3.11 `TEXT` kaçışı: `\` → `\\`, `;` → `\;`, `,` → `\,`,
  /// satır sonu (CRLF / LF / CR) → `\n`.
  static String escapeText(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll(_newline, r'\n');

  /// [line] satırını [maxLineOctets] oktetlik parçalara katlar: her devam
  /// satırı CRLF + tek boşlukla başlar; çok baytlı karakter bölünmez.
  static String foldLine(String line) {
    if (utf8.encode(line).length <= maxLineOctets) return line;
    final out = StringBuffer();
    var octets = 0;
    for (final rune in line.runes) {
      final char = String.fromCharCode(rune);
      final size = utf8.encode(char).length;
      if (octets + size > maxLineOctets) {
        out.write('$crlf ');
        // Devam satırının ilk okteti boşluktur.
        octets = 1;
      }
      out.write(char);
      octets += size;
    }
    return out.toString();
  }

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');

  /// Açıklamada kulüp adı ile metin arasındaki boş satır.
  static const String _paragraph = '\n\n';

  static final RegExp _newline = RegExp(r'\r\n|\r|\n');
  static final RegExp _nonSlug = RegExp('[^a-z0-9]+');
  static final RegExp _edgeDashes = RegExp(r'^-+|-+$');

  /// Türkçe harflerin ASCII karşılıkları (`İ` → `i`: `toLowerCase` `i̇`
  /// üretir).
  static const Map<String, String> _asciiFold = <String, String>{
    'ç': 'c',
    'Ç': 'c',
    'ğ': 'g',
    'Ğ': 'g',
    'ı': 'i',
    'I': 'i',
    'İ': 'i',
    'ö': 'o',
    'Ö': 'o',
    'ş': 's',
    'Ş': 's',
    'ü': 'u',
    'Ü': 'u',
    'â': 'a',
    'Â': 'a',
    'î': 'i',
    'Î': 'i',
    'û': 'u',
    'Û': 'u',
  };
}
