// SHT-05 · Katılma başvurusu (`JoinApplicationSheet` +
// `JoinApplicationViewModel`): içerik, anahtarlar (`SHT-05.note`, `.legal`,
// `.submit`, `.close`, `.scrim`), not sınırı ve doğrulama, gönderim sonuçları
// (`pop(JoinApplicationOutcome)`; TST-X1, TST-X4, TST-24, sunucu hatası),
// bekleme süresi, kirli kapanış (DLG-25), KVKK bağlantısı (AUT-06 `push`),
// yükleniyor / hata durumları, cihaz matrisi (klavye dahil), açık + koyu
// golden. Referans: design/reference-shots/sheets/SHT-05__light.webp,
// __dark.webp; prototip sheets.js:27–32.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/session/auth_status.dart';
import 'package:gu_kulupler/core/session/session_state.dart';
import 'package:gu_kulupler/core/session/session_view_model.dart';
import 'package:gu_kulupler/features/clubs/provider/join_application_state.dart';
import 'package:gu_kulupler/features/clubs/provider/join_application_view_model.dart';
import 'package:gu_kulupler/features/clubs/view/widget/join_application_sheet.dart';
import 'package:gu_kulupler/product/feedback/catalogs/dialogs/unsaved_changes_dialog.dart';
import 'package:gu_kulupler/product/feedback/catalogs/toasts/toast_catalog.dart';
import 'package:gu_kulupler/product/feedback/dialog_id.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_kulupler/product/form/form_field_error.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../fakes/register_fakes.dart';
import '../../../../fixtures/club_model_fixtures.dart';
import '../../../../fixtures/user_model_fixtures.dart';
import '../../../../helpers/action_inventory.dart';
import '../../../../helpers/design_files.dart';
import '../../../../helpers/device_matrix.dart';
import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/test_l10n.dart';
import 'club_sheet_harness.dart';

const Locale _tr = Locale('tr');
const Locale _en = Locale('en');
const String _clubId = 'c03';
const String _email = 'ayse.demir@ogr.gumushane.edu.tr';
final UserModel _user = UserModelFixtures.ayse;

/// `c03` — Doğa Sporları ve Dağcılık Kulübü: onay gerekli, not zorunlu
/// (referans görüntüdeki kulüp).
final ClubModel _club = ClubModelFixtures.byId(_clubId);

final Key _noteKey = GuKey.action('SHT-05.note');
final Key _legalKey = GuKey.action('SHT-05.legal');
final Key _submitKey = GuKey.action('SHT-05.submit');
Key _key(String action) => GuKey.action('SHT-05.$action');

MembershipModel _membership(MembershipStatus status, {DateTime? retryAfter}) =>
    MembershipModel(
      clubId: _clubId,
      userId: _user.uid,
      applicant: MembershipApplicantModel.fromUser(_user),
      status: status,
      retryAfter: retryAfter,
    );

SessionState _session([MembershipModel? membership]) => SessionState(
  status: AuthStatus.active,
  uid: _user.uid,
  user: _user,
  onboardingSeen: true,
  memberships: {_clubId: ?membership},
);

ClubSheetHarness<JoinApplicationOutcome> _harness({
  MembershipModel? membership,
  List<Override> overrides = const [],
}) => ClubSheetHarness<JoinApplicationOutcome>(
  SheetId.sht05,
  (_) => const JoinApplicationSheet(clubId: _clubId),
  session: _session(membership),
  overrides: overrides,
);

/// Sayfayı [club] kulübü ve (varsa) [membership] kaydıyla açar.
Future<ClubSheetHarness<JoinApplicationOutcome>> _open(
  WidgetTester tester, {
  ClubModel? club,
  MembershipModel? membership,
  Locale locale = _tr,
  ThemeMode theme = ThemeMode.light,
}) async {
  final h = _harness(membership: membership);
  await h.pump(tester, locale: locale, theme: theme);
  h.auth.currentUser = AuthUserInfo(
    uid: _user.uid,
    email: _email,
    emailVerified: true,
  );
  h.clubs.clubs[_clubId] = club ?? _club;
  if (membership != null) h.memberships.put(membership, email: _email);
  await h.open(tester);
  return h;
}

