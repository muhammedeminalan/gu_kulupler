// T-33 · DLG-19 Üyeyi çıkar (`RemoveMemberDialog`: neden girdisi, sonuç
// kırpılmış neden / `null`) · DLG-20 Rol değişsin mi? (katalog: ad + eski /
// yeni rol) · DLG-21 Başkanlığı devret? (`TransferPresidencyDialog`: iki adım,
// "DEVRET" tam eşleşme, devre dışı onay → TST-X20). Referans:
// design/reference-shots/dialogs/DLG-{19,20,21}__{light,dark}.webp;
// prototip dialogs.js:35–38.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/dialog_spec.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/dialogs/remove_member_dialog.dart';
import 'package:gu_kulupler/product/feedback/dialogs/transfer_presidency_dialog.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_feedback_service.dart';
import '../../helpers/device_matrix.dart';
import 'dialog_test_support.dart';

const String _name = 'Yiğit Kılıç';
const String _longName =
    'Muhammed Abdurrahman Çağlayan Karaosmanoğlu Büyükçekmeceli';

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

void main() {
  final tr = lookupAppLocalizations(const Locale('tr'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('DLG-20 · Rol değişsin mi? (katalog)', () {
    test('user-cog; gövde ad + eski / yeni rol (TR / EN); Onayla / Vazgeç', () {
      final spec = DialogCatalog.of(DialogId.dlg20)!;
      expect(spec.icon, GuIcons.userCog);
      expect(spec.destructive, isFalse);
      expect(spec.isPrimaryDangerFor(const {}), isFalse);
      expect(spec.title(tr, const {}), tr.dlg20Title);
      const params = {
        DialogParamKeys.name: _name,
        DialogParamKeys.oldRole: ClubRole.member,
        DialogParamKeys.newRole: ClubRole.board,
      };
      expect(
        spec.body!(tr, params),
        tr.dlg20Body(_name, tr.roleMember, tr.roleBoard),
      );
      expect(
        spec.body!(en, params),
        en.dlg20Body(_name, en.roleMember, en.roleBoard),
      );
      // Rol verilmezse "Üye" (`m.role || 'member'`).
      expect(
        spec.body!(tr, const {DialogParamKeys.name: _name}),
        tr.dlg20Body(_name, tr.roleMember, tr.roleMember),
      );
      expect(spec.primaryLabel(tr, const {}), tr.commonConfirm);
      expect(spec.secondaryLabel(tr, const {}), tr.commonGiveUp);
      expect(spec.primaryAction, 'confirm');
      expect(spec.secondaryAction, 'cancel');
    });

    testWidgets('DLG-20 · Onayla → true, Vazgeç → false', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      const params = {
        DialogParamKeys.name: _name,
        DialogParamKeys.oldRole: ClubRole.board,
        DialogParamKeys.newRole: ClubRole.member,
      };
      await harness.open<bool>(
        tester,
        (s) => s.showDialog<bool>(DialogId.dlg20, params: params),
      );
      expect(
        find.text(tr.dlg20Body(_name, tr.roleBoard, tr.roleMember)),
        findsOneWidget,
      );
      await harness.tap(tester, GuKey.action('DLG-20.confirm'));
      expect(harness.result, isTrue);

      await harness.open<bool>(
        tester,
        (s) => s.showDialog<bool>(DialogId.dlg20, params: params),
      );
      await harness.tap(tester, GuKey.action('DLG-20.cancel'));
      expect(harness.result, isFalse);
    });

    testWidgets('DLG-20 · golden (açık + koyu, TR)', (tester) async {
      await DialogHarness().golden<bool>(
        tester,
        'DLG-20',
        (s) => s.showDialog<bool>(
          DialogId.dlg20,
          params: const {
            DialogParamKeys.name: _name,
            DialogParamKeys.oldRole: ClubRole.member,
            DialogParamKeys.newRole: ClubRole.board,
          },
        ),
      );
    });
  });

  group('DLG-19 · Üyeyi çıkar', () {
    testWidgets('çizim: user-x danger, başlık adı taşır, neden girdisi; '
        '"Üyeyi çıkar" danger', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      await harness.open<String>(
        tester,
        (s) => RemoveMemberDialog.show(s, name: _name),
      );
      expect(find.text(tr.dlg19Title(_name)), findsOneWidget);
      expect(find.text(tr.dlg19Body), findsOneWidget);
      expect(find.text(tr.dlg19Reason), findsOneWidget);
      final frame = tester.widget<GuDialogFrame>(find.byType(GuDialogFrame));
      expect(frame.icon, GuIcons.userX);
      expect(frame.danger, isTrue);
      expect(
        tester
            .widget<GuButton>(find.byKey(RemoveMemberDialog.confirmKey))
            .variant,
        GuButtonVariant.danger,
      );
      final input = tester.widget<GuInput>(
        find.ancestor(
          of: find.byKey(RemoveMemberDialog.reasonKey),
          matching: find.byType(GuInput),
        ),
      );
      expect(input.maxLength, Limits.rejectNoteMax);
      expect(input.multiline, isTrue);
    });

    testWidgets('sonuçlar: onay → kırpılmış neden (boş olabilir); Vazgeç / '
        'geri → null', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      Future<String?> open(FeedbackService s) =>
          RemoveMemberDialog.show(s, name: _name);

      await harness.open<String>(tester, open);
      await tester.enterText(
        find.byKey(RemoveMemberDialog.reasonKey),
        '  kurallara aykırı  ',
      );
      await harness.tap(tester, RemoveMemberDialog.confirmKey);
      expect(harness.result, 'kurallara aykırı');

      await harness.open<String>(tester, open);
      await harness.tap(tester, RemoveMemberDialog.confirmKey);
      expect(harness.result, '');

      await harness.open<String>(tester, open);
      await harness.tap(tester, RemoveMemberDialog.cancelKey);
      expect(harness.result, isNull);

      await harness.open<String>(tester, open);
      await harness.back(tester);
      expect(harness.result, isNull);
    });

    testWidgets('cihaz matrisi: uzun ad, klavye açık — taşma yok', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const Center(child: RemoveMemberDialog(name: _longName)),
        keyboard: true,
      );
    });

    testWidgets('DLG-19 · golden (açık + koyu, TR)', (tester) async {
      await DialogHarness().golden<String>(
        tester,
        'DLG-19',
        (s) => RemoveMemberDialog.show(s, name: _name),
      );
    });
  });

  group('DLG-21 · Başkanlığı devret?', () {
    test('"DEVRET" tam eşleşme: kırpılır, Türkçe büyük harf', () {
      final word = tr.dlg21Word;
      expect(word, 'DEVRET');
      expect(en.dlg21Word, word, reason: 'iki dilde aynı sözcük');
      for (final ok in ['DEVRET', 'devret', ' Devret ', 'dEvReT']) {
        expect(TransferPresidencyDialog.matches(ok, word), isTrue, reason: ok);
      }
      for (final bad in ['', 'DEVRE', 'DEVRETT', 'DEV RET', 'devret.']) {
        expect(
          TransferPresidencyDialog.matches(bad, word),
          isFalse,
          reason: bad,
        );
      }
      // Türkçe kural: `i → İ` — "İ" içeren sözcükte noktalı / noktasız ayrımı.
      expect(TransferPresidencyDialog.matches('sil', 'SİL'), isTrue);
      expect(TransferPresidencyDialog.matches('sıl', 'SİL'), isFalse);
    });

    testWidgets('1. adım: crown danger, gövde adı taşır (eski başkan yönetim '
        'kuruluna geçer); Devam → 2. adım', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      await harness.open<bool>(
        tester,
        (s) => TransferPresidencyDialog.show(s, name: _name),
      );
      final frame = tester.widget<GuDialogFrame>(find.byType(GuDialogFrame));
      expect(frame.icon, GuIcons.crown);
      expect(frame.danger, isTrue);
      expect(find.text(tr.dlg21Title), findsOneWidget);
      expect(find.text(tr.dlg21Body1(_name)), findsOneWidget);
      expect(find.byKey(TransferPresidencyDialog.wordKey), findsNothing);
      expect(find.byKey(TransferPresidencyDialog.confirmKey), findsNothing);

      await tester.tap(find.byKey(TransferPresidencyDialog.nextKey));
      await tester.pumpAndSettle();
      expect(harness.isClosed, isFalse);
      expect(find.text(tr.dlg21Body2), findsOneWidget);
      expect(find.byKey(TransferPresidencyDialog.wordKey), findsOneWidget);
      expect(find.byKey(TransferPresidencyDialog.nextKey), findsNothing);
    });

    testWidgets('2. adım: sözcük yokken Devret devre dışı → TST-X20, kapanmaz; '
        '"devret" → etkin → true', (tester) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      await harness.open<bool>(
        tester,
        (s) => TransferPresidencyDialog.show(s, name: _name),
      );
      await tester.tap(find.byKey(TransferPresidencyDialog.nextKey));
      await tester.pumpAndSettle();

      GuButton confirm() => tester.widget<GuButton>(
        find.byKey(TransferPresidencyDialog.confirmKey),
      );
      expect(confirm().disabled, isTrue);
      expect(confirm().variant, GuButtonVariant.danger);
      await tester.tap(find.byKey(TransferPresidencyDialog.confirmKey));
      await tester.pumpAndSettle();
      expect(harness.isClosed, isFalse);
      expect(_feedback().toasts, [ToastId.tstX20]);

      await tester.enterText(
        find.byKey(TransferPresidencyDialog.wordKey),
        'DEVRE',
      );
      await tester.pump();
      expect(confirm().disabled, isTrue);

      await tester.enterText(
        find.byKey(TransferPresidencyDialog.wordKey),
        'devret ',
      );
      await tester.pump();
      expect(confirm().disabled, isFalse);
      await harness.tap(tester, TransferPresidencyDialog.confirmKey);
      expect(harness.result, isTrue);
    });

    testWidgets('Vazgeç → false (her iki adımda); geri → false', (
      tester,
    ) async {
      final harness = DialogHarness();
      await harness.pump(tester);
      Future<bool> open(FeedbackService s) =>
          TransferPresidencyDialog.show(s, name: _name);

      await harness.open<bool>(tester, open);
      await harness.tap(tester, TransferPresidencyDialog.cancelKey);
      expect(harness.result, isFalse);

      await harness.open<bool>(tester, open);
      await tester.tap(find.byKey(TransferPresidencyDialog.nextKey));
      await tester.pumpAndSettle();
      await harness.tap(tester, TransferPresidencyDialog.cancelKey);
      expect(harness.result, isFalse);

      await harness.open<bool>(tester, open);
      await harness.back(tester);
      expect(harness.result, isFalse);
    });

    testWidgets('cihaz matrisi: uzun ad — taşma yok', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const Center(child: TransferPresidencyDialog(name: _longName)),
      );
    });

    testWidgets('DLG-21 · golden (açık + koyu, TR)', (tester) async {
      await DialogHarness().golden<bool>(
        tester,
        'DLG-21',
        (s) => TransferPresidencyDialog.show(s, name: _name),
      );
    });
  });
}
