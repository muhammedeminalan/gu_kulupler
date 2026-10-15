// T-35 · AttendeeRow (widget-catalog P4) — MGT-06 katılımcı satırı: kayıtlı /
// katıldı / gelmedi / iptal rozetleri, Katıldı anahtarı, okutulma saati,
// yöneticinin kendi kaydı (devre dışı + ipucu), danışman salt okunur
// (TST-26), bekleme satırı (sıra pili, avatar 36, "Kayıtlıya al": kontenjan
// dolu → TST-X14), çağıranın verdiği anahtarlar, cihaz matrisi (uzun ad
// 320 × 1.6 dahil) ve galeri golden'ı (açık + koyu). Kaynak: prototip
// `screens-manage.js:134–135`; design/reference-shots/screens/MGT-06__*.webp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/product/widget/member/attendee_row.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../helpers/device_matrix.dart';
import '../../../helpers/golden_helper.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_l10n.dart';

const Locale _tr = Locale('tr');
const String _long = 'Muhammed Burak Yıldırım Arslanoğlu Karadenizli';

RsvpModel _rsvp(String userId, RsvpStatus status) => RsvpModel(
  eventId: 'e17',
  clubId: 'c01',
  userId: userId,
  ticketCode: 'GU-ABCD-EFGH',
  status: status,
);

Key _attendedKey(String userId) => GuKey.action('MGT-06.attended.$userId');
Key _promoteKey(String userId) => GuKey.action('MGT-06.promote.$userId');

/// Çağrıları kaydeden satır.
class _Calls {
  final List<String> log = [];
}

AttendeeRow _row(
  String userId,
  RsvpStatus status, {
  _Calls? calls,
  String name = 'Alp Aksoy',
  String? sub = 'İşletme · 2. sınıf',
  bool? attended,
  bool readOnly = false,
  bool absent = false,
  bool isSelf = false,
  String? scannedAtLabel,
  int? waitlistPosition,
  bool capacityFull = false,
}) => AttendeeRow(
  rsvp: _rsvp(userId, status),
  name: name,
  sub: sub,
  attended: attended ?? status == RsvpStatus.attended,
  onToggle: (value) => calls?.log.add('toggle:$value'),
  actionKey: _attendedKey(userId),
  readOnly: readOnly,
  onDisabledTap: () => calls?.log.add('readOnly'),
  absent: absent,
  isSelf: isSelf,
  scannedAtLabel: scannedAtLabel,
  waitlistPosition: waitlistPosition,
  onPromote: () => calls?.log.add('promote'),
  promoteKey: _promoteKey(userId),
  capacityFull: capacityFull,
  onCapacityFullTap: () => calls?.log.add('full'),
);

Future<void> _pump(WidgetTester tester, Widget row) => tester.pumpApp(
  Scaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [row],
    ),
  ),
);

GuStatusBadge _badge(WidgetTester tester) =>
    tester.widget<GuStatusBadge>(find.byType(GuStatusBadge));

GuSwitch _switch(WidgetTester tester, String userId) =>
    tester.widget<GuSwitch>(find.byKey(_attendedKey(userId)));

/// Galeri: kayıtlı, katıldı (okutulma saati), gelmedi, kendi kaydı, salt
/// okunur, iptal, bekleme (1. sıra), bekleme (kontenjan dolu, uzun ad).
Widget _gallery(BuildContext context) => Scaffold(
  backgroundColor: context.gu.colors.bgCanvas,
  body: SafeArea(
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row('u_arda', RsvpStatus.going, name: 'Arda Polat'),
          _row(
            'u_alp',
            RsvpStatus.attended,
            scannedAtLabel: '19:42',
          ),
          _row('u_berk', RsvpStatus.going, name: 'Berk Demir', absent: true),
          _row('u_elif', RsvpStatus.going, name: 'Elif Şahin', isSelf: true),
          _row(
            'u_long',
            RsvpStatus.attended,
            name: _long,
            sub: 'Radyo, Televizyon ve Sinema · 3. sınıf',
            readOnly: true,
          ),
          _row('u_can', RsvpStatus.cancelled, name: 'Can Yılmaz'),
          _row(
            'u_bora',
            RsvpStatus.waitlist,
            name: 'Bora Yıldırım',
            waitlistPosition: 1,
          ),
          _row(
            'u_long2',
            RsvpStatus.waitlist,
            name: _long,
            waitlistPosition: 12,
            capacityFull: true,
          ),
        ],
      ),
    ),
  ),
);

