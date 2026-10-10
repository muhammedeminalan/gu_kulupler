import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/primitives/gu_action_surface.dart';
import 'package:gu_ui/src/widgets/primitives/gu_button.dart';
import 'package:gu_ui/src/widgets/primitives/gu_icon_button.dart';

/// Ay takvimi — prototip `Calendar` (`ui.js:140–150`), CSS `.cal-head`
/// `.cal-grid` `.cal-day` `.dots` (css:313–317). Q-08: kendi takvim
/// (`table_calendar` yok).
///
/// * Başlık: önceki / sonraki ay ok düğmeleri (`GuIconButton` 40), ortada
///   [monthTitle] (`titleS`), [onToday] verilirse "Bugün" metin düğmesi.
///   Ay değişimi çağırandadır: [onPrev] / [onNext] yeni [month] +
///   [monthTitle] ile yeniden kurar.
/// * Izgara: 6 hafta × 7 = 42 hücre (`GuSizes.calendarWeeks`), aralık 2;
///   hücre kare, en az 44 ([compact] 36), radius 12. Hafta
///   [firstDayOfWeek] ile başlar (D-26: Pazartesi).
/// * Gün durumları: bugün (2 px `brand.primary` iç halka), seçili (dolu
///   `brand.primary`, metin ve noktalar `brand.onPrimary`), diğer ay
///   (`text.disabled`), [min] / [max] dışı (devre dışı: `text.disabled`,
///   [onSelect] çağrılmaz), noktalı (≤ `GuSizes.calendarDotsMax`).
/// * gu_ui yerel ayar bilmez: [monthTitle] (baş harfi büyük, `Ekim 2026`),
///   [weekdayLabels] (7 öğe, [firstDayOfWeek] sırasında, K-40: 2 harf),
///   [todayLabel] ve [daySemanticLabel] çağırandan gelir. `DateTime.now()`
///   çağrılmaz; [today] parametredir.
/// * Hafta başlıkları ölçeklenmez (K-57: css:317 sabit `11px`); gün sayısı
///   ölçeklenir, hücreye sığmazsa küçültülür.
/// * Anahtarlar çağırandan: [prevKey], [nextKey], [todayKey],
///   [dayKeyBuilder] (`(d) => GuKey.action('EVT-01.day.${dayKey(d)}')`,
///   CD-111).
class GuCalendar extends StatelessWidget {
  const GuCalendar({
    required this.month,
    required this.today,
    required this.onSelect,
    required this.monthTitle,
    required this.weekdayLabels,
    required this.onPrev,
    required this.onNext,
    required this.prevSemanticLabel,
    required this.nextSemanticLabel,
    required this.daySemanticLabel,
    this.selected,
    this.dotsFor,
    this.min,
    this.max,
    this.onToday,
    this.todayLabel,
    this.firstDayOfWeek = DateTime.monday,
    this.compact = false,
    this.prevKey,
    this.nextKey,
    this.todayKey,
    this.dayKeyBuilder,
    super.key,
  }) : assert(
         weekdayLabels.length == DateTime.daysPerWeek,
         'weekdayLabels 7 öğe olmalı.',
       ),
       assert(
         firstDayOfWeek >= DateTime.monday && firstDayOfWeek <= DateTime.sunday,
         'firstDayOfWeek DateTime.monday…DateTime.sunday olmalı.',
       ),
       assert(
         onToday == null || todayLabel != null,
         'onToday verilirse todayLabel zorunludur.',
       );

  /// Gösterilen ay (yalnızca yıl + ay kullanılır).
  final DateTime month;

  /// Bugün (halka); çağıranın saatinden (`AppClock`).
  final DateTime today;

  /// Seçili gün; `null` → seçim yok.
  final DateTime? selected;

  /// Gün seçimi (yerel gece yarısı); devre dışı günde çağrılmaz.
  final ValueChanged<DateTime> onSelect;

  /// Ay başlığı (`fmt.monthYear`, baş harfi büyük).
  final String monthTitle;

  /// Hafta günü kısaltmaları, [firstDayOfWeek] sırasında 7 öğe.
  final List<String> weekdayLabels;

  /// Haftanın ilk günü (`DateTime.monday` … `DateTime.sunday`).
  final int firstDayOfWeek;

