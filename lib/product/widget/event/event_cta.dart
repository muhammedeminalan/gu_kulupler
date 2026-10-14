import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/event/event_card_status.dart';
import 'package:gu_ui/gu_ui.dart';

/// Etkinlik katılım düğmesinin türü — prototip `eventQuickAction`
/// (`cards.js:58–67`) ve EVT-02 `cta()` (`screens-events.js:44–53`) tek
/// kaynaktan (design-analysis §B "EventCta").
enum EventCtaKind {
  /// "Biletini göster" (`going`) → EVT-03.
  ticket,

  /// "Kulübe başvur" (`members`) → CLB-03.
  applyClub,

  /// Kartta "Bekleme listesi" (`waitlist`) → EVT-02. EVT-02'de bu durumun
  /// alt çubuğu sıra metni + "Ayrıl"dır (ekranın kendi çubuğu).
  waitlist,

  /// "Bekleme listesine katıl" (`full`, `joinsWaitlist`) → DLG-15.
  joinWaitlist,

  /// "Kayıtlar kapalı" (devre dışı; dokunma → TST-X2).
  closed,

  /// "Katıl" → SHT-12.
  join;

  /// [status] durumundaki [event] için düğme; düğme yoksa (`attended`,
  /// `absent`, `past`, `cancelled`, `draft`) `null`.
  static EventCtaKind? of({
    required EventCardStatus? status,
    required EventModel event,
  }) => switch (status) {
    EventCardStatus.going => ticket,
    EventCardStatus.members => applyClub,
    EventCardStatus.waitlist => waitlist,
    EventCardStatus.full => joinWaitlist,
    EventCardStatus.attended ||
    EventCardStatus.absent ||
    EventCardStatus.past ||
    EventCardStatus.cancelled ||
    EventCardStatus.draft => null,
    null => event.registrationOpen ? join : closed,
  };
}

/// Düğmenin çizildiği yer: kart (`sm`, `cards.js:79`) ya da EVT-02 alt
/// çubuğu (tam genişlik; "Katıl" `lg`, `screens-events.js:53`).
enum EventCtaPlacement {
  /// `EventCard` sağ alt — `GuButtonSize.sm`.
  card,

  /// EVT-02 `StickyCTA` — `full`.
  detail,
}

/// `EventCard`'ın hızlı eylemi: tür + dokunma + anahtar (A.2 #54
/// `EventQuickAction`; etiket / varyant / ikon [EventCta]'dan türetilir).
@immutable
final class EventQuickAction {
  /// [kind] düğmesi; [onPressed] devre dışı "Kayıtlar kapalı"da da çağrılır
  /// (TST-X2).
  const EventQuickAction({
    required this.kind,
    required this.onPressed,
    this.actionKey,
  });

  /// Düğme türü.
  final EventCtaKind kind;

  /// Dokunma (devre dışıyken `onDisabledPressed`).
  final VoidCallback onPressed;

  /// Düğmenin anahtarı (`<ID>.join.<eventId>`; çağıran verir — D-18).
  final Key? actionKey;
}

/// Etkinlik katılım düğmesi — [kind] → `GuButton` (etiket, varyant, ikon,
/// devre dışı). Kart ve EVT-02 aynı eşlemeyi kullanır; [placement] boyutu ve
/// kartla EVT-02 arasındaki varyant farkını seçer.
///
/// Anahtar [actionKey] çağırandan gelir (`EVT-01.join.<id>`, `EVT-02.join`
/// …).
class EventCta extends StatelessWidget {
  /// [kind] düğmesi.
  const EventCta({
    required this.kind,
    required this.onPressed,
    this.placement = EventCtaPlacement.card,
    this.loading = false,
    this.actionKey,
    super.key,
  });

  /// Düğme türü.
  final EventCtaKind kind;

  /// Dokunma; [EventCtaKind.closed]'da devre dışı dokunma (TST-X2).
  final VoidCallback onPressed;

  /// Kart ya da EVT-02 alt çubuğu.
  final EventCtaPlacement placement;

  /// Katılım sürerken (EVT-02 `isActing`).
  final bool loading;

  /// Düğmenin anahtarı.
  final Key? actionKey;

  /// Düğme varyantı — kart `cards.js:60–66`, EVT-02 `screens-events.js:49–54`.
  GuButtonVariant get variant => switch ((kind, placement)) {
    (EventCtaKind.ticket, EventCtaPlacement.card) => GuButtonVariant.tonal,
    (EventCtaKind.ticket, EventCtaPlacement.detail) => GuButtonVariant.primary,
    (EventCtaKind.applyClub, _) => GuButtonVariant.outline,
    (EventCtaKind.waitlist, _) => GuButtonVariant.tonal,
    (EventCtaKind.joinWaitlist, EventCtaPlacement.card) =>
      GuButtonVariant.outline,
    (EventCtaKind.joinWaitlist, EventCtaPlacement.detail) =>
      GuButtonVariant.tonal,
    (EventCtaKind.closed, _) => GuButtonVariant.outline,
    (EventCtaKind.join, _) => GuButtonVariant.primary,
  };

  /// Düğme ikonu; yoksa `null` (aynı kaynaklar).
  GuIcons? get icon => switch ((kind, placement)) {
    (EventCtaKind.ticket, _) => GuIcons.ticket,
    (EventCtaKind.applyClub, _) => GuIcons.lock,
    (EventCtaKind.waitlist, _) => GuIcons.hourglass,
    (EventCtaKind.joinWaitlist, EventCtaPlacement.detail) => GuIcons.hourglass,
    (EventCtaKind.joinWaitlist, EventCtaPlacement.card) ||
    (EventCtaKind.closed, _) ||
    (EventCtaKind.join, _) => null,
  };

  /// Düğme boyutu: kartta `sm` (`cards.js:79`); EVT-02 alt çubuğunda "Katıl"
  /// `lg` (`screens-events.js:54`), diğerleri `md`.
  GuButtonSize get size => switch ((kind, placement)) {
    (_, EventCtaPlacement.card) => GuButtonSize.sm,
    (EventCtaKind.join, EventCtaPlacement.detail) => GuButtonSize.lg,
    (_, EventCtaPlacement.detail) => GuButtonSize.md,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (kind) {
      EventCtaKind.ticket => l10n.eventCtaTicket,
      EventCtaKind.applyClub => l10n.eventCtaApplyClub,
      EventCtaKind.waitlist => l10n.statusWaitlist,
      EventCtaKind.joinWaitlist => l10n.eventCtaWaitlist,
      EventCtaKind.closed => l10n.eventCtaClosed,
      EventCtaKind.join => l10n.eventCtaJoin,
    };
    final disabled = kind == EventCtaKind.closed;
    return GuButton(
      key: actionKey,
      label: label,
      variant: variant,
      icon: icon,
      onPressed: disabled ? null : onPressed,
      onDisabledPressed: disabled ? onPressed : null,
      disabled: disabled,
      loading: loading,
      size: size,
      full: placement == EventCtaPlacement.detail,
    );
  }
}
