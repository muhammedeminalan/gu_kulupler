// SHT-11 · Etkinlik filtresi (`EventFilterSheet`): içerik (bölümler, kulüp
// çipleri — üye olunanlar önce, ilk iki sözcük), taslak üzerinde seçimler,
// "Uygula (n)" sayısı, "Temizle", sonuç (`pop(EventFilterState)`), kapanma
// (`null`), özel aralık (SHT-28 iki kez; bitiş kapatılırsa değişmez), açık +
// koyu golden.
// Referans: design/reference-shots/sheets/SHT-11__light.webp, __dark.webp;
// design/prototype/app/sheets.js:54–61.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/features/events/provider/event_filter_state.dart';
import 'package:gu_kulupler/features/events/view/widget/event_filter_sheet.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../../../helpers/golden_helper.dart';
import '../../../../helpers/test_l10n.dart';
import '../../../clubs/view/widget/club_sheet_harness.dart';
import '../../event_list_test_support.dart';

Key _key(String action) => GuKey.action('SHT-11.$action');

final List<ClubModel> _clubs = [
  for (final club in kAllClubs)
    if (!club.isSuspended) club,
];

/// Taslağın sayısı: süzgecin uyduğu demo etkinlik sayısı.
int _countFor(EventFilterState filter) =>
    filter.types.isEmpty ? 16 : filter.types.length;

ClubSheetHarness<EventFilterState> _harness({
  EventFilterState initial = EventFilterState.none,
}) => ClubSheetHarness<EventFilterState>(
  SheetId.sht11,
  (_) => EventFilterSheet(
    initial: initial,
    clubs: _clubs,
    memberClubIds: const {'c01', 'c03'},
    countFor: _countFor,
  ),
);

Future<void> _tap(WidgetTester tester, String action) async {
  final finder = find.byKey(_key(action));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('içerik: bölümler; kulüp çipleri üye olunanlar önce (ikonlu, '
      'ilk iki sözcük); "Uygula (16)"', (tester) async {
    final h = _harness();
    await h.pump(tester);
    await h.open(tester);
    final l10n = tester.l10nFor(const Locale('tr'));

    expect(
      tester.widget<GuSheetFrame>(find.byType(GuSheetFrame)).title,
      l10n.sht11Title,
    );
    for (final label in [
      l10n.sht11Date,
      l10n.sht11Club,
      l10n.eventFormType,
      l10n.eventFormVisibility,
      l10n.commonSort,
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    final clubChips = [
      for (final club in _clubs)
        tester.widget<GuChip>(find.byKey(_key('club.${club.id}'))),
    ];
    expect(clubChips.first.label, 'Yazılım ve');
    expect(clubChips.first.icon, GuIcons.userCheck);
    final ordered = tester
        .widgetList<GuChip>(find.byType(GuChip))
        .where((chip) => chip.key.toString().contains('SHT-11.club.'))
        .map((chip) => chip.icon != null)
        .toList();
    expect(ordered.take(2), [true, true]);
    expect(ordered.skip(2), everyElement(isFalse));
    expect(
      tester.widget<GuButton>(find.byKey(_key('apply'))).label,
      l10n.sht11Apply(16),
    );
  });

  testWidgets('seçimler taslağa yazılır, sayı güncellenir; "Uygula" sonucu '
      'döndürür; "Temizle" sıfırlar', (tester) async {
    final h = _harness();
    await h.pump(tester);
    await h.open(tester);
    final l10n = tester.l10nFor(const Locale('tr'));

    await _tap(tester, 'date.week');
    await _tap(tester, 'club.c02');
    await _tap(tester, 'type.gezi');
    await _tap(tester, 'type.sosyal');
    await _tap(tester, 'visibility.public');
    await _tap(tester, 'toggle.freeOnly');
    await _tap(tester, 'sort.popular');
    expect(
      tester.widget<GuButton>(find.byKey(_key('apply'))).label,
      l10n.sht11Apply(2),
    );

    await _tap(tester, 'clear');
    expect(
      tester.widget<GuButton>(find.byKey(_key('apply'))).label,
      l10n.sht11Apply(16),
    );
    await _tap(tester, 'type.yarisma');
    await _tap(tester, 'apply');
    expect(h.result, const EventFilterState(types: {EventType.competition}));
  });

  testWidgets('X → null; özel aralık: SHT-28 iki kez, bitiş kapatılırsa '
      'aralık değişmez; seçili aralık özeti', (tester) async {
    final h = _harness();
    await h.pump(tester);
    await h.open(tester);
    h.feedback.nextSheetResult = DateTime(2026, 10, 10);
    await _tap(tester, 'date.custom');
    expect(h.feedback.sheets, [SheetId.sht28, SheetId.sht28]);
    expect(
      tester.widget<GuChip>(find.byKey(_key('date.all'))).selected,
      isTrue,
    );
    await _tap(tester, 'close');
    expect(h.isClosed, isTrue);
    expect(h.result, isNull);

    final custom = _harness(
      initial: EventFilterState.none.withCustomRange(
        from: DateTime(2026, 10, 10),
        to: DateTime(2026, 10, 12),
      ),
    );
    await custom.pump(tester);
    await custom.open(tester);
    expect(
      tester.widget<GuChip>(find.byKey(_key('date.custom'))).selected,
      isTrue,
    );
    expect(find.text('10 Eki → 12 Eki'), findsOneWidget);
  });

  testWidgets('golden: varsayılan açık + koyu', (tester) async {
    for (final theme in kGoldenThemes) {
      final h = _harness();
      await h.pump(tester, theme: theme);
      await h.open(tester);
      await h.expectGolden(tester, 'SHT-11', theme);
    }
  });
}
