import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/event/event_card.dart';
import 'package:gu_ui/gu_ui.dart';

/// EVT-02 gövdesi (tarih / mekân kartından sonrası) — prototip
/// `screens-events.js:61–74`: kontenjan kartı, hatırlatıcı + takvim kartı,
/// açıklama ("Devamı"), katılımcı satırı, şikayet.
///
/// * Kontenjan: "Kontenjan" + `kayıtlı/kontenjan` (ya da "Sınırsız");
///   kontenjanlıda çubuk (dolu → soluk, %85 üstü → uyarı) + "Kontenjan
///   doldu" / "{n} kişi kaldı" ve bekleyen varsa " · {n} kişi bekliyor".
///   Kayıtlı = `goingCount` (yoklaması alınanlar dahil — CD-130).
/// * Hatırlatıcı + takvim kartı yalnızca [showReminder] (bitmemiş, iptal
///   edilmemiş etkinlik); hatırlatıcı alt satırı [reminderLabel] (`null` →
///   "Katıldıktan sonra ayarlanır").
/// * Açıklama 3 satıra kırpılır; metin [readMoreMinLength] karakterden
///   uzunsa "Devamı" (`screens-events.js:73` `ev.desc.length > 160`).
/// * Katılımcı satırı yalnızca [showAttendees] (kulübün içini gören, kayıtlı
///   var). Kayıt listesi katılımcıya kapalıdır (rsvp okuma kuralı — T-22
///   §6.7): avatarlar çizilmez, grup "+N" hapıyla toplamı gösterir
///   (prototip `AvatarGroup users=[] total=N`).
/// * Şikayet yalnızca [showReport] (yönetici ve danışman değil).
///
/// Anahtarlar EVT-02'ye özgüdür: `EVT-02.reminder`, `EVT-02.addToCalendar`,
/// `EVT-02.more`, `EVT-02.attendeesPreview`, `EVT-02.report`.
class EventDetailSections extends StatelessWidget {
  /// [event] etkinliğinin gövdesi.
  const EventDetailSections({
    required this.event,
    required this.expanded,
    required this.onReminder,
    required this.onCalendar,
    required this.onReadMore,
    required this.onAttendees,
    required this.onReport,
    this.showReminder = true,
    this.reminderLabel,
    this.showAttendees = false,
    this.showReport = true,
    super.key,
  });

  /// Etkinlik.
  final EventModel event;

  /// Açıklama açık mı ("Devamı"ya dokunuldu)?
  final bool expanded;

  /// Hatırlatıcı + takvim kartı çizilir mi?
  final bool showReminder;

  /// Kullanıcının hatırlatıcı tercihinin adı; kayıt yoksa `null`.
  final String? reminderLabel;

  /// Katılımcı satırı çizilir mi?
  final bool showAttendees;

  /// "Etkinliği şikayet et" çizilir mi?
  final bool showReport;

  /// Hatırlatıcı satırı (`EVT-02.reminder`).
  final VoidCallback onReminder;

  /// Takvime ekle satırı (`EVT-02.addToCalendar`).
  final VoidCallback onCalendar;

  /// "Devamı" (`EVT-02.more`).
  final VoidCallback onReadMore;

  /// Katılımcı satırı (`EVT-02.attendeesPreview`).
  final VoidCallback onAttendees;

  /// Şikayet (`EVT-02.report`).
  final VoidCallback onReport;

  /// Açıklamanın kapalıyken gösterilen satır sayısı (`.clamp3`).
  static const int collapsedLines = 3;

  /// "Devamı"nın çizildiği en kısa açıklama uzunluğu (karakter).
  static const int readMoreMinLength = 160;

  /// Metin parçaları arasındaki ayraç (`·`).
  static const String separator = ' · ';

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final colors = gu.colors;
    final registered = event.goingCount;
    final capacity = event.capacity;
    final showMore = !expanded && event.desc.length > readMoreMinLength;