Future<void> _enterNote(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(_noteKey), text);
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.byKey(_submitKey));
  await tester.pumpAndSettle();
}

GuButton _submitButton(WidgetTester tester) =>
    tester.widget<GuButton>(find.byKey(_submitKey));

GuInput _input(WidgetTester tester) =>
    tester.widget<GuInput>(find.byType(GuInput));

String _noteText(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(_noteKey)).controller!.text;

/// Sağlayıcıyı sabit [state] ile ezen kayıt (yerleşim testleri).
List<Override> _fixed(JoinApplicationState state, [SessionState? session]) => [
  sessionViewModelProvider.overrideWithBuild((_, _) => session ?? _session()),
  joinApplicationViewModelProvider(
    _clubId,
  ).overrideWithBuild((_, _) => state),
];

void main() {
  group('SHT-05 · Katılma başvurusu · sözleşme', () {
    test('`/// Design: SHT-05` izi JoinApplicationSheet sınıfındadır', () {
      final source = readText(
        'lib/features/clubs/view/widget/join_application_sheet.dart',
      );
      expect(
        RegExp(r'///\s*Design:\s*SHT-05').allMatches(source),
        hasLength(1),
      );
      expect(
        source,
        contains(
          RegExp(r'/// Design: SHT-05\s*\nclass JoinApplicationSheet\b'),
        ),
      );
    });

    test('yasal metin `LegalRoute(…).push<void>(context)` ile açılır', () {
      final source = readText(
        'lib/features/clubs/view/widget/join_application_sheet.dart',
      );
      expect(
        source,
        contains('const LegalRoute(tip: LegalTab.kvkk).push<void>(context)'),
      );
    });
  });

  group('SHT-05 · Katılma başvurusu · içerik', () {
    testWidgets('çerçeve, kulüp satırı, not alanı (otomatik odak, sayaçlı, '
        '"Zorunlu"), bilgi satırı + KVKK, büyük "Başvuruyu gönder" — TR ve EN, '
        'açık + koyu', (tester) async {
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        for (final locale in [_tr, _en]) {
          await _open(tester, locale: locale, theme: theme);
          final l10n = tester.l10nFor(locale);
          final gu = tester.element(find.byType(GuSheetFrame)).gu;

          final frame = tester.widget<GuSheetFrame>(find.byType(GuSheetFrame));
          expect(frame.title, l10n.sht05Title);
          expect(frame.closeSemanticLabel, l10n.a11yClose);
          expect(frame.menu, isFalse);
          expect(frame.flush, isFalse);
          expect(frame.full, isFalse);
          expect(frame.footer, hasLength(1));

          final emblem = tester.widget<GuEmblem>(find.byType(GuEmblem));
          expect(emblem.size, GuEmblemSize.sm);
          expect(emblem.icon, CoverMapper.icon(_club.iconName));
          expect(emblem.icon, isNotNull);
          final name = tester.widget<Text>(find.text(_club.name));
          expect(name.style!.fontSize, gu.text.titleS.fontSize);
          expect(name.style!.fontWeight, gu.text.titleS.fontWeight);
          final meta = tester.widget<Text>(
            find.text(l10n.sht05ClubMeta(l10n.catK03, l10n.clubTypeApproval)),
          );
          expect(meta.style!.fontSize, gu.text.caption.fontSize);

          final input = _input(tester);
          expect(input.label, l10n.sht05Why);
          expect(input.multiline, isTrue);
          expect(input.maxLength, Limits.applicationNoteMax);
          expect(input.showCounter, isTrue);
          expect(input.autofocus, isTrue);
          expect(input.help, l10n.commonRequired);
          expect(input.errorText, isNull);
          expect(
            tester.widget<TextField>(find.byKey(_noteKey)).focusNode!.hasFocus,
            isTrue,
          );

          final link = tester.widget<GuLinkText>(find.byType(GuLinkText));
          expect(link.spans, hasLength(2));
          expect(link.spans.first.text, '${l10n.sht05Privacy} ');
          expect(link.spans.first.isLink, isFalse);
          expect(link.spans.last.text, l10n.legalKvkkShort);
          expect(link.spans.last.actionKey, _legalKey);
          expect(link.style.fontSize, gu.text.bodyS.fontSize);
          expect(link.style.color, gu.colors.textSecondary);
          final info = tester.widget<GuIcon>(
            find.byWidgetPredicate(
              (widget) => widget is GuIcon && widget.icon == GuIcons.info,
            ),
          );
          expect(info.size, GuSizes.icon18);
          expect(info.color, gu.colors.textMuted);

          final submit = _submitButton(tester);
          expect(submit.label, l10n.sht05Submit);
          expect(submit.variant, GuButtonVariant.primary);
          expect(submit.size, GuButtonSize.lg);
          expect(submit.loading, isFalse);
          expect(submit.disabled, isFalse);

          expect(find.text(l10n.sysErrorTitle), findsNothing);
          expect(find.text(l10n.authErrRequired), findsNothing);
        }
      }
    });

    testWidgets('aksiyon anahtarları: not + KVKK + gönder + kapat + scrim', (
      tester,
    ) async {
      await _open(tester);
      expect(ActionInventory.found(tester), {
        'SHT-05.note',
        'SHT-05.legal',
        'SHT-05.submit',
        'SHT-05.close',
        'SHT-05.scrim',
      });
    });

    testWidgets('not istemeyen kulüpte yardım metni "İsteğe bağlı"; onaysız '
        'kulüpte tür "Anında katılım" — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final l10n = tester.l10nFor(locale);

        await _open(
          tester,
          club: _club.copyWith(requireNote: false),
          locale: locale,
        );
        expect(_input(tester).help, l10n.commonOptional);

        await _open(
          tester,
          club: _club.copyWith(approvalRequired: false),
          locale: locale,
        );
        expect(
          find.text(l10n.sht05ClubMeta(l10n.catK03, l10n.clubTypeInstant)),
          findsOneWidget,
        );
        expect(_input(tester).help, l10n.commonOptional);
      }
    });

    testWidgets('ölçüler: gövde 16 dp içeride, bölümler arası 16; amblem 44, '
        'ad 12 dp sağında; düğme 56 dp; sayfa alta yapışık', (tester) async {
      await _open(tester);
      const left = GuSizes.sheetBodyPaddingX;
      const right = 390 - GuSizes.sheetBodyPaddingX;

      final frame = tester.getRect(find.byType(GuSheetFrame));
      expect(frame.bottom, 844);
      expect(frame.width, 390);

      final emblem = tester.getRect(find.byType(GuEmblem));
      expect(emblem.left, left);
      expect(emblem.size, const Size(GuSizes.emblemSm, GuSizes.emblemSm));
      expect(
        tester.getRect(find.text(_club.name)).left,
        emblem.right + GuSpacing.s12,
      );

      final input = tester.getRect(find.byType(GuInput));
      expect(input.left, left);
      expect(input.right, right);
      expect(input.top - emblem.bottom, GuSpacing.s16);

      final info = tester.getRect(
        find.byWidgetPredicate(
          (widget) => widget is GuIcon && widget.icon == GuIcons.info,
        ),
      );
      expect(info.left, left);
      expect(info.top - input.bottom, GuSpacing.s16);
      final link = tester.getRect(find.byType(GuLinkText));
      expect(link.left, info.right + GuSpacing.s8);
      expect(link.right, right);

      final submit = tester.getRect(find.byKey(_submitKey));
      expect(submit.height, GuSizes.buttonHeightLg);
      expect(submit.left, GuSizes.sheetFootPaddingX);
      expect(submit.right, 390 - GuSizes.sheetFootPaddingX);
      // `.pb16` + `.sheet-body` alt dolgusu 16, ardından alt alan (üst çizgi
      // + 12 dolgu).
      expect(
        submit.top - link.bottom,
        GuSpacing.s16 +
            GuSizes.sheetBodyPaddingBottom +
            GuSizes.sheetFootBorder +
            GuSizes.sheetFootPaddingY,
      );
    });

    testWidgets('not sınırı: fazlası kesilir (yapıştırma), sayaç sınırı '
        'geçmez; yarım emoji bırakılmaz', (tester) async {
      await _open(tester);
      const max = Limits.applicationNoteMax;

      await _enterNote(tester, 'a' * (max + 15));
      expect(_noteText(tester), 'a' * max);
      expect(find.text('$max/$max'), findsOneWidget);

      await _enterNote(tester, '${'a' * (max - 1)}😀b');
      expect(_noteText(tester), 'a' * (max - 1));
    });
  });

  group('SHT-05 · Katılma başvurusu · gönderim', () {
    testWidgets('not zorunlu + boş ya da yalnızca boşluk: "Bu alan zorunlu", '
        'sayfa açık kalır, yazılmaz; yazınca hata silinir — TR ve EN', (
      tester,
    ) async {
      for (final locale in [_tr, _en]) {
        final h = await _open(tester, locale: locale);
        final l10n = tester.l10nFor(locale);

        await _submit(tester);
        expect(h.isClosed, isFalse);
        expect(_input(tester).errorText, l10n.authErrRequired);
        expect(find.text(l10n.authErrRequired), findsOneWidget);
        // Hata varken yardım metni gizlenir.
        expect(find.text(l10n.commonRequired), findsNothing);

        await _enterNote(tester, '   ');
        expect(_input(tester).errorText, isNull);
        await _submit(tester);
        expect(_input(tester).errorText, l10n.authErrRequired);

        await _enterNote(tester, 'x');
        expect(_input(tester).errorText, isNull);
        expect(h.memberships.applied, isEmpty);
        expect(h.feedback.toasts, isEmpty);
      }
    });

    testWidgets('geçerli başvuru: kırpılmış notla yazılır, sayfa `applied` '
        'ile kapanır; toast ve DLG-25 yok', (tester) async {
      final h = await _open(tester);
      await _enterNote(tester, '  Tırmanışa yeni başladım.  ');
      await _submit(tester);

      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.result, JoinApplicationOutcome.applied);
      expect(h.memberships.applied.single, (
        clubId: _clubId,
        userId: _user.uid,
        email: _email,
        note: 'Tırmanışa yeni başladım.',
        status: MembershipStatus.pending,
      ));
      expect(h.feedback.toasts, isEmpty);
      expect(h.feedback.dialogs, isEmpty);
    });

    testWidgets('not istemeyen kulüpte boş notla başvurulur', (tester) async {
      final h = await _open(tester, club: _club.copyWith(requireNote: false));
      await _submit(tester);
      expect(h.result, JoinApplicationOutcome.applied);
      expect(h.memberships.applied.single.note, '');
    });

    testWidgets('onaysız kulüp: anında katılım, sayfa `joined` ile kapanır '
        '(TST-34 çağırandadır)', (tester) async {
      final h = await _open(
        tester,
        club: _club.copyWith(approvalRequired: false),
      );
      await _submit(tester);

      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.result, JoinApplicationOutcome.joined);
      expect(h.memberships.applied.single.status, MembershipStatus.active);
      expect(h.feedback.toasts, isEmpty);
    });

    testWidgets('TST-X1: kulüp başvuru almıyor → sayfa açık kalır', (
      tester,
    ) async {
      final h = await _open(tester);
      h.clubs.clubs[_clubId] = _club.copyWith(applicationsOpen: false);
      await _enterNote(tester, 'Katılmak istiyorum.');
      await _submit(tester);

      expect(h.feedback.toasts, [ToastId.tstX1]);
      expect(h.isClosed, isFalse);
      expect(_submitButton(tester).loading, isFalse);
      expect(_noteText(tester), 'Katılmak istiyorum.');
    });

    testWidgets('TST-24: çevrimdışıyken yazılmaz, sayfa ve not kalır', (
      tester,
    ) async {
      final h = await _open(tester);
      h.connectivity.isOffline = true;
      await _enterNote(tester, 'Katılmak istiyorum.');
      await _submit(tester);

      expect(h.feedback.toasts, [ToastId.tst24]);
      expect(h.isClosed, isFalse);
      expect(h.memberships.applied, isEmpty);
      expect(_noteText(tester), 'Katılmak istiyorum.');
    });

    testWidgets('sunucu hatası: bilgi satırının altında hata satırı; not '
        'değişince silinir — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final h = await _open(tester, locale: locale);
        final l10n = tester.l10nFor(locale);
        await _enterNote(tester, 'Katılmak istiyorum.');
        h.memberships.failNext(FirestoreError.permissionDenied);
        await _submit(tester);

        expect(h.isClosed, isFalse);
        expect(h.feedback.toasts, isEmpty);
        final error = find.text(l10n.sysErrorTitle);
        expect(error, findsOneWidget);
        expect(
          tester.widget<Text>(error).style!.color,
          tester.element(error).gu.colors.stateDanger,
        );
        expect(
          tester.getRect(error).top,
          greaterThan(tester.getRect(find.byType(GuLinkText)).bottom),
        );
        expect(_input(tester).errorText, isNull);

        await _enterNote(tester, 'Katılmak istiyorum!');
        expect(find.text(l10n.sysErrorTitle), findsNothing);
      }
    });

    testWidgets('gönderim sürerken düğme meşgul görünür', (tester) async {
      final h = _harness(
        overrides: [
          joinApplicationViewModelProvider(_clubId).overrideWithBuild(
            (_, _) => JoinApplicationState(
              club: _club,
              note: 'not',
              isSubmitting: true,
            ),
          ),
        ],
      );
      await h.pump(tester);
      await h.open(tester, settle: false);
      expect(_submitButton(tester).loading, isTrue);

      // Gönderim sürerken sayfa kapanmaz (kirli olsa da DLG-25 sorulmaz).
      await tester.tap(find.byKey(_key('close')));
      await tester.pump(GuMotion.sheetEnter);
      expect(find.byType(GuSheetFrame), findsOneWidget);
      expect(h.feedback.dialogs, isEmpty);
    });
  });

  group('SHT-05 · Katılma başvurusu · bekleme süresi', () {
    testWidgets('TST-X4: düğme kalan günü yazar ve devre dışıdır; dokunuş '
        'tarihi bildirir, yazılmaz — TR ve EN', (tester) async {
      final until = kDefaultFakeNowUtc.add(const Duration(days: 3));
      for (final (locale, date) in [
        (_tr, '15 Ekim 2026'),
        (_en, '15 October 2026'),
      ]) {
        final h = await _open(
          tester,
          membership: _membership(MembershipStatus.rejected, retryAfter: until),
          locale: locale,
        );
        final l10n = tester.l10nFor(locale);

        final submit = _submitButton(tester);
        expect(submit.label, l10n.timeInDays(3));
        expect(submit.disabled, isTrue);
        expect(submit.loading, isFalse);

        await _enterNote(tester, 'Yeniden denemek istiyorum.');
        await _submit(tester);
        expect(h.feedback.toasts, [ToastId.tstX4]);
        expect(h.feedback.toastParams.single, ToastParams(date: date));
        expect(date, AppDateFormats(locale, h.clock).date(until));
        expect(h.isClosed, isFalse);
        expect(h.memberships.applied, isEmpty);
      }
    });

    testWidgets('süre dolmuşsa düğme olağan görünür ve başvuru yazılır', (
      tester,
    ) async {
      final h = await _open(
        tester,
        membership: _membership(
          MembershipStatus.rejected,
          retryAfter: kDefaultFakeNowUtc.subtract(const Duration(hours: 1)),
        ),
      );
      expect(_submitButton(tester).disabled, isFalse);
      expect(_submitButton(tester).label, tester.l10nFor(_tr).sht05Submit);

      await _enterNote(tester, 'Yeniden denemek istiyorum.');
      await _submit(tester);
      expect(h.result, JoinApplicationOutcome.applied);
    });
  });

  group('SHT-05 · Katılma başvurusu · kapanış', () {
    testWidgets('not boşken kapat, scrim ve geri doğrudan kapatır (`null`)', (
      tester,
    ) async {
      final h = await _open(tester);
      for (final action in ['close', 'scrim']) {
        await tester.tap(find.byKey(_key(action)), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(GuSheetFrame), findsNothing, reason: action);
        expect(h.result, isNull, reason: action);
        await h.open(tester);
      }
      await h.back(tester);
      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.feedback.dialogs, isEmpty);
    });

    testWidgets('DLG-25: not doluyken kapat / scrim / geri sorar; "Düzenlemeye '
        'devam et" → açık kalır, "Kaydetmeden çık" → `null` ile kapanır', (
      tester,
    ) async {
      final h = await _open(tester);
      await _enterNote(tester, 'yarım not');

      Future<void> close(String action) async {
        if (action == 'back') {
          await h.back(tester);
        } else {
          await tester.tap(find.byKey(_key(action)), warnIfMissed: false);
          await tester.pumpAndSettle();
        }
      }

      for (final (index, action) in ['close', 'scrim', 'back'].indexed) {
        h.feedback.nextDialogResult = UnsavedChangesResult.keep;
        await close(action);
        expect(h.feedback.dialogs, hasLength(index + 1), reason: action);
        expect(h.feedback.dialogs.last, DialogId.dlg25, reason: action);
        expect(find.byType(GuSheetFrame), findsOneWidget, reason: action);
        expect(_noteText(tester), 'yarım not');
      }

      h.feedback.nextDialogResult = UnsavedChangesResult.discard;
      await close('close');
      expect(find.byType(GuSheetFrame), findsNothing);
      expect(h.result, isNull);
      expect(h.memberships.applied, isEmpty);
    });

    testWidgets('KVKK bağlantısı AUT-06 KVKK sekmesini açar (`push`); geri '
        'dönünce sayfa ve not yerindedir', (tester) async {
      final h = await _open(tester);
      await _enterNote(tester, 'yarım not');

      await tester.tap(find.byKey(_legalKey));
      await tester.pumpAndSettle();
      expect(find.byKey(kHarnessLegalKey), findsOneWidget);
      expect(find.text('kvkk'), findsOneWidget);
      expect(h.isClosed, isFalse);
      expect(h.feedback.dialogs, isEmpty);

      h.router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(kHarnessLegalKey), findsNothing);
      expect(find.byType(GuSheetFrame), findsOneWidget);
      expect(_noteText(tester), 'yarım not');
    });
  });

  group('SHT-05 · Katılma başvurusu · durumlar', () {
    testWidgets('yükleniyor: iskelet; form ve gönder düğmesi yok', (
      tester,
    ) async {
      final h = _harness(
        overrides: [
          joinApplicationViewModelProvider(_clubId).overrideWithBuild(
            (_, _) => const JoinApplicationState(isFetching: true),
          ),
        ],
      );
      await h.pump(tester);
      await h.open(tester);

      final skeleton = tester.widget<GuSkeletonList>(
        find.byType(GuSkeletonList),
      );
      expect(skeleton.semanticLabel, tester.l10nFor(_tr).commonLoading);
      expect(find.byType(GuInput), findsNothing);
      expect(find.byType(GuErrorState), findsNothing);
      expect(
        tester.widget<GuSheetFrame>(find.byType(GuSheetFrame)).footer,
        isNull,
      );
      expect(ActionInventory.found(tester), {'SHT-05.close', 'SHT-05.scrim'});
    });

    testWidgets('hata: kulüp okunamadı → hata + "Yeniden dene"; yeniden '
        'deneme formu getirir — TR ve EN', (tester) async {
      for (final locale in [_tr, _en]) {
        final h = _harness();
        await h.pump(tester, locale: locale);
        h.clubs.clubs[_clubId] = _club;
        h.clubs.failNext(FirestoreError.unavailable);
        await h.open(tester);
        final l10n = tester.l10nFor(locale);

        final error = tester.widget<GuErrorState>(find.byType(GuErrorState));
        expect(error.title, l10n.sysErrorTitle);
        expect(error.description, l10n.sysErrorDesc);
        expect(error.retryLabel, l10n.commonRetry);
        expect(error.inline, isTrue);
        expect(find.byType(GuInput), findsNothing);
        expect(find.byType(GuSkeletonList), findsNothing);
        expect(ActionInventory.found(tester), {
          'SHT-05.retry',
          'SHT-05.close',
          'SHT-05.scrim',
        });

        await tester.tap(find.byKey(_key('retry')));
        await tester.pumpAndSettle();
        expect(find.byType(GuErrorState), findsNothing);
        expect(find.byType(GuInput), findsOneWidget);
        expect(find.text(_club.name), findsOneWidget);
      }
    });
  });

  group('SHT-05 · Katılma başvurusu · yerleşim', () {
    final waiting = _membership(
      MembershipStatus.rejected,
      retryAfter: kDefaultFakeNowUtc.add(const Duration(days: 12)),
    );
    for (final (name, overrides) in [
      ('form', _fixed(JoinApplicationState(club: _club))),
      (
        'alan + sunucu hatası',
        _fixed(
          JoinApplicationState(
            club: _club,
            errors: const {JoinApplicationField.note: FormFieldError.required},
            submitError: SubmitError.unknown,
          ),
        ),
      ),
      (
        'bekleme süresi',
        _fixed(
          JoinApplicationState(club: _club, membership: waiting),
          _session(waiting),
        ),
      ),
      ('yükleniyor', _fixed(const JoinApplicationState(isFetching: true))),
      ('hata', _fixed(const JoinApplicationState(isError: true))),
    ]) {
      testWidgets('cihaz matrisi: taşma yok ($name; klavye ve güvenli alan '
          'varyantları)', (tester) async {
        await DeviceMatrix.run(
          tester,
          (context) => const Align(
            alignment: Alignment.bottomCenter,
            child: JoinApplicationSheet(clubId: _clubId),
          ),
          overrides: overrides,
          keyboard: true,
          safeAreas: true,
        );
      });
    }

    testWidgets('golden: açık sayfa, not alanı odakta (scrim dahil) — açık + '
        'koyu (TR)', (tester) async {
      // İmleç yanıp sönmez: golden kararlı kalır.
      EditableText.debugDeterministicCursor = true;
      addTearDown(() => EditableText.debugDeterministicCursor = false);
      for (final theme in kGoldenThemes) {
        final h = await _open(tester, theme: theme);
        await h.expectGolden(tester, 'SHT-05', theme);
      }
    });

    testWidgets('golden: zorunlu not boş gönderildi, alan hatası — '
        'açık + koyu (TR)', (tester) async {
      EditableText.debugDeterministicCursor = true;
      addTearDown(() => EditableText.debugDeterministicCursor = false);
      for (final theme in kGoldenThemes) {
        final h = await _open(tester, theme: theme);
        await _submit(tester);
        await h.expectGolden(tester, 'SHT-05__error', theme);
      }
    });
  });
}
