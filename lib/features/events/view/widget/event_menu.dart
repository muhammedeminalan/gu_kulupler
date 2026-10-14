import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';

/// EVT-MENU'de seçilen öğe — `showMenu<EventMenuAction>` dönüş değeri. Sıra
/// tasarımdaki satır sırasıdır (`sheets.js:12`).
enum EventMenuAction {
  /// "Hatırlatıcı" (`EVT-02.menu.reminder`; yalnızca katılım kaydı varken)
  /// → SHT-13.
  reminder('reminder', GuIcons.bellRing),

  /// "Takvime ekle" (`EVT-02.menu.calendar`) → SHT-14.
  calendar('calendar', GuIcons.calendarPlus),

  /// "Paylaş" (`EVT-02.menu.share`) → SHT-15.
  share('share', GuIcons.share2),

  /// "Etkinliği şikayet et" (`EVT-02.menu.report`) → SHT-10.
  report('report', GuIcons.flag);

  const EventMenuAction(this.action, this.icon);

  /// Aksiyon adı (`EVT-02.menu.<action>`).
  final String action;

  /// Satırın ikonu.
  final GuIcons icon;
}

/// "Etkinlik" açılır menüsü — prototip `MENUS['EVT-MENU']` (`sheets.js:12`).
/// EVT-02 "⋮" düğmesi yönetici olmayan kullanıcı için açar (yönetici →
/// SHT-23, T-34).
///
/// Menü hiçbir şey yürütmez: seçilen öğe [EventMenuAction] olarak döner;
/// eylemi EVT-02 view mixin'i başlatır.
///
/// ```dart
/// final action = await feedback.showMenu<EventMenuAction>(
///   id: MenuId.evtMenu,
///   scrimKey: GuKey.action('EVT-02.scrim'),
///   items: EventMenu.items(l10n, hasRsvp: state.rsvp != null),
/// );
/// ```
///
/// Design: EVT-MENU
abstract final class EventMenu {
  /// Menü öğeleri; [hasRsvp] `false` ise "Hatırlatıcı" yoktur.
  static List<GuPopMenuItem> items(
    AppLocalizations l10n, {
    required bool hasRsvp,
  }) => [
    for (final action in EventMenuAction.values)
      if (hasRsvp || action != EventMenuAction.reminder)
        GuPopMenuItem(
          key: keyOf(action),
          label: labelOf(l10n, action),
          icon: action.icon,
          value: action,
        ),
  ];

  /// [action] satırının anahtarı (`EVT-02.menu.<action>`).
  static Key keyOf(EventMenuAction action) => switch (action) {
    EventMenuAction.reminder => GuKey.action('EVT-02.menu.reminder'),
    EventMenuAction.calendar => GuKey.action('EVT-02.menu.calendar'),
    EventMenuAction.share => GuKey.action('EVT-02.menu.share'),
    EventMenuAction.report => GuKey.action('EVT-02.menu.report'),
  };

  /// [action] satırının metni (`sheets.js:12`).
  static String labelOf(AppLocalizations l10n, EventMenuAction action) =>
      switch (action) {
        EventMenuAction.reminder => l10n.eventReminder,
        EventMenuAction.calendar => l10n.eventAddToCalendar,
        EventMenuAction.share => l10n.commonShare,
        EventMenuAction.report => l10n.eventReport,
      };
}
