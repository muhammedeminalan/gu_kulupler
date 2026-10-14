// SET-05 · Yardım ve destek — içerik, 14 envanter aksiyonu ve sonuçları
// (SSS arama + tek açık soru, konu menüsü, SHT-16 ek / kaldır, gönderim →
// TST-23 + başarı kartı + "Yeni talep"), kaydedilmemiş değişiklik uyarısı
// (DLG-25), cihaz matrisi (form + hatalar + klavye, başarı kartı), açık +
// koyu golden. Referans: design/reference-shots/screens/SET-05__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/settings/provider/support_state.dart';
import 'package:gu_kulupler/features/settings/provider/support_view_model.dart';
import 'package:gu_kulupler/features/settings/view/mixin/support_view_mixin.dart';
import 'package:gu_kulupler/features/settings/view/support_view.dart';
import 'package:gu_kulupler/features/settings/view/widget/support_faq_list.dart';
import 'package:gu_kulupler/features/settings/view/widget/support_sent_card.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/unsaved_changes_dialog.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/init/app_preferences_store.dart';
import 'package:gu_kulupler/product/widget/form/form_error_line.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fakes/fake_app_preferences_store.dart';
import '../../../fakes/fake_feedback_service.dart';
import '../../../fakes/fake_image_picker_service.dart';
import '../../../fakes/fake_session_states.dart';
import '../../../fakes/fake_support_repository.dart';
import '../../../helpers/action_inventory.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

final Key _back = GuKey.action('SET-05.back');
final Key _search = GuKey.action('SET-05.search');
final Key _subject = GuKey.action('SET-05.subject');
final Key _message = GuKey.action('SET-05.message');
final Key _attach = GuKey.action('SET-05.attach');
final Key _send = GuKey.action('SET-05.send');

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

FakeSupportRepository _support() =>
    GetIt.I<SupportRepository>() as FakeSupportRepository;

final Override _session = sessionViewModelProvider.overrideWithBuild(
  (ref, notifier) => FakeSessionStates.active,
);

List<Override> _with([SupportState? state]) => [
  _session,
  if (state != null)
    supportViewModelProvider.overrideWithBuild((ref, notifier) => state),
];

Future<void> _pump(
  WidgetTester tester, {
  SupportState? state,
  Locale locale = const Locale('tr'),
}) async {
  await tester.pumpApp(
    const SupportView(),
    locale: locale,
    overrides: _with(state),
  );
  (GetIt.I<AppPreferencesStore>() as FakeAppPreferencesStore)
          .values[AppPreferenceKeys.photoAccessExplained] =
      true;
}

