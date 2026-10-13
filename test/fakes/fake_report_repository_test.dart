// T-15 · FakeReportRepository sözleşmesi (PLAN §16.3): `reports`; gerçek
// repository'nin sonuçlarını izler.
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';

import 'fake_report_repository.dart';
import 'register_fakes.dart';

const String _me = 'u_ayse';
const ReportTarget _post = (
  type: ReportTargetType.post,
  id: 'p01',
  clubId: 'c01',
);

void main() {
  late FakeReportRepository fake;

  setUp(() => fake = FakeReportRepository());

  group('T-15 · FakeReportRepository', () {
    test('ReportRepository arayüzünü uygular; registerDefaultFakes '
        'kaydeder', () {
      addTearDown(GetIt.I.reset);
      registerDefaultFakes();
      expect(GetIt.I<ReportRepository>(), isA<FakeReportRepository>());
    });

    test('report: açık şikayeti belge kimliğiyle `reports`e yazar; '
        'hasReported bunu görür', () async {
      expect(
        (await fake.hasReported(reporterId: _me, target: _post)).dataOrNull,
        isFalse,
      );

      final result = await fake.report(
        reporterId: _me,
        target: _post,
        reason: ReportReason.spam,
        note: 'Reklam.',
      );

      expect(result.isSuccess, isTrue);
      final report = fake.reports['${_me}_post_p01']!;
      expect(report.status, ReportStatus.open);
      expect(report.reason, ReportReason.spam);
      expect(report.targetClubId, 'c01');
      expect(report.note, 'Reklam.');
      expect(
        (await fake.hasReported(reporterId: _me, target: _post)).dataOrNull,
        isTrue,
      );
    });

    test('aynı hedefin ikinci şikayeti alreadyExists; ilk şikayet '
        'değişmez', () async {
      await fake.report(
        reporterId: _me,
        target: _post,
        reason: ReportReason.spam,
      );

      final again = await fake.report(
        reporterId: _me,
        target: _post,
        reason: ReportReason.other,
      );

      expect(again.errorOrNull, FirestoreError.alreadyExists);
      expect(fake.reports.values.single.reason, ReportReason.spam);
    });

    test('kendini şikayet, kulüpsüz gönderi, hedefle uyuşmayan kulüp, uzun '
        'not ve geçersiz kimlik invalidArgument', () async {
      final invalid = <ReportTarget>[
        (type: ReportTargetType.user, id: _me, clubId: null),
        (type: ReportTargetType.user, id: 'u2', clubId: 'c01'),
        (type: ReportTargetType.post, id: 'p01', clubId: null),
        (type: ReportTargetType.club, id: 'c01', clubId: 'c02'),
        (type: ReportTargetType.event, id: 'e/1', clubId: 'c01'),
      ];
      for (final target in invalid) {
        final result = await fake.report(
          reporterId: _me,
          target: target,
          reason: ReportReason.spam,
        );
        expect(
          result.errorOrNull,
          FirestoreError.invalidArgument,
          reason: '$target',
        );
      }
      final longNote = await fake.report(
        reporterId: _me,
        target: _post,
        reason: ReportReason.other,
        note: 'a' * (Limits.reportNoteMax + 1),
      );
      expect(longNote.errorOrNull, FirestoreError.invalidArgument);
      expect(fake.reports, isEmpty);
    });

    test('failNext sıradaki çağrıyı düşürür (tek seferlik)', () async {
      fake.failNext(FirestoreError.permissionDenied);
      final denied = await fake.report(
        reporterId: _me,
        target: _post,
        reason: ReportReason.spam,
      );
      expect(denied.errorOrNull, FirestoreError.permissionDenied);
      expect(fake.reports, isEmpty);
      expect(
        (await fake.hasReported(reporterId: _me, target: _post)).isSuccess,
        isTrue,
      );
    });
  });
}
