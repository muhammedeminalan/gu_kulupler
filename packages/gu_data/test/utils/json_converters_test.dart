// T-08 · TimestampConverter / RequiredTimestampConverter: Firestore Timestamp
// ↔ UTC DateTime — kabul edilen tipler, gidiş-dönüş, hassasiyet, hatalar
// (PLAN §9.3, §9.11; D-26).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:json_annotation/json_annotation.dart';

import '../helpers/repo_sources.dart';

const _nullable = TimestampConverter();
const _required = RequiredTimestampConverter();

/// Gidiş-dönüş tablosu: epoch, epoch öncesi, mikrosaniyeli, uzak gelecek.
final List<DateTime> _instants = [
  DateTime.utc(1970),
  DateTime.utc(1969, 12, 31, 23, 59, 59, 999, 999),
  DateTime.utc(1900, 1, 1, 0, 0, 0, 0, 1),
  DateTime.utc(2024, 2, 29, 23, 59, 59, 999),
  DateTime.utc(2026, 10, 8, 20, 15, 1),
  DateTime.utc(2026, 10, 8, 20, 15, 1, 117),
  DateTime.utc(2026, 10, 8, 20, 15, 1, 117, 345),
  DateTime.utc(2026, 10, 10, 20, 59, 59, 999, 999),
  DateTime.utc(2026, 10, 10, 21),
  DateTime.utc(2099, 12, 31, 23, 59, 59),
];

/// `tool/seed/demo-data.json` içindeki tüm ISO-8601 dizgileri.
List<String> _demoDataTimestamps() {
  final found = <String>[];
  void walk(Object? node) {
    if (node is Map<String, Object?>) {
      node.values.forEach(walk);
    } else if (node is List<Object?>) {
      node.forEach(walk);
    } else if (node is String &&
        RegExp(r'^\d{4}-\d{2}-\d{2}T').hasMatch(node)) {
      found.add(node);
    }
  }

  walk(readRepoJson('tool/seed/demo-data.json'));
  return found;
}

