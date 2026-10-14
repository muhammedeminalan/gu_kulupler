import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/l10n/cancel_reason_labels.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_kulupler/product/widget/event/event_card.dart';
import 'package:gu_kulupler/product/widget/event/event_card_status.dart';
import 'package:gu_ui/gu_ui.dart';

/// EVT-02 üst bölümü — prototip `screens-events.js:55–60`: kapaklı paralaks
/// başlık (geri · paylaş · ⋮ kapak üstü düğmeler), iptal / taslak bandı,
/// başlık + kulüp satırı + tür / görünürlük / durum rozetleri, tarih ve mekân
/// kartı (`GuMapPlaceholder`, yol tarifi).
///
/// * [scrollOffset] kaydırma ofsetidir (`min(220, scrollTop)`), paralaksı
///   sürer.
/// * Kapak 220 dp, ekranın en üstünden başlar (durum çubuğunun altına
///   uzanır; `ClubHeader` ile aynı yerleşim): kaydırma alanı üst güvenli
///   alanın altından başladığı için kapak o kadar yukarı taşar.
/// * Anahtarlar EVT-02'ye özgüdür ve burada yazılır: `EVT-02.back`,
///   `EVT-02.share`, `EVT-02.menu`, `EVT-02.club`, `EVT-02.directions`.
/// * Kapaklı başlıkta durum çubuğu ikonları açıktır (`GuSystemUi` — ekran
///   view'ı kurar).
/// * Tarih kartı: `dateLong` + "saat aralığı · süre" ([timeLabel] —
///   biçimleme view'dadır); mekân kartı: ad + "Kampüs" + "Yol tarifi" +
///   harita yer tutucusu (`eventMapPlaceholder`, CD-88; font CD-19).
class EventHeader extends StatelessWidget {
  /// [event] etkinliğinin üst bölümü.
  const EventHeader({
    required this.event,
    required this.club,
    required this.status,
    required this.placeLabel,
    required this.scrollOffset,
    required this.onBack,
    required this.onShare,
    required this.onMenu,
    required this.onClub,
    required this.onDirections,
    this.dateLabel = '',
    this.timeLabel = '',
    this.coverImage,
    super.key,
  });

  /// Etkinlik.
  final EventModel event;

  /// Düzenleyen kulüp.
  final ClubModel club;

  /// Durum rozeti (`EventCardStatus.of`); yoksa `null`.
  final EventCardStatus? status;

  /// Mekânın gösterilen adı (`EventPlaceLabel.of`).
  final String placeLabel;

  /// Kaydırma ofseti (0–220).
  final double scrollOffset;

  /// Geri (`EVT-02.back`).
  final VoidCallback onBack;

  /// Paylaş (`EVT-02.share`) → SHT-15.
  final VoidCallback onShare;

  /// ⋮ (`EVT-02.menu`) → EVT-MENU / SHT-23.
  final VoidCallback onMenu;

  /// Kulüp satırı (`EVT-02.club`) → CLB-03.
  final VoidCallback onClub;

  /// Yol tarifi (`EVT-02.directions`) → DLG-32.
  final VoidCallback onDirections;

  /// Tarih kartının başlığı (`9 Ekim Cuma`).
  final String dateLabel;

  /// Tarih kartının alt satırı (`18:00–20:00 · 2 sa`).
  final String timeLabel;

  /// Yüklenmiş kapak görseli (`event.coverPath` çözülmüşse); `null` →
  /// şablon kapak (palet × desen, kulübün ikonu).
  final ImageProvider? coverImage;

  /// Kulüp ikonu kayıtta yoksa çizilen ikon (`ClubHeader.fallbackIcon` ile
  /// aynı).
  static const GuIcons fallbackIcon = GuIcons.sparkles;