    return Padding(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        top: GuSpacing.s12,
        right: GuSpacing.s16,
        bottom: GuSpacing.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s12,
        children: [
          GuCard(
            padding: GuCard.bodyPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: GuSpacing.s8,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        spacing: GuSpacing.s6,
                        children: [
                          GuIcon(
                            GuIcons.users,
                            size: GuSizes.icon18,
                            color: colors.textHeading,
                          ),
                          Flexible(
                            child: Text(
                              l10n.eventCapacity,
                              style: gu.text.labelL.copyWith(
                                color: colors.textHeading,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      capacity == null
                          ? l10n.eventUnlimited
                          : '$registered/$capacity',
                      style: gu.text.caption.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (capacity != null) ...[
                  GuProgress(
                    value: registered.toDouble(),
                    max: capacity.toDouble(),
                    kind: EventCard.capacityKindOf(registered, capacity),
                    semanticLabel: l10n.eventCapacity,
                  ),
                  Text(
                    [
                      if (registered >= capacity)
                        l10n.eventFull
                      else
                        l10n.eventRemaining(capacity - registered),
                      if (event.waitlistCount > 0)
                        l10n.eventWaitlistCount(event.waitlistCount),
                    ].join(separator),
                    style: gu.text.bodyS.copyWith(color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (showReminder)
            GuCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GuTile(
                    key: GuKey.action('EVT-02.reminder'),
                    padding: GuTilePadding.inCard,
                    leading: GuIcon(
                      GuIcons.bellRing,
                      size: GuSizes.icon20,
                      color: colors.brandPrimaryText,
                    ),
                    title: l10n.eventReminder,
                    subtitle: reminderLabel ?? l10n.eventReminderAfterJoin,
                    chevron: true,
                    onTap: onReminder,
                  ),
                  const GuDivider(),
                  GuTile(
                    key: GuKey.action('EVT-02.addToCalendar'),
                    padding: GuTilePadding.inCard,
                    leading: GuIcon(
                      GuIcons.calendarPlus,
                      size: GuSizes.icon20,
                      color: colors.brandPrimaryText,
                    ),
                    title: l10n.eventAddToCalendar,
                    chevron: true,
                    onTap: onCalendar,
                  ),
                ],
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: GuSpacing.s6,
            children: [
              Semantics(
                header: true,
                child: Text(l10n.eventAbout, style: gu.text.titleS),
              ),
              Text(
                event.desc,
                maxLines: expanded ? null : collapsedLines,
                overflow: expanded ? null : TextOverflow.ellipsis,
                style: gu.text.bodyM.copyWith(color: colors.textSecondary),
              ),
              if (showMore)
                GuTapTarget(
                  key: GuKey.action('EVT-02.more'),
                  onTap: onReadMore,
                  child: Text(
                    l10n.commonReadMore,
                    style: gu.text.labelL.copyWith(
                      color: colors.brandPrimaryText,
                    ),
                  ),
                ),
            ],
          ),
          // `.row.gap10`: `.gap10` CSS'te tanımsız → aralık yok (K-42).
          if (showAttendees && registered > 0)
            GuTapTarget(
              key: GuKey.action('EVT-02.attendeesPreview'),
              semanticLabel: l10n.eventAttendees,
              onTap: onAttendees,
              child: Row(
                children: [
                  GuAvatarGroup(
                    avatars: const [],
                    // K-47: EVT-02 avatar grubu 32 (en büyük boy).
                    size: GuSizes.avatarGroupSizes.last,
                    moreLabel: '+$registered',
                  ),
                  Flexible(
                    child: Text(
                      l10n.eventAttendeesGoing(registered),
                      style: gu.text.bodyS.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (showReport)
            GuButton(
              key: GuKey.action('EVT-02.report'),
              label: l10n.eventReport,
              icon: GuIcons.flag,
              variant: GuButtonVariant.text,
              full: true,
              onPressed: onReport,
            ),
        ],
      ),
    );
  }
}
