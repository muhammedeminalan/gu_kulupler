// T-09 · Enum'lar (PLAN §9.7): Dart adı → JSON değeri eşlemesi PLAN
// tablosundan OKUNARAK, fromJson gidiş-dönüşü ve bilinmeyen değer davranışı,
// kaynak sözleşmesi (dosya yerleşimi + @JsonEnum), kategori eşlemeleri ve
// sıra pariteleri ↔ design/extracted/registry.json.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

const String _enumsDir = 'packages/gu_data/lib/src/models/enums';

/// Kalıcı (Firestore'a yazılan) bir enum'un test görünümü.
///
/// `json` / `fromJson` erişimi sınıfın içinde kalır: işlev alanları `T`'yi
/// kontravaryant konumda taşır, `_Persisted<Enum>` üzerinden okunamaz.
final class _Persisted<T extends Enum> {
  const _Persisted(this.values, this._json, this._fromJson, {this.fallback});

  final List<T> values;
  final String Function(T value) _json;
  final T Function(String json) _fromJson;

  /// Bilinmeyen değerde dönen üye; `null` ⇒ `fromJson` [ArgumentError] fırlatır.
  final T? fallback;

  /// PLAN §9.7 hücresi biçiminde çiftler: `name→'json'`, bildirim sırasıyla.
  List<String> get pairs => [
    for (final value in values) "${value.name}→'${_json(value)}'",
  ];

  List<String> get jsons => values.map(_json).toList();

  List<T> get roundTrip => [for (final value in values) parse(_json(value))];

  T parse(String json) => _fromJson(json);
}

/// §9.7'nin 22 kalıcı enum'u, tablo sırasıyla.
final Map<String, _Persisted<Enum>> _persisted = {
  'UserStatus': _Persisted<UserStatus>(
    UserStatus.values,
    (value) => value.json,
    UserStatus.fromJson,
  ),
  'ClubStatus': _Persisted<ClubStatus>(
    ClubStatus.values,
    (value) => value.json,
    ClubStatus.fromJson,
  ),
  'MembershipStatus': _Persisted<MembershipStatus>(
    MembershipStatus.values,
    (value) => value.json,
    MembershipStatus.fromJson,
  ),
  'ClubRole': _Persisted<ClubRole>(
    ClubRole.values,
    (value) => value.json,
    ClubRole.fromJson,
  ),
  'PostType': _Persisted<PostType>(
    PostType.values,
    (value) => value.json,
    PostType.fromJson,
  ),
  'EventType': _Persisted<EventType>(
    EventType.values,
    (value) => value.json,
    EventType.fromJson,
  ),
  'EventVisibility': _Persisted<EventVisibility>(
    EventVisibility.values,
    (value) => value.json,
    EventVisibility.fromJson,
  ),
  'EventStatus': _Persisted<EventStatus>(
    EventStatus.values,
    (value) => value.json,
    EventStatus.fromJson,
  ),
  'RsvpStatus': _Persisted<RsvpStatus>(
    RsvpStatus.values,
    (value) => value.json,
    RsvpStatus.fromJson,
  ),
  'ReminderOption': _Persisted<ReminderOption>(
    ReminderOption.values,
    (value) => value.json,
    ReminderOption.fromJson,
  ),
  'NotificationType': _Persisted<NotificationType>(
    NotificationType.values,
    (value) => value.json,
    NotificationType.fromJson,
    fallback: NotificationType.unknown,
  ),
  'ReportTargetType': _Persisted<ReportTargetType>(
    ReportTargetType.values,
    (value) => value.json,
    ReportTargetType.fromJson,
  ),
  'ReportReason': _Persisted<ReportReason>(
    ReportReason.values,
    (value) => value.json,
    ReportReason.fromJson,
  ),
  'ReportStatus': _Persisted<ReportStatus>(
    ReportStatus.values,
    (value) => value.json,
    ReportStatus.fromJson,
  ),
  'ReportAction': _Persisted<ReportAction>(
    ReportAction.values,
    (value) => value.json,
    ReportAction.fromJson,
  ),
  'ActivityKind': _Persisted<ActivityKind>(
    ActivityKind.values,
    (value) => value.json,
    ActivityKind.fromJson,
    fallback: ActivityKind.unknown,
  ),
  'SupportSubject': _Persisted<SupportSubject>(
    SupportSubject.values,
    (value) => value.json,
    SupportSubject.fromJson,
  ),
  'TicketStatus': _Persisted<TicketStatus>(
    TicketStatus.values,
    (value) => value.json,
    TicketStatus.fromJson,
  ),
  'RejectReason': _Persisted<RejectReason>(
    RejectReason.values,
    (value) => value.json,
    RejectReason.fromJson,
  ),
  'ClubPalette': _Persisted<ClubPalette>(
    ClubPalette.values,
    (value) => value.json,
    ClubPalette.fromJson,
  ),
  'ClubPattern': _Persisted<ClubPattern>(
    ClubPattern.values,
    (value) => value.json,
    ClubPattern.fromJson,
  ),
  'YearLevel': _Persisted<YearLevel>(
    YearLevel.values,
    (value) => value.json,
    YearLevel.fromJson,
  ),
};