  /// Günün etkinlik sayısı; en çok `GuSizes.calendarDotsMax` nokta çizilir.
  final int Function(DateTime day)? dotsFor;

  /// Seçilebilir ilk gün (saat yok sayılır).
  final DateTime? min;

  /// Seçilebilir son an: gün başlangıcı [max]'tan sonraysa devre dışı.
  final DateTime? max;

  /// Önceki ay.
  final VoidCallback onPrev;

  /// Sonraki ay.
  final VoidCallback onNext;

  /// "Bugün" düğmesi; `null` → düğme yok.
  final VoidCallback? onToday;

  /// "Bugün" düğmesi metni (`common.today`).
  final String? todayLabel;

  /// Önceki ay düğmesi etiketi (`a11y.prevMonth`).
  final String prevSemanticLabel;

  /// Sonraki ay düğmesi etiketi (`a11y.nextMonth`).
  final String nextSemanticLabel;

  /// Gün hücresi etiketi (tam tarih, `fmt.date`).
  final String Function(DateTime day) daySemanticLabel;

  /// Hücre en küçük yüksekliği 36 (SHT-28, `ui.js:149`).
  final bool compact;

  /// Önceki ay düğmesi anahtarı (`<ID>.prevMonth`).
  final Key? prevKey;

  /// Sonraki ay düğmesi anahtarı (`<ID>.nextMonth`).
  final Key? nextKey;

  /// "Bugün" düğmesi anahtarı (`<ID>.today`).
  final Key? todayKey;

  /// Gün hücresi anahtarı üreticisi (`<ID>.day.<yyyy-mm-dd>`).
  final Key Function(DateTime day)? dayKeyBuilder;

  /// css:314 `.cal-day{aspect-ratio:1}`.
  static const double _dayAspectRatio = 1;

  /// [month] için ızgaranın 42 günü: ayın 1'ini içeren haftanın
  /// [firstDayOfWeek] gününden başlar (`ui.js:142–143`). Günler yerel gece
  /// yarısıdır; taşan gün sayıları `DateTime` ile komşu aya normalleşir.
  static List<DateTime> visibleDays(
    DateTime month, {
    int firstDayOfWeek = DateTime.monday,
  }) {
    final lead =
        (DateTime(month.year, month.month).weekday - firstDayOfWeek) %
        DateTime.daysPerWeek;
    return [
      for (
        var index = 0;
        index < GuSizes.calendarWeeks * DateTime.daysPerWeek;
        index++
      )
        DateTime(month.year, month.month, 1 - lead + index),
    ];
  }

  /// Gün anahtarı `yyyy-mm-dd` (`core.js:435` `dayKey`).
  static String dayKey(DateTime day) =>
      '${day.year}-${_pad2(day.month)}-${_pad2(day.day)}';

