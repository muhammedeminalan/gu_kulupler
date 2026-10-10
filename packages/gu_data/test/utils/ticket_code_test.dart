// T-08 · TicketCodeGenerator / SecureTicketCodeGenerator (D-30): alfabe
// (karışan karakter yok), desen, betikli Random ile birebir eşleme, tohumlu
// Random ile 10 000 üretimde çakışma ve dağılım, üretim kaynağı denetimi.
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

const String _alphabet = TicketCodeGenerator.alphabet;

/// Büyük örneklem boyu (tohumlu üretim).
const int _sampleSize = 10000;

/// Tohumlu testlerin tohumu (D-30'dan; sonuç bu tohumla tekrarlanabilir).
const int _seed = 30;

final RegExp _ticketCode = RegExp(FirestoreIds.ticketCodePattern);
final RegExp _supportTicketNo = RegExp(FirestoreIds.supportTicketNoPattern);

/// Önceden verilen değerleri sırayla döndüren el yazımı [Random].
///
/// `nextInt` dışındaki çağrılar hata fırlatır: üretici yalnızca `nextInt`
/// kullanmalıdır.
final class _ScriptedRandom implements Random {
  _ScriptedRandom(this._values);

  final List<int> _values;

  /// `nextInt` çağrılarına verilen `max` değerleri, sırayla.
  final List<int> maxArguments = [];

  @override
  int nextInt(int max) {
    final value = _values[maxArguments.length % _values.length];
    maxArguments.add(max);
    return value;
  }

  @override
  bool nextBool() => throw UnsupportedError('nextBool beklenmiyor');

  @override
  double nextDouble() => throw UnsupportedError('nextDouble beklenmiyor');
}

/// Tohumlu üretici.
SecureTicketCodeGenerator _seeded([int seed = _seed]) =>
    SecureTicketCodeGenerator.withRandom(Random(seed));

/// Betikli üretici.
SecureTicketCodeGenerator _scripted(_ScriptedRandom random) =>
    SecureTicketCodeGenerator.withRandom(random);

/// Bilet kodunun rastgele 8 karakteri (`GU-XXXX-XXXX` → `XXXXXXXX`).
String _ticketBody(String code) =>
    '${code.substring(3, 7)}${code.substring(8)}';

/// Destek numarasının rastgele 6 karakteri (`GU-XXXXXX` → `XXXXXX`).
String _supportBody(String ticketNo) => ticketNo.substring(3);

/// [bodies] içindeki karakterlerin sembol başına sayısı.
Map<String, int> _symbolCounts(Iterable<String> bodies) {
  final counts = {for (final symbol in _alphabet.split('')) symbol: 0};
  for (final body in bodies) {
    for (final char in body.split('')) {
      counts.update(char, (n) => n + 1);
    }
  }
  return counts;
}

/// Ki-kare istatistiği (eşit olasılık varsayımı; serbestlik = sembol − 1).
double _chiSquare(Map<String, int> counts) {
  final total = counts.values.fold<int>(0, (a, b) => a + b);
  final expected = total / counts.length;
  return counts.values.fold<double>(
    0,
    (sum, observed) => sum + pow(observed - expected, 2) / expected,
  );
}

