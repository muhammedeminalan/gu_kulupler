// T-08 · Limits: PLAN §9.8 tablosuyla ad + tip + değer paritesi (tablo
// docs/PLAN.md'den okunur), desen davranışları ve iç tutarlılık.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

/// `Limits` üyelerinin gerçek değerleri. Dart'ta yansıma olmadığı için elle
/// tutulur; anahtar kümesi hem PLAN §9.8 tablosuyla hem de `limits.dart`
/// kaynak dosyasındaki bildirimlerle karşılaştırılır (eksik/fazla = kırmızı).
const Map<String, Object> _actual = {
  'passwordMinLength': Limits.passwordMinLength,
  'passwordPattern': Limits.passwordPattern,
  'loginMaxFailedAttempts': Limits.loginMaxFailedAttempts,
  'loginLockout': Limits.loginLockout,
  'verificationResendCooldown': Limits.verificationResendCooldown,
  'authTimeout': Limits.authTimeout,
  'firestoreTimeout': Limits.firestoreTimeout,
  'storageUploadTimeout': Limits.storageUploadTimeout,
  'retryBackoff': Limits.retryBackoff,
  'batchMaxWrites': Limits.batchMaxWrites,
  'splashTimeout': Limits.splashTimeout,
  'nameMin': Limits.nameMin,
  'nameMax': Limits.nameMax,
  'clubNameMax': Limits.clubNameMax,
  'interestsMin': Limits.interestsMin,
  'interestsMax': Limits.interestsMax,
  'bioMax': Limits.bioMax,
  'adminReasonMax': Limits.adminReasonMax,
  'fcmTokensMax': Limits.fcmTokensMax,
  'platforms': Limits.platforms,
  'clubSummaryMax': Limits.clubSummaryMax,
  'clubAboutMax': Limits.clubAboutMax,
  'conditionsMax': Limits.conditionsMax,
  'conditionTextMax': Limits.conditionTextMax,
  'foundedMin': Limits.foundedMin,
  'foundedMax': Limits.foundedMax,
  'instagramHandlePattern': Limits.instagramHandlePattern,
  'applicationNoteMax': Limits.applicationNoteMax,
  'rejectNoteMax': Limits.rejectNoteMax,
  'reapplyCooldown': Limits.reapplyCooldown,
  'managerUndoWindow': Limits.managerUndoWindow,
  'clockSkewTolerance': Limits.clockSkewTolerance,
  'postTextMax': Limits.postTextMax,
  'postTitleMax': Limits.postTitleMax,
  'postImagesMax': Limits.postImagesMax,
  'imageMaxBytes': Limits.imageMaxBytes,
  'pollOptionsMin': Limits.pollOptionsMin,
  'pollOptionsMax': Limits.pollOptionsMax,
  'pollOptionTextMax': Limits.pollOptionTextMax,
  'pollDurationsDays': Limits.pollDurationsDays,
  'commentMax': Limits.commentMax,
  'commentCounterFrom': Limits.commentCounterFrom,
  'eventTitleMax': Limits.eventTitleMax,
  'eventDescMax': Limits.eventDescMax,
  'placeTextMax': Limits.placeTextMax,
  'eventCopyShift': Limits.eventCopyShift,
  'attendanceWindowBefore': Limits.attendanceWindowBefore,
  'attendanceWindowAfter': Limits.attendanceWindowAfter,
  'reportNoteMax': Limits.reportNoteMax,
  'supportMessageMax': Limits.supportMessageMax,
  'supportAttachmentsMax': Limits.supportAttachmentsMax,
  'announcementDailyLimit': Limits.announcementDailyLimit,
  'timeOfDayPattern': Limits.timeOfDayPattern,
  'quietFromDefault': Limits.quietFromDefault,
  'quietToDefault': Limits.quietToDefault,
  'isoDayPattern': Limits.isoDayPattern,
  'recentSearchesMax': Limits.recentSearchesMax,
  'searchDebounce': Limits.searchDebounce,
  'pageSize': Limits.pageSize,
  'clubsFetchMax': Limits.clubsFetchMax,
  'upcomingEventsFetchMax': Limits.upcomingEventsFetchMax,
  'notificationInboxLimit': Limits.notificationInboxLimit,
  'unreadBadgeMax': Limits.unreadBadgeMax,
  'notificationFanOutChunkSize': Limits.notificationFanOutChunkSize,
  'eventNewInterestFanOutMax': Limits.eventNewInterestFanOutMax,
  'accountDeletionChunk': Limits.accountDeletionChunk,
  'istanbulUtcOffset': Limits.istanbulUtcOffset,
};

