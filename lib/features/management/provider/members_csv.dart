import 'dart:convert';
import 'dart:typed_data';

import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';

/// CSV hücrelerinin yerelleştirilmiş adları — view verir (ViewModel
/// `BuildContext` görmez): rol (`role.*`), bölüm (`dept.*`), sınıf
/// (`year.*`).
typedef MembersCsvLabels = ({
  String Function(ClubRole role) role,
  String Function(String department) department,
  String Function(YearLevel year) year,
});

/// CSV'nin bir satırı (üye başına).
typedef MembersCsvRow = ({
  String name,
  String email,
  String? department,
  YearLevel? year,
  ClubRole role,
  DateTime? joinedAt,
});

/// MGT-03 "Üye listesini dışa aktar (CSV)" metni — prototip `exportCsv`
/// (`screens-manage.js:66`).
///
/// * Sütunlar prototipteki sırayla ve adlarıyla: `ad`, `eposta`, `bolum`,
///   `sinif`, `rol`, `katilim_tarihi` (`yyyy-MM-dd`, İstanbul takvimi).
///   E-posta yönetimin okuduğu `private/contact` belgesindendir (D-29).
/// * Ayraç `;` (prototip; Türkçe Excel), her hücre çift tırnaklı, içteki `"`
///   ikilenir (RFC 4180 kaçışı), satır sonu CRLF; başta UTF-8 BOM
///   (`﻿`) — Excel Türkçe karakterleri doğru açar.
/// * Formül enjeksiyonu: `=`, `+`, `-`, `@`, sekme ya da CR ile başlayan
///   hücrenin başına `'` eklenir (kullanıcı adı bir hesap tablosunda
///   formül olarak çalışmasın).
abstract final class MembersCsv {
  /// Paylaşılan dosyanın adı (CD-08).
  static const String fileName = 'uyeler.csv';

  /// Paylaşım MIME türü.
  static const String mimeType = 'text/csv';

  /// Başlık satırı (`screens-manage.js:66`).
  static const List<String> header = [
    'ad',
    'eposta',
    'bolum',
    'sinif',
    'rol',
    'katilim_tarihi',
  ];

  /// Hücre ayracı.
  static const String separator = ';';

  /// Satır sonu (RFC 4180).
  static const String lineBreak = '\r\n';

  /// Bayt sırası işareti (UTF-8 BOM).
  static const String bom = '﻿';

  static const Set<String> _formulaLeads = {'=', '+', '-', '@', '\t', '\r'};

  /// [rows] satırlarının BOM'lu CSV metni.
  static String build(List<MembersCsvRow> rows, MembersCsvLabels labels) {
    final lines = [
      _line(header),
      for (final row in rows)
        _line([
          row.name,
          row.email,
          if (row.department case final department?)
            labels.department(department)
          else
            '',
          if (row.year case final year?) labels.year(year) else '',
          labels.role(row.role),
          if (row.joinedAt case final joined?) isoDate(joined) else '',
        ]),
    ];
    return '$bom${lines.join(lineBreak)}$lineBreak';
  }

  /// [text] metninin UTF-8 baytları (`FileService.writeTemp`).
  static Uint8List encode(String text) => utf8.encode(text);

  /// [instant] anının İstanbul takvimindeki tarihi (`2026-03-17`).
  static String isoDate(DateTime instant) {
    final local = AppDateFormats.toIstanbul(instant);
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  /// Tek hücre: formül önekine `'`, tırnak ikilenir, çift tırnakla sarılır.
  static String cell(String value) {
    final safe = value.isNotEmpty && _formulaLeads.contains(value[0])
        ? "'$value"
        : value;
    return '"${safe.replaceAll('"', '""')}"';
  }

  static String _line(List<String> cells) => cells.map(cell).join(separator);
}
