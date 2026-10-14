// SHT-32 · Şifre değiştir (`ChangePasswordSheet` + `ChangePasswordViewModel`):
// içerik ve anahtarlar (`SHT-32.current`, `.new`, `.repeat`, `.save`,
// `.close`), güç çubuğu, doğrulama metinleri, şifre değiştirme yeniden
// doğrulama dalları (başarı → TST-44 + `pop(true)`, hatalı mevcut şifre, çok
// fazla deneme), kirli kapanış (DLG-25), cihaz matrisi (klavye dahil), açık +
// koyu golden. Referans: design/reference-shots/sheets/SHT-32__light.webp,
// __dark.webp; prototip sheets.js:149–152.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/settings/view/widget/change_password_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/unsaved_changes_dialog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/widget/form/password_strength_bar.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../fakes/fake_auth_repository.dart';
import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/test_l10n.dart';
import '../../../clubs/view/widget/club_sheet_harness.dart';

const String _current = 'Demo1234!';
const String _next = 'Yeni5678!';
const AuthUserInfo _user = AuthUserInfo(
  uid: 'u_mehmet',
  email: 'mehmet.kaya@ogr.gumushane.edu.tr',
  emailVerified: true,
);

FakeAuthRepository _repo() => GetIt.I<AuthRepository>() as FakeAuthRepository;

Key _k(String action) => GuKey.action('SHT-32.$action');

Future<ClubSheetHarness<bool>> _open(
  WidgetTester tester, {
  ThemeMode theme = ThemeMode.light,
}) async {
  final h = ClubSheetHarness<bool>(
    SheetId.sht32,
    (_) => const ChangePasswordSheet(),
  );
  await h.pump(tester, theme: theme);
  h.auth.currentUser = _user;
  await h.open(tester);
  return h;
}

Future<void> _type(WidgetTester tester, String action, String text) async {
  await tester.enterText(find.byKey(_k(action)), text);
  await tester.pump();
}

Future<void> _fill(WidgetTester tester, {String next = _next}) async {
  await _type(tester, 'current', _current);
  await _type(tester, 'new', next);
  await _type(tester, 'repeat', next);
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byKey(_k('save')));
  await tester.pumpAndSettle();
}

