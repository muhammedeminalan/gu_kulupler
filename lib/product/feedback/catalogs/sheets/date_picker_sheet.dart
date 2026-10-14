import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/widget/calendar/app_calendar.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-28 "Tarih seç" — `GuCalendar` (`compact`) + "İptal" / "Tamam"
/// (prototip `SHEETS['SHT-28']`, `sheets.js:134–135`). EVT-01 SHT-11 özel
/// aralığı (başlangıç, sonra `sht.11.to` başlıklı bitiş) ve MGT-05 etkinlik
/// formu açar.
///
/// * Tarihler **takvim günüdür** (yalnızca yıl / ay / gün; Istanbul duvar
///   saati — D-26); hafta TR'de Pazartesi, EN'de Pazar başlar
///   (`AppCalendar`). Dönen değer yerel gece yarısıdır (`DateTime(y, m, d)`).
/// * Seçim taslaktır; "Tamam" sayfayı seçili günle kapatır
///   (`pop(DateTime)`), "İptal" / X / scrim / sürükleme / geri → `null`.
/// * [firstDate] / [lastDate] (ikisi de dahil) dışındaki günler devre
///   dışıdır (`min` / `max`). Sınır dışı [initial] en yakın sınıra çekilir;
///   "Bugün" bugünün ayına gider, bugün sınır içindeyse onu seçer — "Tamam"
///   hiçbir zaman devre dışı bir gün döndürmez.
/// * Başlık [title] verilmezse `sht.28.title` ("Tarih seç").
/// * Anahtarlar `SHT-28.cancel`, `SHT-28.ok`, `SHT-28.prevMonth`,
///   `SHT-28.nextMonth`, `SHT-28.today`, `SHT-28.day.<yyyy-mm-dd>`,
///   `SHT-28.close` (+ `SHT-28.scrim`, `FeedbackService`).
///
/// ```dart
/// final day = await feedback.showSheet<DateTime>(
///   SheetId.sht28,
///   builder: (_) => DatePickerSheet(initial: from, firstDate: today),
/// );
/// ```
///
/// Design: SHT-28
class DatePickerSheet extends ConsumerStatefulWidget {
  /// [initial] günü seçili açılan takvim.
  const DatePickerSheet({
    required this.initial,
    this.firstDate,
    this.lastDate,
    this.title,
    super.key,
  });

  /// Açılışta seçili gün (ve gösterilen ay).
  final DateTime initial;

  /// Seçilebilir ilk gün; `null` → sınır yok.
  final DateTime? firstDate;

  /// Seçilebilir son gün; `null` → sınır yok.
  final DateTime? lastDate;

  /// Sayfa başlığı; `null` → `sht.28.title`.
  final String? title;

  /// SHT-28 [action] anahtarı (`SHT-28.<aksiyon>`).
  static Key keyOf(String action) =>
      FeedbackKeys.of(SheetId.sht28.designId, action);

  /// [day] hücresinin anahtarı (`SHT-28.day.<yyyy-mm-dd>`).
  static Key dayKeyOf(DateTime day) => keyOf('day.${GuCalendar.dayKey(day)}');

  @override
  ConsumerState<DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends ConsumerState<DatePickerSheet> {
  late DateTime _selected;
  late DateTime _month;

  DateTime? get _first {
    final first = widget.firstDate;
    return first == null ? null : AppCalendar.dateOnly(first);
  }

  DateTime? get _last {
    final last = widget.lastDate;
    return last == null ? null : AppCalendar.dateOnly(last);
  }

  bool _inRange(DateTime day) {
    final first = _first;
    final last = _last;
    return (first == null || !day.isBefore(first)) &&
        (last == null || !day.isAfter(last));
  }

  /// [day] sınır içindeyse kendisi, değilse en yakın sınır.
  DateTime _clamp(DateTime day) {
    final first = _first;
    final last = _last;
    if (first != null && day.isBefore(first)) return first;
    if (last != null && day.isAfter(last)) return last;
    return day;
  }

  @override
  void initState() {
    super.initState();
    _selected = _clamp(AppCalendar.dateOnly(widget.initial));
    _month = DateTime(_selected.year, _selected.month);
  }

  void _shiftMonth(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  void _goToday(DateTime today) => setState(() {
    _month = DateTime(today.year, today.month);
    if (_inRange(today)) _selected = today;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final today = AppCalendar.todayOf(ref.watch(appClockProvider));
    return GuSheetFrame(
      title: widget.title ?? l10n.sht28Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: DatePickerSheet.keyOf('close'),
      footer: [
        GuButton(
          key: DatePickerSheet.keyOf('cancel'),
          label: l10n.commonCancel,
          variant: GuButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
        GuButton(
          key: DatePickerSheet.keyOf('ok'),
          label: l10n.commonOk,
          onPressed: () => Navigator.of(context).pop(_selected),
        ),
      ],
      // `div.pb16` (sheets.js:135).
      body: Padding(
        padding: GuInsets.only(bottom: GuSpacing.s16),
        child: AppCalendar(
          month: _month,
          today: today,
          selected: _selected,
          onSelect: (day) => setState(() => _selected = day),
          onPrev: () => _shiftMonth(-1),
          onNext: () => _shiftMonth(1),
          onToday: () => _goToday(today),
          min: _first,
          max: _last,
          compact: true,
          prevKey: DatePickerSheet.keyOf('prevMonth'),
          nextKey: DatePickerSheet.keyOf('nextMonth'),
          todayKey: DatePickerSheet.keyOf('today'),
          dayKeyBuilder: DatePickerSheet.dayKeyOf,
        ),
      ),
    );
  }
}
