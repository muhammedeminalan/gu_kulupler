// DLG-07 · DLG-08 · DLG-09 — `MembershipDialogsMixin`: üç onayın açılışı
// (katalog kipi, kulüp adı değişkeni), sonuç eşlemesi (yalnızca birincil
// düğme `true`) ve gerçek servisle uçtan uca gösterim. Referans: prototip
// dialogs.js:22, :24, :25.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/core/di/project_dependency_mixin.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/mixin/membership_dialogs_mixin.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_feedback_service.dart';
import '../../fakes/register_fakes.dart';
import '../../helpers/design_files.dart';
import '../../helpers/test_l10n.dart';
import '../feedback/dialog_test_support.dart';

/// Üyelikten çıkan bir ViewModel'in en küçük hali.
final class _Notifier with ProjectDependencyMixin, MembershipDialogsMixin {}

const String _club = 'Doğa Sporları ve Dağcılık Kulübü';

void main() {
  group('DLG-07 / DLG-08 / DLG-09 · MembershipDialogsMixin', () {
    late FakeFeedbackService feedback;

    setUp(() async {
      await GetIt.I.reset();
      registerDefaultFakes();
      addTearDown(GetIt.I.reset);
      feedback = GetIt.I<FeedbackService>() as FakeFeedbackService;
    });

    test('confirmCancelApplication: DLG-07 katalog kipinde, kulüp adıyla '
        'açılır', () async {
      await _Notifier().confirmCancelApplication(clubName: _club);

      expect(feedback.dialogs, [DialogId.dlg07]);
      expect(feedback.dialogParams.single, {DialogParamKeys.club: _club});
      expect(feedback.lastDialogBuilder, isNull);
    });

    test('confirmLeaveClub: DLG-08 katalog kipinde, kulüp adıyla '
        'açılır', () async {
      await _Notifier().confirmLeaveClub(clubName: _club);

      expect(feedback.dialogs, [DialogId.dlg08]);
      expect(feedback.dialogParams.single, {DialogParamKeys.club: _club});
      expect(feedback.lastDialogBuilder, isNull);
    });

    test('showSolePresidentDialog: DLG-09 değişkensiz açılır', () async {
      await _Notifier().showSolePresidentDialog();

      expect(feedback.dialogs, [DialogId.dlg09]);
      expect(feedback.dialogParams.single, isEmpty);
      expect(feedback.lastDialogBuilder, isNull);
    });

    test('sonuç: birincil düğme (true) → true; ikincil (false) ve scrim / '
        'geri (null) → false', () async {
      final notifier = _Notifier();
      final asks = <Future<bool> Function()>[
        () => notifier.confirmCancelApplication(clubName: _club),
        () => notifier.confirmLeaveClub(clubName: _club),
        notifier.showSolePresidentDialog,
      ];
      for (final ask in asks) {
        feedback.nextDialogResult = true;
        expect(await ask(), isTrue);
        feedback.nextDialogResult = false;
        expect(await ask(), isFalse);
        expect(await ask(), isFalse);
      }
    });

    test('mixin yalnızca sorar: repository, toast ve gezinme yok', () async {
      feedback.nextDialogResult = true;
      await _Notifier().confirmLeaveClub(clubName: _club);

      expect(feedback.toasts, isEmpty);
      final source = readText(
        'lib/product/mixin/membership_dialogs_mixin.dart',
      );
      for (final forbidden in const [
        'membershipRepository.',
        'showToast',
        'GoRouter',
      ]) {
        expect(
          source.split('\n').where((line) => !line.trimLeft().startsWith('//')),
          everyElement(isNot(contains(forbidden))),
          reason: forbidden,
        );
      }
    });

    test('her yöntemin üstünde kendi `/// Design:` izi', () {
      final source = readText(
        'lib/product/mixin/membership_dialogs_mixin.dart',
      );
      for (final (id, member) in const [
        ('DLG-07', 'confirmCancelApplication'),
        ('DLG-08', 'confirmLeaveClub'),
        ('DLG-09', 'showSolePresidentDialog'),
      ]) {
        expect(
          source,
          contains(RegExp('/// Design: $id\\s*\\n\\s*Future<bool> $member\\b')),
          reason: id,
        );
      }
    });
  });

  group('DLG-07 / DLG-08 / DLG-09 · uçtan uca (gerçek FeedbackService)', () {
    Future<DialogHarness> pump(WidgetTester tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      // `pumpApp` fake'leri kaydetti: geri bildirimi gerçek servisle değiştir.
      await GetIt.I.unregister<FeedbackService>();
      GetIt.I.registerSingleton<FeedbackService>(harness.service);
      return harness;
    }

    testWidgets('confirmCancelApplication: gövde kulüp adını gösterir; '
        '"İsteği iptal et" → true, "Vazgeç" → false', (tester) async {
      await pump(tester);
      final l10n = tester.l10nFor(const Locale('tr'));
      for (final (action, expected) in [('confirm', true), ('cancel', false)]) {
        bool? result;
        unawaited(
          _Notifier()
              .confirmCancelApplication(clubName: _club)
              .then((value) => result = value),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.dlg07Title), findsOneWidget);
        expect(find.text(l10n.dlg07Body(_club)), findsOneWidget);

        await tester.tap(
          find.byKey(DialogHarness.keyOf(DialogId.dlg07, action)),
        );
        await tester.pumpAndSettle();

        expect(result, expected, reason: action);
        expect(find.byType(GuDialogFrame), findsNothing);
      }
    });

    testWidgets('confirmLeaveClub: gövde kulüp adını gösterir; "Kulüpten '
        'ayrıl" → true, scrim → false', (tester) async {
      await pump(tester);
      final l10n = tester.l10nFor(const Locale('tr'));

      bool? result;
      unawaited(
        _Notifier().confirmLeaveClub(clubName: _club).then((v) => result = v),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.dlg08Body(_club)), findsOneWidget);
      await tester.tap(
        find.byKey(DialogHarness.keyOf(DialogId.dlg08, 'confirm')),
      );
      await tester.pumpAndSettle();
      expect(result, isTrue);

      result = null;
      unawaited(
        _Notifier().confirmLeaveClub(clubName: _club).then((v) => result = v),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('showSolePresidentDialog: "Başkanlığı devret" → true, '
        '"Tamam" → false', (tester) async {
      await pump(tester);
      final l10n = tester.l10nFor(const Locale('tr'));
      for (final (action, expected) in [('transfer', true), ('ok', false)]) {
        bool? result;
        unawaited(
          _Notifier().showSolePresidentDialog().then((v) => result = v),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.dlg09Title), findsOneWidget);
        expect(find.text(l10n.dlg09Body), findsOneWidget);

        await tester.tap(
          find.byKey(DialogHarness.keyOf(DialogId.dlg09, action)),
        );
        await tester.pumpAndSettle();

        expect(result, expected, reason: action);
      }
    });
  });
}