void main() {
  group('SHT-32 · Şifre değiştir · içerik', () {
    testWidgets('başlık, üç gizli alan (etiketler), güç çubuğu, "Kaydet"; '
        'demo şifre satırı yok', (tester) async {
      final h = await _open(tester);
      final l10n = tester.l10n;
      final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
      expect(frame.title, l10n.sht32Title);
      expect(find.byKey(_k('close')), findsOneWidget);
      for (final (action, label) in [
        ('current', l10n.sht32Current),
        ('new', l10n.sht32New),
        ('repeat', l10n.sht32Repeat),
      ]) {
        expect(find.byKey(_k(action)), findsOneWidget);
        expect(find.text(label), findsOneWidget);
      }
      final inputs = tester.widgetList<GuInput>(find.byType(GuInput));
      expect(inputs.every((input) => input.obscure), isTrue);
      expect(inputs.first.autofocus, isTrue);
      expect(
        tester
            .widget<PasswordStrengthBar>(find.byType(PasswordStrengthBar))
            .strength,
        0,
      );
      expect(find.text(l10n.commonSave), findsOneWidget);
      expect(find.textContaining('Demo1234'), findsNothing);
      expect(h.isClosed, isFalse);
    });

    testWidgets('güç çubuğu yeni şifreyle dolar', (tester) async {
      await _open(tester);
      await _type(tester, 'new', 'Abcdefg1');
      expect(
        tester
            .widget<PasswordStrengthBar>(find.byType(PasswordStrengthBar))
            .strength,
        3,
      );
    });
  });

  group('SHT-32 · Şifre değiştir · doğrulama', () {
    testWidgets('boş "Kaydet": mevcut zorunlu, yeni şifre kuralı; istek yok', (
      tester,
    ) async {
      final h = await _open(tester);
      await _save(tester);
      final l10n = tester.l10n;
      expect(find.text(l10n.authErrRequired), findsOneWidget);
      expect(find.text(l10n.authErrPassword), findsOneWidget);
      expect(_repo().callsTo('changePassword'), isEmpty);
      expect(h.isClosed, isFalse);
    });

    testWidgets('tekrar uyuşmuyor', (tester) async {
      await _open(tester);
      await _type(tester, 'current', _current);
      await _type(tester, 'new', _next);
      await _type(tester, 'repeat', 'Yeni5678?');
      await _save(tester);
      expect(find.text(tester.l10n.authErrMismatch), findsOneWidget);
    });
  });

  group('SHT-32 · Şifre değiştir · yeniden doğrulama', () {
    testWidgets('başarı: mevcut şifreyle yeniden doğrulama + güncelleme → '
        'TST-44, sayfa true ile kapanır', (tester) async {
      final h = await _open(tester);
      await _fill(tester);
      await _save(tester);
      expect(h.auth.callsTo('reauthenticate').single.args, [_current]);
      expect(h.auth.callsTo('updatePassword').single.args, [_next]);
      expect(h.feedback.toasts, [ToastId.tst44]);
      expect(h.isClosed, isTrue);
      expect(h.result, isTrue);
    });

    testWidgets('hatalı mevcut şifre: "Şifre hatalı", sayfa açık', (
      tester,
    ) async {
      final h = await _open(tester);
      h.auth.failNext(AuthError.invalidCredentials);
      await _fill(tester);
      await _save(tester);
      expect(find.text(tester.l10n.authErrWrongPassword), findsOneWidget);
      expect(h.auth.callsTo('updatePassword'), isEmpty);
      expect(h.feedback.toasts, isEmpty);
      expect(h.isClosed, isFalse);
    });

    testWidgets('çok fazla deneme: form altı hata satırı', (tester) async {
      final h = await _open(tester);
      h.auth.failNext(AuthError.tooManyRequests);
      await _fill(tester);
      await _save(tester);
      expect(find.text(tester.l10n.dlg02Title), findsOneWidget);
      expect(h.isClosed, isFalse);
    });
  });

  group('SHT-32 · Şifre değiştir · kapanış', () {
    testWidgets('temiz form: kapat doğrudan null ile kapanır', (tester) async {
      final h = await _open(tester);
      await tester.tap(find.byKey(_k('close')));
      await tester.pumpAndSettle();
      expect(h.feedback.dialogs, isEmpty);
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);
    });

    testWidgets('kirli form: DLG-25; "Düzenlemeye devam" açık bırakır, '
        '"Kaydetmeden çık" kapatır', (tester) async {
      final h = await _open(tester);
      await _type(tester, 'current', _current);
      h.feedback.nextDialogResult = UnsavedChangesResult.keep;
      await tester.tap(find.byKey(_k('close')));
      await tester.pumpAndSettle();
      expect(h.feedback.dialogs, [DialogId.dlg25]);
      expect(h.isClosed, isFalse);
      h.feedback.nextDialogResult = UnsavedChangesResult.discard;
      await tester.tap(find.byKey(_k('close')));
      await tester.pumpAndSettle();
      expect(h.isClosed, isTrue);
      expect(h.result, isNull);
    });
  });

  group('SHT-32 · Şifre değiştir · cihaz matrisi ve golden', () {
    testWidgets('cihaz matrisi: taşma yok (klavye ve güvenli alan)', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (context) => const Align(
          alignment: Alignment.bottomCenter,
          child: ChangePasswordSheet(),
        ),
        keyboard: true,
        safeAreas: true,
      );
    });

    testWidgets('golden: açık sayfa (scrim dahil) — açık + koyu (TR)', (
      tester,
    ) async {
      EditableText.debugDeterministicCursor = true;
      addTearDown(() => EditableText.debugDeterministicCursor = false);
      for (final theme in kGoldenThemes) {
        final h = await _open(tester, theme: theme);
        await h.expectGolden(tester, 'SHT-32', theme);
      }
    });
  });
}