/// `/profile/settings` (yer tutucu) üstünde `…/support`: geri dönüşü sınar.
Future<GoRouter> _pumpRouter(WidgetTester tester) async {
  GoRouter? created;
  await tester.pumpAppRouter(
    overrides: _with(),
    routerOf: (ref) => created ??= GoRouter(
      initialLocation: '/profile/settings/support',
      routes: [
        GoRoute(
          path: '/profile/settings',
          builder: (context, state) => const _Stub(),
          routes: [
            GoRoute(
              path: 'support',
              builder: (context, state) => const SupportView(),
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

String _path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pump();
}

GuButton _button(WidgetTester tester, Key key) =>
    tester.widget<GuButton>(find.byKey(key));

GuPickerField _picker(WidgetTester tester) => tester.widget<GuPickerField>(
  find.ancestor(of: find.byKey(_subject), matching: find.byType(GuPickerField)),
);

/// Hatalı, açık soru ve ekli form (matris).
final SupportState _busy = SupportState(
  expandedFaq: 8,
  subject: SupportSubject.suggestion,
  message: 'a' * Limits.supportMessageMax,
  attachment: kFakeJpeg,
  errors: const {
    SupportField.subject: FormFieldError.required,
    SupportField.message: FormFieldError.required,
    SupportField.attachment: FormFieldError.limitExceeded,
  },
  submitError: SupportError.unknown,
);

class _Stub extends StatelessWidget {
  const _Stub();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('/profile/settings'));
}

void main() {
  group('SET-05 · Yardım ve destek · içerik', () {
    testWidgets('çubuk, SSS arama, 8 soru (kapalı), "Bize ulaş" formu', (
      tester,
    ) async {
      await _pump(tester);
      final l10n = tester.l10n;

      expect(find.text(l10n.supportTitle), findsOneWidget);
      expect(find.text(l10n.supportSearchFaq), findsOneWidget);
      expect(find.text(l10n.supportFaq), findsOneWidget);
      for (final question in [l10n.faqQ1, l10n.faqQ5, l10n.faqQ8]) {
        expect(find.text(question), findsOneWidget);
      }
      for (final index in SupportState.faqIndexes) {
        expect(find.byKey(SupportFaqList.keyOf(index)), findsOneWidget);
      }
      expect(find.text(l10n.faqA1), findsNothing);
      expect(find.text(l10n.supportContact), findsOneWidget);
      expect(_picker(tester).value, isNull);
      expect(_picker(tester).placeholder, l10n.commonSelect);
      expect(find.text(l10n.supportMessage), findsOneWidget);
      expect(_button(tester, _attach).label, l10n.supportAttach);
      expect(_button(tester, _attach).variant, GuButtonVariant.outline);
      expect(find.text(l10n.commonOptional), findsOneWidget);
      expect(_button(tester, _send).full, isTrue);
      expect(find.byType(SupportSentCard), findsNothing);
    });

    testWidgets('hatalar: konu, mesaj, ek ve gönderim satırı', (tester) async {
      await _pump(tester, state: _busy);
      final l10n = tester.l10n;

      expect(_picker(tester).errorText, l10n.authErrRequired);
      expect(find.text(l10n.faqA8), findsOneWidget);
      expect(
        find.widgetWithText(FormErrorLine, l10n.imageTooLarge(5)),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FormErrorLine, l10n.sysErrorTitle),
        findsOneWidget,
      );
      expect(_button(tester, _attach).label, l10n.supportAttached);
      expect(_button(tester, _attach).variant, GuButtonVariant.tonal);
    });
  });

  group('SET-05 · Yardım ve destek · aksiyonlar', () {
    testWidgets('aksiyon envanteri: 14 aksiyon', (tester) async {
      await _pump(tester);
      expectActionInventory(tester, 'SET-05');
    });

    testWidgets('SET-05.faq.<n>: cevap açılır; başka soru öncekini kapatır', (
      tester,
    ) async {
      await _pump(tester);
      final l10n = tester.l10n;

      await _tap(tester, SupportFaqList.keyOf(1));
      expect(find.text(l10n.faqA1), findsOneWidget);
      await _tap(tester, SupportFaqList.keyOf(2));
      expect(find.text(l10n.faqA1), findsNothing);
      expect(find.text(l10n.faqA2), findsOneWidget);
    });

    testWidgets('SET-05.search: soru + cevapta süzer; eşleşme yoksa boş '
        'metin', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;

      await tester.enterText(find.byKey(_search), 'QR');
      await tester.pump();
      expect(find.byKey(SupportFaqList.keyOf(3)), findsOneWidget);
      expect(find.byKey(SupportFaqList.keyOf(1)), findsNothing);

      await tester.enterText(find.byKey(_search), 'zzzz');
      await tester.pump();
      expect(find.text(l10n.supportNoFaq), findsOneWidget);
    });

    testWidgets('SET-05.subject → konu menüsü (5 konu, scrim) → seçim '
        'alanda', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;
      _feedback().nextMenuResult = SupportSubject.club;

      await _tap(tester, _subject);
      await tester.pump();

      expect(_feedback().menus, [null]);
      expect(
        _feedback().lastMenuItems.map((item) => item.key),
        SupportSubject.values.map(SupportViewMixin.subjectKeyOf),
      );
      expect(_picker(tester).value, l10n.supportSubjectClub);
    });

    testWidgets('SET-05.attach → SHT-16 galeri → "eklendi"; yeniden '
        'dokunma "Fotoğrafı kaldır" sunar → kaldırılır', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;
      _feedback().nextSheetResult = PhotoSourceChoice.gallery;

      await _tap(tester, _attach);
      await tester.pump();
      expect(_feedback().sheets, [SheetId.sht16]);
      expect(_button(tester, _attach).label, l10n.supportAttached);

      _feedback().nextSheetResult = PhotoSourceChoice.remove;
      await _tap(tester, _attach);
      await tester.pump();
      final sheet =
          _feedback().lastSheetBuilder!(tester.element(find.byKey(_attach)))
              as PhotoSourceSheet;
      expect(sheet.hasPhoto, isTrue);
      expect(_button(tester, _attach).label, l10n.supportAttach);
    });

    testWidgets('SET-05.send boş formda: hatalar, gönderim yok', (
      tester,
    ) async {
      await _pump(tester);

      await _tap(tester, _send);

      expect(_picker(tester).errorText, tester.l10n.authErrRequired);
      expect(_support().callsTo('createTicket'), isEmpty);
    });

    testWidgets('SET-05.send: TST-23 `#GU-XXXXXX` + başarı kartı → '
        'SET-05.newRequest boş form', (tester) async {
      await _pump(tester);
      final l10n = tester.l10n;
      _feedback().nextMenuResult = SupportSubject.bug;
      await _tap(tester, _subject);
      await tester.enterText(find.byKey(_message), 'Uygulama açılmıyor');
      await tester.pump();

      await _tap(tester, _send);
      await tester.pump();

      expect(_support().tickets.values.single.message, 'Uygulama açılmıyor');
      expect(_feedback().toasts, [ToastId.tst23]);
      expect(_feedback().toastParams.single.no, '#GU-AAAAAB');
      expect(find.byType(SupportSentCard), findsOneWidget);
      expect(find.text(l10n.supportSentDesc('#GU-AAAAAB')), findsOneWidget);
      expect(find.byKey(_send), findsNothing);

      await _tap(tester, SupportSentCard.newRequestKey);
      expect(find.byKey(_send), findsOneWidget);
      expect(find.text('Uygulama açılmıyor'), findsNothing);
      expect(_picker(tester).value, isNull);
    });
  });

  group('SET-05 · Yardım ve destek · kaydedilmemiş değişiklik (DLG-25)', () {
    testWidgets('girdi yokken geri: soru sorulmaz, SET-01 ekranına döner', (
      tester,
    ) async {
      final router = await _pumpRouter(tester);

      await _tap(tester, _back);
      await tester.pumpAndSettle();

      expect(_feedback().dialogs, isEmpty);
      expect(_path(router), '/profile/settings');
    });

    testWidgets('mesaj varken geri: DLG-25 ("Kaydet" yok) → "Kaydetmeden '
        'çık" → ekran kapanır', (tester) async {
      final router = await _pumpRouter(tester);
      await tester.enterText(find.byKey(_message), 'Yarım mesaj');
      await tester.pump();
      _feedback().nextDialogResult = UnsavedChangesResult.discard;

      await _tap(tester, _back);
      await tester.pumpAndSettle();

      expect(_feedback().dialogs, [DialogId.dlg25]);
      final dialog =
          _feedback().lastDialogBuilder!(tester.element(find.byType(_Stub)))
              as UnsavedChangesDialog;
      expect(dialog.hasSave, isFalse);
      expect(_path(router), '/profile/settings');
    });
  });

  group('SET-05 · Yardım ve destek · matris ve golden', () {
    testWidgets('cihaz matrisi (+ klavye): hatalı, açık soru, ekli form '
        'taşmaz', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const SupportView(),
        overrides: _with(_busy),
        keyboard: true,
      );
    });

    testWidgets('cihaz matrisi: başarı kartı taşmaz', (tester) async {
      await DeviceMatrix.run(
        tester,
        (_) => const SupportView(),
        overrides: _with(const SupportState(ticketNo: 'GU-7K3Q9X')),
      );
    });

    testWidgets('varsayılan açık + koyu', (tester) async {
      await goldenForThemes(
        tester,
        'SET-05',
        const SupportView(),
        overrides: _with(),
      );
    });
  });
}
