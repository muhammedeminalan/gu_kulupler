import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/events/view/widget/reminder_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/widget/event/event_place_label.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-12 "Katılım onayı" — etkinlik özeti + hatırlatıcı seçimi + "Katılımı
/// onayla" (prototip `SHEETS['SHT-12']`, `sheets.js:62–67`).
///
/// * Sayfa yazma yapmaz: "Katılımı onayla" seçilen hatırlatıcıyı döndürür
///   (`pop(ReminderOption)`); katılımı çağıran yürütür
///   (`EventDetailViewModel.join(reminder)`). X / scrim / geri → `null`.
/// * Özet kartı (`Card muted`): başlık, tarih · saat, mekân.
/// * Hatırlatıcı çipleri [options] — tasarımın "Hatırlatma yok · 1 saat önce ·
///   1 gün önce" çipleri. Tasarımdaki "İkisi" (`both`) çizilmez: kayıt tek
///   tercih taşır (`ReminderOption` dört değer, Rules
///   `reminder ∈ [none, 15m, 1h, 1d]` — CD-34).
/// * [hasConflict] → çakışma uyarısı (`sht12Conflict`); [event]
///   `joinsWaitlist` ise bekleme listesi notu (`sht12FullNote`).
/// * Anahtarlar `SHT-12.reminder.<json>`, `SHT-12.confirm`, `SHT-12.close`.
///
/// ```dart
/// final reminder = await feedback.showSheet<ReminderOption>(
///   SheetId.sht12,
///   builder: (_) => RsvpConfirmSheet(event: event, hasConflict: conflict),
/// );
/// if (reminder != null) await viewModel.join(reminder);
/// ```
///
/// Design: SHT-12
class RsvpConfirmSheet extends ConsumerStatefulWidget {
  /// [event] etkinliğine katılım onayı.
  const RsvpConfirmSheet({
    required this.event,
    this.hasConflict = false,
    this.initialReminder = ReminderOption.oneHour,
    super.key,
  });

  /// Katılınacak etkinlik.
  final EventModel event;

  /// Kullanıcının aynı saatte başka bir kaydı var mı?
  final bool hasConflict;

  /// Başlangıçta seçili hatırlatıcı (`useState('1h')`, `sheets.js:63`).
  final ReminderOption initialReminder;

  /// Çizilen hatırlatıcı çipleri, tasarım sırasıyla (`sheets.js:65`).
  static const List<ReminderOption> options = [
    ReminderOption.none,
    ReminderOption.oneHour,
    ReminderOption.oneDay,
  ];

  /// [option] çipinin anahtarı (`SHT-12.reminder.<json>`).
  static Key reminderKeyOf(ReminderOption option) =>
      FeedbackKeys.of(SheetId.sht12.designId, 'reminder.${option.json}');

  @override
  ConsumerState<RsvpConfirmSheet> createState() => _RsvpConfirmSheetState();
}

class _RsvpConfirmSheetState extends ConsumerState<RsvpConfirmSheet> {
  late ReminderOption _reminder = widget.initialReminder;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final colors = gu.colors;
    final event = widget.event;
    final formats = AppDateFormats(
      Localizations.localeOf(context),
      ref.watch(appClockProvider),
    );
    final meta = gu.text.bodyS.copyWith(color: colors.textSecondary);

    Widget metaRow(GuIcons icon, String text) => Row(
      spacing: GuSpacing.s4,
      children: [
        GuIcon(icon, size: GuSizes.icon14, color: colors.textSecondary),
        Flexible(child: Text(text, style: meta)),
      ],
    );

    return GuSheetFrame(
      title: l10n.sht12Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: FeedbackKeys.of(SheetId.sht12.designId, 'close'),
      body: Padding(
        padding: GuInsets.only(bottom: GuSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s16,
          children: [
            GuCard(
              muted: true,
              padding: GuCard.bodyPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: GuSpacing.s4,
                children: [
                  Text(event.title, style: gu.text.titleS),
                  metaRow(
                    GuIcons.calendarDays,
                    formats.dateTime(l10n, event.startsAt),
                  ),
                  metaRow(GuIcons.mapPin, EventPlaceLabel.of(context, event)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: GuSpacing.s8,
              children: [
                Text(l10n.eventReminder, style: gu.text.fieldLabel),
                Wrap(
                  spacing: GuSpacing.s8,
                  runSpacing: GuSpacing.s8,
                  children: [
                    for (final option in RsvpConfirmSheet.options)
                      GuChip(
                        key: RsvpConfirmSheet.reminderKeyOf(option),
                        label: ReminderSheet.labelOf(l10n, option),
                        selected: option == _reminder,
                        onTap: () => setState(() => _reminder = option),
                      ),
                  ],
                ),
              ],
            ),
            if (widget.hasConflict)
              GuBanner(
                kind: GuBannerKind.warning,
                text: l10n.sht12Conflict,
                card: true,
              ),
            if (event.joinsWaitlist)
              GuBanner(text: l10n.sht12FullNote, card: true),
          ],
        ),
      ),
      footer: [
        GuButton(
          key: FeedbackKeys.of(SheetId.sht12.designId, 'confirm'),
          label: l10n.sht12Confirm,
          size: GuButtonSize.lg,
          onPressed: () => context.pop(_reminder),
        ),
      ],
    );
  }
}
