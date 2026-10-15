// T-35 · TicketScanParser (MGT-07, D-30): `gu:ticket:v1:{eventId}:{code}`
// QR yükü ve elle girilen `GU-XXXX-XXXX` kodu ekranın etkinliğine göre
// çözülür; biçim kuralı `FirestoreIds.parseTicketQr` /
// `ticketCodePattern`'dadır (roadmap T-35 "QR içeriği ayrıştırma").
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/event/ticket_scan_parser.dart';

const String _eventId = 'e17';
const String _code = 'GU-7KQ2-M9XA';

const TicketScanParse _malformed = TicketScanRejected(
  TicketScanRejection.malformed,
);

void main() {
  group('T-35 · TicketScanParser.parseQr', () {
    test('bu etkinliğin v1 yükü → (eventId, code) ve kanonik yük', () {
      final payload = FirestoreIds.ticketQrPayload(_eventId, _code);
      expect(payload, 'gu:ticket:v1:e17:GU-7KQ2-M9XA');

      final parsed = TicketScanParser.parseQr(payload, eventId: _eventId);

      expect(
        parsed,
        const TicketScanAccepted(eventId: _eventId, code: _code),
      );
      expect((parsed as TicketScanAccepted).payload, payload);
    });

    test('başka etkinliğin geçerli bileti → otherEvent', () {
      expect(
        TicketScanParser.parseQr(
          FirestoreIds.ticketQrPayload('e01', _code),
          eventId: _eventId,
        ),
        const TicketScanRejected(TicketScanRejection.otherEvent),
      );
    });

    const malformed = <String, String>{
      'boş': '',
      'yalnızca kod': _code,
      'yanlış önek': 'gx:ticket:v1:e17:GU-7KQ2-M9XA',
      'yanlış tür': 'gu:pass:v1:e17:GU-7KQ2-M9XA',
      'yanlış sürüm (v2 — W-93)': 'gu:ticket:v2:e17:GU-7KQ2-M9XA',
      'büyük harf önek': 'GU:ticket:v1:e17:GU-7KQ2-M9XA',
      'boş eventId': 'gu:ticket:v1::GU-7KQ2-M9XA',
      'boş kod': 'gu:ticket:v1:e17:',
      'eksik parça': 'gu:ticket:v1:GU-7KQ2-M9XA',
      'fazla parça': 'gu:ticket:v1:e17:GU-7KQ2-M9XA:x',
      'yol ayırıcılı eventId': 'gu:ticket:v1:e/17:GU-7KQ2-M9XA',
      'küçük harf kod': 'gu:ticket:v1:e17:gu-7kq2-m9xa',
      'alfabe dışı I': 'gu:ticket:v1:e17:GU-7KQI-M9XA',
      'alfabe dışı O': 'gu:ticket:v1:e17:GU-7KQ2-M9XO',
      'alfabe dışı 0': 'gu:ticket:v1:e17:GU-7KQ0-M9XA',
      'alfabe dışı 1': 'gu:ticket:v1:e17:GU-7KQ1-M9XA',
      'kısa kod': 'gu:ticket:v1:e17:GU-7KQ2-M9X',
      'destek numarası': 'gu:ticket:v1:e17:GU-7KQ2M9',
      'baştaki boşluk': ' gu:ticket:v1:e17:GU-7KQ2-M9XA',
      'sondaki satır sonu': 'gu:ticket:v1:e17:GU-7KQ2-M9XA\n',
      'URL': 'https://example.com/gu:ticket:v1:e17:GU-7KQ2-M9XA',
    };
    for (final MapEntry(key: reason, value: raw) in malformed.entries) {
      test('geçersiz ($reason) → malformed', () {
        expect(TicketScanParser.parseQr(raw, eventId: _eventId), _malformed);
      });
    }
  });

  group('T-35 · TicketScanParser.parseManual', () {
    test('kod kırpılır ve büyük harfe çevrilir (prototip '
        '`code.trim().toUpperCase()`)', () {
      for (final input in [_code, '  gu-7kq2-m9xa ', 'Gu-7Kq2-M9xA\t']) {
        expect(
          TicketScanParser.parseManual(input, eventId: _eventId),
          const TicketScanAccepted(eventId: _eventId, code: _code),
          reason: input,
        );
      }
    });

    test('yapıştırılan tam QR yükü yük olarak çözülür (başka etkinlik '
        'reddedilir)', () {
      expect(
        TicketScanParser.parseManual(
          ' ${FirestoreIds.ticketQrPayload(_eventId, _code)} ',
          eventId: _eventId,
        ),
        const TicketScanAccepted(eventId: _eventId, code: _code),
      );
      expect(
        TicketScanParser.parseManual(
          FirestoreIds.ticketQrPayload('e01', _code),
          eventId: _eventId,
        ),
        const TicketScanRejected(TicketScanRejection.otherEvent),
      );
    });

    for (final input in [
      '',
      '   ',
      'GU-7KQ2',
      'GU7KQ2M9XA',
      'GU-7KQ2-M9XA-',
      'GU-7KQI-M9XA', // I yok
      'GU-7KQ2-M9X0', // 0 yok
      'XX-7KQ2-M9XA',
    ]) {
      test('geçersiz kod "$input" → malformed', () {
        expect(
          TicketScanParser.parseManual(input, eventId: _eventId),
          _malformed,
        );
      });
    }

    test('"Doğrula" en az 12 karakterde etkin (normalleştirilmiş)', () {
      expect(TicketScanParser.manualCodeLength, _code.length);
      expect(TicketScanParser.canVerify(''), isFalse);
      expect(TicketScanParser.canVerify('GU-7KQ2-M9X'), isFalse);
      expect(TicketScanParser.canVerify('  GU-7KQ2-M9X  '), isFalse);
      expect(TicketScanParser.canVerify('gu-7kq2-m9xa'), isTrue);
      expect(TicketScanParser.normalizeManual(' gu-7kq2-m9xa '), _code);
    });
  });
}