/// PLAN §9.8 tablosunun tek bir sabiti (birleşik satırlar açılmış hâlde).
typedef _PlanLimit = ({String name, String signature, String type, String raw});

/// `limits.dart` içindeki tek bir statik üye bildirimi.
typedef _SourceMember = ({
  String name,
  String type,
  bool isConst,
  String? args,
});

/// PLAN §9.8 tablosunu okur; `` `a` / `b` `` biçimindeki birleşik satırları
/// tek tek sabitlere açar.
List<_PlanLimit> _readPlanLimits() {
  final table = markdownTable(
    readRepoFile('docs/PLAN.md'),
    heading: '### 9.8 ',
  );
  if (table.header.take(3).join('|') != 'Sabit|Tip|Değer') {
    throw StateError('PLAN §9.8 başlığı değişmiş: ${table.header}');
  }
  final limits = <_PlanLimit>[];
  for (final row in table.rows) {
    final signatures = codeSpans(row[0]);
    final types = codeSpans(row[1]);
    final values = codeSpans(row[2]);
    if (signatures.isEmpty ||
        types.length != 1 ||
        values.length < signatures.length) {
      throw StateError('PLAN §9.8 satırı ayrıştırılamadı: $row');
    }
    for (var i = 0; i < signatures.length; i++) {
      limits.add((
        name: signatures[i].split('(').first,
        signature: signatures[i],
        type: types.single,
        raw: values[i],
      ));
    }
  }
  return limits;
}

/// `limits.dart` kaynak metnindeki `static` üye bildirimlerini çıkarır.
List<_SourceMember> _readSourceMembers() {
  final source = readRepoFile('packages/gu_data/lib/src/constants/limits.dart');
  final declaration = RegExp(
    r'^ {2}static (const )?([A-Za-z][\w<>, ]*?) (\w+)(?:\(([^)]*)\))?\s*(?:=>|=)',
    multiLine: true,
  );
  return [
    for (final match in declaration.allMatches(source))
      (
        name: match.group(3)!,
        type: match.group(2)!,
        isConst: match.group(1) != null,
        args: match.group(4),
      ),
  ];
}

int _parseInt(String raw) => raw
    .split('*')
    .map((factor) => int.parse(factor.trim()))
    .reduce((a, b) => a * b);

Duration _parseDuration(String raw) {
  final match = RegExp(
    r'^Duration\((days|hours|minutes|seconds|milliseconds): (\d+)\)$',
  ).firstMatch(raw);
  if (match == null) throw FormatException('Duration değil', raw);
  final amount = int.parse(match.group(2)!);
  return switch (match.group(1)!) {
    'days' => Duration(days: amount),
    'hours' => Duration(hours: amount),
    'minutes' => Duration(minutes: amount),
    'seconds' => Duration(seconds: amount),
    _ => Duration(milliseconds: amount),
  };
}

List<String> _listItems(String raw, String open, String close) {
  if (!raw.startsWith(open) || !raw.endsWith(close)) {
    throw FormatException('"$open…$close" bekleniyordu', raw);
  }
  return [
    for (final item in raw.substring(1, raw.length - 1).split(',')) item.trim(),
  ];
}

Duration _parseMs(String raw) {
  final match = RegExp(r'^(\d+) ms$').firstMatch(raw);
  if (match == null) throw FormatException('"<n> ms" bekleniyordu', raw);
  return Duration(milliseconds: int.parse(match.group(1)!));
}

String _unquote(String raw) {
  if (raw.length < 2 || !raw.startsWith("'") || !raw.endsWith("'")) {
    throw FormatException('Tek tırnaklı dizgi bekleniyordu', raw);
  }
  return raw.substring(1, raw.length - 1);
}

