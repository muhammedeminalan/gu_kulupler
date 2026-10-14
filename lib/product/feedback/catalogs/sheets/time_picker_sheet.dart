import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/format/time_of_day_value.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-29 "Saat seç" — saat (0–23) ve dakika ([minuteStep] adımlı) tekerleği
/// + "İptal" / "Tamam" (prototip `SHEETS['SHT-29']`, `sheets.js:136–140`).
/// NTF-02 sessiz saatler (`NTF-02.quietFrom` / `quietTo`) ve MGT-05 etkinlik
/// saati açar.
///
/// * Açılış değeri [initial]; dakika en yakın [minuteStep] katına yuvarlanır
///   (`round(m / step) * step % 60`, sheets.js:139).
/// * Seçim taslaktır; "Tamam" sayfayı seçili saatle kapatır
///   (`pop(TimeOfDayValue)`), "İptal" / X / scrim / sürükleme / geri → `null`.
/// * Başlık [title] verilmezse `sht.29.title` ("Saat seç").
/// * Anahtarlar `SHT-29.hour`, `SHT-29.minute`, `SHT-29.cancel`,
///   `SHT-29.ok`, `SHT-29.close` (+ `SHT-29.scrim`, `FeedbackService`).
///
/// ```dart
/// final time = await feedback.showSheet<TimeOfDayValue>(
///   SheetId.sht29,
///   builder: (_) => TimePickerSheet(initial: from),
/// );
/// ```
///
/// Design: SHT-29
class TimePickerSheet extends ConsumerStatefulWidget {
  /// [initial] saati seçili açılan tekerlekler.
  const TimePickerSheet({
    required this.initial,
    this.minuteStep = defaultMinuteStep,
    this.title,
    super.key,
  }) : assert(
         minuteStep > 0 && TimeOfDayValue.minutesPerHour % minuteStep == 0,
         'TimePickerSheet: minuteStep 60’ı tam bölmeli',
       );

  /// Prototip dakika adımı (`i * 5`, sheets.js:140).
  static const int defaultMinuteStep = 5;

  /// Açılışta seçili saat.
  final TimeOfDayValue initial;

  /// Dakika tekerleğinin adımı (60'ı tam böler).
  final int minuteStep;

  /// Sayfa başlığı; `null` → `sht.29.title`.
  final String? title;

  /// SHT-29 [action] anahtarı (`SHT-29.<aksiyon>`).
  static Key keyOf(String action) =>
      FeedbackKeys.of(SheetId.sht29.designId, action);

  @override
  ConsumerState<TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends ConsumerState<TimePickerSheet> {
  /// Saat ile dakika arasındaki ayırıcı (sheets.js:140; `HH:mm` biçimiyle
  /// aynı karakter).
  static const String _separator = ':';

  late int _hour;
  late int _minute;

  @override
  void initState() {
    super.initState();
    final step = widget.minuteStep;
    _hour = widget.initial.hour;
    _minute =
        (widget.initial.minute / step).round() *
        step %
        TimeOfDayValue.minutesPerHour;
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final hours = [
      for (var h = 0; h < TimeOfDayValue.hoursPerDay; h++)
        TimeOfDayValue.pad2(h),
    ];
    final minutes = [
      for (var m = 0; m < TimeOfDayValue.minutesPerHour; m += widget.minuteStep)
        TimeOfDayValue.pad2(m),
    ];
    // `GuSizes.wheelSelectionBorder` (1) = `BorderSide` varsayılan kalınlığı.
    final selectionBorder = BorderSide(color: gu.colors.borderDefault);
    return GuSheetFrame(
      title: widget.title ?? l10n.sht29Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: TimePickerSheet.keyOf('close'),
      footer: [
        GuButton(
          key: TimePickerSheet.keyOf('cancel'),
          label: l10n.commonCancel,
          variant: GuButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
        GuButton(
          key: TimePickerSheet.keyOf('ok'),
          label: l10n.commonOk,
          onPressed: () =>
              Navigator.of(context).pop(TimeOfDayValue(_hour, _minute)),
        ),
      ],
      // `<div class="row gap8 pb16" style="position:relative">` + seçim bandı
      // (`top:50%;height:40px;border-top/bottom:1px solid
      // var(--border-default);pointer-events:none`, sheets.js:140). Bant iki
      // tekerleği ve ayırıcıyı birlikte kaplar; yüksekliği tekerlek öğesiyle
      // aynı ölçeklenir (K-08).
      body: Padding(
        padding: GuInsets.only(bottom: GuSpacing.s16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: GuWheelPicker.itemExtentOf(context),
                  decoration: BoxDecoration(
                    border: Border(
                      top: selectionBorder,
                      bottom: selectionBorder,
                    ),
                  ),
                ),
              ),
            ),
            Row(
              spacing: GuSpacing.s8,
              children: [
                Expanded(
                  child: GuWheelPicker(
                    key: TimePickerSheet.keyOf('hour'),
                    values: hours,
                    value: TimeOfDayValue.pad2(_hour),
                    semanticLabel: l10n.sht29Hour,
                    onChanged: (v) => setState(() => _hour = int.parse(v)),
                  ),
                ),
                // `<span class="t-title-m">:</span>` — görsel ayırıcı;
                // tekerlekler kendi etiketini taşır.
                ExcludeSemantics(
                  child: Text(_separator, style: gu.text.titleM),
                ),
                Expanded(
                  child: GuWheelPicker(
                    key: TimePickerSheet.keyOf('minute'),
                    values: minutes,
                    value: TimeOfDayValue.pad2(_minute),
                    semanticLabel: l10n.sht29Minute,
                    onChanged: (v) => setState(() => _minute = int.parse(v)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
