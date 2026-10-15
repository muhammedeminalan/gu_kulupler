// DLG-12 · Şikayetin alındı — `ReportReceivedMixin`: açılış (katalog kipi,
// kullanıcı adı değişkeni), sonuç eşlemesi ("… kullanıcısını da engelle" →
// `true`) ve gerçek servisle uçtan uca gösterim. Referans: prototip
// dialogs.js:28.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/report_reason_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/mixin/report_received_mixin.dart';
import 'package:gu_kulupler/product/mixin/write_guard_mixin.dart';
import 'package:gu_kulupler/product/service/connectivity_service.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_connectivity_service.dart';
import '../../fakes/fake_feedback_service.dart';
import '../../fakes/fake_report_repository.dart';
import '../../fakes/register_fakes.dart';
import '../../helpers/design_files.dart';
import '../../helpers/test_l10n.dart';
import '../feedback/dialog_test_support.dart';

/// Şikayet gönderen bir ViewModel'in en küçük hali.
final class _Notifier
    with ProjectDependencyMixin, WriteGuardMixin, ReportReceivedMixin {}

const String _user = 'Yiğit Kılıç';

void main() {
  group('DLG-12 · ReportReceivedMixin', () {
    late FakeFeedbackService feedback;

    setUp(() async {
      await GetIt.I.reset();
      registerDefaultFakes();
      addTearDown(GetIt.I.reset);
      feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    });

    test('kullanıcıya bağlı olmayan şikayet (kulüp / etkinlik): değişkensiz '
        'açılır; her sonuçta false', () async {
      for (final result in [true, false, null]) {
        feedback.nextDialogResult = result;
        expect(await _Notifier().showReportReceivedDialog(), isFalse);
      }
      expect(feedback.dialogs, List.filled(3, DialogId.dlg12));
      expect(feedback.dialogParams, everyElement(isEmpty));
      expect(feedback.lastDialogBuilder, isNull);
    });

    test('kullanıcıya bağlı şikayet: ad değişken olarak verilir (baştaki / '
        'sondaki boşluk atılır)', () async {
      await _Notifier().showReportReceivedDialog(blockableUserName: ' $_user ');

      expect(feedback.dialogs, [DialogId.dlg12]);
      expect(feedback.dialogParams.single, {DialogParamKeys.name: _user});
    });

    test('sonuç: "… engelle" (false) → true; "Tamam" (true) ve scrim / geri '
        '(null) → false', () async {
      final notifier = _Notifier();
      Future<bool> ask() =>
          notifier.showReportReceivedDialog(blockableUserName: _user);

      feedback.nextDialogResult = false;
      expect(await ask(), isTrue);
      feedback.nextDialogResult = true;
      expect(await ask(), isFalse);
      expect(await ask(), isFalse);
    });

    test('boş ad kullanıcı yok sayılır: değişken verilmez, sonuç '
        'false', () async {
      feedback.nextDialogResult = false;

      expect(
        await _Notifier().showReportReceivedDialog(blockableUserName: '  '),
        isFalse,
      );
      expect(feedback.dialogParams.single, isEmpty);
    });

    group('sendReport → SHT-10 sonucu (T-45)', () {
      const report = ReportReasonResult(
        target: (type: ReportTargetType.post, id: 'p01', clubId: 'c01'),
        reason: ReportReason.spam,
      );
      late FakeReportRepository reports;

      setUp(
        () => reports = GetIt.I<ReportRepository>() as FakeReportRepository,
      );

      test('yazıldı ve "zaten bildirildi" → sent', () async {
        final notifier = _Notifier();
        expect(
          await notifier.sendReport(reporterId: 'u1', report: report),
          ReportSubmitOutcome.sent,
        );
        expect(
          await notifier.sendReport(reporterId: 'u1', report: report),
          ReportSubmitOutcome.sent,
        );
        expect(reports.reports, hasLength(1));
        expect(feedback.toasts, isEmpty);
      });

      test('günlük şikayet sınırı → dailyLimit; toast yok, yazılmaz', () async {
        reports.todayCounts['u1'] = Limits.reportDailyLimit;

        expect(
          await _Notifier().sendReport(reporterId: 'u1', report: report),
          ReportSubmitOutcome.dailyLimit,
        );
        expect(reports.reports, isEmpty);
        expect(feedback.toasts, isEmpty);
      });

      test(
        'oturum yok / çevrimdışı (TST-24) / yetki (TST-X18) → failed',
        () async {
          final notifier = _Notifier();
          expect(
            await notifier.sendReport(reporterId: null, report: report),
            ReportSubmitOutcome.failed,
          );
          (GetIt.I<ConnectivityService>() as FakeConnectivityService)
                  .isOffline =
              true;
          expect(
            await notifier.sendReport(reporterId: 'u1', report: report),
            ReportSubmitOutcome.failed,
          );
          (GetIt.I<ConnectivityService>() as FakeConnectivityService)
                  .isOffline =
              false;
          reports.failNext(FirestoreError.permissionDenied);
          expect(
            await notifier.sendReport(reporterId: 'u1', report: report),
            ReportSubmitOutcome.failed,
          );
          expect(feedback.toasts, [ToastId.tst24, ToastId.tstX18]);
          expect(reports.reports, isEmpty);
        },
      );
    });

    test('`/// Design: DLG-12` izi mixin bildirimindedir', () {
      expect(
        readText('lib/product/mixin/report_received_mixin.dart'),
        contains(RegExp(r'/// Design: DLG-12\s*\nmixin ReportReceivedMixin\b')),
      );
    });
  });

  group('DLG-12 · uçtan uca (gerçek FeedbackService)', () {
    Future<void> pump(WidgetTester tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      await GetIt.I.unregister<FeedbackService>();
      GetIt.I.registerSingleton<FeedbackService>(harness.service);
    }

    testWidgets('kulüp şikayeti: yalnızca "Tamam"; dokununca kapanır ve '
        'false döner', (tester) async {
      await pump(tester);
      final l10n = tester.l10nFor(const Locale('tr'));

      bool? result;
      unawaited(
        _Notifier().showReportReceivedDialog().then((v) => result = v),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.dlg12Title), findsOneWidget);
      expect(find.text(l10n.dlg12Body), findsOneWidget);
      expect(find.byType(GuButton), findsOneWidget);

      await tester.tap(find.byKey(DialogHarness.keyOf(DialogId.dlg12, 'ok')));
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(find.byType(GuDialogFrame), findsNothing);
    });

    testWidgets('kullanıcı şikayeti: "… kullanıcısını da engelle" → true; '
        '"Tamam" → false', (tester) async {
      await pump(tester);
      final l10n = tester.l10nFor(const Locale('tr'));
      for (final (action, expected) in [('block', true), ('ok', false)]) {
        bool? result;
        unawaited(
          _Notifier()
              .showReportReceivedDialog(blockableUserName: _user)
              .then((v) => result = v),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.dlg12Block(_user)), findsOneWidget);

        await tester.tap(
          find.byKey(DialogHarness.keyOf(DialogId.dlg12, action)),
        );
        await tester.pumpAndSettle();

        expect(result, expected, reason: action);
      }
    });
  });
}