/// PLAN "Değer" hücresini "Tip" hücresine göre Dart değerine çevirir.
Object _parseValue(_PlanLimit limit) => switch (limit.type) {
  'int' => _parseInt(limit.raw),
  // Tırnaklı = düz dizgi (`'22:00'`); tırnaksız = RegExp kaynağı.
  'String' => limit.raw.startsWith("'") ? _unquote(limit.raw) : limit.raw,
  'Duration' => _parseDuration(limit.raw),
  'List<int>' => _listItems(limit.raw, '[', ']').map(int.parse).toList(),
  'List<Duration>' => _listItems(limit.raw, '[', ']').map(_parseMs).toList(),
  'Set<String>' => _listItems(limit.raw, '{', '}').map(_unquote).toSet(),
  _ => throw StateError('PLAN §9.8: bilinmeyen tip "${limit.type}"'),
};

Matcher _isOfPlanType(String type) => switch (type) {
  'int' => isA<int>(),
  'String' => isA<String>(),
  'Duration' => isA<Duration>(),
  'List<int>' => isA<List<int>>(),
  'List<Duration>' => isA<List<Duration>>(),
  'Set<String>' => isA<Set<String>>(),
  _ => throw StateError('PLAN §9.8: bilinmeyen tip "$type"'),
};

/// Yalnızca [nowUtc] cevap veren saat; `foundedMax` başka üyeye dokunursa
/// test kırılır.
final class _YearClock implements AppClock {
  _YearClock(this._now);

  final DateTime _now;

  /// [nowUtc] çağrı sayısı.
  int calls = 0;

  @override
  DateTime nowUtc() {
    calls++;
    return _now;
  }

  @override
  String istanbulDayKey(DateTime utc) => throw UnimplementedError();

  @override
  String istanbulDay(DateTime utc) => throw UnimplementedError();

  @override
  DateTime istanbulStartOfDay(DateTime utc) => throw UnimplementedError();
}

bool _matches(String pattern, String input, {bool unicode = false}) =>
    RegExp(pattern, unicode: unicode).hasMatch(input);

