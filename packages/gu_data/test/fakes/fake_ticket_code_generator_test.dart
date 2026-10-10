// T-08 · FakeTicketCodeGenerator: arayüz sözleşmesi, sıralı ve desene uyan
// kodlar, bağımsız sayaçlar, üretilenlerin kaydı.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';
import 'fake_ticket_code_generator.dart';

final RegExp _ticketCode = RegExp(FirestoreIds.ticketCodePattern);
final RegExp _supportTicketNo = RegExp(FirestoreIds.supportTicketNoPattern);

void main() {
  group('T-08 · FakeTicketCodeGenerator · sözleşme', () {
    test('TicketCodeGenerator arayüzünü uygular', () {
      expect(FakeTicketCodeGenerator(), isA<TicketCodeGenerator>());
    });

    test('ilk bilet kodları sıralı ve sabittir', () {
      final fake = FakeTicketCodeGenerator();

      expect(
        [for (var i = 0; i < 4; i++) fake.ticketCode()],
        ['GU-AAAA-AAAB', 'GU-AAAA-AAAC', 'GU-AAAA-AAAD', 'GU-AAAA-AAAE'],
      );
    });

    test('ilk destek numaraları sıralı ve sabittir', () {
      final fake = FakeTicketCodeGenerator();

      expect(
        [for (var i = 0; i < 3; i++) fake.supportTicketNo()],
        ['GU-AAAAAB', 'GU-AAAAAC', 'GU-AAAAAD'],
      );
    });

    test('her yeni örnek baştan başlar (testler arası durum taşınmaz)', () {
      final first = FakeTicketCodeGenerator()
        ..ticketCode()
        ..ticketCode();
      final second = FakeTicketCodeGenerator();

      expect(first.ticketCode(), 'GU-AAAA-AAAD');
      expect(second.ticketCode(), 'GU-AAAA-AAAB');
    });

    test('bilet ve destek sayaçları bağımsızdır', () {
      final fake = FakeTicketCodeGenerator();

      expect(fake.ticketCode(), 'GU-AAAA-AAAB');
      expect(fake.supportTicketNo(), 'GU-AAAAAB');
      expect(fake.ticketCode(), 'GU-AAAA-AAAC');
      expect(fake.ticketCode(), 'GU-AAAA-AAAD');
      expect(fake.supportTicketNo(), 'GU-AAAAAC');
    });
  });

  group('T-08 · FakeTicketCodeGenerator · gerçek biçimle uyum', () {
    test('1000 bilet kodu ticketCodePattern ile eşleşir ve tekildir', () {
      final fake = FakeTicketCodeGenerator();
      final codes = [for (var i = 0; i < 1000; i++) fake.ticketCode()];

      expect(codes.where((code) => !_ticketCode.hasMatch(code)), isEmpty);
      expect(codes.toSet(), hasLength(1000));
    });

    test('1000 destek numarası supportTicketNoPattern ile eşleşir ve '
        'tekildir', () {
      final fake = FakeTicketCodeGenerator();
      final numbers = [for (var i = 0; i < 1000; i++) fake.supportTicketNo()];

      expect(numbers.where((no) => !_supportTicketNo.hasMatch(no)), isEmpty);
      expect(numbers.toSet(), hasLength(1000));
    });

    test('kodlar artan sıradadır (alfabe sırasına göre)', () {
      int rank(String body) => body
          .split('')
          .fold(
            0,
            (value, char) =>
                value * TicketCodeGenerator.alphabet.length +
                TicketCodeGenerator.alphabet.indexOf(char),
          );
      final fake = FakeTicketCodeGenerator();
      final ranks = [
        for (var i = 0; i < 100; i++) rank(fake.ticketCode().substring(8)),
      ];

      expect(ranks, [for (var n = 1; n <= 100; n++) n]);
    });

    test('32. çağrıda basamak taşar: AAA9 → AABA', () {
      final fake = FakeTicketCodeGenerator();
      final codes = [for (var i = 0; i < 33; i++) fake.ticketCode()];

      expect(codes[30], 'GU-AAAA-AAA9');
      expect(codes[31], 'GU-AAAA-AABA');
      expect(codes[32], 'GU-AAAA-AABB');
    });

    test('üretilen kod QR yükünde gidiş-dönüş yapar', () {
      final code = FakeTicketCodeGenerator().ticketCode();

      expect(
        FirestoreIds.parseTicketQr(FirestoreIds.ticketQrPayload('e03', code)),
        (eventId: 'e03', code: code),
      );
    });

    test('onluk sayaç yazımı (GU-AAAA-0001) desene uymaz; sahte kod bu yüzden '
        'alfabe tabanında sayar', () {
      expect(_ticketCode.hasMatch('GU-AAAA-0001'), isFalse);
      expect(
        _ticketCode.hasMatch(FakeTicketCodeGenerator.ticketCodeAt(1)),
        isTrue,
      );
    });

    test('PLAN §16.3 fake satırındaki örnek kodlar ilk iki çağrının '
        'çıktısıdır', () {
      final row = readRepoFile('docs/PLAN.md')
          .split('\n')
          .singleWhere(
            (line) => line.startsWith('| `FakeTicketCodeGenerator` |'),
          );
      final fake = FakeTicketCodeGenerator();
      final first = fake.ticketCode();
      final second = fake.ticketCode();

      expect(first, 'GU-AAAA-AAAB');
      expect(second, 'GU-AAAA-AAAC');
      expect(row, contains('`$first`, `$second`, artan'));
      expect(row, contains('`${FakeTicketCodeGenerator().supportTicketNo()}`'));
      expect(row, isNot(contains('GU-AAAA-0001')));
      for (final code in codeSpans(row).where((c) => c.startsWith('GU-'))) {
        expect(
          _ticketCode.hasMatch(code) || _supportTicketNo.hasMatch(code),
          isTrue,
          reason: code,
        );
      }
    });
  });

  group('T-08 · FakeTicketCodeGenerator · üretilenlerin kaydı', () {
    test('başlangıçta boş', () {
      final fake = FakeTicketCodeGenerator();

      expect(fake.issuedTicketCodes, isEmpty);
      expect(fake.issuedSupportTicketNos, isEmpty);
    });

    test('üretilen her kod sırasıyla kaydedilir', () {
      final fake = FakeTicketCodeGenerator();
      final first = fake.ticketCode();
      final second = fake.ticketCode();
      final ticketNo = fake.supportTicketNo();

      expect(fake.issuedTicketCodes, [first, second]);
      expect(fake.issuedSupportTicketNos, [ticketNo]);
    });

    test('kayıt listeleri dışarıdan değiştirilemez', () {
      final fake = FakeTicketCodeGenerator()
        ..ticketCode()
        ..supportTicketNo();

      expect(() => fake.issuedTicketCodes.add('x'), throwsUnsupportedError);
      expect(fake.issuedTicketCodes.clear, throwsUnsupportedError);
      expect(
        () => fake.issuedSupportTicketNos.add('x'),
        throwsUnsupportedError,
      );
      expect(fake.ticketCode(), 'GU-AAAA-AAAC');
    });

    test(
      'kayıt anlık görüntüdür (sonraki üretim eski listeyi değiştirmez)',
      () {
        final fake = FakeTicketCodeGenerator()..ticketCode();
        final snapshot = fake.issuedTicketCodes;

        fake.ticketCode();

        expect(snapshot, hasLength(1));
        expect(fake.issuedTicketCodes, hasLength(2));
      },
    );
  });

  group(
    'T-08 · FakeTicketCodeGenerator · ticketCodeAt / supportTicketNoAt',
    () {
      test('n. çağrının sonucunu verir', () {
        final fake = FakeTicketCodeGenerator();

        for (var n = 1; n <= 50; n++) {
          expect(fake.ticketCode(), FakeTicketCodeGenerator.ticketCodeAt(n));
          expect(
            fake.supportTicketNo(),
            FakeTicketCodeGenerator.supportTicketNoAt(n),
          );
        }
      });

      test('bilinen değerler', () {
        expect(FakeTicketCodeGenerator.ticketCodeAt(1), 'GU-AAAA-AAAB');
        expect(FakeTicketCodeGenerator.ticketCodeAt(31), 'GU-AAAA-AAA9');
        expect(FakeTicketCodeGenerator.ticketCodeAt(32), 'GU-AAAA-AABA');
        expect(FakeTicketCodeGenerator.ticketCodeAt(1024), 'GU-AAAA-ABAA');
        expect(FakeTicketCodeGenerator.ticketCodeAt(32768), 'GU-AAAA-BAAA');
        expect(FakeTicketCodeGenerator.ticketCodeAt(1048575), 'GU-AAAA-9999');
        expect(FakeTicketCodeGenerator.supportTicketNoAt(1), 'GU-AAAAAB');
        expect(FakeTicketCodeGenerator.supportTicketNoAt(32), 'GU-AAAABA');
        expect(
          FakeTicketCodeGenerator.supportTicketNoAt(1073741823),
          'GU-999999',
        );
      });

      test('aralık dışı n → RangeError', () {
        for (final n in [0, -1, 1048576]) {
          expect(
            () => FakeTicketCodeGenerator.ticketCodeAt(n),
            throwsRangeError,
            reason: '$n',
          );
        }
        for (final n in [0, -1, 1073741824]) {
          expect(
            () => FakeTicketCodeGenerator.supportTicketNoAt(n),
            throwsRangeError,
            reason: '$n',
          );
        }
      });

      test('uç değerler de desene uyar', () {
        for (final n in [1, 31, 32, 1023, 1024, 1048575]) {
          expect(
            _ticketCode.hasMatch(FakeTicketCodeGenerator.ticketCodeAt(n)),
            isTrue,
            reason: '$n',
          );
        }
        for (final n in [1, 32, 1073741823]) {
          expect(
            _supportTicketNo.hasMatch(
              FakeTicketCodeGenerator.supportTicketNoAt(n),
            ),
            isTrue,
            reason: '$n',
          );
        }
      });
    },
  );
}