  Widget _cover() {
    final image = coverImage;
    if (image != null) {
      return GuCover.image(image: image, ratio: GuCoverRatio.fill);
    }
    return GuCover.template(
      palette: CoverMapper.palette(event.coverPalette),
      pattern: CoverMapper.pattern(event.coverPattern),
      icon: CoverMapper.icon(club.iconName),
      ratio: GuCoverRatio.fill,
    );
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final colors = gu.colors;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final status = this.status;
    final reason = CancelReasonLabels.of(l10n, event.cancelReason);
    final isMembers = event.visibility == EventVisibility.membersOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: math.max(0, GuSizes.parallaxHeight - topInset),
          child: OverflowBox(
            alignment: Alignment.bottomCenter,
            minHeight: GuSizes.parallaxHeight,
            maxHeight: GuSizes.parallaxHeight,
            child: GuParallaxHeader(
              scrollOffset: AlwaysStoppedAnimation<double>(scrollOffset),
              cover: _cover(),
              leading: GuIconButton(
                key: GuKey.action('EVT-02.back'),
                icon: GuIcons.arrowLeft,
                semanticLabel: l10n.a11yBack,
                onCover: true,
                onPressed: onBack,
              ),
              actions: [
                GuIconButton(
                  key: GuKey.action('EVT-02.share'),
                  icon: GuIcons.share2,
                  semanticLabel: l10n.commonShare,
                  onCover: true,
                  onPressed: onShare,
                ),
                GuIconButton(
                  key: GuKey.action('EVT-02.menu'),
                  icon: GuIcons.moreVertical,
                  semanticLabel: l10n.a11yMore,
                  onCover: true,
                  onPressed: onMenu,
                ),
              ],
            ),
          ),
        ),
        if (event.status == EventStatus.cancelled)
          GuBanner(
            kind: GuBannerKind.danger,
            icon: GuIcons.calendarX,
            text: reason == null
                ? l10n.eventCancelledBanner
                : l10n.eventCancelledBannerReason(reason),
          ),
        if (event.status == EventStatus.draft)
          GuBanner(
            icon: GuIcons.fileText,
            text: l10n.eventDraftBanner,
          ),
        Padding(
          padding: GuInsets.only(
            left: GuSpacing.s16,
            top: GuSpacing.s16,
            right: GuSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: GuSpacing.s8,
            children: [
              Semantics(
                header: true,
                child: Text(event.title, style: gu.text.titleL),
              ),
              GuTapTarget(
                key: GuKey.action('EVT-02.club'),
                semanticLabel: club.name,
                onTap: onClub,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: GuSpacing.s8,
                  children: [
                    GuEmblem(
                      icon: CoverMapper.icon(club.iconName) ?? fallbackIcon,
                      size: GuEmblemSize.xs,
                    ),
                    Flexible(
                      child: Text(
                        club.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: gu.text.bodyM.copyWith(
                          color: colors.brandPrimaryText,
                          fontWeight: gu.text.labelL.fontWeight,
                        ),
                      ),
                    ),
                    GuIcon(
                      GuIcons.chevronRight,
                      size: GuSizes.icon16,
                      color: colors.textMuted,
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: GuSpacing.s6,
                runSpacing: GuSpacing.s6,
                children: [
                  GuBadge(label: StaticLabels.eventType(context, event.type)),
                  GuBadge(
                    label: isMembers
                        ? l10n.eventVisibilityMembers
                        : l10n.eventVisibilityPublic,
                    kind: isMembers ? GuBadgeKind.info : GuBadgeKind.success,
                    icon: isMembers ? GuIcons.lock : GuIcons.globe,
                  ),
                  if (status != null)
                    GuStatusBadge(
                      kind: EventCard.badgeKindOf(status),
                      label: EventCard.badgeLabelOf(l10n, status),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: GuInsets.only(
            left: GuSpacing.s16,
            top: GuSpacing.s16,
            right: GuSpacing.s16,
          ),
          child: GuCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GuTile(
                  padding: GuTilePadding.inCard,
                  leading: const GuIconBox(icon: GuIcons.calendarDays),
                  title: dateLabel,
                  subtitle: timeLabel,
                ),
                const GuDivider(),
                GuTile(
                  padding: GuTilePadding.inCard,
                  leading: const GuIconBox(
                    icon: GuIcons.mapPin,
                    tone: GuIconBoxTone.info,
                  ),
                  title: placeLabel,
                  subtitle: l10n.eventPlaceCampus,
                  trailing: GuButton(
                    key: GuKey.action('EVT-02.directions'),
                    label: l10n.eventDirections,
                    icon: GuIcons.navigation,
                    size: GuButtonSize.sm,
                    variant: GuButtonVariant.text,
                    onPressed: onDirections,
                  ),
                ),
                Padding(
                  padding: GuInsets.only(
                    left: GuSpacing.s16,
                    right: GuSpacing.s16,
                    bottom: GuSpacing.s16,
                  ),
                  child: GuMapPlaceholder(
                    label: l10n.eventMapPlaceholder(placeLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
