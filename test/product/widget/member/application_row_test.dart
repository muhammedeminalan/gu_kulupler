// T-32 · ApplicationRow (widget-catalog P3) — MGT-02 başvuru satırı: beklemede
// (ad + "Daha önce başvurdu" rozeti, bölüm · sınıf, not / "Not yok", zaman,
// tonlu onay / ret), seçim kipi, salt okunur (TST-26), silinmiş başvuran
// (W-92), karar verilmiş satırlar (durum rozeti + ret nedeni), çağıranın
// verdiği anahtarlar, cihaz matrisi (uzun ad 320 × 1.6 dahil) ve galeri
// golden'ı (açık + koyu). Kaynak: prototip `cards.js:170–178`,
// `screens-manage.js:57`; design/reference-shots/screens/MGT-02__light__tr.webp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/widget/member/application_row.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../fixtures/membership_model_fixtures.dart';
import '../../../fixtures/user_model_fixtures.dart';
import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

const Locale _tr = Locale('tr');

/// Demo `c03` başvuruları: Cem (önceki başvuru yok), uzun adlı (önceki
/// başvuru 1), reddedilmiş (kontenjan).
final MembershipModel _cem = MembershipModelFixtures.byId('c03_u_cem');
final MembershipModel _long = MembershipModelFixtures.byId('c03_u_long');
final MembershipModel _rejected = MembershipModelFixtures.byId('c03_u082');
final MembershipModel _approved = _cem.copyWith(
  status: MembershipStatus.active,
  decidedAt: DateTime.utc(2026, 10, 8),
);

/// Hesabı silinmiş başvuran: anlık görüntü anonimleştirilmiş (M14).
final MembershipModel _deleted = _cem.copyWith(
  applicant: const MembershipApplicantModel(
    name: Anonymization.deletedUserName,
    avatarSeed: 'deleted',
  ),
);

const String _note = 'Yürüyüş ve kamp deneyimim var; ekipmanım tam.';

Key _key(String action, MembershipModel m) =>
    GuKey.action('MGT-02.$action.${m.userId}');

/// Çağrıları kaydeden satır.
class _Calls {
  final List<String> log = [];
}

ApplicationRow _row(
  MembershipModel m, {
  _Calls? calls,
  String? note = _note,
  bool selecting = false,
  bool selected = false,
  bool readOnly = false,
  UserModel? user,
  String timeLabel = '3 saat önce',
}) => ApplicationRow(
  application: m,
  user: user,
  note: note,
  timeLabel: timeLabel,
  selecting: selecting,
  selected: selected,
  readOnly: readOnly,
  actionKey: _key('row', m),
  approveActionKey: _key('approve', m),
  rejectActionKey: _key('reject', m),
  selectActionKey: _key('select', m),
  onOpen: () => calls?.log.add('open'),
  onApprove: () => calls?.log.add('approve'),
  onReject: () => calls?.log.add('reject'),
  onSelect: (value) => calls?.log.add('select:$value'),
  onReadOnlyTap: () => calls?.log.add('readOnly'),
);

Future<void> _pump(
  WidgetTester tester,
  Widget row, {
  Size size = const Size(390, 844),
  double textScale = 1,
}) => tester.pumpApp(
  Scaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [row],
    ),
  ),
  size: size,
  textScale: textScale,
);

GuIconButton _button(WidgetTester tester, Key key) =>
    tester.widget<GuIconButton>(find.byKey(key));

/// Galeri: beklemede (not, "Not yok" + önceki başvuru), seçim kipi (seçili /
/// değil), salt okunur, silinmiş, onaylanan, reddedilen.
Widget _gallery(BuildContext context) => Scaffold(
  backgroundColor: context.gu.colors.bgCanvas,
  body: SafeArea(
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(_cem),
          _row(_long, note: null, timeLabel: '2 gün önce'),
          _row(_cem, selecting: true, selected: true),
          _row(_long, selecting: true),
          _row(_cem, readOnly: true),
          _row(_deleted),
          _row(_approved, timeLabel: '8 Eki'),
          _row(_rejected, timeLabel: '20 Eyl'),
        ],
      ),
    ),
  ),
);

