// T-15 · ReportRepository: şikayet oluşturma (6 neden × 5 hedef, yazılan
// alanlar, `null` alan yazılmaz — W-51), aynı hedefe ikinci şikayet
// (`alreadyExists`), kendini şikayet ve hedef–kulüp tutarlılığı, not sınırı,
// `hasReported`, geçersiz kimlik (W-54) ve hata eşlemesi (PLAN §9.6.12,
// §10.4; rules-spec §3.10; CD-33, D-10).
//
// T-45 (kullanıcı kararı 3): günlük şikayet kotası — ön okuma
// (`reportCounters/{uid}_{yyyyMMdd}`) + tek batch (şikayet + sayaç
// `set(merge)` `increment(1)`); kota dolu → yazmadan `reportLimit`; Rules
// reddi sonrası sayaç doluysa `reportLimit`; gün sınırı penceresinde komşu
// günle bir kez yeniden deneme (W-50, rules-spec §3.18).
//
// Mutlu yollar `fake_cloud_firestore` ile (Q-06); hata yolları el yazımı
// çiftlerle (`test/fakes/sdk_firestore_stubs.dart`). `fake_cloud_firestore`
// kural çalıştırmadığı için "var olan belgeye yazım Rules'ta reddedilir",
// sayaç sınırı ve sunucu günü davranışlarını SDK çifti kurar
// (`test/fakes/rules_report_firestore.dart`).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../fakes/fake_app_clock.dart';
import '../fakes/rules_report_firestore.dart';
import '../fakes/sdk_firestore_stubs.dart';
import '../helpers/plan_repository_table.dart';
import '../helpers/plan_service_table.dart';
import '../helpers/repo_sources.dart';

const String _interface =
    'packages/gu_data/lib/src/repositories/report_repository.dart';
const String _implementation =
    'packages/gu_data/lib/src/repositories/firebase_report_repository.dart';
const String _reporter = 'u_ayse';

const ReportTarget _post = (
  type: ReportTargetType.post,
  id: 'p01',
  clubId: 'c01',
);

/// Her hedef türü için geçerli bir hedef, enum sırasıyla (CD-33).
const List<ReportTarget> _targets = [
  _post,
  (type: ReportTargetType.comment, id: 'cm01', clubId: 'c01'),
  (type: ReportTargetType.user, id: 'u_mehmet', clubId: null),
  (type: ReportTargetType.club, id: 'c01', clubId: 'c01'),
  (type: ReportTargetType.event, id: 'e01', clubId: 'c02'),
];

/// Geçersiz belge kimlikleri (W-54).
const List<String> _invalidIds = ['', 'u/1', '..', '__uid__'];

/// Istanbul'da 13 Ekim 2026 12:00 — gün sınırı penceresinin dışında.
final DateTime _noon = DateTime.utc(2026, 10, 13, 9);

/// Istanbul'da 14 Ekim 00:00 (gün sınırı).
final DateTime _midnight = DateTime.utc(2026, 10, 13, 21);

const String _day13 = '20261013';
const String _day14 = '20261014';

/// [reporter] kullanıcısının [dayKey] günündeki sayaç belgesi yolu.
String _counterPath(String dayKey, [String reporter = _reporter]) =>
    'reportCounters/${reporter}_$dayKey';

