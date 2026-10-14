import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/events/provider/event_detail_state.dart';
import 'package:gu_kulupler/product/widget/event/event_cta.dart';
import 'package:gu_ui/gu_ui.dart';

/// EVT-02 alt çubuğu — prototip `cta()` (`screens-events.js:44–53`); tür
/// [EventDetailState.barAt]'tan gelir:
///
/// | [bar] | Çizim | Anahtarlar |
/// |---|---|---|
/// | `cancelled` | iptal bandı (çubuk yok) | — |
/// | `manager` | Düzenle (outline) · Katılımcılar (tonal) · Yoklama başlat | `EVT-02.edit`, `.attendees`, `.scan` |
/// | `advisor` | salt okunur bandı | — |
/// | `ended` | yoklaması alınmışsa "Katıldın" rozeti; değilse devre dışı "Etkinlik sona erdi" (TST-X6) | `EVT-02.ended` |
/// | `going` | "Vazgeç" (metin) · "Biletini göster" | `EVT-02.leave`, `.ticket` |
/// | `waitlist` | sıra + not · "Ayrıl" (outline) | `EVT-02.leave` |
/// | `cta` | `EventCta(detail)`: kulübe başvur · bekleme listesine katıl · kayıtlar kapalı · katıl | `EVT-02.applyClub`, `.waitlist`, `.join` |
///
/// Bekleme sırası ([waitlistPosition]) yalnızca bu ekranda katılınca
/// bilinir (W-76); bilinmiyorsa sırasız "Bekleme listesindesin".
class EventDetailCtaBar extends StatelessWidget {
  /// [bar] türündeki alt çubuk.
  const EventDetailCtaBar({
    required this.bar,
    required this.onJoin,
    required this.onClosed,
    required this.onJoinWaitlist,
    required this.onApplyClub,
    required this.onTicket,
    required this.onLeave,
    required this.onEnded,
    required this.onEdit,
    required this.onAttendees,
    required this.onScan,
    this.ctaKind,
    this.attended = false,
    this.waitlistPosition,
    this.cancelledText = '',
    this.isActing = false,
    super.key,
  });

  /// Çubuğun türü.
  final EventDetailBar bar;

  /// [EventDetailBar.cta] düğmesi (`EventCtaKind.of`); `null` → çubuk yok.
  final EventCtaKind? ctaKind;

  /// Bitmiş etkinlikte yoklaması alındı mı ("Katıldın" rozeti)?
  final bool attended;

  /// Bekleme sırası; bilinmiyorsa `null`.
  final int? waitlistPosition;

  /// İptal bandının metni.
  final String cancelledText;

  /// Katılım / vazgeçme sürüyor mu (düğme meşgul)?
  final bool isActing;

  /// "Katıl" → SHT-12.
  final VoidCallback onJoin;

  /// Devre dışı "Kayıtlar kapalı" → TST-X2.
  final VoidCallback onClosed;

  /// "Bekleme listesine katıl" → DLG-15.
  final VoidCallback onJoinWaitlist;

  /// "Kulübe başvur" → CLB-03.
  final VoidCallback onApplyClub;

  /// "Biletini göster" → EVT-03.
  final VoidCallback onTicket;

  /// "Vazgeç" / "Ayrıl" → DLG-14.
  final VoidCallback onLeave;

  /// Devre dışı "Etkinlik sona erdi" → TST-X6.
  final VoidCallback onEnded;

  /// "Düzenle" → MGT-05.
  final VoidCallback onEdit;

  /// "Katılımcılar" → MGT-06.
  final VoidCallback onAttendees;

  /// "Yoklama başlat" → MGT-07.
  final VoidCallback onScan;

