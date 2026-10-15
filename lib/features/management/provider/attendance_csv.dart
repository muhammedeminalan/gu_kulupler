import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/management/provider/members_csv.dart';

/// CSV'nin bir satırı (katılımcı başına).
typedef AttendanceCsvRow = ({
  String name,
  String email,
  RsvpStatus status,
  DateTime? scannedAt,
});

/// MGT-06 "⋮ → Dışa aktar (CSV)" metni — prototip `exportCsv`
/// (`screens-manage.js:126`).
///
/// * Sütunlar prototipteki sırayla ve adlarıyla: `ad`, `eposta`, `durum`
///   (yerelleştirilmiş durum adı — view verir), `okutma` (ISO 8601 UTC;
///   okutulmadıysa boş).
/// * Biçim (ayraç `;`, tırnaklama, formül önlemi, CRLF, UTF-8 BOM)
///   [MembersCsv] ile aynıdır.
abstract final class AttendanceCsv {
  /// Paylaşılan dosyanın adı (prototip `katilimcilar.csv`).
  static const String fileName = 'katilimcilar.csv';

  /// Başlık satırı (`screens-manage.js:126`).
  static const List<String> header = ['ad', 'eposta', 'durum', 'okutma'];

  /// [rows] satırlarının BOM'lu CSV metni; [statusLabel] durum adını verir.
  static String build(
    List<AttendanceCsvRow> rows,
    String Function(RsvpStatus status) statusLabel,
  ) {
    final lines = [
      _line(header),
      for (final row in rows)
        _line([
          row.name,
          row.email,
          statusLabel(row.status),
          row.scannedAt?.toUtc().toIso8601String() ?? '',
        ]),
    ];
    return '${MembersCsv.bom}${lines.join(MembersCsv.lineBreak)}'
        '${MembersCsv.lineBreak}';
  }

  static String _line(List<String> cells) =>
      cells.map(MembersCsv.cell).join(MembersCsv.separator);
}
