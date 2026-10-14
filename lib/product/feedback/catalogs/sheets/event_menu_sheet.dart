import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-23'te dokunulan satır — sayfanın `pop` değeri. Sıra tasarımdaki satır
/// sırasıdır (`sheets.js:109–112`).
enum EventMenuAction {
  /// "Düzenle" (`SHT-23.edit`) → MGT-05 (`EventEditRoute`).
  edit('edit', GuIcons.pencil),

  /// "Çoğalt" (`SHT-23.duplicate`) → yeni taslak, +7 gün (TST-13).
  duplicate('duplicate', GuIcons.copy),

  /// "Katılımcılar" (`SHT-23.attendees`) → MGT-06 (T-35).
  attendees('attendees', GuIcons.users),

  /// "Yoklama başlat" (`SHT-23.scan`) → MGT-07 (T-35).
  scan('scan', GuIcons.scanLine),

  /// "Paylaş" (`SHT-23.share`) → SHT-15.
  share('share', GuIcons.share2),

  /// "Yayından kaldır / taslağa al" (`SHT-23.unpublish`) → TST-X19; kayıtlı
  /// varken devre dışı (K-F).
  unpublish('unpublish', GuIcons.fileText),

  /// "İptal et" (`SHT-23.cancel`, yıkıcı) → DLG-23.
  cancel('cancel', GuIcons.calendarX),

  /// "Sil" (`SHT-23.delete`, yıkıcı; yalnız taslak) → DLG-31.
  delete('delete', GuIcons.trash2);

  const EventMenuAction(this.action, this.icon);

  /// Aksiyon adı (`SHT-23.<action>`).
  final String action;

  /// Satırın ikonu.
  final GuIcons icon;

  /// Yıkıcı satır mı (kırmızı ikon + metin): "İptal et" ve "Sil".
  bool get isDanger => this == cancel || this == delete;
}

/// SHT-23'ün bir satırı: eylem + etkin mi. Devre dışı satır soluk çizilir,
/// altında nedeni yazar (`sht23UnpublishBlocked`) ve kapanmaz (yalnızca
/// "Taslağa al", kayıtlı varken — K-F).
final class EventMenuOption extends Equatable {
  /// [action] satırı; [enabled] `false` → devre dışı.
  const EventMenuOption(this.action, {this.enabled = true});

  /// Satırın eylemi.
  final EventMenuAction action;

  /// Eylem bu etkinliğe şu an uygulanabilir mi.
  final bool enabled;

  @override
  List<Object?> get props => [action, enabled];
}

/// SHT-23 "Etkinlik menüsü" — bir etkinliğin yönetici menüsü (prototip
/// `SHEETS['SHT-23']`, `sheets.js:108–112`). MGT-04 kart menüsü
/// (`MGT-04.menu.<eventId>`) ve EVT-02 yönetici "⋮" (W-27) açar; iki feature
/// kullandığı için product'tadır (SHT-21 kalıbı).
///
/// * Başlık etkinliğin başlığıdır.
/// * Hangi satırın görünüp etkin olduğuna **yalnızca** [actionsFor] karar
///   verir (durum makinesi + K-F tek yer).
/// * Sayfa hiçbir şey yürütmez: etkin satır [EventMenuAction] olarak döner
///   (`pop`); yazma eylemini çağıran `WriteGuardMixin` ile başlatır
///   (danışman → TST-26). X / scrim / sürükleme / geri → `null`.
/// * Anahtarlar `SHT-23.<action>`, `SHT-23.close` (+ `SHT-23.scrim`,
///   `FeedbackService`).
///
/// ```dart
/// final action = await feedback.showSheet<EventMenuAction>(
///   SheetId.sht23,
///   builder: (_) => EventMenuSheet(event: event, now: clock.nowUtc()),
/// );
/// ```
///
/// Design: SHT-23
class EventMenuSheet extends StatelessWidget {
  /// [event] etkinliğinin menüsü; [now] durum kurallarının anı (UTC,
  /// `AppClock.nowUtc`).
  const EventMenuSheet({required this.event, required this.now, super.key});

  /// Menüsü açılan etkinlik.
  final EventModel event;

  /// Kuralların değerlendirildiği an (UTC).
  final DateTime now;

  /// [action] satırının anahtarı (`SHT-23.<action>`).
  static Key keyOf(EventMenuAction action) => switch (action) {
    EventMenuAction.edit => GuKey.action('SHT-23.edit'),
    EventMenuAction.duplicate => GuKey.action('SHT-23.duplicate'),
    EventMenuAction.attendees => GuKey.action('SHT-23.attendees'),
    EventMenuAction.scan => GuKey.action('SHT-23.scan'),
    EventMenuAction.share => GuKey.action('SHT-23.share'),
    EventMenuAction.unpublish => GuKey.action('SHT-23.unpublish'),
    EventMenuAction.cancel => GuKey.action('SHT-23.cancel'),
    EventMenuAction.delete => GuKey.action('SHT-23.delete'),
  };

