import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/widget/event/qr_code_view.dart';
import 'package:gu_ui/gu_ui.dart';

/// EVT-03 bilet kartı — prototip `.ticket` (`screens-events.js:81–83`):
/// üstte kulüp (overline) + başlık + durum rozeti + tarih / mekân, kesik
/// çizgi, altta `QrCodeView` + (okutulduysa) okutulma satırı + bilet kodu
/// (`GuTypography.ticketCode`) + sahibin adı.
///
/// [state] `valid` / `used` / `voided` (`RsvpModel.ticketState(event)`);
/// görünüm farkı `QrCodeView` ve `GuStatusBadge`'dedir. Tarih ve okutulma
/// metinleri biçimlenmiş gelir ([dateLabel], [scannedAtLabel]; saat
/// `AppClock` / `AppDateFormats` view'dadır).
class TicketCard extends StatelessWidget {
  /// [rsvp] biletinin kartı.
  const TicketCard({
    required this.event,
    required this.rsvp,
    required this.state,
    required this.clubName,
    required this.holderName,
    required this.placeLabel,
    required this.qrSemanticLabel,
    this.dateLabel = '',
    this.scannedAtLabel,
    super.key,
  });

  /// Etkinlik.
  final EventModel event;

  /// Kullanıcının katılım kaydı (bilet kodu, `scannedAt`).
  final RsvpModel rsvp;

  /// Bilet durumu.
  final TicketState state;

  /// Düzenleyen kulübün adı.
  final String clubName;

  /// Bilet sahibinin adı (`SessionState` profil adı).
  final String holderName;

  /// Mekânın gösterilen adı (`EventPlaceLabel.of`); boşsa satır yok.
  final String placeLabel;

  /// QR'ın ekran okuyucu etiketi.
  final String qrSemanticLabel;

  /// Başlangıç anı (`AppDateFormats.dateTime`: "9 Eki Cum, 18:00"); boşsa
  /// satır yok.
  final String dateLabel;

  /// "Okutuldu: {time}" satırı — yalnızca [state] `used` iken çizilir.
  final String? scannedAtLabel;

  /// [state] rozetinin türü (registry `statusBadge.valid/used/void`).
  static GuStatusBadgeKind badgeKindOf(TicketState state) => switch (state) {
    TicketState.valid => GuStatusBadgeKind.valid,
    TicketState.used => GuStatusBadgeKind.used,
    TicketState.voided => GuStatusBadgeKind.voided,
  };

  /// [state] rozetinin metni (`ticket.status.<valid|used|void>`).
  static String badgeLabelOf(AppLocalizations l10n, TicketState state) =>
      switch (state) {
        TicketState.valid => l10n.ticketStatusValid,
        TicketState.used => l10n.ticketStatusUsed,
        TicketState.voided => l10n.ticketStatusVoid,
      };

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final scanned = scannedAtLabel;
    return GuTicketFrame(
      // `.card-body.col.gap8` (screens-events.js:81).
      header: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s8,
        children: [
          // `.row.between.start`: kulüp + başlık | durum rozeti.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: GuSpacing.s8,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: GuSpacing.s4,
                  children: [
                    Text(clubName.upperFor(locale), style: gu.text.overline),
                    Semantics(
                      header: true,
                      child: Text(event.title, style: gu.text.titleM),
                    ),
                  ],
                ),
              ),
              GuStatusBadge(
                kind: badgeKindOf(state),
                label: badgeLabelOf(l10n, state),
              ),
            ],
          ),
          if (dateLabel.isNotEmpty)
            _MetaRow(icon: GuIcons.calendarDays, text: dateLabel),
          if (placeLabel.isNotEmpty)
            _MetaRow(icon: GuIcons.mapPin, text: placeLabel),
        ],
      ),
      // `.card-body.col.gap12` ortalı (screens-events.js:83).
      body: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: GuSpacing.s12,
        children: [
          QrCodeView(
            data: rsvp.qrPayload,
            state: state,
            semanticLabel: qrSemanticLabel,
          ),
          if (state == TicketState.used && scanned != null)
            // `.row.gap6.c-success.t-label-l` + `circle-check` 18.
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: GuSpacing.s6,
              children: [
                GuIcon(
                  GuIcons.circleCheck,
                  size: GuSizes.icon18,
                  color: gu.colors.stateSuccess,
                ),
                Flexible(
                  child: Text(
                    scanned,
                    style: gu.text.labelL.copyWith(
                      color: gu.colors.stateSuccess,
                    ),
                  ),
                ),
              ],
            ),
          // `.t-title-s.tnum` + `letter-spacing:.12em` (`ticketCode`).
          Text(
            rsvp.ticketCode,
            style: gu.text.ticketCode,
            textAlign: TextAlign.center,
          ),
          // `.t-body-m.c-heading`.
          Text(
            holderName,
            style: gu.text.bodyM.copyWith(color: gu.colors.textHeading),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// `.t-body-s.c-sec.row.gap4` + 14 px ikon (tarih, mekân).
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final GuIcons icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final color = gu.colors.textSecondary;
    return Row(
      spacing: GuSpacing.s4,
      children: [
        GuIcon(icon, size: GuSizes.icon14, color: color),
        Expanded(
          child: Text(text, style: gu.text.bodyS.copyWith(color: color)),
        ),
      ],
    );
  }
}