/// §9.7'nin 3 türetilmiş enum'u (Firestore'a yazılmaz; JSON eşlemesi yok).
const Map<String, List<Enum>> _derived = {
  'NotificationCategory': NotificationCategory.values,
  'ActivityCategory': ActivityCategory.values,
  'TicketState': TicketState.values,
};

/// PLAN §9.7 tablosu: enum adı → "Değerler" hücresindeki kod parçaları.
final Map<String, List<String>> _plan = () {
  final table = markdownTable(
    readRepoFile('docs/PLAN.md'),
    heading: '### 9.7 ',
  );
  if (table.header[1] != 'Değerler (Dart → JSON)') {
    throw StateError('PLAN §9.7 tablo başlığı değişmiş: ${table.header}');
  }
  return {
    for (final row in table.rows)
      codeSpans(row.first).single: codeSpans(row[1]),
  };
}();

final Map<String, Object?> _registry = readRepoJson(
  'design/extracted/registry.json',
);

/// Registry kökündeki [key] haritası (tür kodu → kategori kodu).
Map<String, String> _registryMap(String key) =>
    (_registry[key]! as Map<String, Object?>).cast<String, String>();

/// `UserStatus` → `user_status` (dosya adı).
String _snake(String name) => name
    .replaceAllMapped(RegExp('(?<!^)[A-Z]'), (match) => '_${match[0]}')
    .toLowerCase();

