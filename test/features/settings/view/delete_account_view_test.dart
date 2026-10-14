// SET-03 · Hesabı sil — içerik (uyarı, silinecekler / kalacaklar, başkanlık
// kartı), 3 envanter aksiyonu (geri, Devam, Devret) + adım aksiyonları
// (neden, şifre, SİL, onay), durumlar (ön denetim sürüyor / okunamadı,
// yanlış şifre, silme sürüyor + ilerleme), TST-X10 / TST-X11, adım geri
// gezintisi ve ekrandan çıkış, cihaz matrisi, açık + koyu golden.
// Referans: design/reference-shots/screens/SET-03__*.webp
// (screens-profile.js:80–92).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/settings/provider/delete_account_state.dart';
import 'package:gu_kulupler/features/settings/provider/delete_account_view_model.dart';
import 'package:gu_kulupler/features/settings/view/delete_account_view.dart';
import 'package:gu_kulupler/features/settings/view/widget/delete_account_steps.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/widget/form/form_error_line.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

final Key _back = GuKey.action('SET-03.back');
final Key _next = GuKey.action('SET-03.next');
final Key _confirm = GuKey.action('SET-03.confirm');
final Key _password = GuKey.action('SET-03.password');
final Key _word = GuKey.action('SET-03.confirmWord');
final Key _reasonText = GuKey.action('SET-03.reasonText');

const String _clubName = 'Doğa Sporları ve Dağcılık Kulübü';

/// Referans görüntünün durumu: c03 başkanı (`u_burak`).
const DeleteAccountState _president = DeleteAccountState(
  isChecking: false,
  presidentOfClubIds: ['c03'],
  clubNames: {'c03': _clubName},
);

const DeleteAccountState _ready = DeleteAccountState(isChecking: false);

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

final Override _session = sessionViewModelProvider.overrideWithBuild(
  (ref, notifier) => FakeSessionStates.active,
);

List<Override> _with([DeleteAccountState? state]) => [
  _session,
  if (state != null)
    deleteAccountViewModelProvider.overrideWithBuild((ref, notifier) => state),
];

Future<void> _pump(
  WidgetTester tester, {
  DeleteAccountState? state = _ready,
  Locale locale = const Locale('tr'),
}) => tester.pumpApp(
  const DeleteAccountView(),
  locale: locale,
  overrides: _with(state),
);

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pump();
}

GuButton _button(WidgetTester tester, Key key) =>
    tester.widget<GuButton>(find.byKey(key));

GuInput _input(WidgetTester tester, Key key) => tester.widget<GuInput>(
  find.ancestor(of: find.byKey(key), matching: find.byType(GuInput)).first,
);

/// `/profile/settings` (yer tutucu) üstünde `…/delete`: çıkışı sınar.
Future<GoRouter> _pumpRouter(WidgetTester tester) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    overrides: _with(_ready),
    routerOf: (ref) => created ??= GoRouter(
      initialLocation: '/profile/settings/delete',
      routes: [
        GoRoute(
          path: '/profile/settings',
          builder: (context, state) => const _Stub(),
          routes: [
            GoRoute(
              path: 'delete',
              builder: (context, state) => const DeleteAccountView(),
            ),
          ],
        ),
      ],
    ),
  );
  final router = created!;
  addTearDown(router.dispose);
  await tester.pumpAndSettle();
  return router;
}

class _Stub extends StatelessWidget {
  const _Stub();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('/profile/settings'));
}

