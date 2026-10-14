// T-34 · SHT-23 · Etkinlik menüsü (`EventMenuSheet.actionsFor`): durum
// makinesinin tek yeri — taslak (düzenle / çoğalt / sil), yayında
// başlamamış (taslağa al: `goingCount > 0` → devre dışı, K-F; iptal),
// sürüyor (taslağa al yok), geçmiş (iptal yok), iptal (düzenleme yok);
// anahtarlar `SHT-23.<action>`. Çizim: başlık etkinlik adı, yıkıcı satırlar
// kırmızı, devre dışı "Taslağa al" nedenini yazar ve kapanmaz; etkin satır
// eylemiyle kapanır; golden. Prototip sheets.js:108–112; referans
// design/reference-shots/sheets/SHT-23__{light,dark}.webp.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/event_menu_sheet.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../fixtures/event_model_fixtures.dart';
import 'sheet_test_support.dart';

const EventMenuAction _edit = EventMenuAction.edit;
const EventMenuAction _duplicate = EventMenuAction.duplicate;
const EventMenuAction _attendees = EventMenuAction.attendees;
const EventMenuAction _scan = EventMenuAction.scan;
const EventMenuAction _share = EventMenuAction.share;
const EventMenuAction _unpublish = EventMenuAction.unpublish;
const EventMenuAction _cancel = EventMenuAction.cancel;
const EventMenuAction _delete = EventMenuAction.delete;

final DateTime _now = DateTime.utc(2026, 10, 15, 12);
final DateTime _start = _now.add(const Duration(days: 2));
final DateTime _end = _start.add(const Duration(hours: 2));

List<EventMenuOption> _options(
  EventStatus status, {
  int goingCount = 0,
  DateTime? startsAt,
  DateTime? endsAt,
}) => EventMenuSheet.actionsFor(
  status: status,
  goingCount: goingCount,
  startsAt: startsAt ?? _start,
  endsAt: endsAt ?? _end,
  now: _now,
);

List<EventMenuAction> _actions(List<EventMenuOption> options) =>
    options.map((option) => option.action).toList();

void main() {
  group('T-34 · SHT-23 · actionsFor', () {
    test('taslak: düzenle · çoğalt · sil (yalnız taslak silinir — DLG-31)', () {
      expect(_options(EventStatus.draft), const [
        EventMenuOption(_edit),
        EventMenuOption(_duplicate),
        EventMenuOption(_delete),
      ]);
    });

    test('yayında, başlamamış, kayıtsız: tüm satırlar etkin; sil yok', () {
      expect(_options(EventStatus.published), const [
        EventMenuOption(_edit),
        EventMenuOption(_duplicate),
        EventMenuOption(_attendees),
        EventMenuOption(_scan),
        EventMenuOption(_share),
        EventMenuOption(_unpublish),
        EventMenuOption(_cancel),
      ]);
    });

    test('K-F: kayıtlı varken "Taslağa al" görünür ama devre dışı', () {
      final options = _options(EventStatus.published, goingCount: 1);
      expect(
        options.firstWhere((option) => option.action == _unpublish),
        const EventMenuOption(_unpublish, enabled: false),
      );
      expect(
        options.where((option) => option.action != _unpublish),
        everyElement(
          isA<EventMenuOption>().having((o) => o.enabled, 'enabled', isTrue),
        ),
      );
    });

    test('sürüyor (başlangıç ≤ şimdi < bitiş): taslağa al yok, iptal var', () {
      final actions = _actions(
        _options(
          EventStatus.published,
          startsAt: _now,
          endsAt: _now.add(const Duration(hours: 1)),
        ),
      );
      expect(actions, isNot(contains(_unpublish)));
      expect(actions, contains(_cancel));
      expect(actions, contains(_edit));
    });

    test('geçmiş (bitiş ≤ şimdi): taslağa al ve iptal yok', () {
      expect(
        _actions(
          _options(
            EventStatus.published,
            startsAt: _now.subtract(const Duration(hours: 3)),
            endsAt: _now,
          ),
        ),
        [_edit, _duplicate, _attendees, _scan, _share],
      );
    });

    test('iptal: düzenleme, yoklama, durum geçişi ve silme yok', () {
      expect(_options(EventStatus.cancelled), const [
        EventMenuOption(_duplicate),
        EventMenuOption(_attendees),
        EventMenuOption(_share),
      ]);
    });

    test('anahtarlar `SHT-23.<action>`; yıkıcı satırlar iptal ve sil', () {
      for (final action in EventMenuAction.values) {
        expect(
          EventMenuSheet.keyOf(action),
          GuKey.action('SHT-23.${action.action}'),
          reason: action.name,
        );
      }
      expect(
        EventMenuAction.values.where((action) => action.isDanger),
        [_cancel, _delete],
      );
    });
  });

  group('T-34 · SHT-23 · çizim', () {
    final tr = lookupAppLocalizations(const Locale('tr'));
    // e03: yayında, başlamamış, 30 kayıtlı (tasarım yakalaması).
    final event = EventModelFixtures.e03;
    final now = event.startsAt.subtract(const Duration(days: 5));

    SheetHarness<EventMenuAction> harness() => SheetHarness<EventMenuAction>(
      SheetId.sht23,
      (_) => EventMenuSheet(event: event, now: now),
    );

    testWidgets('başlık; 7 satır; K-F devre dışı satır nedeni yazar ve '
        'kapanmaz; "Çoğalt" → duplicate', (tester) async {
      final sheet = harness();
      await sheet.pump(tester);
      await sheet.open(tester);
      expect(find.text(event.title), findsOneWidget);
      expect(find.byType(GuTile), findsNWidgets(7));
      expect(find.text(tr.sht23UnpublishBlocked), findsOneWidget);
      final unpublish = tester.widget<GuTile>(
        find.byKey(EventMenuSheet.keyOf(_unpublish)),
      );
      expect(unpublish.disabled, isTrue);
      expect(
        tester.widget<GuTile>(find.byKey(EventMenuSheet.keyOf(_cancel))).danger,
        isTrue,
      );
      await tester.tap(find.byKey(EventMenuSheet.keyOf(_unpublish)));
      await tester.pumpAndSettle();
      expect(sheet.isClosed, isFalse);
      await tester.tap(find.byKey(EventMenuSheet.keyOf(_duplicate)));
      await tester.pumpAndSettle();
      expect(sheet.result, _duplicate);
    });

    testWidgets('golden: yayındaki etkinlik (scrim dahil) — açık + koyu (TR)', (
      tester,
    ) async {
      await harness().golden(tester, 'SHT-23');
    });
  });
}