void main() {
  final planLimits = _readPlanLimits();
  final planNames = [for (final limit in planLimits) limit.name];

  group('T-08 · Limits · PLAN §9.8 ad paritesi', () {
    test('tablo okunur: 67 tekil sabit', () {
      expect(planLimits, hasLength(67));
      expect(planNames.toSet(), hasLength(67), reason: 'yinelenen ad');
    });

    test('test değer haritası tablodaki adlarla birebir', () {
      expect(_actual.keys.toSet(), planNames.toSet());
    });

    test('limits.dart üyeleri tablodaki adlarla birebir (fazla/eksik yok)', () {
      final sourceNames = [for (final m in _readSourceMembers()) m.name];

      expect(sourceNames.toSet(), hasLength(sourceNames.length));
      expect(
        sourceNames.toSet().difference(planNames.toSet()),
        isEmpty,
        reason: 'tabloda olmayan Limits üyesi',
      );
      expect(
        planNames.toSet().difference(sourceNames.toSet()),
        isEmpty,
        reason: 'tabloda olup Limits içinde olmayan üye',
      );
    });

    test('limits.dart tek sınıftır; statik olmayan üye yok', () {
      final source = readRepoFile(
        'packages/gu_data/lib/src/constants/limits.dart',
      );
      final typeDeclarations = RegExp(
        '^(?:abstract |final |sealed |base |interface )*'
        r'(?:class|mixin|enum|extension)\b.*$',
        multiLine: true,
      ).allMatches(source).map((match) => match.group(0)).toList();
      final memberLines = source
          .substring(source.indexOf('abstract final class Limits {'))
          .split('\n')
          .where((line) => RegExp('^ {2}[A-Za-z_@]').hasMatch(line));

      expect(typeDeclarations, ['abstract final class Limits {']);
      expect(memberLines, hasLength(67));
      expect(memberLines, everyElement(startsWith('  static ')));
    });

    test('her üye static const; tek istisna foundedMax(AppClock clock)', () {
      final members = _readSourceMembers();
      final nonConst = [
        for (final m in members)
          if (!m.isConst) m.name,
      ];
      final functions = [
        for (final m in members)
          if (m.args != null) '${m.name}(${m.args})',
      ];

      expect(nonConst, ['foundedMax']);
      expect(functions, ['foundedMax(AppClock clock)']);
      expect(
        planLimits.singleWhere((l) => l.name == 'foundedMax').signature,
        'foundedMax(AppClock clock)',
      );
    });

    test('bildirilen tipler tablodaki "Tip" sütunuyla aynı', () {
      final sourceTypes = {
        for (final m in _readSourceMembers())
          m.name: m.isConst ? m.type : 'static ${m.type}',
      };
      final planTypes = {for (final l in planLimits) l.name: l.type};

      expect(sourceTypes, planTypes);
    });
  });

  group('T-08 · Limits · PLAN §9.8 değer paritesi', () {
    for (final limit in planLimits.where((l) => l.type != 'static int')) {
      test('${limit.name} = ${limit.raw}', () {
        final actual = _actual[limit.name];

        expect(actual, _isOfPlanType(limit.type));
        expect(actual, _parseValue(limit));
      });
    }

    test('foundedMax(AppClock clock) = clock.nowUtc().year', () {
      final limit = planLimits.singleWhere((l) => l.name == 'foundedMax');
      final clock = _YearClock(DateTime.utc(2026, 10, 8));

      expect(limit.type, 'static int');
      expect(limit.raw, 'clock.nowUtc().year');
      expect(_actual['foundedMax'], isA<int Function(AppClock)>());
      expect(Limits.foundedMax(clock), clock.nowUtc().year);
    });

    test('değer ayrıştırıcı bilinmeyen tipi ve bozuk değeri reddeder', () {
      _PlanLimit limit(String type, String raw) =>
          (name: 'x', signature: 'x', type: type, raw: raw);

      expect(() => _parseValue(limit('double', '1.5')), throwsStateError);
      expect(() => _isOfPlanType('double'), throwsStateError);
      for (final broken in [
        limit('int', 'on'),
        limit('Duration', 'Duration(weeks: 1)'),
        limit('Duration', '30 s'),
        limit('List<Duration>', '[250, 500]'),
        limit('List<Duration>', '250 ms, 500 ms'),
        limit('List<int>', '1, 3, 7'),
        limit('List<int>', '[1, x]'),
        limit('Set<String>', '{ios, android}'),
        limit('Set<String>', "['ios']"),
        limit('String', "'22:00"),
      ]) {
        expect(
          () => _parseValue(broken),
          throwsFormatException,
          reason: '${broken.type} ← ${broken.raw}',
        );
      }
    });
  });

  group('T-08 · Limits · passwordPattern', () {
    bool ok(String password) =>
        _matches(Limits.passwordPattern, password, unicode: true);

    test('büyük harf + rakam + en az 8 karakter geçer', () {
      expect(ok('Şifre1234'), isTrue);
      expect(ok('Abcdefg1'), isTrue, reason: 'tam 8 karakter');
      expect(ok('1bcdefgH'), isTrue, reason: 'sıra önemsiz');
      expect(ok('İstanbul1'), isTrue, reason: 'Türkçe büyük harf İ');
      expect(ok('çığöşüĞ9'), isTrue, reason: 'Türkçe büyük harf Ğ');
      expect(ok('Parola 12 boşluklu'), isTrue);
    });

    test('büyük harf yoksa geçmez', () {
      expect(ok('sifre1234'), isFalse);
      expect(ok('şifre1234'), isFalse);
      expect(ok('12345678'), isFalse);
    });

    test('rakam yoksa geçmez', () {
      expect(ok('SIFRE'), isFalse);
      expect(ok('Abcdefgh'), isFalse);
      expect(ok('ŞİFREŞİFRE'), isFalse);
    });

    test('8 karakterden kısaysa geçmez', () {
      expect(ok('Abcdef1'), isFalse, reason: '7 karakter');
      expect(ok('A1'), isFalse);
      expect(ok(''), isFalse);
    });

    test('desendeki alt sınır passwordMinLength ile aynı', () {
      expect(
        Limits.passwordPattern,
        endsWith('.{${Limits.passwordMinLength},}\$'),
      );
      expect(ok('A1${'x' * (Limits.passwordMinLength - 2)}'), isTrue);
      expect(ok('A1${'x' * (Limits.passwordMinLength - 3)}'), isFalse);
    });

    test(r'unicode bayrağı olmadan derlenirse \p{Lu} çalışmaz (belgelenen '
        'kullanım: RegExp(unicode: true))', () {
      expect(_matches(Limits.passwordPattern, 'Şifre1234'), isFalse);
    });
  });

  group('T-08 · Limits · timeOfDayPattern', () {
    bool ok(String time) => _matches(Limits.timeOfDayPattern, time);

    test('00:00–23:59 arası HH:mm geçer', () {
      for (final time in [
        '00:00',
        '08:00',
        '09:05',
        '19:59',
        '22:00',
        '23:59',
      ]) {
        expect(ok(time), isTrue, reason: time);
      }
    });

    test('aralık dışı ve bozuk biçim geçmez', () {
      for (final time in [
        '24:00',
        '23:60',
        '7:30',
        '07:5',
        '0730',
        '07.30',
        '07:30:00',
        ' 07:30',
        '07:30 ',
        '07:30\n',
        'aa:bb',
        '',
      ]) {
        expect(ok(time), isFalse, reason: '"$time"');
      }
    });

    test('sessiz saat varsayılanları desene uyar', () {
      expect(ok(Limits.quietFromDefault), isTrue);
      expect(ok(Limits.quietToDefault), isTrue);
      expect(Limits.quietFromDefault, isNot(Limits.quietToDefault));
    });
  });

  group('T-08 · Limits · isoDayPattern', () {
    bool ok(String day) => _matches(Limits.isoDayPattern, day);

    test('yyyy-MM-dd geçer', () {
      expect(ok('2026-10-08'), isTrue);
      expect(ok('1900-01-01'), isTrue);
    });

    test('ayraçsız, kısa ya da ekli biçim geçmez', () {
      for (final day in [
        '20261008',
        '2026-1-8',
        '26-10-08',
        '2026/10/08',
        '2026-10-08T00:00',
        ' 2026-10-08',
        '2026-10-08\n',
        '',
      ]) {
        expect(ok(day), isFalse, reason: '"$day"');
      }
    });
  });

  group('T-08 · Limits · instagramHandlePattern', () {
    bool ok(String handle) => _matches(Limits.instagramHandlePattern, handle);

    test('@ isteğe bağlı; harf, rakam, nokta, alt çizgi geçer', () {
      expect(ok('@gu_kulupler'), isTrue);
      expect(ok('gu.kulupler'), isTrue);
      expect(ok('@a'), isTrue, reason: 'K-50: alt sınır 1');
      expect(ok('A9._'), isTrue);
      expect(ok('a' * 30), isTrue, reason: '30 karakter');
      expect(ok('@${'a' * 30}'), isTrue, reason: '@ sayılmaz');
    });

    test('boşluk, 31 karakter, yalnız @ ve ASCII dışı harf geçmez', () {
      for (final handle in [
        '@a b',
        'a' * 31,
        '@${'a' * 31}',
        '@',
        '',
        '@@a',
        'a@',
        'gümüşhane',
        'gu-kulupler',
        'gu/kulupler',
        'gu_kulupler\n',
      ]) {
        expect(ok(handle), isFalse, reason: '"$handle"');
      }
    });
  });

  group('T-08 · Limits · foundedMax', () {
    test('saatin UTC yılını verir', () {
      expect(Limits.foundedMax(_YearClock(DateTime.utc(2026, 10, 8))), 2026);
      expect(Limits.foundedMax(_YearClock(DateTime.utc(1999, 6, 15))), 1999);
    });

    test('yıl sınırında UTC esas alınır (Rules request.time.year())', () {
      // 2026-12-31 22:30 UTC = Istanbul 2027-01-01 01:30; Rules UTC yılına bakar.
      expect(
        Limits.foundedMax(_YearClock(DateTime.utc(2026, 12, 31, 22, 30))),
        2026,
      );
      expect(
        Limits.foundedMax(
          _YearClock(DateTime.utc(2026, 12, 31, 23, 59, 59, 999)),
        ),
        2026,
      );
      expect(Limits.foundedMax(_YearClock(DateTime.utc(2027))), 2027);
    });

    test('saati tam bir kez okur, başka AppClock üyesine dokunmaz', () {
      final clock = _YearClock(DateTime.utc(2026, 10, 8));

      Limits.foundedMax(clock);

      expect(clock.calls, 1);
    });

    test('foundedMin güncel üst sınırın altındadır', () {
      expect(
        Limits.foundedMin,
        lessThan(Limits.foundedMax(_YearClock(DateTime.utc(2026, 10, 8)))),
      );
    });
  });

  group('T-08 · Limits · iç tutarlılık', () {
    test('alt sınırlar üst sınırları aşmaz', () {
      expect(Limits.nameMin, lessThan(Limits.nameMax));
      expect(Limits.interestsMin, lessThan(Limits.interestsMax));
      expect(Limits.pollOptionsMin, lessThan(Limits.pollOptionsMax));
      expect(Limits.commentCounterFrom, lessThan(Limits.commentMax));
      expect(Limits.clubSummaryMax, lessThan(Limits.clubAboutMax));
    });

    test('alt sınırlar pozitiftir (boş ad / sıfır seçenek kabul edilmez)', () {
      expect(Limits.nameMin, greaterThan(0));
      expect(Limits.interestsMin, greaterThan(0));
      expect(Limits.pollOptionsMin, greaterThanOrEqualTo(2));
      expect(Limits.passwordMinLength, greaterThan(0));
    });

    test('tüm int sınırlar pozitiftir', () {
      final ints = _actual.entries.where((entry) => entry.value is int);

      expect(ints, isNotEmpty);
      for (final entry in ints) {
        expect(entry.value, greaterThan(0), reason: entry.key);
      }
    });

    test('tüm süreler pozitiftir', () {
      final durations = _actual.entries.where((e) => e.value is Duration);

      expect(durations, isNotEmpty);
      for (final entry in durations) {
        expect(
          entry.value,
          greaterThan(Duration.zero),
          reason: entry.key,
        );
      }
    });

    test('retryBackoff üç deneme, kesin artan', () {
      expect(Limits.retryBackoff, hasLength(3));
      expect(Limits.retryBackoff, const [
        Duration(milliseconds: 250),
        Duration(milliseconds: 500),
        Duration(milliseconds: 1000),
      ]);
      for (var i = 1; i < Limits.retryBackoff.length; i++) {
        expect(
          Limits.retryBackoff[i],
          greaterThan(Limits.retryBackoff[i - 1]),
        );
      }
    });

    test('pollDurationsDays kesin artan ve pozitif', () {
      expect(Limits.pollDurationsDays, [1, 3, 7]);
      for (var i = 1; i < Limits.pollDurationsDays.length; i++) {
        expect(
          Limits.pollDurationsDays[i],
          greaterThan(Limits.pollDurationsDays[i - 1]),
        );
      }
    });

    test('batch ve parça boyutları Firestore 500 yazma sınırının altında', () {
      expect(Limits.batchMaxWrites, lessThan(500));
      expect(
        Limits.notificationFanOutChunkSize,
        inInclusiveRange(10, Limits.batchMaxWrites),
      );
      expect(Limits.accountDeletionChunk, lessThan(Limits.batchMaxWrites));
    });

    test('imageMaxBytes tam 5 MiB (5 242 880 bayt)', () {
      expect(Limits.imageMaxBytes, 5242880);
    });

    test('süre sabitleri plan metnindeki birimlerle aynı', () {
      expect(Limits.clockSkewTolerance, const Duration(minutes: 5));
      expect(Limits.istanbulUtcOffset, const Duration(hours: 3));
      expect(Limits.reapplyCooldown.inDays, 7);
      expect(Limits.managerUndoWindow.inSeconds, 30);
      expect(Limits.loginLockout.inSeconds, 30);
      expect(Limits.verificationResendCooldown.inSeconds, 60);
      expect(Limits.attendanceWindowBefore.inHours, 2);
      expect(Limits.attendanceWindowAfter.inHours, 6);
      expect(Limits.searchDebounce.inMilliseconds, 250);
    });

    test('okunmamış rozeti sınırı gelen kutusu sınırının altında', () {
      expect(Limits.unreadBadgeMax, lessThan(Limits.notificationInboxLimit));
    });

    test('platforms tam olarak ios ve android', () {
      expect(Limits.platforms, {'ios', 'android'});
    });

    test('koleksiyon sabitleri değiştirilemez', () {
      expect(
        () => Limits.retryBackoff.add(Duration.zero),
        throwsUnsupportedError,
      );
      expect(() => Limits.pollDurationsDays.add(14), throwsUnsupportedError);
      expect(() => Limits.platforms.add('web'), throwsUnsupportedError);
    });
  });

  group('T-08 · Limits · sınıf adı (CD-31)', () {
    test('domain-model yalnızca Limits adını kullanır; GuLimits yok', () {
      final domainModel = readRepoFile('docs/domain-model.md');

      expect(domainModel, contains('## 9. Sabit sınırlar (`Limits`, tek yer)'));
      expect(domainModel, isNot(contains('GuLimits')));
    });

    test('domain-model §9: sunum süreleri Limits listesinde değil, GuMotion / '
        'AppDurations göndermesidir (PLAN §9.8, CD-24, CD-58)', () {
      final lines = readRepoFile('docs/domain-model.md').split('\n');
      final start = lines.indexOf('## 9. Sabit sınırlar (`Limits`, tek yer)');
      final end = lines.indexWhere((l) => l.startsWith('## '), start + 1);
      final section = lines.sublist(start + 1, end);
      final limitsList = section.firstWhere((l) => l.startsWith('Şifre ≥ 8'));
      final presentation = section.singleWhere(
        (l) => l.startsWith('Sunum süreleri'),
      );

      // Dört sunum süresi Limits listesinden çıktı.
      for (final phrase in ['toast', 'splash', 'QR', 'oto-kapanma']) {
        expect(limitsList, isNot(contains(phrase)), reason: phrase);
      }
      // …ve token / sabit göndermesine çevrildi.
      expect(presentation, contains("`Limits`'te **değildir**"));
      for (final reference in [
        '4 sn → `GuMotion.toastDefault`',
        '6 sn → `GuMotion.toastUndo`',
        '1.2 sn → `GuMotion.splash`',
        '2 sn → `AppDurations.qrSuccessAutoClose`',
      ]) {
        expect(presentation, contains(reference), reason: reference);
      }
      // Limits'te kalan süreler listede durur.
      expect(limitsList, contains('yönetici karar geri alma 30 sn (Rules)'));
      expect(limitsList, contains('arama debounce 250 ms'));
    });

    test('Limits sunum süresi üyesi taşımaz (kaynakta toast / splash / '
        'autoClose adı yok)', () {
      final source = readRepoFile(
        'packages/gu_data/lib/src/constants/limits.dart',
      );
      final members = [
        for (final match in RegExp(
          r'^  static (?:const )?[\w<>, ?]+ (\w+)(?: =|\()',
          multiLine: true,
        ).allMatches(source))
          match.group(1)!,
      ];

      expect(members, isNotEmpty);
      for (final name in members) {
        final lower = name.toLowerCase();
        // `splashTimeout` oturum bekleme üst sınırıdır (sunum süresi değil).
        if (name == 'splashTimeout') continue;
        for (final forbidden in [
          'toast',
          'splash',
          'autoclose',
          'sheetdelay',
        ]) {
          expect(lower, isNot(contains(forbidden)), reason: name);
        }
      }
    });

    test('paket kaynağında GuLimits adı geçmez', () {
      final sources = Directory('$repoRoot/packages/gu_data/lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      expect(sources, isNotEmpty);
      for (final file in sources) {
        expect(
          file.readAsStringSync(),
          isNot(contains('GuLimits')),
          reason: file.path,
        );
      }
    });
  });
}