void main() {
  group('T-35 · AttendeeRow · kayıtlı / katıldı', () {
    testWidgets('kayıtlı: "Kayıtlı" rozeti (going), anahtar kapalı; '
        'dokunuş → toggle:true', (tester) async {
      final calls = _Calls();
      await _pump(tester, _row('u1', RsvpStatus.going, calls: calls));
      final l10n = tester.l10nFor(_tr);
      expect(_badge(tester).kind, GuStatusBadgeKind.going);
      expect(_badge(tester).label, l10n.attendanceRegisteredOne);
      expect(_switch(tester, 'u1').value, isFalse);
      expect(_switch(tester, 'u1').disabled, isFalse);
      expect(find.text('Alp Aksoy'), findsOneWidget);
      expect(find.text('İşletme · 2. sınıf'), findsOneWidget);
      await tester.tap(find.byKey(_attendedKey('u1')));
      expect(calls.log, ['toggle:true']);
    });

    testWidgets('katıldı: "Katıldın" rozeti (attended), anahtar açık, '
        '"Okutuldu: 19:42"; dokunuş → toggle:false', (tester) async {
      final calls = _Calls();
      await _pump(
        tester,
        _row(
          'u1',
          RsvpStatus.attended,
          calls: calls,
          scannedAtLabel: '19:42',
        ),
      );
      final l10n = tester.l10nFor(_tr);
      expect(_badge(tester).kind, GuStatusBadgeKind.attended);
      expect(_badge(tester).label, l10n.statusAttended);
      expect(_switch(tester, 'u1').value, isTrue);
      expect(find.text(l10n.ticketScannedAt('19:42')), findsOneWidget);
      await tester.tap(find.byKey(_attendedKey('u1')));
      expect(calls.log, ['toggle:false']);
    });

    testWidgets('iyimser değer: [attended] rozet ve anahtarı belirler; '
        'okutulma saati yalnızca katılmışta', (tester) async {
      await _pump(
        tester,
        _row('u1', RsvpStatus.going, attended: true, scannedAtLabel: '19:42'),
      );
      expect(_badge(tester).kind, GuStatusBadgeKind.attended);
      expect(_switch(tester, 'u1').value, isTrue);

      await _pump(
        tester,
        _row(
          'u1',
          RsvpStatus.attended,
          attended: false,
          scannedAtLabel: '19:42',
        ),
      );
      final l10n = tester.l10nFor(_tr);
      expect(_badge(tester).kind, GuStatusBadgeKind.going);
      expect(find.text(l10n.ticketScannedAt('19:42')), findsNothing);
    });

    testWidgets('gelmedi: "Gelmedi" rozeti (absent)', (tester) async {
      await _pump(tester, _row('u1', RsvpStatus.going, absent: true));
      final l10n = tester.l10nFor(_tr);
      expect(_badge(tester).kind, GuStatusBadgeKind.absent);
      expect(_badge(tester).label, l10n.attendanceAbsent);
    });

    testWidgets('kendi kaydı: anahtar devre dışı + ipucu; dokunuş geri çağrı '
        'üretmez', (tester) async {
      final calls = _Calls();
      await _pump(
        tester,
        _row('u1', RsvpStatus.going, calls: calls, isSelf: true),
      );
      final l10n = tester.l10nFor(_tr);
      expect(_switch(tester, 'u1').disabled, isTrue);
      expect(find.text(l10n.attendanceSelfHint), findsOneWidget);
      await tester.tap(find.byKey(_attendedKey('u1')));
      expect(calls.log, isEmpty);
    });

    testWidgets('salt okunur (danışman): anahtar devre dışı, dokunuş TST-26 '
        'geri çağrısına', (tester) async {
      final calls = _Calls();
      await _pump(
        tester,
        _row('u1', RsvpStatus.going, calls: calls, readOnly: true),
      );
      expect(_switch(tester, 'u1').disabled, isTrue);
      await tester.tap(find.byKey(_attendedKey('u1')));
      expect(calls.log, ['readOnly']);
    });

    testWidgets('iptal: "İptal" rozeti, anahtar yok', (tester) async {
      await _pump(tester, _row('u1', RsvpStatus.cancelled));
      final l10n = tester.l10nFor(_tr);
      expect(_badge(tester).kind, GuStatusBadgeKind.cancelled);
      expect(_badge(tester).label, l10n.statusCancelled);
      expect(find.byType(GuSwitch), findsNothing);
    });

    testWidgets('Semantics: anahtar "Katıldın" etiketiyle okunur', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _row('u1', RsvpStatus.going));
      final l10n = tester.l10nFor(_tr);
      expect(
        tester.getSemantics(find.byKey(_attendedKey('u1'))),
        matchesSemantics(
          label: l10n.statusAttended,
          hasToggledState: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });
  });

  group('T-35 · AttendeeRow · bekleme listesi', () {
    testWidgets('sıra pili (md, muted), avatar 36, "Kayıtlıya al" (sm tonal) '
        '→ promote', (tester) async {
      final calls = _Calls();
      await _pump(
        tester,
        _row('u1', RsvpStatus.waitlist, calls: calls, waitlistPosition: 3),
      );
      final l10n = tester.l10nFor(_tr);
      final pill = tester.widget<GuCountBadge>(find.byType(GuCountBadge));
      expect(pill.label, '3');
      expect(pill.size, GuCountBadgeSize.md);
      expect(pill.tone, GuCountBadgeTone.muted);
      expect(tester.widget<GuAvatar>(find.byType(GuAvatar)).size, 36);
      final button = tester.widget<GuButton>(find.byKey(_promoteKey('u1')));
      expect(button.label, l10n.attendancePromote);
      expect(button.variant, GuButtonVariant.tonal);
      expect(button.size, GuButtonSize.sm);
      expect(find.byType(GuSwitch), findsNothing);
      expect(find.byType(GuStatusBadge), findsNothing);
      await tester.tap(find.byKey(_promoteKey('u1')));
      expect(calls.log, ['promote']);
    });

    testWidgets('kontenjan dolu → devre dışı, dokunuş TST-X14; salt okunur '
        '→ TST-26', (tester) async {
      final calls = _Calls();
      await _pump(
        tester,
        _row('u1', RsvpStatus.waitlist, calls: calls, capacityFull: true),
      );
      expect(
        tester.widget<GuButton>(find.byKey(_promoteKey('u1'))).disabled,
        isTrue,
      );
      await tester.tap(find.byKey(_promoteKey('u1')));
      await _pump(
        tester,
        _row('u1', RsvpStatus.waitlist, calls: calls, readOnly: true),
      );
      await tester.tap(find.byKey(_promoteKey('u1')));
      expect(calls.log, ['full', 'readOnly']);
    });
  });

  group('T-35 · AttendeeRow · matris + golden', () {
    testWidgets('cihaz matrisi: taşma yok (uzun ad 320 × 1.6 dahil)', (
      tester,
    ) async {
      await DeviceMatrix.run(tester, _gallery);
    });

    testWidgets('golden: galeri — açık + koyu (TR)', (tester) async {
      await goldenForThemes(
        tester,
        'attendee_row',
        const Builder(builder: _gallery),
        size: const Size(390, 760),
      );
    });
  });
}
