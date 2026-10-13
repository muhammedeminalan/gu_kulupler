import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/clubs/provider/club_detail_state.dart';
import 'package:gu_kulupler/product/widget/club/club_cta.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-03 alt eylem çubuğu — prototip `screens-clubs.js:108–111`; kullanıcının
/// kulüpteki kipine göre:
///
/// | Kip | İçerik |
/// |---|---|
/// | askıdaki kulüp, üye | çubuk yok ([hasBar] `false`) |
/// | yönetici, süper admin | "Yönetim" (`layout-grid`) + tonal "Etkinlik oluştur" (`calendar-plus`) |
/// | danışman | tonal "Yönetimi görüntüle" (`eye`) |
/// | diğerleri | (not satırı) + [cta] (`ClubCta`, büyük, tam genişlik) |
///
/// Not satırı (`caption`, ortalı): başvurular kapalıysa "Başvurular şu an
/// kapalı"; reddedilmiş kullanıcının beklemesi sürüyorsa "Tekrar
/// başvurabileceğin tarih: {tarih}" ([retryNote]).
///
/// Anahtarlar çağırandan gelir (D-18): [manageKey], [createEventKey].
class ClubDetailCtaBar extends StatelessWidget {
  /// [state] durumundaki kulübün alt çubuğu.
  const ClubDetailCtaBar({
    required this.state,
    required this.cta,
    required this.onManage,
    required this.onCreateEvent,
    this.retryNote,
    this.manageKey,
    this.createEventKey,
    super.key,
  });

  /// Ekranın durumu (`club` dolu olmalı).
  final ClubDetailState state;

  /// Katılım eylemi (`ClubCta`, büyük + tam genişlik).
  final Widget cta;

  /// Bekleme notu ("Tekrar başvurabileceğin tarih: …"); bekleme yoksa `null`.
  final String? retryNote;

  /// "Yönetim" / "Yönetimi görüntüle" (`CLB-03.openManage`).
  final VoidCallback onManage;

  /// "Etkinlik oluştur" (`CLB-03.createEvent`).
  final VoidCallback onCreateEvent;

  /// Yönetim düğmesinin anahtarı.
  final Key? manageKey;

  /// "Etkinlik oluştur" düğmesinin anahtarı.
  final Key? createEventKey;

  /// [state] için alt çubuk çizilir mi? Askıdaki kulüpte ve sıradan üyede
  /// çubuk yoktur.
  static bool hasBar(ClubDetailState state) {
    final club = state.club;
    return club != null &&
        !club.isSuspended &&
        state.access != ClubAccess.member;
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final club = state.club;
    if (club == null || !hasBar(state)) return const SizedBox.shrink();

    if (state.canManage) {
      return GuStickyCta(
        children: [
          GuButton(
            key: manageKey,
            label: l10n.clubCtaManage,
            icon: GuIcons.layoutGrid,
            onPressed: onManage,
          ),
          GuButton(
            key: createEventKey,
            label: l10n.clubCtaCreateEvent,
            icon: GuIcons.calendarPlus,
            variant: GuButtonVariant.tonal,
            onPressed: onCreateEvent,
          ),
        ],
      );
    }
    if (state.access == ClubAccess.advisor) {
      return GuStickyCta(
        children: [
          GuButton(
            key: manageKey,
            label: l10n.clubCtaViewManage,
            icon: GuIcons.eye,
            variant: GuButtonVariant.tonal,
            onPressed: onManage,
          ),
        ],
      );
    }

    final closed =
        ClubCta.kindOf(
          club: club,
          access: state.access,
          membershipStatus: state.membership?.status,
        ) ==
        ClubCtaKind.closed;
    final note = closed
        ? l10n.clubClosedNote
        : state.access == ClubAccess.rejected
        ? retryNote
        : null;
    return GuStickyCta(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: GuSpacing.s4,
            children: [
              if (note != null)
                Text(
                  note,
                  style: gu.text.caption,
                  textAlign: TextAlign.center,
                ),
              cta,
            ],
          ),
        ),
      ],
    );
  }
}
