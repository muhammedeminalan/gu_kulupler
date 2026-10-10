// T-06 · GuCalendar (widget-catalog #36; A.2 #36; css:313–317;
// ui.js:140–150; Q-08, D-26, K-40, K-57, CD-111).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/pump_app.dart';

const _action = 'EVT-01';
const _weekdays = ['Pz', 'Sa', 'Ça', 'Pe', 'Cu', 'Cm', 'Pa'];
const _months = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

final DateTime _today = DateTime(2026, 10, 8, 20, 5);
final Key _prevKey = GuKey.action('$_action.prevMonth');
final Key _nextKey = GuKey.action('$_action.nextMonth');
final Key _todayKey = GuKey.action('$_action.today');

Key _dayKey(DateTime day) =>
    GuKey.action('$_action.day.${GuCalendar.dayKey(day)}');

Finder _day(int year, int month, int day) =>
    find.byKey(_dayKey(DateTime(year, month, day)));

String _title(DateTime month) => '${_months[month.month - 1]} ${month.year}';

String _dayLabel(DateTime day) =>
    '${day.day} ${_months[day.month - 1]} ${day.year}';

BoxDecoration _decoration(WidgetTester tester, Finder cell) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(of: cell, matching: find.byType(DecoratedBox))
                  .first,
            )
            .decoration
        as BoxDecoration;

Text _number(WidgetTester tester, Finder cell) => tester.widget<Text>(
  find.descendant(of: cell, matching: find.byType(Text)),
);

/// Hücredeki nokta kutuları (ilk `DecoratedBox` hücre zeminidir).
List<BoxDecoration> _dots(WidgetTester tester, Finder cell) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: cell, matching: find.byType(DecoratedBox)),
    )
    .skip(1)
    .map((box) => box.decoration as BoxDecoration)
    .toList();

/// Ay geçişi ve seçim durumunu tutan çağıran.
class _Host extends StatefulWidget {
  const _Host({
    this.width = 320,
    this.min,
    this.max,
    this.compact = false,
    this.withToday = true,
    this.firstDayOfWeek = DateTime.monday,
    this.dots = const {},
    this.initialSelected,
    this.log,
  });

  final double width;
  final DateTime? min;
  final DateTime? max;
  final bool compact;
  final bool withToday;
  final int firstDayOfWeek;
  final Map<int, int> dots;
  final DateTime? initialSelected;
  final List<DateTime>? log;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  DateTime _month = DateTime(2026, 10);
  late DateTime? _selected = widget.initialSelected;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: widget.width,
      child: GuCalendar(
        month: _month,
        today: _today,
        selected: _selected,
        onSelect: (day) {
          widget.log?.add(day);
          setState(() => _selected = day);
        },
        monthTitle: _title(_month),
        weekdayLabels: _weekdays,
        firstDayOfWeek: widget.firstDayOfWeek,
        dotsFor: (day) =>
            day.month == DateTime.october ? widget.dots[day.day] ?? 0 : 0,
        min: widget.min,
        max: widget.max,
        onPrev: () =>
            setState(() => _month = DateTime(_month.year, _month.month - 1)),
        onNext: () =>
            setState(() => _month = DateTime(_month.year, _month.month + 1)),
        onToday: widget.withToday
            ? () => setState(() {
                _month = DateTime(_today.year, _today.month);
                _selected = DateTime(_today.year, _today.month, _today.day);
              })
            : null,
        todayLabel: 'Bugün',
        prevSemanticLabel: 'Önceki ay',
        nextSemanticLabel: 'Sonraki ay',
        daySemanticLabel: _dayLabel,
        compact: widget.compact,
        prevKey: _prevKey,
        nextKey: _nextKey,
        todayKey: _todayKey,
        dayKeyBuilder: _dayKey,
      ),
    ),
  );
}

