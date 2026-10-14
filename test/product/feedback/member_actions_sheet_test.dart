// T-33 · SHT-21 · Üye işlemleri (`MemberActionsSheet`): hiyerarşi tablosu
// (`actionsFor` / `canOpen` — board yalnız member'ı çıkarır; başkan /
// süper president hariç herkesi; president ve danışman satırında menü yok;
// danışman / üye / üye olmayan aktör hiçbir şey; kendine işlem yok),
// anahtarlar, etkin satır `pop(MemberAction)`, devre dışı satır TST-X18.
// Prototip sheets.js:102–104.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/member_actions_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_service.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/feedback/toast_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fakes/fake_feedback_service.dart';
import '../../helpers/device_matrix.dart';
import 'sheet_test_support.dart';

const MemberAction _profile = MemberAction.viewProfile;
const MemberAction _role = MemberAction.changeRole;
const MemberAction _remove = MemberAction.remove;

MembershipModel _member(ClubRole role) => MembershipModel(
  clubId: 'c03',
  userId: 'u001',
  status: MembershipStatus.active,
  role: role,
  applicant: const MembershipApplicantModel(
    name: 'Yiğit Kılıç',
    avatarSeed: 'u001',
  ),
);

/// `actionsFor` sonucu: eylem → etkin mi (boş = menü yok).
Map<MemberAction, bool> _table(
  ClubRole? actor,
  ClubRole target, {
  bool isSelf = false,
  bool isSuper = false,
}) => {
  for (final o in MemberActionsSheet.actionsFor(
    actorRole: actor,
    targetRole: target,
    isSelf: isSelf,
    isSuperAdmin: isSuper,
  ))
    o.action: o.enabled,
};

FakeFeedbackService _feedback() =>
    GetIt.I<FeedbackService>() as FakeFeedbackService;