void main() {
  group('T-08 · TimestampConverter.fromJson', () {
    test('null → null', () {
      expect(_nullable.fromJson(null), isNull);
    });

    test('Timestamp → aynı an, UTC', () {
      final result = _nullable.fromJson(
        Timestamp.fromDate(DateTime.utc(2026, 10, 8, 20, 15, 1, 117)),
      );

      expect(result, DateTime.utc(2026, 10, 8, 20, 15, 1, 117));
      expect(result!.isUtc, isTrue);
    });

    test('Timestamp(saniye, nanosaniye) → mikrosaniye altı atılır', () {
      final result = _nullable.fromJson(Timestamp(1, 123456789));

      expect(result!.isUtc, isTrue);
      expect(result.microsecondsSinceEpoch, 1123456);
    });

    test('epoch öncesi Timestamp doğru ana çevrilir', () {
      final result = _nullable.fromJson(Timestamp(-1, 500000000));

      expect(result, DateTime.utc(1969, 12, 31, 23, 59, 59, 500));
    });

    test('UTC DateTime → aynı değer', () {
      final input = DateTime.utc(2026, 10, 8, 20, 15, 1);

      final result = _nullable.fromJson(input);

      expect(result, input);
      expect(result!.isUtc, isTrue);
    });

    test('yerel DateTime → aynı anın UTC karşılığı', () {
      final utc = DateTime.utc(2026, 10, 8, 20, 15, 1);
      final local = utc.toLocal();

      final result = _nullable.fromJson(local);

      expect(local.isUtc, isFalse);
      expect(result!.isUtc, isTrue);
      expect(result, utc);
      expect(result.millisecondsSinceEpoch, local.millisecondsSinceEpoch);
    });

    test('ISO-8601 "Z" dizgisi (demo veri biçimi) → UTC an', () {
      final result = _nullable.fromJson('2025-02-13T16:08:42.117Z');

      expect(result, DateTime.utc(2025, 2, 13, 16, 8, 42, 117));
      expect(result!.isUtc, isTrue);
    });

    test('ISO-8601 +03:00 kaymalı dizgi → karşılık gelen UTC an', () {
      final result = _nullable.fromJson('2026-10-08T23:15:01+03:00');

      expect(result, DateTime.utc(2026, 10, 8, 20, 15, 1));
      expect(result!.isUtc, isTrue);
    });

    test("ISO-8601 −05:00 kaymalı dizgi gün değiştirerek UTC'ye çevrilir", () {
      final result = _nullable.fromJson('2026-10-08T22:00:00-05:00');

      expect(result, DateTime.utc(2026, 10, 9, 3));
    });

    test('mikrosaniyeli ISO dizgisi hassasiyetini korur', () {
      final result = _nullable.fromJson('2026-10-08T20:15:01.117345Z');

      expect(result, DateTime.utc(2026, 10, 8, 20, 15, 1, 117, 345));
    });

    test('desteklenmeyen tip → FormatException (tip adıyla)', () {
      for (final (value, type) in <(Object, String)>[
        (1760000000000, 'int'),
        (1.5, 'double'),
        (true, 'bool'),
      ]) {
        expect(
          () => _nullable.fromJson(value),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'TimestampConverter: $type',
            ),
          ),
          reason: type,
        );
      }
    });

    test('Map ve List de reddedilir', () {
      expect(
        () => _nullable.fromJson(const {'seconds': 1, 'nanoseconds': 0}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            startsWith('TimestampConverter: '),
          ),
        ),
      );
      expect(() => _nullable.fromJson(const [1, 0]), throwsFormatException);
    });

    test('ISO olmayan dizgi → FormatException', () {
      for (final value in ['', 'yarın', '08.10.2026', '2026/10/08', 'T20:15']) {
        expect(
          () => _nullable.fromJson(value),
          throwsFormatException,
          reason: '"$value"',
        );
      }
    });
  });

  group('T-08 · TimestampConverter.fromJson · saat dilimsiz dizgi = UTC', () {
    test('tarih + saat', () {
      final result = _nullable.fromJson('2026-10-08T20:15:01');

      expect(result, DateTime.utc(2026, 10, 8, 20, 15, 1));
      expect(result!.isUtc, isTrue);
    });

    test('boşlukla ayrılmış tarih + saat, mikrosaniyeli', () {
      final result = _nullable.fromJson('2026-10-08 20:15:01.123456');

      expect(result, DateTime.utc(2026, 10, 8, 20, 15, 1, 123, 456));
      expect(result!.isUtc, isTrue);
    });

    test('yalnızca tarih → o günün UTC gece yarısı', () {
      final result = _nullable.fromJson('2026-10-08');

      expect(result, DateTime.utc(2026, 10, 8));
      expect(result!.isUtc, isTrue);
    });

    test('yaz saati boşluğuna düşen duvar saatleri kaydırılmaz '
        '(cihaz saat diliminden bağımsız)', () {
      // 02:30 şu bölgelerde o gün "yok": Avrupa (29 Mart), ABD (8 Mart),
      // eski Türkiye kuralı (27 Mart 2016, 03:30).
      expect(
        _nullable.fromJson('2026-03-29T02:30:00'),
        DateTime.utc(2026, 3, 29, 2, 30),
      );
      expect(
        _nullable.fromJson('2026-03-08T02:30:00'),
        DateTime.utc(2026, 3, 8, 2, 30),
      );
      expect(
        _nullable.fromJson('2016-03-27T03:30:00'),
        DateTime.utc(2016, 3, 27, 3, 30),
      );
    });

    test('"Z" ekli ve eksiz aynı dizgi aynı ana çevrilir', () {
      expect(
        _nullable.fromJson('2026-10-08T20:15:01'),
        _nullable.fromJson('2026-10-08T20:15:01Z'),
      );
    });
  });

  group('T-08 · TimestampConverter.toJson', () {
    test('null → null', () {
      expect(_nullable.toJson(null), isNull);
    });

    test("UTC DateTime → aynı anın Timestamp'i", () {
      final json = _nullable.toJson(DateTime.utc(2026, 10, 8, 20, 15, 1, 117));

      expect(json, isA<Timestamp>());
      expect(
        json,
        Timestamp.fromMillisecondsSinceEpoch(
          DateTime.utc(2026, 10, 8, 20, 15, 1, 117).millisecondsSinceEpoch,
        ),
      );
    });

    test('yerel DateTime → UTC karşılığıyla aynı Timestamp', () {
      final utc = DateTime.utc(2026, 10, 8, 20, 15, 1);

      expect(_nullable.toJson(utc.toLocal()), _nullable.toJson(utc));
    });

    test('mikrosaniye Timestamp nanosaniyesine taşınır', () {
      final json =
          _nullable.toJson(DateTime.utc(2026, 10, 8, 20, 15, 1, 117, 345))!
              as Timestamp;

      expect(json.nanoseconds, 117345000);
    });

    test('çıktıda DateTime ya da dizgi yoktur (Firestore tipi yazılır)', () {
      final json = _nullable.toJson(DateTime.utc(2026));

      expect(json, isNot(isA<DateTime>()));
      expect(json, isNot(isA<String>()));
    });
  });

  group('T-08 · TimestampConverter · gidiş-dönüş', () {
    for (final instant in _instants) {
      test('${instant.toIso8601String()} DateTime → Timestamp → DateTime', () {
        final back = _nullable.fromJson(_nullable.toJson(instant));

        expect(back!.isUtc, isTrue);
        expect(back.millisecondsSinceEpoch, instant.millisecondsSinceEpoch);
        expect(back, instant);
      });
    }

    test('yerel an gidiş-dönüş sonrası UTC ve aynı an', () {
      for (final instant in _instants) {
        final back = _nullable.fromJson(_nullable.toJson(instant.toLocal()));

        expect(back!.isUtc, isTrue);
        expect(back, instant);
      }
    });

    test('Timestamp → DateTime → Timestamp (mikrosaniye hassasiyetinde)', () {
      for (final timestamp in [
        Timestamp(0, 0),
        Timestamp(1, 123456000),
        Timestamp(-1, 999999000),
        Timestamp(1760000000, 117000000),
      ]) {
        expect(_nullable.toJson(_nullable.fromJson(timestamp)), timestamp);
      }
    });

    test('null gidiş-dönüşte null kalır', () {
      expect(_nullable.fromJson(_nullable.toJson(null)), isNull);
    });

    test('demo verideki her zaman dizgisi UTC ana çevrilir ve aynı dizgiye '
        'geri yazılır', () {
      final timestamps = _demoDataTimestamps();

      expect(timestamps, isNotEmpty);
      for (final text in timestamps) {
        final parsed = _nullable.fromJson(text);
        expect(parsed!.isUtc, isTrue, reason: text);
        expect(parsed.toIso8601String(), text);
        expect(_nullable.fromJson(_nullable.toJson(parsed)), parsed);
      }
    });
  });

  group('T-08 · RequiredTimestampConverter.fromJson', () {
    test('Timestamp → aynı an, UTC', () {
      final result = _required.fromJson(
        Timestamp.fromDate(DateTime.utc(2026, 11, 1, 15)),
      );

      expect(result, DateTime.utc(2026, 11, 1, 15));
      expect(result.isUtc, isTrue);
    });

    test('yerel DateTime → aynı anın UTC karşılığı', () {
      final utc = DateTime.utc(2026, 11, 1, 15);

      final result = _required.fromJson(utc.toLocal());

      expect(result, utc);
      expect(result.isUtc, isTrue);
    });

    test('ISO-8601 dizgisi → UTC an', () {
      expect(
        _required.fromJson('2026-11-01T18:00:00+03:00'),
        DateTime.utc(2026, 11, 1, 15),
      );
      expect(
        _required.fromJson('2026-11-01T15:00:00'),
        DateTime.utc(2026, 11, 1, 15),
      );
    });

    test('TimestampConverter ile aynı kurallar (her girdi aynı sonuç)', () {
      final inputs = <Object>[
        Timestamp(1760000000, 117000000),
        DateTime.utc(2026, 10, 8, 20, 15, 1),
        DateTime.utc(2026, 10, 8, 20, 15, 1).toLocal(),
        '2025-02-13T16:08:42.117Z',
        '2026-10-08T23:15:01+03:00',
        '2026-10-08T20:15:01',
        '2026-10-08',
      ];

      for (final input in inputs) {
        expect(
          _required.fromJson(input),
          _nullable.fromJson(input),
          reason: '$input',
        );
      }
    });

    test('desteklenmeyen tip → FormatException (kendi adıyla)', () {
      expect(
        () => _required.fromJson(42),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'RequiredTimestampConverter: int',
          ),
        ),
      );
    });

    test('ISO olmayan dizgi → FormatException', () {
      expect(() => _required.fromJson('yarın'), throwsFormatException);
    });
  });

  group('T-08 · RequiredTimestampConverter.toJson ve gidiş-dönüş', () {
    test('DateTime → Timestamp', () {
      final json = _required.toJson(DateTime.utc(2026, 11, 1, 15));

      expect(json, Timestamp.fromDate(DateTime.utc(2026, 11, 1, 15)));
    });

    test('yerel DateTime → UTC karşılığıyla aynı Timestamp', () {
      final utc = DateTime.utc(2026, 11, 1, 15);

      expect(_required.toJson(utc.toLocal()), _required.toJson(utc));
    });

    test('TimestampConverter ile aynı çıktı', () {
      for (final instant in _instants) {
        expect(_required.toJson(instant), _nullable.toJson(instant));
      }
    });

    for (final instant in _instants) {
      test('${instant.toIso8601String()} gidiş-dönüş: UTC ve aynı an', () {
        final back = _required.fromJson(_required.toJson(instant));

        expect(back.isUtc, isTrue);
        expect(back.millisecondsSinceEpoch, instant.millisecondsSinceEpoch);
        expect(back, instant);
      });
    }
  });

  group(
    'T-08 · RequiredTimestampConverter · null (üretilen fromJson yolu)',
    () {
      // json_serializable `checked: true` ile her alanı `$checkedConvert`
      // içinde okur; zorunlu alan `v as Object` ile dönüştürücüye verilir.
      DateTime readStartsAt(Map<String, Object?> json) => $checkedConvert(
        json,
        'startsAt',
        (v) => _required.fromJson(v as Object),
      );

      test('alan null ise CheckedFromJsonException (alan adıyla)', () {
        expect(
          () => readStartsAt({'startsAt': null}),
          throwsA(
            isA<CheckedFromJsonException>().having(
              (e) => e.key,
              'key',
              'startsAt',
            ),
          ),
        );
      });

      test('alan eksikse CheckedFromJsonException (alan adıyla)', () {
        expect(
          () => readStartsAt({'title': 'Atölye'}),
          throwsA(
            isA<CheckedFromJsonException>().having(
              (e) => e.key,
              'key',
              'startsAt',
            ),
          ),
        );
      });

      test('alan geçersiz tipteyse CheckedFromJsonException; iç hata '
          'FormatException', () {
        expect(
          () => readStartsAt({'startsAt': 12}),
          throwsA(
            isA<CheckedFromJsonException>()
                .having((e) => e.key, 'key', 'startsAt')
                .having(
                  (e) => e.innerError,
                  'innerError',
                  isA<FormatException>(),
                ),
          ),
        );
      });

      test('alan geçerliyse değer UTC okunur', () {
        expect(
          readStartsAt({'startsAt': Timestamp(1760000000, 0)}),
          DateTime.fromMillisecondsSinceEpoch(1760000000000, isUtc: true),
        );
      });
    },
  );

  group('T-08 · dönüştürücüler · sözleşme', () {
    test('TimestampConverter: JsonConverter<DateTime?, Object?>, const', () {
      const a = TimestampConverter();

      expect(a, isA<JsonConverter<DateTime?, Object?>>());
      expect(identical(a, _nullable), isTrue);
    });

    test('RequiredTimestampConverter: JsonConverter<DateTime, Object>, '
        'const', () {
      const a = RequiredTimestampConverter();

      expect(a, isA<JsonConverter<DateTime, Object>>());
      expect(identical(a, _required), isTrue);
    });
  });
}