  /// Görünen satırlar, tasarım sırasıyla — etkinlik durum kurallarının **tek
  /// yeri** (domain-model §2.7, §8; K-F; `EventRepository` sözleşmesi):
  ///
  /// | satır | taslak | yayında, başlamamış | yayında, sürüyor | geçmiş | iptal |
  /// |---|---|---|---|---|---|
  /// | Düzenle | ✓ | ✓ | ✓ (zaman kilitli — W-82) | ✓ | — |
  /// | Çoğalt | ✓ | ✓ | ✓ | ✓ | ✓ |
  /// | Katılımcılar | — | ✓ | ✓ | ✓ | ✓ |
  /// | Yoklama başlat | — | ✓ | ✓ | ✓ | — |
  /// | Paylaş | — | ✓ | ✓ | ✓ | ✓ |
  /// | Taslağa al | — | ✓ (`goingCount > 0` → devre dışı, K-F) | — | — | — |
  /// | İptal et | — | ✓ | ✓ | — | — |
  /// | Sil | ✓ | — | — | — | — |
  ///
  /// * "Geçmiş" türetilmiştir: yayında ve `endsAt <= now`; "sürüyor":
  ///   yayında ve `startsAt <= now < endsAt`.
  /// * İptal edilen etkinlik düzenlenemez (`update` → `failedPrecondition`).
  /// * Taslak paylaşılmaz (yalnızca yönetici görür) ve kaydı / yoklaması
  ///   yoktur.
  /// * Başlamış etkinlik taslağa alınmaz: yayın gelecekteki başlangıç ister
  ///   (`publish` → `eventEnded`), taslak bir daha yayınlanamazdı.
  /// * Bitmiş etkinlik iptal edilmez (iptal bildirimi anlamsız).
  /// * Yoklama penceresi (K-G) MGT-06 / MGT-07'de denetlenir.
  static List<EventMenuOption> actionsFor({
    required EventStatus status,
    required int goingCount,
    required DateTime startsAt,
    required DateTime endsAt,
    required DateTime now,
  }) {
    switch (status) {
      case EventStatus.draft:
        return const [
          EventMenuOption(EventMenuAction.edit),
          EventMenuOption(EventMenuAction.duplicate),
          EventMenuOption(EventMenuAction.delete),
        ];
      case EventStatus.cancelled:
        return const [
          EventMenuOption(EventMenuAction.duplicate),
          EventMenuOption(EventMenuAction.attendees),
          EventMenuOption(EventMenuAction.share),
        ];
      case EventStatus.published:
        final started = !now.isBefore(startsAt);
        final ended = !now.isBefore(endsAt);
        return [
          const EventMenuOption(EventMenuAction.edit),
          const EventMenuOption(EventMenuAction.duplicate),
          const EventMenuOption(EventMenuAction.attendees),
          const EventMenuOption(EventMenuAction.scan),
          const EventMenuOption(EventMenuAction.share),
          if (!started)
            EventMenuOption(
              EventMenuAction.unpublish,
              enabled: goingCount == 0,
            ),
          if (!ended) const EventMenuOption(EventMenuAction.cancel),
        ];
    }
  }

  /// [event] için [actionsFor].
  static List<EventMenuOption> actionsOf(EventModel event, DateTime now) =>
      actionsFor(
        status: event.status,
        goingCount: event.goingCount,
        startsAt: event.startsAt,
        endsAt: event.endsAt,
        now: now,
      );

  /// [action] satırının görünen adı.
  static String labelOf(AppLocalizations l10n, EventMenuAction action) =>
      switch (action) {
        EventMenuAction.edit => l10n.commonEdit,
        EventMenuAction.duplicate => l10n.sht23Duplicate,
        EventMenuAction.attendees => l10n.eventCtaAttendees,
        EventMenuAction.scan => l10n.eventCtaScan,
        EventMenuAction.share => l10n.commonShare,
        EventMenuAction.unpublish => l10n.sht23Unpublish,
        EventMenuAction.cancel => l10n.sht23Cancel,
        EventMenuAction.delete => l10n.commonDelete,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.gu.colors;
    return GuSheetFrame(
      title: event.title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: GuKey.action('SHT-23.close'),
      menu: true,
      flush: true,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in actionsOf(event, now))
            GuTile(
              key: keyOf(option.action),
              title: labelOf(l10n, option.action),
              // K-F: devre dışı "Taslağa al" nedenini söyler (PLAN K-F).
              subtitle: option.enabled ? null : l10n.sht23UnpublishBlocked,
              danger: option.action.isDanger,
              disabled: !option.enabled,
              leading: GuIcon(
                option.action.icon,
                size: GuSizes.icon22,
                color: option.action.isDanger
                    ? colors.stateDanger
                    : colors.textHeading,
              ),
              onTap: option.enabled
                  ? () => Navigator.of(context).pop(option.action)
                  : null,
            ),
        ],
      ),
    );
  }
}