  /// Alttaki bant (iptal, danışman): çubuk zemini olmadan, alt güvenli alan
  /// payıyla.
  Widget _banner(Widget banner) => SafeArea(top: false, child: banner);

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final colors = gu.colors;
    switch (bar) {
      case EventDetailBar.cancelled:
        return _banner(
          GuBanner(
            kind: GuBannerKind.danger,
            icon: GuIcons.calendarX,
            text: cancelledText,
          ),
        );
      case EventDetailBar.manager:
        return GuStickyCta(
          children: [
            GuButton(
              key: GuKey.action('EVT-02.edit'),
              label: l10n.commonEdit,
              icon: GuIcons.pencil,
              variant: GuButtonVariant.outline,
              onPressed: onEdit,
            ),
            GuButton(
              key: GuKey.action('EVT-02.attendees'),
              label: l10n.eventCtaAttendees,
              icon: GuIcons.users,
              variant: GuButtonVariant.tonal,
              onPressed: onAttendees,
            ),
            GuButton(
              key: GuKey.action('EVT-02.scan'),
              label: l10n.eventCtaScan,
              icon: GuIcons.scanLine,
              onPressed: onScan,
            ),
          ],
        );
      case EventDetailBar.advisor:
        return _banner(
          GuBanner(kind: GuBannerKind.readonly, text: l10n.mgtReadOnlyBanner),
        );
      case EventDetailBar.ended:
        return GuStickyCta(
          children: [
            if (attended)
              Expanded(
                child: Center(
                  child: GuStatusBadge(
                    kind: GuStatusBadgeKind.attended,
                    label: l10n.statusAttended,
                  ),
                ),
              )
            else
              GuButton(
                key: GuKey.action('EVT-02.ended'),
                label: l10n.eventEnded,
                variant: GuButtonVariant.outline,
                disabled: true,
                full: true,
                onPressed: null,
                onDisabledPressed: onEnded,
              ),
          ],
        );
      case EventDetailBar.going:
        return GuStickyCta(
          children: [
            GuButton(
              key: GuKey.action('EVT-02.leave'),
              label: l10n.eventCtaLeave,
              variant: GuButtonVariant.text,
              disabled: isActing,
              onPressed: onLeave,
            ),
            Expanded(
              child: EventCta(
                kind: EventCtaKind.ticket,
                placement: EventCtaPlacement.detail,
                actionKey: GuKey.action('EVT-02.ticket'),
                onPressed: onTicket,
              ),
            ),
          ],
        );
      case EventDetailBar.waitlist:
        final position = waitlistPosition;
        return GuStickyCta(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    position == null
                        ? l10n.eventWaitlistIn
                        : l10n.eventWaitlistPos(position),
                    style: gu.text.labelL.copyWith(color: colors.textHeading),
                  ),
                  Text(l10n.eventWaitlistNote, style: gu.text.caption),
                ],
              ),
            ),
            GuButton(
              key: GuKey.action('EVT-02.leave'),
              label: l10n.eventCtaLeaveWaitlist,
              variant: GuButtonVariant.outline,
              loading: isActing,
              onPressed: onLeave,
            ),
          ],
        );
      case EventDetailBar.cta:
        final kind = ctaKind;
        if (kind == null) return const SizedBox.shrink();
        final (key, onPressed) = switch (kind) {
          EventCtaKind.applyClub => (
            GuKey.action('EVT-02.applyClub'),
            onApplyClub,
          ),
          EventCtaKind.joinWaitlist => (
            GuKey.action('EVT-02.waitlist'),
            onJoinWaitlist,
          ),
          EventCtaKind.closed => (GuKey.action('EVT-02.join'), onClosed),
          EventCtaKind.join => (GuKey.action('EVT-02.join'), onJoin),
          // Kayıtlı / bekleyen kullanıcının çubuğu ayrıdır (`going`,
          // `waitlist`); bu türler buraya düşmez.
          EventCtaKind.ticket => (GuKey.action('EVT-02.ticket'), onTicket),
          EventCtaKind.waitlist => (GuKey.action('EVT-02.leave'), onLeave),
        };
        return GuStickyCta(
          children: [
            Expanded(
              child: EventCta(
                kind: kind,
                placement: EventCtaPlacement.detail,
                loading: isActing,
                actionKey: key,
                onPressed: onPressed,
              ),
            ),
          ],
        );
    }
  }
}
