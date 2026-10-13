import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/widget/club/adaptive_pair.dart';
import 'package:gu_ui/gu_ui.dart';

/// [ClubCta]'nın çizdiği çıktı — prototip `ClubCTA` dalları
/// (`cards.js:19–27`; design-analysis A.2 #51).
enum ClubCtaKind {
  /// Kulüp askıda: "Askıda" rozeti (düğme yok).
  suspended,

  /// Ziyaretçi, başvurular açık: birincil "Katıl".
  join,

  /// Ziyaretçi, başvurular kapalı: devre dışı "Başvurular kapalı".
  closed,

  /// Başvuru karar bekliyor: "İstek gönderildi".
  pending,

  /// Başvuru reddedildi: "Reddedildi".
  rejected,

  /// Üyelikten çıkarıldı: "Çıkarıldın".
  removed,

  /// Kulübün içini gören (üye, yönetici, danışman, süper admin): "Aç".
  open,
}

/// Kulübe katılım eylemi — prototip `ClubCTA` (`cards.js:19–27`): kullanıcının
/// kulüpteki durumuna göre tek bir düğme ya da rozet.
///
/// | [ClubCtaKind] | Çizim | Dokunma |
/// |---|---|---|
/// | `suspended` | `GuBadge(danger, ban)` "Askıda" | — |
/// | `join` | birincil "Katıl" | [onJoin] |
/// | `closed` | çerçeveli, devre dışı "Başvurular kapalı" | [onClosedTap] (TST-X1) |
/// | `pending` | tonal + `hourglass` "İstek gönderildi" | [onStatus] |
/// | `rejected` | tonal + `circle-x` "Reddedildi" | [onStatus] |
/// | `removed` | tonal + `user-x` "Çıkarıldın" | [onStatus] |
/// | `open` | (yönetici → "Yönetici" rozeti, danışman → rol rozeti) + çerçeveli "Aç" | [onOpen] |
///
/// * Girdi alan modelidir: [club] (askı, `applicationsOpen`) + [access]
///   (`SessionState.accessTo`) + [membershipStatus] (`removed` ayrımı —
///   `ClubAccess`'te karşılığı yoktur). Eşleme [kindOf]'tadır.
/// * Hangi akışın başlayacağına (SHT-05, anında katılım, `retryAfter` →
///   CLB-05; `cards.js:12–18`) çağıran karar verir; widget yalnızca dokunmayı
///   bildirir.
/// * Anahtarları çağıran verir (D-18: `GuKey.action` değişmezi çağrı yerinde
///   yazılır, CD-86): [joinKey] `<ID>.join.<clubId>` (`join` ve `closed`),
///   [statusKey] `<ID>.status.<clubId>`, [openKey] `<ID>.open.<clubId>`.
/// * [size] / [full] düğmeye aktarılır: kartlarda `sm`, CLB-03 kilitli
///   blokta `md`, CLB-03 alt çubukta `lg` + `full`.
/// * "Reddedildi" düğmesi düz tonal çizilir: prototipteki `.c-danger` sınıfı
///   `.btn-tonal`'dan önce tanımlıdır (css:98 < css:143) ve rengi etkilemez.
///
/// ```dart
/// ClubCta(
///   club: club,
///   access: session.accessTo(club.id),
///   membershipStatus: session.memberships[club.id]?.status,
///   size: GuButtonSize.lg,
///   full: true,
///   joinKey: GuKey.action('CLB-03.join.${club.id}'),
///   statusKey: GuKey.action('CLB-03.status.${club.id}'),
///   openKey: GuKey.action('CLB-03.open.${club.id}'),
///   onJoin: startJoin,
///   onClosedTap: showApplicationsClosed,
///   onStatus: openApplication,
///   onOpen: openClub,
/// )
/// ```
class ClubCta extends StatelessWidget {
  /// [club] kulübü için, [access] / [membershipStatus] durumundaki
  /// kullanıcının katılım eylemi.
  const ClubCta({
    required this.club,
    required this.access,
    required this.onJoin,
    required this.onClosedTap,
    required this.onStatus,
    required this.onOpen,
    this.membershipStatus,
    this.size = GuButtonSize.md,
    this.full = false,
    this.joinKey,
    this.statusKey,
    this.openKey,
    super.key,
  });

  /// Kulüp (askı durumu ve `applicationsOpen`).
  final ClubModel club;

  /// Kullanıcının kulübe erişim kipi (`RolePolicy.accessOf`).
  final ClubAccess access;

  /// Üyelik belgesinin durumu; belge yoksa `null`. Yalnızca
  /// [MembershipStatus.removed] ayrımı için okunur ([ClubAccess.visitor]
  /// çıkarılmış üyeyi de kapsar).
  final MembershipStatus? membershipStatus;

  /// Düğme boyutu.
  final GuButtonSize size;

  /// Düğme satırı doldurur (`.btn-full`).
  final bool full;

  /// "Katıl" — katılım akışını başlatır ([ClubCtaKind.join]).
  final VoidCallback onJoin;

  /// Devre dışı "Başvurular kapalı" düğmesine dokunma — neden kapalı olduğunu
  /// söyler (TST-X1; [ClubCtaKind.closed]).
  final VoidCallback onClosedTap;

