// IcsBuilder — RFC 5545 çıktısı (SHT-14 "Cihaz takvimi"; K-15, CD-08):
// altın metin karşılaştırması, kaçış, 75 oktet katlama (çok baytlı karakter
// bölünmez), CRLF, isteğe bağlı satırlar, dosya adı.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

EventModel _event({
  String title = 'Yapay Zekâya Giriş Atölyesi',
  String desc =
      'Makine öğrenmesi; temel kavramlar, uygulama.\nBilgisayarını getir.',
  String? placeText,
  EventStatus status = EventStatus.published,
  DateTime? updatedAt,
  DateTime? createdAt,
}) => EventModel(
  id: 'e01',
  clubId: 'c01',
  title: title,
  desc: desc,
  type: EventType.training,
  startsAt: DateTime.utc(2026, 10, 9, 15),
  endsAt: DateTime.utc(2026, 10, 9, 17, 30),
  placeText: placeText,
  status: status,
  coverPalette: ClubPalette.values.first,
  coverPattern: ClubPattern.values.first,
  updatedAt: updatedAt,
  createdAt: createdAt,
);

/// Katlanmış metni açar (RFC 5545 §3.1: CRLF + tek boşluk silinir).
String _unfold(String text) => text.replaceAll('\r\n ', '');

void main() {
  group('IcsBuilder.build', () {
    test('altın metin: VCALENDAR / VEVENT, UTC zamanlar, kaçış, katlama', () {
      final ics = IcsBuilder.build(
        _event(updatedAt: DateTime.utc(2026, 9, 20, 8, 30, 5)),
        clubName: 'Yazılım ve Yapay Zekâ Topluluğu',
        location: 'Bilgisayar Laboratuvarı-2',
      );
      expect(
        ics,
        'BEGIN:VCALENDAR\r\n'
        'VERSION:2.0\r\n'
        'PRODID:-//GU Kulupler//TR\r\n'
        'CALSCALE:GREGORIAN\r\n'
        'METHOD:PUBLISH\r\n'
        'BEGIN:VEVENT\r\n'
        'UID:e01@kulupler.gumushane.edu.tr\r\n'
        'DTSTAMP:20260920T083005Z\r\n'
        'DTSTART:20261009T150000Z\r\n'
        'DTEND:20261009T173000Z\r\n'
        'SUMMARY:Yapay Zekâya Giriş Atölyesi\r\n'
        'LOCATION:Bilgisayar Laboratuvarı-2\r\n'
        // 12 + 63 = 75 oktet ("ı", "â", "ğ", "ö" ikişer bayt), sonra katlama.
        'DESCRIPTION:Yazılım ve Yapay Zekâ Topluluğu\\n\\nMakine öğrenmesi\\; tem\r\n'
        ' el kavramlar\\, uygulama.\\nBilgisayarını getir.\r\n'
        'END:VEVENT\r\n'
        'END:VCALENDAR\r\n',
      );
    });

    test('her satır CRLF ile biter, en çok 75 oktettir; çıplak LF yok', () {
      final ics = IcsBuilder.build(
        _event(desc: 'ğüşiöç' * 40),
        clubName: 'Kulüp',
      );
      expect(ics.endsWith('\r\n'), isTrue);
      expect(ics.replaceAll('\r\n', '').contains('\n'), isFalse);
      expect(ics.replaceAll('\r\n', '').contains('\r'), isFalse);
      for (final line in ics.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: line);
      }
    });

    test('katlama çok baytlı karakteri bölmez; açılınca özgün satır döner', () {
      final line = 'SUMMARY:${'ş' * 100}';
      final folded = IcsBuilder.foldLine(line);
      expect(folded, contains('\r\n '));
      // Her parça geçerli UTF-8 olarak çözülür (bölünmüş bayt yok).
      for (final part in folded.split('\r\n')) {
        expect(() => utf8.decode(utf8.encode(part)), returnsNormally);
        expect(utf8.encode(part).length, lessThanOrEqualTo(75));
      }
      expect(_unfold(folded), line);
      // 75 oktete sığan satır katlanmaz.
      final fits = 'A' * 75;
      expect(IcsBuilder.foldLine(fits), fits);
      expect(IcsBuilder.foldLine('${fits}B'), '$fits\r\n B');
    });

    test('kaçış: ters bölü, noktalı virgül, virgül, satır sonları', () {
      expect(IcsBuilder.escapeText(r'a\b;c,d'), r'a\\b\;c\,d');
      expect(IcsBuilder.escapeText('a\r\nb\nc\rd'), r'a\nb\nc\nd');
      final ics = _unfold(
        IcsBuilder.build(_event(title: 'Kod; Kahve, Sohbet'), clubName: ''),
      );
      expect(
        ics,
        contains(
          r'SUMMARY:Kod\; Kahve\, Sohbet'
          '\r\n',
        ),
      );
    });

    test('mekân: verilen ad → placeText → yok; açıklama boşsa satır yok', () {
      String unfolded({String? location, String? placeText}) => _unfold(
        IcsBuilder.build(
          _event(desc: '', placeText: placeText),
          clubName: '',
          location: location,
        ),
      );
      expect(unfolded(location: 'Amfi 1'), contains('LOCATION:Amfi 1\r\n'));
      expect(unfolded(placeText: 'Kampüs'), contains('LOCATION:Kampüs\r\n'));
      expect(unfolded(), isNot(contains('LOCATION:')));
      expect(unfolded(), isNot(contains('DESCRIPTION:')));
    });

    test('DTSTAMP belgeden: updatedAt → createdAt → startsAt', () {
      String stamp(EventModel event) => RegExp(
        r'DTSTAMP:(\S+)\r\n',
      ).firstMatch(IcsBuilder.build(event, clubName: ''))!.group(1)!;
      expect(
        stamp(
          _event(
            updatedAt: DateTime.utc(2026, 9, 2),
            createdAt: DateTime.utc(2026, 9),
          ),
        ),
        '20260902T000000Z',
      );
      expect(
        stamp(_event(createdAt: DateTime.utc(2026, 9))),
        '20260901T000000Z',
      );
      expect(stamp(_event()), '20261009T150000Z');
    });

    test('yerel saatli an UTC yazılır; iptal → STATUS:CANCELLED', () {
      expect(
        IcsBuilder.formatUtc(DateTime.utc(2026, 1, 2, 3, 4, 5).toLocal()),
        '20260102T030405Z',
      );
      expect(
        IcsBuilder.build(_event(), clubName: ''),
        isNot(contains('STATUS:')),
      );
      expect(
        IcsBuilder.build(_event(status: EventStatus.cancelled), clubName: ''),
        contains('STATUS:CANCELLED\r\nEND:VEVENT'),
      );
    });
  });

  group('IcsBuilder dosya adı', () {
    test('başlığın ASCII kısaltması + .ics; boş kalırsa kimlik', () {
      expect(
        IcsBuilder.fileNameFor(_event()),
        'yapay-zekaya-giris-atolyesi.ics',
      );
      expect(
        IcsBuilder.fileNameFor(_event(title: 'İSTANBUL Işık — Çağrı!')),
        'istanbul-isik-cagri.ics',
      );
      expect(IcsBuilder.fileNameFor(_event(title: '  ¡¿  ')), 'e01.ics');
      expect(IcsBuilder.mimeType, 'text/calendar');
    });
  });
}
