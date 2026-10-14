import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_kulupler/product/widget/event/event_card_status.dart';
import 'package:gu_kulupler/product/widget/event/event_cta.dart';
import 'package:gu_kulupler/product/widget/event/event_place_label.dart';
import 'package:gu_ui/gu_ui.dart';

/// Etkinlik kartı — prototip `EventCard` (`cards.js:68–80`): EVT-01 listesi
/// ve takvim günü (`compact`), CLB-03 "Etkinlikler" sekmesi (`compact`,
/// `showClub: false`), CLB-02 etkinlik sonuçları, MGT-05 önizleme.
///
/// * Girdi alan modelidir: [event] + [club] + türetilmiş [status]
///   (`EventCardStatus.of`) + [registeredCount] (`event.goingCount`).
/// * [quickAction] sağ alttaki `EventCta(sm)` düğmesidir
///   (`EventCtaKind.of`); `null` → düğme yok.
/// * Karta dokunma [onOpen] (EVT-02); kulüp adı [onClub] (CLB-03).
/// * Anahtarları çağıran verir (D-18, CD-86): [actionKey]
///   `<ID>.card.<eventId>`, [clubKey] `<ID>.club.<eventId>`, düğme
///   `EventQuickAction.actionKey` `<ID>.join.<eventId>`.
///
/// Çizim (`cards.js:70–79`): dolgu 12, aralık 12 —
///
/// | Sol sütun (aralık 8, ortalı) | Sağ sütun (aralık 4) |
/// |---|---|
/// | `GuDateBadge` (Istanbul günü + büyük harf kısa ay) | başlık (`titleS`, 2 satır) + durum rozeti |
/// | `compact` değilse 48 dp 1:1 kapak (radius `chip` 10) | kulüp adı (`caption`, `brandPrimaryText`, tek satır) |
/// | | saat · mekân (`bodyS`, ikincil; ikon 14) |
/// | | kontenjan çubuğu (ince) + `N/K` ya da "Sınırsız · N kayıtlı" |
/// | | sağa yaslı hızlı eylem |
///
/// Kapak: [coverImage] verilirse yüklenmiş görsel (`event.coverPath`;
/// çağıran `lib/product/media` çözücüsüyle kurar), yoksa etkinliğin
/// palet × desen şablonu, gömülü ikon kulübün ikonu (kulüp yoksa takvim).
///
/// Erişilebilirlik: kart tek düğmedir; etiketi tarih + başlık + rozet + saat
/// · mekân + kontenjan metinlerinden birleşir. Kulüp adı ve hızlı eylem
/// kartın içinde ayrı düğmelerdir.
///
/// ```dart
/// EventCard(
///   event: event,
///   club: clubs[event.clubId],
///   status: EventCardStatus.of(event: event, rsvp: rsvp,
///       canSeeInside: inside, nowUtc: clock.nowUtc()),
///   registeredCount: event.goingCount,
///   quickAction: EventQuickAction(kind: kind, onPressed: () => …,
///       actionKey: GuKey.action('EVT-01.join.${event.id}')),
///   actionKey: GuKey.action('EVT-01.card.${event.id}'),
///   clubKey: GuKey.action('EVT-01.club.${event.id}'),
///   onOpen: () => open(event),
///   onClub: () => openClub(event.clubId),
/// )
/// ```
class EventCard extends ConsumerWidget {
  /// [event] etkinliğinin kartı.
  const EventCard({
    required this.event,
    required this.club,
    required this.status,
    required this.registeredCount,
    required this.onOpen,
    this.quickAction,
    this.onClub,
    this.compact = false,
    this.showClub = true,
    this.highlight = false,
    this.actionKey,
    this.clubKey,
    this.coverImage,
    super.key,
  });

  /// Kontenjan çubuğunun uyarı rengine döndüğü doluluk oranı (`cards.js:77`
  /// `reg / capacity > 0.85`).
  static const double capacityWarningRatio = 0.85;

  /// Durum rozetinin başlık satırında kaplayabileceği en büyük pay (dar
  /// ekranda / büyük metinde başlık sıkışmasın; rozet metni kısalır).
  static const double _badgeMaxShare = 0.5;