  /// Başvuru durumuna git (CLB-05; [ClubCtaKind.pending],
  /// [ClubCtaKind.rejected], [ClubCtaKind.removed]).
  final VoidCallback onStatus;

  /// Kulübü aç (CLB-03; [ClubCtaKind.open]).
  final VoidCallback onOpen;

  /// "Katıl" / "Başvurular kapalı" düğmesinin anahtarı
  /// (`<ID>.join.<clubId>`).
  final Key? joinKey;

  /// Durum düğmesinin anahtarı (`<ID>.status.<clubId>`).
  final Key? statusKey;

  /// "Aç" düğmesinin anahtarı (`<ID>.open.<clubId>`).
  final Key? openKey;

  /// [club] kulübünde [access] / [membershipStatus] durumundaki kullanıcıya
  /// gösterilecek çıktı (prototip `sel.mode` + `ClubCTA`, `actions.js:22–27`,
  /// `cards.js:21–26`).
  ///
  /// Askı her erişim kipinden önce gelir. [ClubAccess.visitor] içinde
  /// çıkarılmış üye ([MembershipStatus.removed]) ayrıdır; ayrılan (`left`),
  /// başvurusunu geri çeken (`cancelled`) ve üyeliği olmayan kullanıcı aynı
  /// "Katıl" / "Başvurular kapalı" çıktısını alır. Süper admin üyelik
  /// durumundan bağımsız olarak [ClubCtaKind.open]'dır.
  static ClubCtaKind kindOf({
    required ClubModel club,
    required ClubAccess access,
    MembershipStatus? membershipStatus,
  }) {
    if (club.isSuspended) return ClubCtaKind.suspended;
    return switch (access) {
      ClubAccess.visitor =>
        membershipStatus == MembershipStatus.removed
            ? ClubCtaKind.removed
            : club.applicationsOpen
            ? ClubCtaKind.join
            : ClubCtaKind.closed,
      ClubAccess.pending => ClubCtaKind.pending,
      ClubAccess.rejected => ClubCtaKind.rejected,
      ClubAccess.member ||
      ClubAccess.manager ||
      ClubAccess.advisor ||
      ClubAccess.superAdmin => ClubCtaKind.open,
    };
  }

  /// Bu widget'ın çıktısı ([kindOf]).
  ClubCtaKind get kind => kindOf(
    club: club,
    access: access,
    membershipStatus: membershipStatus,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    GuButton status({required GuIcons icon, required String label}) => GuButton(
      key: statusKey,
      label: label,
      icon: icon,
      variant: GuButtonVariant.tonal,
      size: size,
      full: full,
      onPressed: onStatus,
    );

    switch (kind) {
      case ClubCtaKind.suspended:
        // `.badge` satır içi kutudur (css:188 `inline-flex; flex:none`):
        // ebeveyn genişliği zorlasa da rozet kendi genişliğinde kalır.
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: GuBadge(
                label: l10n.statusSuspended,
                kind: GuBadgeKind.danger,
                icon: GuIcons.ban,
              ),
            ),
          ],
        );
      case ClubCtaKind.join:
        return GuButton(
          key: joinKey,
          label: l10n.clubsCardJoin,
          size: size,
          full: full,
          onPressed: onJoin,
        );
      case ClubCtaKind.closed:
        return GuButton(
          key: joinKey,
          label: l10n.clubsCardClosed,
          variant: GuButtonVariant.outline,
          size: size,
          full: full,
          disabled: true,
          onPressed: null,
          onDisabledPressed: onClosedTap,
        );
      case ClubCtaKind.pending:
        return status(icon: GuIcons.hourglass, label: l10n.clubsCardPending);
      case ClubCtaKind.rejected:
        return status(icon: GuIcons.circleX, label: l10n.clubsCardRejected);
      case ClubCtaKind.removed:
        return status(icon: GuIcons.userX, label: l10n.clubsCardRemoved);
      case ClubCtaKind.open:
        final button = GuButton(
          key: openKey,
          label: l10n.clubsCardOpen,
          variant: GuButtonVariant.outline,
          size: size,
          full: full,
          onPressed: onOpen,
        );
        final badge = switch (access) {
          ClubAccess.manager => GuBadge(
            label: l10n.clubsCardManager,
            kind: GuBadgeKind.president,
            icon: GuIcons.shieldCheck,
          ),
          ClubAccess.advisor => GuRoleBadge(
            kind: GuRoleBadgeKind.advisor,
            label: l10n.roleAdvisor,
          ),
          _ => null,
        };
        if (badge == null) return button;
        // `<span class="row gap8">` (cards.js:26): rozet kendi genişliğinde,
        // düğme kalan alanda. Tam genişlikte düğmeye yer kalmazsa (dar ızgara
        // sütunu × büyük metin ölçeği) rozet üstte, düğme altta dizilir.
        if (full) {
          return AdaptivePair(
            gap: GuSpacing.s8,
            fill: AdaptivePairFill.trailing,
            leading: badge,
            trailing: button,
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          spacing: GuSpacing.s8,
          children: [
            badge,
            Flexible(child: button),
          ],
        );
    }
  }
}