void main() {
  group('T-32 · ApplicationRow · beklemede', () {
    testWidgets('anlık görüntüden ad, bölüm · sınıf; not tırnaklı italik; '
        'zaman; avatar 44; tonlu onay / ret (K-31 / K-32)', (tester) async {
      await _pump(tester, _row(_cem));
      final l10n = tester.l10nFor(_tr);
      expect(find.text('Cem Aydın'), findsOneWidget);
      expect(find.textContaining('2. sınıf'), findsOneWidget);
      final note = tester.widget<Text>(
        find.text(l10n.appliedNoteQuote(_note)),
      );
      expect(note.style!.fontStyle, FontStyle.italic);
      expect(note.maxLines, 1);
      expect(find.text('3 saat önce'), findsOneWidget);
      final avatar = tester.widget<GuAvatar>(find.byType(GuAvatar));
      expect(avatar.size, GuSizes.applicationRowAvatar);
      expect(avatar.initials, 'CA');
      expect(find.byType(GuBadge), findsNothing);
      expect(find.byType(GuCheckbox), findsNothing);
      expect(
        _button(tester, _key('approve', _cem)).tone,
        GuIconButtonTone.success,
      );
      expect(
        _button(tester, _key('reject', _cem)).tone,
        GuIconButtonTone.danger,
      );
      expect(
        tester.getSize(find.byType(ApplicationRow)).height,
        greaterThanOrEqualTo(GuSizes.applicationRowMinHeight),
      );
    });

    testWidgets('not yok → "Not yok"; önceki başvuru → rozet (history)', (
      tester,
    ) async {
      await _pump(tester, _row(_long, note: '  '));
      final l10n = tester.l10nFor(_tr);
      expect(find.text(l10n.applicationsNoNote), findsOneWidget);
      final badge = tester.widget<GuBadge>(find.byType(GuBadge));
      expect(badge.label, l10n.applicationsPrior);
      expect(badge.icon, GuIcons.history);
    });

    testWidgets('dokunuşlar: satır → aç, onay, ret, uzun basış → seçim', (
      tester,
    ) async {
      final calls = _Calls();
      await _pump(tester, _row(_cem, calls: calls));
      await tester.tap(find.byKey(_key('row', _cem)));
      await tester.tap(find.byKey(_key('approve', _cem)));
      await tester.tap(find.byKey(_key('reject', _cem)));
      await tester.longPress(find.byKey(_key('row', _cem)));
      expect(calls.log, ['open', 'approve', 'reject', 'select:true']);
    });

    testWidgets('seçim kipi: onay kutusu, düğmeler gizli; kutu seçimi '
        'değiştirir', (tester) async {
      final calls = _Calls();
      await _pump(tester, _row(_cem, calls: calls, selecting: true));
      expect(find.byKey(_key('approve', _cem)), findsNothing);
      expect(find.byKey(_key('reject', _cem)), findsNothing);
      final box = tester.widget<GuCheckbox>(find.byKey(_key('select', _cem)));
      expect(box.value, isFalse);
      await tester.tap(find.byKey(_key('select', _cem)));
      await tester.tap(find.byKey(_key('row', _cem)));
      expect(calls.log, ['select:true', 'open']);

      calls.log.clear();
      await _pump(
        tester,
        _row(_cem, calls: calls, selecting: true, selected: true),
      );
      await tester.tap(find.byKey(_key('select', _cem)));
      // Seçiliyken uzun basış seçim geri çağrısı üretmez.
      await tester.longPress(find.byKey(_key('row', _cem)));
      expect(calls.log.first, 'select:false');
      expect(calls.log, isNot(contains('select:true')));
    });

    testWidgets('salt okunur (danışman): düğmeler devre dışı, dokunuş '
        'TST-26 geri çağrısına', (tester) async {
      final calls = _Calls();
      await _pump(tester, _row(_cem, calls: calls, readOnly: true));
      expect(_button(tester, _key('approve', _cem)).disabled, isTrue);
      expect(_button(tester, _key('reject', _cem)).disabled, isTrue);
      await tester.tap(find.byKey(_key('approve', _cem)));
      await tester.tap(find.byKey(_key('reject', _cem)));
      expect(calls.log, ['readOnly', 'readOnly']);
    });

    testWidgets('silinmiş başvuran (W-92): "Silinmiş kullanıcı", avatar ?, '
        'not / alt satır yok, satır ve düğmeler etkisiz', (tester) async {
      final l10n = tester.l10nFor(_tr);
      final calls = _Calls();
      for (final (application, user) in [
        (_deleted, null),
        (
          _cem,
          UserModelFixtures.byId('u_cem').copyWith(isDeleted: true),
        ),
      ]) {
        calls.log.clear();
        await _pump(tester, _row(application, calls: calls, user: user));
        expect(find.text(l10n.commonDeletedUser), findsOneWidget);
        expect(tester.widget<GuAvatar>(find.byType(GuAvatar)).initials, '?');
        expect(find.textContaining(_note), findsNothing);
        expect(find.text(l10n.applicationsNoNote), findsNothing);
        expect(find.textContaining('sınıf'), findsNothing);
        expect(_button(tester, _key('approve', _cem)).disabled, isTrue);
        await tester.tap(find.byKey(_key('row', _cem)));
        await tester.tap(find.byKey(_key('approve', _cem)));
        await tester.longPress(find.byKey(_key('row', _cem)));
        expect(calls.log, isEmpty);
      }
      expect(ApplicationRow.isDeletedApplicant(_cem, null), isFalse);
    });
  });

  group('T-32 · ApplicationRow · karar verilmiş', () {
    testWidgets('onaylanan: UserRow + "Onaylandı" rozeti; alt satırda karar '
        'tarihi; düğme yok', (tester) async {
      final calls = _Calls();
      await _pump(tester, _row(_approved, calls: calls, timeLabel: '8 Eki'));
      final l10n = tester.l10nFor(_tr);
      final badge = tester.widget<GuStatusBadge>(find.byType(GuStatusBadge));
      expect(badge.kind, GuStatusBadgeKind.approved);
      expect(badge.label, l10n.statusApproved);
      expect(
        tester.widget<UserRow>(find.byType(UserRow)).sub,
        endsWith(
          ' · 8 Eki',
        ),
      );
      expect(find.byType(GuIconButton), findsNothing);
      await tester.tap(find.byKey(_key('row', _approved)));
      expect(calls.log, ['open']);
    });

    testWidgets('reddedilen: "Reddedildi" rozeti + ret nedeni', (
      tester,
    ) async {
      await _pump(tester, _row(_rejected, timeLabel: '20 Eyl'));
      final l10n = tester.l10nFor(_tr);
      expect(
        tester.widget<GuStatusBadge>(find.byType(GuStatusBadge)).kind,
        GuStatusBadgeKind.rejected,
      );
      expect(find.text(l10n.rejectReasonQuota), findsOneWidget);
    });
  });

  group('T-32 · ApplicationRow · matris + golden', () {
    testWidgets('cihaz matrisi: taşma yok (uzun ad + rozet 320 × 1.6 dahil)', (
      tester,
    ) async {
      await DeviceMatrix.run(tester, _gallery);
    });

    testWidgets('golden: galeri — açık + koyu (TR)', (tester) async {
      await goldenForThemes(
        tester,
        'application_row',
        const Builder(builder: _gallery),
        size: const Size(390, 900),
      );
    });
  });
}
