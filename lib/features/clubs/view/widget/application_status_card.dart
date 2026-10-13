import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/clubs/provider/club_application_state.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-05'in üst bloğu: kulüp kartı + başvurunun üç adımlı zaman çizelgesi
/// (prototip `screens-clubs.js:130–131`; aralık 20).
///
/// * **Kart** (`Card tappable`, dolgu 12 / 16, aralık 12): küçük amblem ·
///   kulüp adı + kategori · durum rozeti. Dokununca kulüp sayfası açılır
///   (`CLB-05.openClub`).
/// * **Zaman çizelgesi** (`GuTimeline`; K-36): "Gönderildi" (başvuru anı) ·
///   "İnceleniyor" (beklerken "Kulüp yönetimi inceliyor", sonra karar anı) ·
///   "Sonuç" (Onaylandı / Reddedildi / Çıkarıldı; yoksa "Bekleniyor").
///
/// | Evre | Rozet | Nokta 1 · 2 · 3 |
/// |---|---|---|
/// | `pending` | Beklemede | tamam · etkin · bekliyor |
/// | `approved` | Onaylandı | tamam · tamam · tamam |
/// | `rejected` / `removed` | Reddedildi / Çıkarıldı | tamam · tamam · tehlike |
/// | `none` | İptal | tamam · tamam · bekliyor |
///
/// `none` evresinde (aktif başvuru yok) adımlar tarih taşımaz: prototipte bu
/// evre üyelik kaydının hiç olmamasıdır; iptal edilmiş ya da ayrılınmış
/// üyeliğin eski tarihleri güncel bir başvuruya aitmiş gibi gösterilmez.
class ApplicationStatusCard extends ConsumerWidget {
  /// [club] kulübündeki [membership] başvurusunun özeti.
  const ApplicationStatusCard({
    required this.club,
    required this.phase,
    required this.onOpenClub,
    this.membership,
    super.key,
  });

  /// Başvurulan kulüp.
  final ClubModel club;

  /// Başvurunun evresi.
  final ApplicationPhase phase;

  /// Kullanıcının üyelik belgesi; yoksa `null`.
  final MembershipModel? membership;

  /// Karta dokunma (`CLB-05.openClub`).
  final VoidCallback onOpenClub;

  /// Kayıtta olmayan ikon adında amblemin yedeği.
  static const GuIcons _fallbackIcon = GuIcons.users;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gu = context.gu;
    final l10n = context.l10n;
    final formats = AppDateFormats(
      Localizations.localeOf(context),
      ref.watch(appClockProvider),
    );
    final (kind, label) = _badge(l10n);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s20,
      children: [
        GuCard(
          key: GuKey.action('CLB-05.openClub'),
          onTap: onOpenClub,
          semanticLabel: club.name,
          padding: GuInsets.h16v12,
          child: Row(
            spacing: GuSpacing.s12,
            children: [
              GuEmblem(icon: CoverMapper.icon(club.iconName) ?? _fallbackIcon),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(club.name, style: gu.text.titleS),
                    Text(
                      StaticLabels.category(context, club.categoryId),
                      style: gu.text.caption,
                    ),
                  ],
                ),
              ),
              GuStatusBadge(kind: kind, label: label),
            ],
          ),
        ),
        GuTimeline(items: _steps(l10n, formats)),
      ],
    );
  }

  /// Durum rozeti (`screens-clubs.js:130`: `active → approved`,
  /// `none → cancelled`).
  (GuStatusBadgeKind, String) _badge(AppLocalizations l10n) => switch (phase) {
    ApplicationPhase.pending => (
      GuStatusBadgeKind.pending,
      l10n.statusPending,
    ),
    ApplicationPhase.approved => (
      GuStatusBadgeKind.approved,
      l10n.statusApproved,
    ),
    ApplicationPhase.rejected => (
      GuStatusBadgeKind.rejected,
      l10n.statusRejected,
    ),
    ApplicationPhase.removed => (
      GuStatusBadgeKind.removed,
      l10n.statusRemoved,
    ),
    ApplicationPhase.none => (
      GuStatusBadgeKind.cancelled,
      l10n.statusCancelled,
    ),
  };

  /// Üç adım (`screens-clubs.js:127, 131`).
  List<GuTimelineItem> _steps(AppLocalizations l10n, AppDateFormats formats) {
    final current = phase == ApplicationPhase.none ? null : membership;
    final appliedAt = current?.appliedAt;
    final decidedAt = current?.decidedAt;
    final isPending = phase == ApplicationPhase.pending;
    return [
      GuTimelineItem(
        state: GuTimelineDotState.done,
        title: l10n.applicationStepSent,
        caption: appliedAt == null ? null : formats.dateTime(l10n, appliedAt),
      ),
      GuTimelineItem(
        state: isPending ? GuTimelineDotState.active : GuTimelineDotState.done,
        title: l10n.applicationStepReview,
        caption: isPending
            ? l10n.applicationReviewing
            : decidedAt == null
            ? null
            : formats.dateTime(l10n, decidedAt),
      ),
      GuTimelineItem(
        state: switch (phase) {
          ApplicationPhase.approved => GuTimelineDotState.done,
          ApplicationPhase.rejected ||
          ApplicationPhase.removed => GuTimelineDotState.danger,
          ApplicationPhase.pending ||
          ApplicationPhase.none => GuTimelineDotState.pending,
        },
        title: l10n.applicationStepResult,
        caption: switch (phase) {
          ApplicationPhase.approved => l10n.statusApproved,
          ApplicationPhase.rejected => l10n.statusRejected,
          ApplicationPhase.removed => l10n.statusRemoved,
          ApplicationPhase.pending ||
          ApplicationPhase.none => l10n.applicationWaitingResult,
        },
      ),
    ];
  }
}