  static String _pad2(int value) => value.toString().padLeft(2, '0');

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// `ui.js:149`: `ts < startOfDay(min) || ts > max`.
  bool _isDisabled(DateTime day) {
    final lower = min;
    final upper = max;
    if (lower != null &&
        day.isBefore(DateTime(lower.year, lower.month, lower.day))) {
      return true;
    }
    return upper != null && day.isAfter(upper);
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final days = visibleDays(month, firstDayOfWeek: firstDayOfWeek);
    final picked = selected;
    final goToday = onToday;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s8,
      children: [
        // `.row.between` (ui.js:147): ok — başlık — [Bugün] ok.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GuIconButton(
              key: prevKey,
              icon: GuIcons.chevronLeft,
              semanticLabel: prevSemanticLabel,
              onPressed: onPrev,
              size: GuIconButtonSize.sm,
            ),
            Flexible(
              child: Text(
                monthTitle,
                style: gu.text.titleS,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: GuSpacing.s4,
              children: [
                if (goToday != null)
                  GuButton(
                    key: todayKey,
                    label: todayLabel ?? '',
                    onPressed: goToday,
                    variant: GuButtonVariant.text,
                    size: GuButtonSize.sm,
                  ),
                GuIconButton(
                  key: nextKey,
                  icon: GuIcons.chevronRight,
                  semanticLabel: nextSemanticLabel,
                  onPressed: onNext,
                  size: GuIconButtonSize.sm,
                ),
              ],
            ),
          ],
        ),
        // `.cal-head` (css:317): 7 eşit sütun, aralıksız.
        Padding(
          padding: GuInsets.sym(v: GuSizes.calendarHeadPaddingY),
          child: Row(
            children: [
              for (final label in weekdayLabels)
                Expanded(
                  child: Text(
                    label,
                    style: gu.text.calendarHead,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.clip,
                  ),
                ),
            ],
          ),
        ),
        // `.cal-grid` (css:313): 7 sütun, aralık 2.
        Column(
          mainAxisSize: MainAxisSize.min,
          spacing: GuSizes.calendarGap,
          children: [
            for (var week = 0; week < GuSizes.calendarWeeks; week++)
              Row(
                spacing: GuSizes.calendarGap,
                children: [
                  for (final day
                      in days
                          .skip(week * DateTime.daysPerWeek)
                          .take(
                            DateTime.daysPerWeek,
                          ))
                    Expanded(
                      // Kutu, hücrenin dokunma alanını kendi sınırına kırpar
                      // (bitişik hücreler: `GuTapTarget` dolgusu komşuya
                      // taşmaz).
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: compact
                              ? GuSizes.calendarDayMinHeightCompact
                              : GuSizes.calendarDayMinHeight,
                        ),
                        child: AspectRatio(
                          aspectRatio: _dayAspectRatio,
                          child: _GuCalendarDay(
                            key: dayKeyBuilder?.call(day),
                            day: day,
                            semanticLabel: daySemanticLabel(day),
                            isOther:
                                day.month != month.month ||
                                day.year != month.year,
                            isToday: _sameDay(day, today),
                            isSelected: picked != null && _sameDay(day, picked),
                            isDisabled: _isDisabled(day),
                            dots: (dotsFor?.call(day) ?? 0).clamp(
                              0,
                              GuSizes.calendarDotsMax,
                            ),
                            onSelect: onSelect,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Gün hücresi — `button.cal-day` (`ui.js:149`, css:314–316): sayı + 4 px
/// nokta satırı (nokta yokken de yer tutar), aralık 2.
class _GuCalendarDay extends StatelessWidget {
  const _GuCalendarDay({
    required this.day,
    required this.semanticLabel,
    required this.isOther,
    required this.isToday,
    required this.isSelected,
    required this.isDisabled,
    required this.dots,
    required this.onSelect,
    super.key,
  });

  final DateTime day;
  final String semanticLabel;
  final bool isOther;
  final bool isToday;
  final bool isSelected;
  final bool isDisabled;
  final int dots;
  final ValueChanged<DateTime> onSelect;

  void _handleTap() {
    if (!isDisabled) onSelect(day);
  }

  @override
  Widget build(BuildContext context) => GuActionSurface(
    onTap: _handleTap,
    enabled: !isDisabled,
    semanticLabel: semanticLabel,
    selected: isSelected,
    borderRadius: GuRadius.borderSm,
    builder: _buildVisual,
  );

  Widget _buildVisual(BuildContext context, bool pressed) {
    final gu = context.gu;
    final colors = gu.colors;
    // css:315 kaynak sırası: `[aria-disabled]` > `.is-selected` > `.is-other`.
    final Color foreground;
    if (isDisabled || (isOther && !isSelected)) {
      foreground = colors.textDisabled;
    } else if (isSelected) {
      foreground = colors.brandOnPrimary;
    } else {
      foreground = colors.textPrimary;
    }
    final dotColor = isSelected ? colors.brandOnPrimary : colors.brandPrimary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isSelected ? colors.brandPrimary : null,
        borderRadius: GuRadius.borderSm,
        // css:315 `box-shadow:inset 0 0 0 2px` → iç kenarlık.
        border: isToday
            ? Border.all(
                color: colors.brandPrimary,
                width: GuSizes.calendarTodayRing,
              )
            : null,
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: GuSizes.calendarDayGap,
            children: [
              Text(
                '${day.day}',
                style: gu.text.calendarDay.copyWith(color: foreground),
                maxLines: 1,
                softWrap: false,
              ),
              SizedBox(
                height: GuSizes.calendarDotsHeight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: GuSizes.calendarDotGap,
                  children: [
                    for (var index = 0; index < dots; index++)
                      SizedBox.square(
                        dimension: GuSizes.calendarDot,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