void main() {
  group("T-09 · enum'lar · PLAN §9.7 tablosu", () {
    test('tablodaki enum kümesi = 22 kalıcı + 3 türetilmiş enum', () {
      expect(_persisted, hasLength(22));
      expect(_derived, hasLength(3));
      expect(_plan.keys, [..._persisted.keys, ..._derived.keys]);
    });

    for (final MapEntry(key: name, value: spec) in _persisted.entries) {
      test('$name: Dart adı → JSON değeri tabloyla birebir (sıra dahil)', () {
        expect(spec.pairs, _plan[name]);
      });
    }

    for (final MapEntry(key: name, value: values) in _derived.entries) {
      test('$name (türetilmiş): üye adları tabloyla birebir', () {
        expect([for (final value in values) value.name], _plan[name]);
      });
    }
  });

  group("T-09 · enum'lar · fromJson", () {
    for (final MapEntry(key: name, value: spec) in _persisted.entries) {
      test('$name: values → json → fromJson gidiş-dönüşü', () {
        expect(spec.roundTrip, spec.values);
      });
    }

    /// Hiçbir enum'da karşılığı olmayan dizgiler (birebir eşleşme: büyük/küçük
    /// harf ve boşluk duyarlı).
    List<String> strangers(_Persisted<Enum> spec) => [
      '',
      '__yok__',
      spec.jsons.first.toUpperCase(),
      ' ${spec.jsons.first}',
    ];

    test('unknown üyesi olmayan enum bilinmeyen değerde ArgumentError '
        'fırlatır (değer, parametre adı ve enum adıyla)', () {
      final strict = {
        for (final MapEntry(:key, :value) in _persisted.entries)
          if (value.fallback == null) key: value,
      };

      expect(strict, hasLength(20));
      for (final MapEntry(key: name, value: spec) in strict.entries) {
        for (final stranger in [...strangers(spec), 'unknown']) {
          expect(
            () => spec.parse(stranger),
            throwsA(
              isA<ArgumentError>()
                  .having((e) => e.invalidValue, 'invalidValue', stranger)
                  .having((e) => e.name, 'name', 'json')
                  .having((e) => '${e.message}', 'message', contains(name)),
            ),
            reason: '$name ← "$stranger"',
          );
        }
      }
    });

    test('NotificationType ve ActivityKind bilinmeyen değerde unknown döner '
        '(ileri uyumluluk; hata yok)', () {
      final tolerant = {
        for (final MapEntry(:key, :value) in _persisted.entries)
          if (value.fallback != null) key: value,
      };

      expect(tolerant.keys, ['NotificationType', 'ActivityKind']);
      for (final MapEntry(key: name, value: spec) in tolerant.entries) {
        for (final stranger in strangers(spec)) {
          expect(
            spec.parse(stranger),
            spec.fallback,
            reason: '$name ← "$stranger"',
          );
        }
      }
    });
  });

  group("T-09 · enum'lar · kaynak sözleşmesi", () {
    test("kalıcı enum kendi dosyasında ve @JsonEnum(valueField: 'json') ile "
        'işaretlidir (json_serializable eşlemesi json alanından)', () {
      for (final name in _persisted.keys) {
        expect(
          readRepoFile('$_enumsDir/${_snake(name)}.dart'),
          contains("@JsonEnum(valueField: 'json')\nenum $name {"),
          reason: name,
        );
      }
    });

    test('türetilmiş enum kendi dosyasında ve JSON eşlemesi taşımaz', () {
      for (final name in _derived.keys) {
        final source = readRepoFile('$_enumsDir/${_snake(name)}.dart');

        expect(source, contains('\nenum $name {'), reason: name);
        expect(source, isNot(contains('JsonEnum')), reason: name);
      }
    });
  });

  group("T-09 · enum'lar · registry.json pariteleri", () {
    test('NotificationType.category ↔ notifCat (13 tür); unknown '
        'kategorisizdir', () {
      expect(
        {
          for (final type in NotificationType.values)
            if (type != NotificationType.unknown)
              type.json: type.category?.name,
        },
        _registryMap('notifCat'),
      );
      expect(NotificationType.unknown.category, isNull);
    });

    test('ActivityKind.category ↔ actCat (13 tür); unknown kategorisizdir', () {
      expect(
        {
          for (final kind in ActivityKind.values)
            if (kind != ActivityKind.unknown) kind.json: kind.category?.name,
        },
        _registryMap('actCat'),
      );
      expect(ActivityKind.unknown.category, isNull);
    });

    test('ActivityCategory.kinds, actCat eşlemesinin tersidir', () {
      final actCat = _registryMap('actCat');

      for (final category in ActivityCategory.values) {
        expect(
          [for (final kind in category.kinds) kind.json],
          unorderedEquals([
            for (final MapEntry(:key, :value) in actCat.entries)
              if (value == category.name) key,
          ]),
          reason: category.name,
        );
      }
    });

    test('EventType, YearLevel ve ClubPalette sırası; ClubPattern kümesi', () {
      expect(_persisted['EventType']!.jsons, _registry['eventTypes']);
      expect(_persisted['YearLevel']!.jsons, _registry['years']);
      expect(_persisted['ClubPalette']!.jsons, _registry['palettes']);
      expect(
        _persisted['ClubPattern']!.jsons,
        unorderedEquals((_registry['patterns']! as Map<String, Object?>).keys),
      );
    });
  });
}