  /// Saat ile mekân arasındaki ayraç (`cards.js:76` `' · '`).
  static const String _separator = ' · ';

  /// `.tnum` (saat, `N/K`).
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Kulüp kaydı okunamadığında kapak şablonundaki ikon (`cards.js:72`
  /// `'calendar'`).
  static const GuIcons fallbackIcon = GuIcons.calendar;

  /// Etkinlik.
  final EventModel event;

  /// Düzenleyen kulüp; okunamadıysa `null` (kulüp satırı ve kapak ikonu
  /// yedeğe düşer).
  final ClubModel? club;

  /// Durum rozeti; yoksa `null`.
  final EventCardStatus? status;

  /// Kayıtlı sayısı (kontenjan çubuğu / "Sınırsız · N kayıtlı").
  final int registeredCount;

  /// Sağ alttaki hızlı eylem; yoksa `null`.
  final EventQuickAction? quickAction;

  /// Karta dokunma — EVT-02.
  final VoidCallback onOpen;

  /// Kulüp adına dokunma — CLB-03; `null` ya da [showClub] `false` → satır
  /// yok.
  final VoidCallback? onClub;

  /// Yalnızca tarih rozeti (kapak yok).
  final bool compact;

  /// Kulüp adı satırı.
  final bool showClub;

  /// 1,5 sn vurgu halkası (`GuCard.highlight`).
  final bool highlight;

  /// Kartın anahtarı (`<ID>.card.<eventId>`).
  final Key? actionKey;

  /// Kulüp satırının anahtarı (`<ID>.club.<eventId>`).
  final Key? clubKey;

  /// Yüklenmiş kapak görseli (`event.coverPath` çözülmüşse); `null` →
  /// şablon kapak.
  final ImageProvider? coverImage;

  /// [status] → rozet türü (`STATUS_BADGE`, `ui.js`); EVT-02 başlığı da
  /// kullanır.
  static GuStatusBadgeKind badgeKindOf(EventCardStatus status) =>
      switch (status) {
        EventCardStatus.cancelled => GuStatusBadgeKind.cancelled,
        EventCardStatus.draft => GuStatusBadgeKind.draft,
        EventCardStatus.attended => GuStatusBadgeKind.attended,
        EventCardStatus.absent => GuStatusBadgeKind.absent,
        EventCardStatus.past => GuStatusBadgeKind.past,
        EventCardStatus.waitlist => GuStatusBadgeKind.waitlist,
        EventCardStatus.going => GuStatusBadgeKind.going,
        EventCardStatus.members => GuStatusBadgeKind.members,
        EventCardStatus.full => GuStatusBadgeKind.full,
      };

  /// [status] rozetinin metni (`t('status.' + st)`).
  static String badgeLabelOf(AppLocalizations l10n, EventCardStatus status) =>
      switch (status) {
        EventCardStatus.cancelled => l10n.statusCancelled,
        EventCardStatus.draft => l10n.statusDraft,
        EventCardStatus.attended => l10n.statusAttended,
        EventCardStatus.absent => l10n.statusAbsent,
        EventCardStatus.past => l10n.statusPast,
        EventCardStatus.waitlist => l10n.statusWaitlist,
        EventCardStatus.going => l10n.statusGoing,
        EventCardStatus.members => l10n.statusMembers,
        EventCardStatus.full => l10n.statusFull,
      };

  /// Kontenjan çubuğunun rengi (`cards.js:77`): dolu → soluk, %85 üstü →
  /// uyarı, değilse marka.
  static GuProgressKind capacityKindOf(int registered, int capacity) {
    if (registered >= capacity) return GuProgressKind.muted;
    if (capacity > 0 && registered / capacity > capacityWarningRatio) {
      return GuProgressKind.warning;
    }
    return GuProgressKind.brand;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = Localizations.localeOf(context);
    final formats = AppDateFormats(locale, ref.watch(appClockProvider));
    final action = quickAction;
    final clubModel = club;
    final clubTap = onClub;
    return GuCard(
      key: actionKey,
      onTap: onOpen,
      highlight: highlight,
      padding: GuInsets.all12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: GuSpacing.s12,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: GuSpacing.s8,
            children: [
              GuDateBadge(
                day: AppDateFormats.toIstanbul(event.startsAt).day,
                monthShort: formats.monthShort(event.startsAt).upperFor(locale),
                semanticLabel: formats.date(event.startsAt),
              ),
              if (!compact) _cover(),
            ],
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: GuSpacing.s4,
              children: [
                _titleRow(context),
                if (showClub && clubModel != null && clubTap != null)
                  _clubLine(context, clubModel, clubTap),
                _whenWhere(context, formats),
                _capacity(context),
                if (action != null)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: EventCta(
                      kind: action.kind,
                      onPressed: action.onPressed,
                      actionKey: action.actionKey,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 48 dp kare kapak (`cards.js:72` `width:48px; border-radius:10px` —
  /// tarih rozetiyle aynı genişlik).
  Widget _cover() {
    final image = coverImage;
    if (image != null) {
      return GuCover.image(
        image: image,
        ratio: GuCoverRatio.r1x1,
        size: GuSizes.dateBadgeWidth,
        borderRadius: GuRadius.borderChip,
      );
    }
    final clubModel = club;
    return GuCover.template(
      palette: CoverMapper.palette(event.coverPalette),
      pattern: CoverMapper.pattern(event.coverPattern),
      icon: clubModel == null
          ? fallbackIcon
          : CoverMapper.icon(clubModel.iconName) ?? fallbackIcon,
      ratio: GuCoverRatio.r1x1,
      size: GuSizes.dateBadgeWidth,
      borderRadius: GuRadius.borderChip,
    );
  }

  /// Başlık (2 satır) + durum rozeti (`row gap6 start`).
  Widget _titleRow(BuildContext context) {
    final title = Text(
      event.title,
      style: context.gu.text.titleS,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final current = status;
    if (current == null) return title;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: GuSpacing.s6,
        children: [
          Expanded(child: title),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * _badgeMaxShare,
            ),
            child: GuStatusBadge(
              kind: badgeKindOf(current),
              label: badgeLabelOf(context.l10n, current),
            ),
          ),
        ],
      ),
    );
  }

  /// Kulüp adı (`t-caption c-brand ellipsis`, sola yaslı düğme).
  Widget _clubLine(
    BuildContext context,
    ClubModel clubModel,
    VoidCallback tap,
  ) {
    final gu = context.gu;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: GuTapTarget(
        key: clubKey,
        onTap: tap,
        child: Text(
          clubModel.name,
          style: gu.text.caption.copyWith(color: gu.colors.brandPrimaryText),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Saat · mekân (`t-body-s c-sec row gap4`, ikonlar 14).
  Widget _whenWhere(BuildContext context, AppDateFormats formats) {
    final gu = context.gu;
    final style = gu.text.bodyS.copyWith(color: gu.colors.textSecondary);
    final place = EventPlaceLabel.of(context, event);
    return Row(
      spacing: GuSpacing.s4,
      children: [
        GuIcon(GuIcons.clock, size: GuSizes.icon14, color: style.color),
        Text(
          formats.time(event.startsAt) + _separator,
          style: style.copyWith(fontFeatures: _tabular),
          maxLines: 1,
        ),
        GuIcon(GuIcons.mapPin, size: GuSizes.icon14, color: style.color),
        Expanded(
          child: Text(
            place.isEmpty ? context.l10n.eventPlaceTbd : place,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Kontenjan çubuğu + `N/K` ya da "Sınırsız · N kayıtlı".
  Widget _capacity(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final caption = gu.text.caption;
    final capacity = event.capacity;
    if (capacity == null) {
      return Text(
        l10n.eventUnlimited +
            _separator +
            l10n.eventRegisteredCount(
              registeredCount,
            ),
        style: caption,
      );
    }
    return Row(
      spacing: GuSpacing.s8,
      children: [
        Expanded(
          child: GuProgress(
            value: registeredCount.toDouble(),
            max: capacity.toDouble(),
            kind: capacityKindOf(registeredCount, capacity),
            thin: true,
            semanticLabel: l10n.eventCapacity,
          ),
        ),
        Text(
          '$registeredCount/$capacity',
          style: caption.copyWith(fontFeatures: _tabular),
          maxLines: 1,
        ),
      ],
    );
  }
}
