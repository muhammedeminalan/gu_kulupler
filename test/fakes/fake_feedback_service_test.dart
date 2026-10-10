// T-07 · FakeFeedbackService sözleşmesi (PLAN §16.3). Kimlikler enum'dan
// seçilir (literal tasarım kimliği yazılmaz — TEST01 kanıtı sayılmasın).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/menu_id.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';

import 'fake_base.dart';
import 'fake_feedback_service.dart';
import 'register_fakes.dart';

const Key _scrimKey = ValueKey<String>('fake.scrim');

Widget _content(BuildContext context) => const SizedBox.shrink();

void main() {
  final sheet = SheetId.values.first;
  final dialog = DialogId.values.first;
  final menu = MenuId.values.first;
  final toast = ToastId.values.first;
  final otherToast = ToastId.values.last;

  group('T-07 · FakeFeedbackService', () {
    test(
      'FeedbackService arayüzünü uygular; registerDefaultFakes kaydeder',
      () {
        addTearDown(GetIt.I.reset);
        registerDefaultFakes();
        expect(GetIt.I<FeedbackService>(), isA<FakeFeedbackService>());
        expect(GetIt.I<FeedbackService>(), isA<FakeBase>());
      },
    );

    test('showSheet: kayıt + tek seferlik nextSheetResult', () async {
      final fake = FakeFeedbackService()..nextSheetResult = 'seçim';
      expect(await fake.showSheet<String>(sheet, builder: _content), 'seçim');
      expect(await fake.showSheet<String>(sheet, builder: _content), isNull);
      expect(fake.sheets, [sheet, sheet]);
      expect(fake.lastSheetBuilder, _content);
      expect(fake.callsTo('showSheet'), hasLength(2));
    });

    test(
      'showDialog: kayıt, değişkenler + tek seferlik nextDialogResult',
      () async {
        final fake = FakeFeedbackService()..nextDialogResult = true;
        const params = <String, Object>{'club': 'Dağcılık'};
        expect(await fake.showDialog<bool>(dialog, params: params), isTrue);
        expect(await fake.showDialog<bool>(dialog, builder: _content), isNull);
        expect(fake.dialogs, [dialog, dialog]);
        expect(fake.dialogParams, [params, const <String, Object>{}]);
        expect(fake.lastDialogBuilder, _content);
        expect(fake.calls.first, FakeCall('showDialog', [dialog, params]));
      },
    );

    test('showToast: kimlik + değişken günlüğü, görünen toast, eylem', () {
      final fake = FakeFeedbackService();
      var undone = 0;
      const params = ToastParams(name: 'Ayşe');
      fake.showToast(toast);
      expect(fake.hasToastAction, isFalse);
      expect(fake.tapToastAction, throwsStateError);
      fake.showToast(otherToast, params: params, onAction: () => undone++);
      expect(fake.toasts, [toast, otherToast]);
      expect(fake.toastParams, [const ToastParams(), params]);
      expect(fake.visibleToast, otherToast);
      expect(fake.hasToastAction, isTrue);
      fake.tapToastAction();
      expect(undone, 1);
      expect(fake.visibleToast, isNull);
      expect(fake.hasToastAction, isFalse);
      expect(fake.calls.last, FakeCall('showToast', [otherToast, params]));
    });

    test('closeToast görünen toastı ve eylemi kaldırır', () {
      final fake = FakeFeedbackService()..showToast(toast, onAction: () {});
      expect(fake.visibleToast, toast);
      fake.closeToast();
      expect(fake.visibleToast, isNull);
      expect(fake.hasToastAction, isFalse);
      expect(fake.toasts, [toast]);
      expect(fake.callsTo('closeToast'), hasLength(1));
    });

    test(
      'showMenu: kayıtlı ve satır içi (id: null) + nextMenuResult',
      () async {
        final fake = FakeFeedbackService()..nextMenuResult = 'paylaş';
        const items = <Widget>[SizedBox.shrink()];
        expect(
          await fake.showMenu<String>(
            id: menu,
            scrimKey: _scrimKey,
            items: items,
          ),
          'paylaş',
        );
        expect(
          await fake.showMenu<String>(scrimKey: _scrimKey, items: const []),
          isNull,
        );
        expect(fake.menus, [menu, null]);
        expect(fake.lastMenuItems, isEmpty);
        expect(fake.calls.first, FakeCall('showMenu', [menu, _scrimKey]));
      },
    );

    test('yanlış türde sonuç TypeError verir', () async {
      final fake = FakeFeedbackService()..nextDialogResult = 'metin';
      await expectLater(
        fake.showDialog<bool>(dialog),
        throwsA(isA<TypeError>()),
      );
    });

    test('resetFake tüm günlükleri ve bekleyen sonuçları siler', () async {
      final fake = FakeFeedbackService()
        ..nextSheetResult = 1
        ..nextDialogResult = true
        ..nextMenuResult = 'x'
        ..showToast(toast, onAction: () {});
      await fake.showMenu<String>(
        id: menu,
        scrimKey: _scrimKey,
        items: const [],
      );
      fake.resetFake();
      expect(fake.calls, isEmpty);
      expect(fake.toasts, isEmpty);
      expect(fake.toastParams, isEmpty);
      expect(fake.menus, isEmpty);
      expect(fake.visibleToast, isNull);
      expect(fake.hasToastAction, isFalse);
      expect(await fake.showSheet<int>(sheet, builder: _content), isNull);
      expect(await fake.showDialog<bool>(dialog), isNull);
      expect(fake.sheets, [sheet]);
      expect(fake.dialogs, [dialog]);
    });
  });
}