void main() {
  group('T-06 · GuCalendar', () {
    testWidgets('T-06 · GuCalendar · Pazartesi başlangıç, 42 hücre; bugün '
        'halkası / seçili / diğer ay / devre dışı / noktalar token '
        'değerleriyle açık + koyu; Semantics', (tester) async {
      // Saf tarih hesabı: Ekim 2026'nın 1'i Perşembe.
      final october = GuCalendar.visibleDays(DateTime(2026, 10, 20));
      expect(october, hasLength(GuSizes.calendarWeeks * 7));
      expect(october.first, DateTime(2026, 9, 28));
      expect(october.first.weekday, DateTime.monday);
      expect(october.last, DateTime(2026, 11, 8));
      expect(
        GuCalendar.visibleDays(
          DateTime(2026, 10),
          firstDayOfWeek: DateTime.sunday,
        ).first,
        DateTime(2026, 9, 27),
      );
      // Ay Pazartesi başlarsa önde boş hafta yok; Pazar başlarsa 6 gün.
      expect(
        GuCalendar.visibleDays(DateTime(2026, 6)).first,
        DateTime(2026, 6),
      );
      expect(
        GuCalendar.visibleDays(DateTime(2026, 2)).first,
        DateTime(2026, 1, 26),
      );
      expect(GuCalendar.dayKey(DateTime(2026, 3, 5)), '2026-03-05');

      final handle = tester.ensureSemantics();
      for (final (mode, colors) in [
        (ThemeMode.light, GuColors.light),
        (ThemeMode.dark, GuColors.dark),
      ]) {
        final text = GuTypography.resolve(colors);
        await tester.pumpApp(
          _Host(
            min: DateTime(2026, 9, 30, 18),
            max: DateTime(2026, 11, 1, 12),
            dots: const {9: 1, 13: 2, 14: 5},
            initialSelected: DateTime(2026, 10, 14),
          ),
          theme: mode,
        );
        for (final day in october) {
          expect(find.byKey(_dayKey(day)), findsOneWidget, reason: '$day');
        }
        // (320 − 6 × 2) / 7 = 44: kare hücre, aralık 2, sol üstte 28 Eylül.
        expect(tester.getSize(_day(2026, 10, 9)), const Size(44, 44));
        expect(tester.getTopLeft(_day(2026, 9, 28)).dx, 0);
        expect(
          tester.getTopLeft(_day(2026, 9, 29)).dx -
              tester.getTopRight(_day(2026, 9, 28)).dx,
          GuSizes.calendarGap,
        );
        expect(
          tester.getTopLeft(_day(2026, 10, 5)).dy -
              tester.getBottomLeft(_day(2026, 9, 28)).dy,
          GuSizes.calendarGap,
        );
        expect(tester.getTopRight(_day(2026, 11, 8)).dx, 320);

        // Başlık + hafta günleri (ölçeklenmez, K-57).
        expect(tester.widget<Text>(find.text('Ekim 2026')).style, text.titleS);
        final head = tester.widget<Text>(find.text('Pz'));
        expect(head.style, text.calendarHead);
        expect(head.textScaler, TextScaler.noScaling);
        expect(tester.getCenter(find.text('Pz')).dx, closeTo(320 / 14, 0.01));
        expect(tester.getSize(find.byKey(_prevKey)), const Size.square(40));

        // Varsayılan gün.
        expect(_number(tester, _day(2026, 10, 9)).style, text.calendarDay);
        expect(text.calendarDay.color, colors.textPrimary);
        expect(_decoration(tester, _day(2026, 10, 9)).color, isNull);
        expect(_decoration(tester, _day(2026, 10, 9)).border, isNull);
        expect(
          _decoration(tester, _day(2026, 10, 9)).borderRadius,
          GuRadius.borderSm,
        );
        expect(_dots(tester, _day(2026, 10, 9)), hasLength(1));
        expect(
          _dots(tester, _day(2026, 10, 9)).single.color,
          colors.brandPrimary,
        );
        expect(_dots(tester, _day(2026, 10, 10)), isEmpty);

        // Bugün: 2 px brand.primary iç halka.
        expect(
          _decoration(tester, _day(2026, 10, 8)).border,
          Border.all(
            color: colors.brandPrimary,
            width: GuSizes.calendarTodayRing,
          ),
          reason: '$mode',
        );

        // Seçili: dolu brand.primary, metin + noktalar brand.onPrimary; ≤ 3.
        expect(
          _decoration(tester, _day(2026, 10, 14)).color,
          colors.brandPrimary,
        );
        expect(
          _number(tester, _day(2026, 10, 14)).style!.color,
          colors.brandOnPrimary,
        );
        final selectedDots = _dots(tester, _day(2026, 10, 14));
        expect(selectedDots, hasLength(GuSizes.calendarDotsMax));
        expect(selectedDots.first.color, colors.brandOnPrimary);
        expect(selectedDots.first.shape, BoxShape.circle);

        // Noktalar 4 px, aralık 2.
        final dotBoxes = find.descendant(
          of: _day(2026, 10, 13),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox && widget.width == GuSizes.calendarDot,
          ),
        );
        expect(dotBoxes, findsNWidgets(2));
        expect(tester.getSize(dotBoxes.first), const Size.square(4));
        expect(
          tester.getTopLeft(dotBoxes.last).dx -
              tester.getTopRight(dotBoxes.first).dx,
          GuSizes.calendarDotGap,
        );

        // Diğer ay ve min / max dışı: text.disabled.
        for (final cell in [
          _day(2026, 9, 28),
          _day(2026, 9, 30),
          _day(2026, 11, 2),
        ]) {
          expect(_number(tester, cell).style!.color, colors.textDisabled);
        }

        expect(
          tester.getSemantics(_day(2026, 10, 14)),
          isSemantics(
            label: '14 Ekim 2026',
            isButton: true,
            hasSelectedState: true,
            isSelected: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(_day(2026, 10, 9)),
          isSemantics(
            label: '9 Ekim 2026',
            isButton: true,
            isSelected: false,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        // min saat yok sayılır (30 Eylül açık); max anından sonraki gün kapalı.
        expect(
          tester.getSemantics(_day(2026, 9, 30)),
          isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
        );
        expect(
          tester.getSemantics(_day(2026, 11, 1)),
          isSemantics(isButton: true, isEnabled: true, hasTapAction: true),
        );
        for (final cell in [_day(2026, 9, 29), _day(2026, 11, 2)]) {
          expect(
            tester.getSemantics(cell),
            isSemantics(isButton: true, isEnabled: false, hasTapAction: false),
          );
        }
        expect(
          tester.getSemantics(find.byKey(_prevKey)),
          isSemantics(label: 'Önceki ay', isButton: true, hasTapAction: true),
        );
        expect(
          tester.getSemantics(find.byKey(_nextKey)),
          isSemantics(label: 'Sonraki ay', isButton: true, hasTapAction: true),
        );
      }
      handle.dispose();
    });

    testWidgets('T-06 · GuCalendar · gün seçimi, devre dışı gün çağırmaz, ok '
        'düğmeleriyle ay geçişi (yıl devri), Bugün; Pazar başlangıç; dokunma '
        'hedefi', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <DateTime>[];
      await tester.pumpApp(
        _Host(width: 390, min: DateTime(2026, 10, 5, 15), log: log),
      );
      // (390 − 12) / 7 = 54.
      expect(tester.getSize(_day(2026, 10, 9)), const Size(54, 54));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      await tester.tap(_day(2026, 10, 9));
      await tester.pump();
      expect(log, [DateTime(2026, 10, 9)]);
      expect(
        _decoration(tester, _day(2026, 10, 9)).color,
        GuColors.light.brandPrimary,
      );

      // 4 Ekim min'den önce: çağrı yok; 5 Ekim (min günü) seçilebilir.
      await tester.tap(_day(2026, 10, 4));
      await tester.pump();
      expect(log, hasLength(1));
      await tester.tap(_day(2026, 10, 5));
      await tester.pump();
      expect(log.last, DateTime(2026, 10, 5));

      // Sonraki ay: Kasım 2026'nın 1'i Pazar → ızgara 26 Ekim'de başlar.
      await tester.tap(find.byKey(_nextKey));
      await tester.pump();
      expect(find.text('Kasım 2026'), findsOneWidget);
      expect(find.text('Ekim 2026'), findsNothing);
      expect(tester.getTopLeft(_day(2026, 10, 26)).dx, 0);
      expect(_day(2026, 12, 6), findsOneWidget);
      expect(_day(2026, 9, 28), findsNothing);

      // Yıl devri ve geri dönüş.
      await tester.tap(find.byKey(_nextKey));
      await tester.pump();
      await tester.tap(find.byKey(_nextKey));
      await tester.pump();
      expect(find.text('Ocak 2027'), findsOneWidget);
      expect(tester.getTopLeft(_day(2026, 12, 28)).dx, 0);
      await tester.tap(find.byKey(_prevKey));
      await tester.pump();
      expect(find.text('Aralık 2026'), findsOneWidget);

      // Bugün: ay + seçim bugüne döner.
      expect(tester.widget<GuButton>(find.byKey(_todayKey)).label, 'Bugün');
      await tester.tap(find.byKey(_todayKey));
      await tester.pump();
      expect(find.text('Ekim 2026'), findsOneWidget);
      expect(
        _decoration(tester, _day(2026, 10, 8)).color,
        GuColors.light.brandPrimary,
      );
      expect(log, hasLength(2));

      // Pazar başlangıç + Bugün düğmesi yok.
      await tester.pumpApp(
        const _Host(firstDayOfWeek: DateTime.sunday, withToday: false),
      );
      expect(tester.getTopLeft(_day(2026, 9, 27)).dx, 0);
      expect(_day(2026, 11, 7), findsOneWidget);
      expect(find.byKey(_todayKey), findsNothing);
      handle.dispose();
    });

    testWidgets('T-06 · GuCalendar · 320 × 640, ölçek 1.6: taşma yok; dar '
        'hücre en az 44, compact 36', (tester) async {
      await tester.pumpApp(
        const SingleChildScrollView(
          padding: GuInsets.all16,
          child: Column(
            children: [
              _Host(width: 288, dots: {8: 3, 28: 2}),
              GuGap.v16,
              _Host(width: 256, compact: true, withToday: false),
            ],
          ),
        ),
        size: const Size(320, 640),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
      // (288 − 12) / 7 ≈ 39.4 genişlik → yükseklik min 44.
      final regular = tester.getSize(_day(2026, 10, 8).first);
      expect(regular.width, closeTo(276 / 7, 0.01));
      expect(regular.height, GuSizes.calendarDayMinHeight);
      // (256 − 12) / 7 ≈ 34.9 → compact min 36.
      final compact = tester.getSize(_day(2026, 10, 8).last);
      expect(compact.width, closeTo(244 / 7, 0.01));
      expect(compact.height, GuSizes.calendarDayMinHeightCompact);
      // Gün sayısı ölçeklenir (css:314 `--ts`), hafta başlığı ölçeklenmez.
      expect(_number(tester, _day(2026, 10, 8).first).textScaler, isNull);
      expect(
        tester.widget<Text>(find.text('Pz').first).textScaler,
        TextScaler.noScaling,
      );
    });
  });
}