/// `packages/gu_data/lib` altındaki Dart kaynakları: yol → yorumsuz metin.
Map<String, String> _libSources() {
  final root = Directory('$repoRoot/packages/gu_data/lib');
  return {
    for (final file in root.listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.dart') && !file.path.endsWith('.g.dart'))
        file.path.substring(root.path.length + 1): file
            .readAsLinesSync()
            .where((line) => !line.trimLeft().startsWith('//'))
            .join('\n'),
  };
}

void main() {
  group('T-08 · TicketCodeGenerator · alfabe', () {
    test('değer', () {
      expect(_alphabet, 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789');
    });

    test('32 karakter (5 bit), hepsi tekil', () {
      expect(_alphabet, hasLength(32));
      expect(_alphabet.length, 1 << 5);
      expect(_alphabet.split('').toSet(), hasLength(32));
    });

    test('karışan karakterler yok: I, O, 0, 1', () {
      for (final confusing in ['I', 'O', '0', '1']) {
        expect(_alphabet, isNot(contains(confusing)), reason: confusing);
      }
    });

    test(
      'yalnızca büyük ASCII harf ve rakam (küçük harf, Türkçe harf yok)',
      () {
        expect(_alphabet, matches(RegExp(r'^[A-Z0-9]+$')));
        expect(_alphabet, _alphabet.toUpperCase());
        expect(_alphabet.codeUnits.every((unit) => unit < 0x80), isTrue);
      },
    );

    test('24 harf (A–Z eksi I, O) + 8 rakam (2–9), sıralı', () {
      final letters = [
        for (var unit = 0x41; unit <= 0x5A; unit++)
          if (!'IO'.contains(String.fromCharCode(unit)))
            String.fromCharCode(unit),
      ];
      final digits = [for (var digit = 2; digit <= 9; digit++) '$digit'];

      expect(letters, hasLength(24));
      expect(digits, hasLength(8));
      expect(_alphabet, [...letters, ...digits].join());
    });

    test('PLAN §9.4 ve §10.3 tanımıyla birebir', () {
      expect(
        "`TicketCodeGenerator.alphabet = '$_alphabet'`".allMatches(
          readRepoFile('docs/PLAN.md'),
        ),
        hasLength(2),
      );
    });

    test('prototip alfabesiyle birebir (art.js ticketCode)', () {
      expect(
        readRepoFile('design/prototype/app/art.js'),
        contains("const A = '$_alphabet'"),
      );
    });
  });

  group('T-08 · SecureTicketCodeGenerator · betikli Random ile eşleme', () {
    test('ticketCode dizinleri alfabeye sırayla eşler: GU-ABCD-EFGH', () {
      final random = _ScriptedRandom([0, 1, 2, 3, 4, 5, 6, 7]);

      expect(_scripted(random).ticketCode(), 'GU-ABCD-EFGH');
    });

    test('ticketCode tam 8 kez nextInt(32) çağırır', () {
      final random = _ScriptedRandom([0]);

      _scripted(random).ticketCode();

      expect(random.maxArguments, List.filled(8, _alphabet.length));
    });

    test('supportTicketNo dizinleri alfabeye sırayla eşler: GU-ABCDEF', () {
      final random = _ScriptedRandom([0, 1, 2, 3, 4, 5]);

      expect(_scripted(random).supportTicketNo(), 'GU-ABCDEF');
    });

    test('supportTicketNo tam 6 kez nextInt(32) çağırır', () {
      final random = _ScriptedRandom([0]);

      _scripted(random).supportTicketNo();

      expect(random.maxArguments, List.filled(6, _alphabet.length));
    });

    test('uç dizinler: 0 → A, 31 → 9', () {
      expect(_scripted(_ScriptedRandom([0])).ticketCode(), 'GU-AAAA-AAAA');
      expect(_scripted(_ScriptedRandom([31])).ticketCode(), 'GU-9999-9999');
      expect(_scripted(_ScriptedRandom([0])).supportTicketNo(), 'GU-AAAAAA');
      expect(_scripted(_ScriptedRandom([31])).supportTicketNo(), 'GU-999999');
    });

    test('her dizin her konumda kendi alfabe karakterini üretir '
        '(8 × 32 bilet, 6 × 32 destek)', () {
      for (var position = 0; position < 8; position++) {
        for (var index = 0; index < _alphabet.length; index++) {
          final script = List.filled(8, 0)..[position] = index;
          final body = _ticketBody(
            _scripted(_ScriptedRandom(script)).ticketCode(),
          );

          expect(
            body,
            'A' * position + _alphabet[index] + 'A' * (7 - position),
            reason: 'bilet konum $position, dizin $index',
          );
        }
      }
      for (var position = 0; position < 6; position++) {
        for (var index = 0; index < _alphabet.length; index++) {
          final script = List.filled(6, 0)..[position] = index;
          final body = _supportBody(
            _scripted(_ScriptedRandom(script)).supportTicketNo(),
          );

          expect(
            body,
            'A' * position + _alphabet[index] + 'A' * (5 - position),
            reason: 'destek konum $position, dizin $index',
          );
        }
      }
    });

    test('ardışık çağrılar kaynağı sırayla tüketir (durum taşınmaz)', () {
      final random = _ScriptedRandom([for (var i = 0; i < 32; i++) i]);
      final generator = _scripted(random);

      expect(generator.ticketCode(), 'GU-ABCD-EFGH');
      expect(generator.supportTicketNo(), 'GU-JKLMNP');
      expect(generator.ticketCode(), 'GU-QRST-UVWX');
      expect(random.maxArguments, hasLength(8 + 6 + 8));
      expect(random.maxArguments.toSet(), {_alphabet.length});
    });

    test('yalnızca nextInt kullanır (nextBool / nextDouble çağrılmaz)', () {
      final generator = _scripted(_ScriptedRandom([7, 13, 29]));

      expect(generator.ticketCode, returnsNormally);
      expect(generator.supportTicketNo, returnsNormally);
    });
  });

  group('T-08 · SecureTicketCodeGenerator · biçim', () {
    test('TicketCodeGenerator arayüzünü uygular', () {
      expect(SecureTicketCodeGenerator(), isA<TicketCodeGenerator>());
      expect(_seeded(), isA<TicketCodeGenerator>());
    });

    test('ticketCode GU-XXXX-XXXX: 12 karakter, iki tire, GU- öneki', () {
      final code = _seeded().ticketCode();

      expect(code, hasLength(12));
      expect(code, startsWith('GU-'));
      expect(code[7], '-');
      expect(code.split('-'), hasLength(3));
      expect(code.split('-').skip(1).map((group) => group.length), [4, 4]);
      expect(_ticketCode.hasMatch(code), isTrue);
    });

    test('supportTicketNo GU-XXXXXX: 9 karakter, tek tire, GU- öneki', () {
      final ticketNo = _seeded().supportTicketNo();

      expect(ticketNo, hasLength(9));
      expect(ticketNo, startsWith('GU-'));
      expect(ticketNo.split('-'), hasLength(2));
      expect(ticketNo.split('-').last, hasLength(6));
      expect(_supportTicketNo.hasMatch(ticketNo), isTrue);
    });

    test('iki biçim birbirinin deseniyle eşleşmez', () {
      final generator = _seeded();

      expect(_supportTicketNo.hasMatch(generator.ticketCode()), isFalse);
      expect(_ticketCode.hasMatch(generator.supportTicketNo()), isFalse);
    });

    test('üretilen bilet kodu QR yükünde gidiş-dönüş yapar', () {
      final generator = _seeded();
      for (var i = 0; i < 100; i++) {
        final code = generator.ticketCode();

        expect(
          FirestoreIds.parseTicketQr(FirestoreIds.ticketQrPayload('e03', code)),
          (eventId: 'e03', code: code),
        );
      }
    });
  });

  group('T-08 · SecureTicketCodeGenerator · $_sampleSize üretim (tohum '
      '$_seed)', () {
    late final List<String> ticketCodes;
    late final List<String> supportTicketNos;

    setUpAll(() {
      final tickets = _seeded();
      final support = _seeded(_seed + 1);
      ticketCodes = [
        for (var i = 0; i < _sampleSize; i++) tickets.ticketCode(),
      ];
      supportTicketNos = [
        for (var i = 0; i < _sampleSize; i++) support.supportTicketNo(),
      ];
    });

    test('her bilet kodu ticketCodePattern ile eşleşir', () {
      expect(ticketCodes, hasLength(_sampleSize));
      expect(ticketCodes.where((code) => !_ticketCode.hasMatch(code)), isEmpty);
    });

    test('her destek numarası supportTicketNoPattern ile eşleşir', () {
      expect(supportTicketNos, hasLength(_sampleSize));
      expect(
        supportTicketNos.where((no) => !_supportTicketNo.hasMatch(no)),
        isEmpty,
      );
    });

    test('hiçbir kodda karışan karakter (I, O, 0, 1) ya da küçük harf yok', () {
      final bodies = [
        ...ticketCodes.map(_ticketBody),
        ...supportTicketNos.map(_supportBody),
      ].join();

      expect(bodies, hasLength(_sampleSize * (8 + 6)));
      expect(bodies, isNot(matches(RegExp('[IO01a-z]'))));
      expect(
        bodies.split('').toSet().difference(_alphabet.split('').toSet()),
        isEmpty,
      );
    });

    test('bilet kodlarında çakışma yok (40 bit uzay)', () {
      expect(ticketCodes.toSet(), hasLength(_sampleSize));
    });

    test('destek numaralarında çakışma beklenen sınırda (30 bit uzay)', () {
      // Doğum günü tahmini: n² / (2 · 32⁶) ≈ 0,05 beklenen çakışma.
      expect(supportTicketNos.toSet().length, greaterThanOrEqualTo(9990));
    });

    test('alfabenin 32 karakterinin tamamı kullanılır', () {
      expect(
        _symbolCounts(ticketCodes.map(_ticketBody)).values,
        everyElement(greaterThan(0)),
      );
      expect(
        _symbolCounts(supportTicketNos.map(_supportBody)).values,
        everyElement(greaterThan(0)),
      );
    });

    test('bilet kodu sembol dağılımı kabaca düzgün (beklenen 2500 ± %10)', () {
      // 80 000 karakter, p = 1/32 → ortalama 2500, σ ≈ 49; ±250 ≈ 5σ.
      final counts = _symbolCounts(ticketCodes.map(_ticketBody));

      expect(counts.values.fold<int>(0, (a, b) => a + b), _sampleSize * 8);
      for (final MapEntry(key: symbol, value: count) in counts.entries) {
        expect(count, inInclusiveRange(2250, 2750), reason: symbol);
      }
    });

    test('destek numarası sembol dağılımı kabaca düzgün (beklenen 1875 ± '
        '%11)', () {
      // 60 000 karakter, p = 1/32 → ortalama 1875, σ ≈ 43; ±213 ≈ 5σ.
      final counts = _symbolCounts(supportTicketNos.map(_supportBody));

      for (final MapEntry(key: symbol, value: count) in counts.entries) {
        expect(count, inInclusiveRange(1662, 2088), reason: symbol);
      }
    });

    test('ki-kare istatistiği düzgün dağılımla uyumlu (serbestlik 31)', () {
      // Ortalama 31, standart sapma ≈ 7,9; eşik 70 ≈ ortalama + 5σ.
      expect(
        _chiSquare(_symbolCounts(ticketCodes.map(_ticketBody))),
        lessThan(70),
      );
      expect(
        _chiSquare(_symbolCounts(supportTicketNos.map(_supportBody))),
        lessThan(70),
      );
    });

    test('8 konumun her birinde dağılım kabaca düzgün (beklenen 312,5; '
        '225–400)', () {
      // Konum başına 10 000 karakter → ortalama 312,5, σ ≈ 17; ±87 ≈ 5σ.
      for (var position = 0; position < 8; position++) {
        final counts = _symbolCounts(
          ticketCodes.map((code) => _ticketBody(code)[position]),
        );

        for (final MapEntry(key: symbol, value: count) in counts.entries) {
          expect(
            count,
            inInclusiveRange(225, 400),
            reason: 'konum $position, sembol $symbol',
          );
        }
      }
    });

    test('iki grup birbirinden bağımsız (aynı gruplu kod neredeyse yok)', () {
      // Olasılık 1 / 32⁴; 10 000 kodda beklenen ≈ 0,01.
      final sameGroups = ticketCodes.where(
        (code) => code.substring(3, 7) == code.substring(8),
      );

      expect(sameGroups.length, lessThanOrEqualTo(2));
    });

    test('ardışık kodlar birbirini tekrar etmez ve sabit ek taşımaz', () {
      for (var i = 1; i < ticketCodes.length; i++) {
        expect(ticketCodes[i], isNot(ticketCodes[i - 1]));
      }
      // İlk gruplar tek bir değere çökmüş değil.
      expect(
        {for (final code in ticketCodes) code.substring(3, 7)}.length,
        greaterThan(9900),
      );
    });
  });

  group('T-08 · SecureTicketCodeGenerator · tohum ve kaynak', () {
    test(
      'aynı tohum aynı diziyi üretir (enjekte edilen kaynak kullanılır)',
      () {
        final first = _seeded(7);
        final second = _seeded(7);

        expect(
          [for (var i = 0; i < 50; i++) first.ticketCode()],
          [for (var i = 0; i < 50; i++) second.ticketCode()],
        );
        expect(
          [for (var i = 0; i < 50; i++) first.supportTicketNo()],
          [for (var i = 0; i < 50; i++) second.supportTicketNo()],
        );
      },
    );

    test('farklı tohum farklı dizi üretir', () {
      final first = _seeded(7);
      final second = _seeded(8);

      expect(
        [for (var i = 0; i < 10; i++) first.ticketCode()],
        isNot([for (var i = 0; i < 10; i++) second.ticketCode()]),
      );
    });

    test('varsayılan kurucu (Random.secure) desenlere uyan kod üretir', () {
      final generator = SecureTicketCodeGenerator();
      for (var i = 0; i < 1000; i++) {
        expect(_ticketCode.hasMatch(generator.ticketCode()), isTrue);
        expect(_supportTicketNo.hasMatch(generator.supportTicketNo()), isTrue);
      }
    });

    test('varsayılan kurucuyla iki örnek aynı diziyi üretmez (tohumsuz)', () {
      final first = SecureTicketCodeGenerator();
      final second = SecureTicketCodeGenerator();

      // Dört kodun tamamının eşit çıkma olasılığı 2⁻¹⁶⁰.
      expect(
        [for (var i = 0; i < 4; i++) first.ticketCode()],
        isNot([for (var i = 0; i < 4; i++) second.ticketCode()]),
      );
    });

    test('gu_data/lib içinde tohumlu kurucu (withRandom) çağrılmaz', () {
      final sources = _libSources();

      expect(sources, contains('src/utils/ticket_code.dart'));
      for (final MapEntry(key: path, value: code) in sources.entries) {
        final calls = RegExp(r'\bwithRandom\(').allMatches(code).length;

        // Tek geçiş: kurucunun kendi bildirimi.
        expect(
          calls,
          path == 'src/utils/ticket_code.dart' ? 1 : 0,
          reason: path,
        );
      }
    });

    test('gu_data/lib içinde Random yalnızca ticket_code.dart içinde ve '
        'yalnızca Random.secure() ile kurulur', () {
      final sources = _libSources();
      final seededCalls = RegExp(r'(?<![\w.])Random\(');
      final secureCalls = RegExp(r'\bRandom\.secure\(');

      for (final MapEntry(key: path, value: code) in sources.entries) {
        expect(seededCalls.hasMatch(code), isFalse, reason: path);
        expect(
          secureCalls.allMatches(code).length,
          path == 'src/utils/ticket_code.dart' ? 1 : 0,
          reason: path,
        );
      }
    });
  });
}