void main() {
  late FakeFirebaseFirestore db;
  late FakeAppClock clock;
  late ReportRepository repository;

  Future<Json?> read(String id) async =>
      (await db.collection('reports').doc(id).get()).data();

  Future<List<String>> ids() async => [
    for (final doc in (await db.collection('reports').get()).docs) doc.id,
  ];

  /// Her çağrısı [code] hatasıyla biten veritabanına bağlı repository.
  ReportRepository failing(String code) => FirebaseReportRepository(
    FirebaseFirestoreService(StubFirestore(error: firestoreException(code))),
    clock,
  );

  /// Security Rules şikayet davranışlı (var olan şikayete set ret, sayaç
  /// sınırı, [serverDayKey] verilirse sunucu günü) repository.
  RulesReportFirestore useRules({String? serverDayKey}) {
    final rules = RulesReportFirestore(db, serverDayKey: serverDayKey);
    repository = FirebaseReportRepository(
      FirebaseFirestoreService(rules),
      clock,
    );
    return rules;
  }

  Future<Json?> readPath(String path) async =>
      (await db.doc(path).get()).data();

  /// [dayKey] gününün sayacını [count] ile kurar (kurallar dışında).
  Future<void> seedCounter(String dayKey, int count) =>
      db.doc(_counterPath(dayKey)).set({
        'userId': _reporter,
        'day':
            '${dayKey.substring(0, 4)}-${dayKey.substring(4, 6)}-'
            '${dayKey.substring(6)}',
        'count': count,
        'reportId': null,
        'updatedAt': Timestamp.fromDate(_noon),
      });

  Future<FirestoreResult<void>> reportPost(
    String id, {
    ReportReason reason = ReportReason.spam,
  }) => repository.report(
    reporterId: _reporter,
    target: (type: ReportTargetType.post, id: id, clubId: 'c01'),
    reason: reason,
  );

  void expectLimit(FirestoreResult<void> result) {
    expect(result.errorOrNull, FirestoreError.ruleViolation);
    expect(
      (result as FirebaseFailure<void, FirestoreError>).detail,
      const FirestoreFailureDetail(FirestoreRuleCode.reportLimit),
    );
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    clock = FakeAppClock(_noon);
    repository = FirebaseReportRepository(FirebaseFirestoreService(db), clock);
  });

  group('T-15 · ReportRepository · sözleşme', () {
    test('PLAN §10.4 tablosundaki her metot arayüzde aynı imzayla var; başka '
        'üye yok', () {
      final plan = [
        for (final row in markdownTable(
          readRepoFile('docs/PLAN.md'),
          heading: '#### $ReportRepository ',
        ).rows)
          // `new_report` satırı metot değildir: imza hücresi `—` (CD-37).
          if (row[1].startsWith('`'))
            normalizeDartSource(codeSpans(row[1]).first),
      ];

      expect(plan, hasLength(2));
      expect(
        interfaceMembers(_interface, '$ReportRepository').toSet(),
        plan.toSet(),
      );
    });

    test('arayüzde ve uygulamada silme üyesi yok (D-10)', () {
      expect(deleteIdentifiersIn(_interface), isEmpty);
      expect(deleteIdentifiersIn(_implementation), isEmpty);
    });
  });

  group('T-15 · ReportRepository · report', () {
    test('6 neden × 5 hedef: her şikayet türeyen kimliğe, yalnızca dolu '
        'alanlarla yazılır (W-51)', () async {
      expect(_targets.map((target) => target.type), ReportTargetType.values);

      for (final target in _targets) {
        for (final reason in ReportReason.values) {
          final reporter = 'u_${reason.json}';

          final result = await repository.report(
            reporterId: reporter,
            target: target,
            reason: reason,
            note: 'açıklama',
          );

          final label = '${target.type.json} × ${reason.json}';
          expect(result.isSuccess, isTrue, reason: label);
          expect(
            await read('${reporter}_${target.type.json}_${target.id}'),
            {
              'targetType': target.type.json,
              'targetId': target.id,
              'targetClubId': ?target.clubId,
              'reporterId': reporter,
              'reason': reason.json,
              'note': 'açıklama',
              'status': 'open',
              'createdAt': isA<Timestamp>(),
              'updatedAt': isA<Timestamp>(),
              'isDeleted': false,
              'deletedAt': null,
              'deletedBy': null,
            },
            reason: label,
          );
        }
      }
      expect(
        await ids(),
        hasLength(_targets.length * ReportReason.values.length),
      );
    });

    test('not verilmezse boş yazılır; belge açık şikayet olarak modele '
        'çevrilir', () async {
      await repository.report(
        reporterId: _reporter,
        target: _post,
        reason: ReportReason.spam,
      );

      final report = ReportModel.fromJson(
        (await read('u_ayse_post_p01'))!,
        id: 'u_ayse_post_p01',
      );
      expect(report.createdAt, isNotNull);
      expect(
        report.copyWith(clearCreatedAt: true, clearUpdatedAt: true),
        const ReportModel(
          targetType: ReportTargetType.post,
          targetId: 'p01',
          targetClubId: 'c01',
          reporterId: _reporter,
          reason: ReportReason.spam,
        ),
      );
    });

    test('kimlik şikayet eden + tür + hedeften türer: başka kullanıcı ve '
        'başka tür ayrı belgedir', () async {
      const comment = (
        type: ReportTargetType.comment,
        id: 'p01',
        clubId: 'c01',
      );

      for (final (reporter, target) in [
        (_reporter, _post),
        ('u_mehmet', _post),
        (_reporter, comment),
      ]) {
        await repository.report(
          reporterId: reporter,
          target: target,
          reason: ReportReason.spam,
        );
      }

      expect(
        await ids(),
        unorderedEquals([
          'u_ayse_post_p01',
          'u_mehmet_post_p01',
          'u_ayse_comment_p01',
        ]),
      );
    });

    test('aynı hedefe ikinci şikayet alreadyExists döner; ilk şikayet ve '
        'sayaç değişmez', () async {
      useRules();
      final guarded = repository;
      final first = await guarded.report(
        reporterId: _reporter,
        target: _post,
        reason: ReportReason.spam,
        note: 'ilk',
      );
      final before = await read('u_ayse_post_p01');

      final second = await guarded.report(
        reporterId: _reporter,
        target: _post,
        reason: ReportReason.other,
        note: 'ikinci',
      );

      expect(first.isSuccess, isTrue);
      expect(second.errorOrNull, FirestoreError.alreadyExists);
      expect(await read('u_ayse_post_p01'), before);
      expect(before, containsPair('note', 'ilk'));
      expect(await readPath(_counterPath(_day13)), containsPair('count', 1));
    });

    for (final (code, error) in [
      // Belge yokken gelen ret (etkin olmayan kullanıcı) "zaten bildirildi"
      // sayılmaz.
      ('permission-denied', FirestoreError.permissionDenied),
      ('already-exists', FirestoreError.alreadyExists),
      ('unavailable', FirestoreError.unavailable),
    ]) {
      test('yazma hatası aynen eşlenir: $code', () async {
        final result =
            await failing(
              code,
            ).report(
              reporterId: _reporter,
              target: _post,
              reason: ReportReason.spam,
            );

        expect(result.errorOrNull, error);
      });
    }

    test('not sınırı: ${Limits.reportNoteMax} karakter yazılır, bir fazlası '
        'yazmadan invalidArgument', () async {
      final atLimit = await repository.report(
        reporterId: _reporter,
        target: _post,
        reason: ReportReason.other,
        note: 'a' * Limits.reportNoteMax,
      );
      final overLimit = await repository.report(
        reporterId: 'u_mehmet',
        target: _post,
        reason: ReportReason.other,
        note: 'a' * (Limits.reportNoteMax + 1),
      );

      expect(atLimit.isSuccess, isTrue);
      expect(overLimit.errorOrNull, FirestoreError.invalidArgument);
      expect(await ids(), ['u_ayse_post_p01']);
    });

    for (final (label, target) in <(String, ReportTarget)>[
      (
        'kullanıcı kendini şikayet edemez',
        (type: ReportTargetType.user, id: _reporter, clubId: null),
      ),
      (
        'kullanıcı hedefinde kulüp olmaz',
        (type: ReportTargetType.user, id: 'u_mehmet', clubId: 'c01'),
      ),
      (
        'gönderi hedefinde kulüp zorunlu',
        (type: ReportTargetType.post, id: 'p01', clubId: null),
      ),
      (
        'etkinlik hedefinde kulüp zorunlu',
        (type: ReportTargetType.event, id: 'e01', clubId: null),
      ),
      (
        'kulüp hedefinde kulüp zorunlu',
        (type: ReportTargetType.club, id: 'c01', clubId: null),
      ),
      (
        'kulüp hedefinde kulüp hedefin kendisidir',
        (type: ReportTargetType.club, id: 'c01', clubId: 'c02'),
      ),
    ]) {
      test('geçersiz hedef yazmadan invalidArgument: $label', () async {
        final result = await repository.report(
          reporterId: _reporter,
          target: target,
          reason: ReportReason.harassment,
        );

        expect(result.errorOrNull, FirestoreError.invalidArgument);
        expect(await ids(), isEmpty);
      });
    }
  });

  group('T-45 · ReportRepository · günlük şikayet kotası (karar 3)', () {
    test('şikayet ve günün sayacı tek batch: sayaç yoksa count 1, varsa +1; '
        'sayaç alanları userId / day / count / reportId / updatedAt', () async {
      final rules = useRules(serverDayKey: _day13);

      expect((await reportPost('p01')).isSuccess, isTrue);
      expect(await readPath(_counterPath(_day13)), {
        'userId': _reporter,
        'day': '2026-10-13',
        'count': 1,
        'reportId': 'u_ayse_post_p01',
        'updatedAt': isA<Timestamp>(),
      });

      expect((await reportPost('p02')).isSuccess, isTrue);
      expect(
        await readPath(_counterPath(_day13)),
        allOf(
          containsPair('count', 2),
          containsPair('reportId', 'u_ayse_post_p02'),
        ),
      );
      expect(rules.commits, 2);
      expect(await ids(), ['u_ayse_post_p01', 'u_ayse_post_p02']);
    });

    test('Limits.reportDailyLimit = 20 (kullanıcı kararı 3)', () {
      expect(Limits.reportDailyLimit, 20);
    });

    test('20. şikayet geçer (19 → 20); 21. yazmadan reportLimit döner, '
        'şikayet ve sayaç değişmez', () async {
      final rules = useRules(serverDayKey: _day13);
      await seedCounter(_day13, Limits.reportDailyLimit - 1);

      expect((await reportPost('p20')).isSuccess, isTrue);
      expect(
        await readPath(_counterPath(_day13)),
        containsPair('count', Limits.reportDailyLimit),
      );

      final over = await reportPost('p21');

      expectLimit(over);
      expect(rules.commits, 1, reason: 'kota doluyken batch gönderilmez');
      expect(await read('u_ayse_post_p21'), isNull);
      expect(
        await readPath(_counterPath(_day13)),
        containsPair('count', Limits.reportDailyLimit),
      );
    });

    test('baştan 20 şikayet geçer, 21. reportLimit (istemci ön denetimi '
        'Rules sınırıyla aynı)', () async {
      useRules(serverDayKey: _day13);
      for (var i = 0; i < Limits.reportDailyLimit; i++) {
        expect((await reportPost('p$i')).isSuccess, isTrue, reason: 'p$i');
      }

      expectLimit(await reportPost('p_over'));
      expect(await ids(), hasLength(Limits.reportDailyLimit));
    });

    test('kota doluyken aynı hedef zaten bildirilmişse alreadyExists '
        '(DLG-12 "zaten bildirdin" önce gelir)', () async {
      useRules(serverDayKey: _day13);
      expect((await reportPost('p01')).isSuccess, isTrue);
      await seedCounter(_day13, Limits.reportDailyLimit);

      expect(
        (await reportPost('p01')).errorOrNull,
        FirestoreError.alreadyExists,
      );
    });

    test('önceki günün dolu sayacı bugünü etkilemez', () async {
      useRules(serverDayKey: _day13);
      await seedCounter('20261012', Limits.reportDailyLimit);

      expect((await reportPost('p01')).isSuccess, isTrue);
      expect(await readPath(_counterPath(_day13)), containsPair('count', 1));
      expect(
        await readPath(_counterPath('20261012')),
        containsPair('count', Limits.reportDailyLimit),
      );
    });

    test('Rules reddi (ön denetimden sonra eşzamanlı şikayet sayacı '
        'doldurdu): sayaç yeniden okunur ve reportLimit döner', () async {
      final rules = useRules(serverDayKey: _day13);
      await seedCounter(_day13, Limits.reportDailyLimit - 1);
      rules.beforeCommit = () => seedCounter(_day13, Limits.reportDailyLimit);

      expectLimit(await reportPost('p01'));
      expect(rules.denied, [_counterPath(_day13)]);
      expect(await read('u_ayse_post_p01'), isNull);
    });

    test('Rules reddi, sayaç dolu değil (etkin olmayan hesap vb.): '
        'permissionDenied aynen döner', () async {
      final rules = useRules(serverDayKey: _day13)..denyAll = true;

      final result = await reportPost('p01');

      expect(result.errorOrNull, FirestoreError.permissionDenied);
      expect(rules.commits, 1);
      expect(await ids(), isEmpty);
    });

    test('okuma hatası (ön denetim) aynen eşlenir; yazım denenmez', () async {
      final result = await failing('unavailable').report(
        reporterId: _reporter,
        target: _post,
        reason: ReportReason.spam,
      );

      expect(result.errorOrNull, FirestoreError.unavailable);
    });
  });

  group('T-45 · ReportRepository · gün sınırı (W-50 — rules-spec §3.18)', () {
    test('gün başından sonraki pencere: cihaz yarında, sunucu dünde → ret, '
        'dünün sayacıyla bir kez yeniden denenir', () async {
      final rules = useRules(serverDayKey: _day13);
      clock.set(_midnight.add(const Duration(minutes: 2)));

      expect((await reportPost('p01')).isSuccess, isTrue);
      expect(rules.commits, 2);
      expect(rules.denied, [_counterPath(_day14)]);
      expect(await readPath(_counterPath(_day13)), containsPair('count', 1));
      expect(await readPath(_counterPath(_day14)), isNull);
      expect(await ids(), ['u_ayse_post_p01']);
    });

    test('gün bitmeden önceki pencere: cihaz bugünde, sunucu yarında → '
        'yarının sayacıyla yeniden denenir', () async {
      final rules = useRules(serverDayKey: _day14);
      clock.set(_midnight.subtract(const Duration(minutes: 3)));

      expect((await reportPost('p01')).isSuccess, isTrue);
      expect(rules.commits, 2);
      expect(await readPath(_counterPath(_day14)), containsPair('count', 1));
      expect(await readPath(_counterPath(_day13)), isNull);
    });

    test('pencere dışında yeniden deneme yok: ret olduğu gibi döner', () async {
      final rules = useRules(serverDayKey: _day14);

      expect(
        (await reportPost('p01')).errorOrNull,
        FirestoreError.permissionDenied,
      );
      expect(rules.commits, 1);
      expect(await ids(), isEmpty);
    });

    test('komşu günün hakkı dolmuşsa yeniden deneme yazmadan reportLimit '
        'döner', () async {
      final rules = useRules(serverDayKey: _day13);
      clock.set(_midnight.add(const Duration(minutes: 2)));
      await seedCounter(_day13, Limits.reportDailyLimit);

      expectLimit(await reportPost('p01'));
      expect(rules.commits, 1);
      expect(await ids(), isEmpty);
    });

    test('aynı hedef zaten bildirilmişse pencere içinde de yeniden deneme '
        'yok: alreadyExists', () async {
      final rules = useRules(serverDayKey: _day14);
      await db.collection('reports').doc('u_ayse_post_p01').set({
        'status': 'open',
      });
      clock.set(_midnight.add(const Duration(minutes: 2)));

      expect(
        (await reportPost('p01')).errorOrNull,
        FirestoreError.alreadyExists,
      );
      expect(rules.commits, 1);
    });
  });

  group('T-15 · ReportRepository · hasReported', () {
    Future<bool?> hasReported(String reporterId, ReportTarget target) async =>
        (await repository.hasReported(
          reporterId: reporterId,
          target: target,
        )).dataOrNull;

    test('şikayetten önce false, sonra true; başka kullanıcı ve başka tür '
        'sayılmaz, kulüp okunmaz', () async {
      expect(await hasReported(_reporter, _post), isFalse);

      await repository.report(
        reporterId: _reporter,
        target: _post,
        reason: ReportReason.misinformation,
      );

      expect(await hasReported(_reporter, _post), isTrue);
      expect(
        await hasReported(_reporter, (
          type: ReportTargetType.post,
          id: 'p01',
          clubId: null,
        )),
        isTrue,
      );
      expect(await hasReported('u_mehmet', _post), isFalse);
      expect(
        await hasReported(_reporter, (
          type: ReportTargetType.comment,
          id: 'p01',
          clubId: 'c01',
        )),
        isFalse,
      );
    });

    test('çözülmüş şikayet de sayılır', () async {
      await db.collection('reports').doc('u_ayse_post_p01').set({
        'status': 'resolved',
      });

      expect(await hasReported(_reporter, _post), isTrue);
    });

    test('okuma hatası aynen eşlenir', () async {
      final result = await failing(
        'permission-denied',
      ).hasReported(reporterId: _reporter, target: _post);

      expect(result.errorOrNull, FirestoreError.permissionDenied);
    });
  });

  group('T-15 · ReportRepository · geçersiz kimlik (W-54)', () {
    for (final id in _invalidIds) {
      test('"$id": her metot invalidArgument döner, istisna sızmaz', () async {
        final results = <FirestoreResult<Object?>>[
          await repository.report(
            reporterId: id,
            target: _post,
            reason: ReportReason.spam,
          ),
          await repository.report(
            reporterId: _reporter,
            target: (type: ReportTargetType.post, id: id, clubId: 'c01'),
            reason: ReportReason.spam,
          ),
          await repository.report(
            reporterId: _reporter,
            target: (type: ReportTargetType.post, id: 'p01', clubId: id),
            reason: ReportReason.spam,
          ),
          await repository.hasReported(reporterId: id, target: _post),
          await repository.hasReported(
            reporterId: _reporter,
            target: (type: ReportTargetType.post, id: id, clubId: 'c01'),
          ),
        ];

        expect(
          results.map((result) => result.errorOrNull),
          everyElement(FirestoreError.invalidArgument),
        );
        expect(await ids(), isEmpty);
      });
    }
  });
}