void main() {
  group('SHT-21 · hiyerarşi (actionsFor — tek yer)', () {
    test('başkan: member ve board üzerinde rol + çıkar etkin', () {
      for (final target in [ClubRole.member, ClubRole.board]) {
        expect(_table(ClubRole.president, target), {
          _profile: true,
          _role: true,
          _remove: true,
        });
      }
    });

    test('süper admin (rolsüz) başkan gibidir', () {
      expect(_table(null, ClubRole.board, isSuper: true), {
        _profile: true,
        _role: true,
        _remove: true,
      });
    });

    test('board: yalnız member çıkarır; rol değiştiremez', () {
      expect(_table(ClubRole.board, ClubRole.member), {
        _profile: true,
        _role: false,
        _remove: true,
      });
      expect(_table(ClubRole.board, ClubRole.board), {
        _profile: true,
        _role: false,
        _remove: false,
      });
    });

    test('president ve advisor hedefinde menü yok (kimse çıkaramaz)', () {
      for (final target in [ClubRole.president, ClubRole.advisor]) {
        for (final actor in [ClubRole.president, ClubRole.board]) {
          expect(_table(actor, target), isEmpty);
          expect(
            MemberActionsSheet.canOpen(actorRole: actor, targetRole: target),
            isFalse,
          );
        }
        expect(_table(null, target, isSuper: true), isEmpty);
      }
    });

    test('danışman / üye / üye olmayan aktör: hiçbir şey', () {
      for (final actor in [ClubRole.advisor, ClubRole.member, null]) {
        for (final target in ClubRole.values) {
          expect(_table(actor, target), isEmpty);
        }
      }
    });

    test('kendine: yalnız profil etkin', () {
      expect(_table(ClubRole.board, ClubRole.board, isSelf: true), {
        _profile: true,
        _role: false,
        _remove: false,
      });
      expect(_table(null, ClubRole.member, isSelf: true, isSuper: true), {
        _profile: true,
        _role: false,
        _remove: false,
      });
    });
  });

  group('SHT-21 · sayfa', () {
    test('anahtarlar prototipteki aksiyon adlarıdır', () {
      expect(MemberAction.values.map(MemberActionsSheet.keyOf), [
        GuKey.action('SHT-21.profile'),
        GuKey.action('SHT-21.changeRole'),
        GuKey.action('SHT-21.remove'),
      ]);
    });

    testWidgets('etkin satır → pop(MemberAction)', (tester) async {
      final harness = SheetHarness<MemberAction>(
        SheetId.sht21,
        (_) => MemberActionsSheet(
          membership: _member(ClubRole.member),
          actorRole: ClubRole.president,
        ),
      );
      await harness.pump(tester);
      await harness.open(tester);
      await tester.tap(find.byKey(MemberActionsSheet.keyOf(_remove)));
      await tester.pumpAndSettle();
      expect(harness.result, _remove);
    });

    testWidgets('devre dışı satır kapanmaz, TST-X18 gösterir', (tester) async {
      final harness = SheetHarness<MemberAction>(
        SheetId.sht21,
        (_) => MemberActionsSheet(
          membership: _member(ClubRole.board),
          actorRole: ClubRole.board,
        ),
      );
      await harness.pump(tester);
      await harness.open(tester);
      await tester.tap(find.byKey(MemberActionsSheet.keyOf(_remove)));
      await tester.pumpAndSettle();
      expect(harness.isClosed, isFalse);
      expect(_feedback().toasts, [ToastId.tstX18]);
    });

    testWidgets('başlık üyenin adı; üç satır tasarım sırasıyla; board '
        'aktörde devre dışı satırlar nedenini yazar', (tester) async {
      final tr = lookupAppLocalizations(const Locale('tr'));
      final harness = SheetHarness<MemberAction>(
        SheetId.sht21,
        (_) => MemberActionsSheet(
          membership: _member(ClubRole.board),
          actorRole: ClubRole.board,
          userName: 'Yiğit Kılıç',
        ),
      );
      await harness.pump(tester);
      await harness.open(tester);
      expect(find.text('Yiğit Kılıç'), findsOneWidget);
      final tiles = tester.widgetList<GuTile>(find.byType(GuTile)).toList();
      expect(tiles.map((t) => t.title), [
        tr.userprofileView,
        tr.userprofileChangeRole,
        tr.userprofileRemove,
      ]);
      expect(tiles.map((t) => t.disabled), [false, true, true]);
      expect(tiles.map((t) => t.subtitle), [
        null,
        tr.sht21PresidentOnly,
        tr.sht21Hierarchy,
      ]);
      expect(tiles.map((t) => t.danger), [false, false, true]);
    });

    testWidgets('ad yoksa genel başlık; X → null', (tester) async {
      final tr = lookupAppLocalizations(const Locale('tr'));
      final harness = SheetHarness<MemberAction>(
        SheetId.sht21,
        (_) => MemberActionsSheet(
          membership: _member(ClubRole.member),
          actorRole: ClubRole.president,
        ),
      );
      await harness.pump(tester);
      await harness.open(tester);
      expect(find.text(tr.sht21Title), findsOneWidget);
      await tester.tap(find.byKey(GuKey.action('SHT-21.close')));
      await tester.pumpAndSettle();
      expect(harness.result, isNull);
    });

    testWidgets('cihaz matrisi: uzun ad, devre dışı satırlar — taşma yok', (
      tester,
    ) async {
      await DeviceMatrix.run(
        tester,
        (_) => Align(
          alignment: Alignment.bottomCenter,
          child: MemberActionsSheet(
            membership: _member(ClubRole.board),
            actorRole: ClubRole.board,
            userName:
                'Muhammed Abdurrahman Çağlayan Karaosmanoğlu Büyükçekmeceli',
          ),
        ),
        safeAreas: true,
      );
    });

    testWidgets('golden: başkan menüsü (scrim dahil) — açık + koyu (TR)', (
      tester,
    ) async {
      await SheetHarness<MemberAction>(
        SheetId.sht21,
        (_) => MemberActionsSheet(
          membership: _member(ClubRole.member),
          actorRole: ClubRole.president,
          userName: 'Yiğit Kılıç',
        ),
      ).golden(tester, 'SHT-21');
    });
  });
}