void main() {
  group('SET-03 · Hesabı sil · içerik', () {
    testWidgets('1/3: tehlike bandı, silinecekler (4) + kalacaklar; başkan '
        'değilken kart yok, Devam dangerOutline açık', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;

      expect(find.text(l10n.deleteAccountTitle), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      final banner = tester.widget<GuBanner>(find.byType(GuBanner));
      expect(banner.kind, GuBannerKind.danger);
      expect(banner.card, isTrue);
      expect(banner.text, l10n.deleteAccountWarning);
      expect(find.text(l10n.deleteAccountDeleted.trUpper()), findsOneWidget);
      expect(find.text(l10n.deleteAccountKept.trUpper()), findsOneWidget);
      expect(tester.widget<GuBulletList>(find.byType(GuBulletList)).items, [
        l10n.deleteAccountItemMemberships,
        l10n.deleteAccountItemApplications,
        l10n.deleteAccountItemTickets,
        l10n.deleteAccountItemNotifications,
      ]);
      expect(find.text(l10n.deleteAccountKeptDesc), findsOneWidget);
      expect(find.text(l10n.deleteAccountPresidentBlock), findsNothing);
      expect(_button(tester, _next).variant, GuButtonVariant.dangerOutline);
      expect(_button(tester, _next).disabled, isFalse);
      expect(_button(tester, _next).label, l10n.commonContinue);
    });

    testWidgets('TST-X10 · başkan: uyarı kenarlıklı kart (kulüp adı + '
        'Devret tonal sm); Devam kapalı, dokunma → TST-X10', (tester) async {
      await _pump(tester, state: _president);
      final l10n = tester.l10n;

      expect(find.text(l10n.deleteAccountPresidentBlock), findsOneWidget);
      expect(find.text(_clubName), findsOneWidget);
      final transfer = _button(
        tester,
        DeleteAccountWarningStep.transferKey('c03'),
      );
      expect(transfer.label, l10n.deleteAccountTransfer);
      expect(transfer.variant, GuButtonVariant.tonal);
      expect(transfer.size, GuButtonSize.sm);
      final card = tester.widget<GuCard>(
        find.ancestor(
          of: find.text(_clubName),
          matching: find.byType(GuCard),
        ),
      );
      expect(card.borderColor, GuColors.light.stateWarning);
      expect(_button(tester, _next).disabled, isTrue);

      await _tap(tester, _next);
      expect(_feedback().toasts, [ToastId.tstX10]);
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('durumlar: ön denetim sürerken Devam yükleniyor; okunamazsa '
        'hata satırı', (tester) async {
      await _pump(tester, state: const DeleteAccountState());
      expect(_button(tester, _next).loading, isTrue);

      await _pump(
        tester,
        state: const DeleteAccountState(isChecking: false, isCheckError: true),
      );
      expect(
        find.widgetWithText(FormErrorLine, tester.l10n.sysErrorTitle),
        findsOneWidget,
      );
    });
  });

  group('SET-03 · Hesabı sil · aksiyonlar', () {
    testWidgets('aksiyon envanteri: 3 aksiyon (başkan görünümü)', (
      tester,
    ) async {
      await _pump(tester, state: _president);
      expectActionInventory(tester, 'SET-03');
    });

    testWidgets('SET-03.next → 2/3 neden (5 seçenek, isteğe bağlı, metin '
        'alanı) → 3/3 şifre + SİL; geri 3 → 2 → 1', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;

      await _tap(tester, _next);
      expect(find.text('2/3'), findsOneWidget);
      expect(find.text(l10n.deleteAccountReasonTitle), findsOneWidget);
      expect(find.text(l10n.commonOptional), findsOneWidget);
      for (final reason in DeleteReason.values) {
        expect(
          find.byKey(DeleteAccountReasonStep.reasonKey(reason)),
          findsOneWidget,
        );
      }
      await _tap(
        tester,
        DeleteAccountReasonStep.reasonKey(DeleteReason.graduated),
      );
      expect(
        tester
            .widget<GuOptionRow>(
              find.byKey(
                DeleteAccountReasonStep.reasonKey(DeleteReason.graduated),
              ),
            )
            .selected,
        isTrue,
      );
      expect(_input(tester, _reasonText).maxLength, 300);
      expect(_button(tester, _next).variant, GuButtonVariant.primary);

      await _tap(tester, _next);
      expect(find.text('3/3'), findsOneWidget);
      expect(find.text(l10n.deleteAccountConfirmTitle), findsOneWidget);
      expect(_input(tester, _password).obscure, isTrue);
      expect(_input(tester, _word).placeholder, l10n.set03ConfirmWord);
      expect(_button(tester, _confirm).variant, GuButtonVariant.danger);

      await _tap(tester, _back);
      expect(find.text('2/3'), findsOneWidget);
      await _tap(tester, _back);
      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('TST-X11 · onay: şifre + SİL yokken kapalı (dokunma → '
        'TST-X11); "sil" yazınca açılır, girdiler adım değişince korunur', (
      tester,
    ) async {
      await _pump(tester);
      await _tap(tester, _next);
      await _tap(tester, _next);

      expect(_button(tester, _confirm).disabled, isTrue);
      await _tap(tester, _confirm);
      expect(_feedback().toasts, [ToastId.tstX11]);

      await tester.enterText(find.byKey(_password), 'Demo1234!');
      await tester.enterText(find.byKey(_word), 'SIL');
      await tester.pump();
      expect(_button(tester, _confirm).disabled, isTrue);
      await tester.enterText(find.byKey(_word), 'sil');
      await tester.pump();
      expect(_button(tester, _confirm).disabled, isFalse);

      await _tap(tester, _back);
      await _tap(tester, _next);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).last)
            .controller
            .text,
        'sil',
      );
      expect(_button(tester, _confirm).disabled, isFalse);
    });

    testWidgets('yanlış şifre: alan hatası "Şifre hatalı"; silme sürerken '
        'yükleniyor + ilerleme çubuğu, girdiler kilitli', (tester) async {
      await _pump(
        tester,
        state: const DeleteAccountState(
          isChecking: false,
          step: DeleteStep.confirm,
          password: 'x',
          submitError: DeleteError.wrongPassword,
        ),
      );
      expect(
        _input(tester, _password).errorText,
        tester.l10n.authErrWrongPassword,
      );

      await _pump(
        tester,
        state: const DeleteAccountState(
          isChecking: false,
          step: DeleteStep.confirm,
          password: 'x',
          confirmWord: 'SİL',
          isSubmitting: true,
          progress: DeleteProgress(done: 1, total: 3),
        ),
      );
      expect(_button(tester, _confirm).loading, isTrue);
      expect(_input(tester, _password).disabled, isTrue);
      final progress = tester.widget<GuProgress>(find.byType(GuProgress));
      expect((progress.value, progress.max), (1.0, 3.0));
    });

    testWidgets('SET-03.back 1. adımda ekranı kapatır (SET-01)', (
      tester,
    ) async {
      final router = await _pumpRouter(tester);
      await _tap(tester, _back);
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/profile/settings',
      );
    });

    testWidgets('SET-03.transfer.<id> → bu ekranda SHT-25 (başkanlık devri, '
        'W-34); kapatılınca yazım yok', (tester) async {
      await tester.pumpApp(
        const DeleteAccountView(),
        overrides: [
          sessionViewModelProvider.overrideWithBuild(
            (ref, notifier) => FakeSessionStates.active.copyWith(
              memberships: {
                'c03': const MembershipModel(
                  clubId: 'c03',
                  userId: FakeSessionStates.uid,
                  applicant: MembershipApplicantModel(
                    name: 'Burak',
                    avatarSeed: 'b',
                  ),
                  role: ClubRole.president,
                  status: MembershipStatus.active,
                ),
              },
            ),
          ),
          deleteAccountViewModelProvider.overrideWithBuild(
            (ref, notifier) => _president,
          ),
        ],
      );
      await _tap(tester, DeleteAccountWarningStep.transferKey('c03'));
      await tester.pump();
      expect(find.byType(DeleteAccountView), findsOneWidget);
      expect(_feedback().sheets, [SheetId.sht25]);
      expect(_feedback().toasts, isEmpty);
    });
  });

  group('SET-03 · Hesabı sil · matris ve golden', () {
    testWidgets('cihaz matrisi: 1. adım (başkan kartı) taşmaz', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const DeleteAccountView(),
        overrides: _with(_president),
      );
    });

    testWidgets('cihaz matrisi (+ klavye): 3. adım, hata + ilerleme taşmaz', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => const DeleteAccountView(),
        overrides: _with(
          const DeleteAccountState(
            isChecking: false,
            step: DeleteStep.confirm,
            password: 'x',
            confirmWord: 'SİL',
            submitError: DeleteError.unknown,
          ),
        ),
        keyboard: true,
      );
    });

    testWidgets('cihaz matrisi: 2. adım (neden) taşmaz', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const DeleteAccountView(),
        overrides: _with(
          const DeleteAccountState(
            isChecking: false,
            step: DeleteStep.reason,
            reason: DeleteReason.privacy,
          ),
        ),
      );
    });

    testWidgets('referans durumu (başkan) açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'SET-03',
        const DeleteAccountView(),
        overrides: _with(_president),
      );
    });
  });
}
