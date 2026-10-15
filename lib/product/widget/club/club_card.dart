import 'package:flutter/widgets.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/l10n/static_labels.dart';
import 'package:gu_kulupler/product/widget/club/adaptive_pair.dart';
import 'package:gu_kulupler/product/widget/club/club_cta.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

/// Kulüp kartı — prototip `ClubCard` (`cards.js:28–40`): CLB-01 listesi /
/// ızgarası ve CLB-02 "Önerilen kulüpler".
///
/// * Girdi alan modelidir: [club] + [access] (`SessionState.accessTo`) +
///   [membershipStatus]; [memberPreview] liste kartındaki avatar grubudur
///   (yönetici üyelikleri — CD-139; "+N" `club.memberCount`'tan).
/// * [grid] `true` ise ızgara kartı (3:2 kapak, amblem kapağın üstünde, tam
///   genişlik düğme), değilse liste kartı (16:9 kapak, özet, avatar grubu).
/// * Karta dokunma [onOpen] (CLB-03); katılım eylemleri `ClubCta`'ya
///   aktarılır ([onJoin], [onClosedTap], [onStatus]; "Aç" → [onOpen]).
/// * Anahtarları çağıran verir (D-18: `GuKey.action` değişmezi çağrı yerinde,
///   CD-86): [actionKey] `<ID>.card.<clubId>`, [joinKey] `<ID>.join.<clubId>`,
///   [statusKey] `<ID>.status.<clubId>`, [openKey] `<ID>.open.<clubId>`.
///
/// Çizim (ölçüler `cards.js:30–39`):
///
/// | | Liste | Izgara |
/// |---|---|---|
/// | Kapak | 16:9; askıdaysa sol üst (12 / 12) "Askıda" rozeti | 3:2; sol alt (10 / 10) `xs` amblem (`bg.surface`), sağ üst (8 / 8) üyelik rozeti |
/// | Gövde | dolgu 12 / 16 / 16, aralık 8 | dolgu 10 / 12 / 12, aralık 6 |
/// | Başlık | `sm` amblem (ikon 22) + ad (`titleS`, 2 satır) + kategori rozeti + üye sayısı | ad (`titleS`, 2 satır) + "kategori · N üye" (`caption`) |
/// | Özet | `summary about` (`bodyS`, ikincil, 2 satır) | — |
/// | Alt satır | avatar grubu (24, en çok 3, "+N") + katılım türü — sağda `ClubCta(sm)` | `ClubCta(sm, full)` |
///
/// Kapak ve amblem yüklenmiş görselle çizilir ([coverImage] / [logoImage] —
/// çağıran çözer; T-36), yoksa şablon / ikon. Izgaradaki üyelik rozeti
/// [gridStatusOf]'tadır. Liste kartının alt satırı
/// dar genişlikte / büyük metin ölçeğinde önce katılım türü metnini sarar,
/// yine sığmazsa düğmeyi alt satıra indirir (taşma olmaz).
///
/// Erişilebilirlik: kart tek düğmedir; etiketi ad + kategori + üye sayısı (+
/// katılım türü) metinlerinden birleşir, özet ve avatar grubu okunmaz.
/// `ClubCta` düğmesi kartın içinde ayrı bir düğme olarak kalır.
///
/// ```dart
/// ClubCard(
///   club: club,
///   access: session.accessTo(club.id),
///   membershipStatus: session.memberships[club.id]?.status,
///   memberPreview: previews[club.id] ?? const [],
///   grid: state.layout == ClubListLayout.grid,
///   actionKey: GuKey.action('CLB-01.card.${club.id}'),
///   joinKey: GuKey.action('CLB-01.join.${club.id}'),
///   statusKey: GuKey.action('CLB-01.status.${club.id}'),
///   openKey: GuKey.action('CLB-01.open.${club.id}'),
///   onOpen: () => openClub(club),
///   onJoin: () => join(club),
///   onClosedTap: showApplicationsClosed,
///   onStatus: () => openApplication(club),
/// )
/// ```
class ClubCard extends StatelessWidget {
  /// [club] kulübünün kartı; [access] / [membershipStatus] kullanıcının
  /// kulüpteki durumudur.
  const ClubCard({
    required this.club,
    required this.access,
    required this.onOpen,
    required this.onJoin,
    required this.onClosedTap,
    required this.onStatus,
    this.membershipStatus,
    this.memberPreview = const <GuAvatarData>[],
    this.grid = false,
    this.highlight = false,
    this.coverImage,
    this.logoImage,
    this.actionKey,
    this.joinKey,
    this.statusKey,
    this.openKey,
    super.key,
  });

  /// Liste kartındaki avatar grubunda çizilen en çok kişi
  /// (`members.slice(0, 3)`, `cards.js:38`).
  static const int previewMax = 3;

  /// Kulüp ikonu kayıtta yoksa amblemde çizilen ikon.
  static const GuIcons fallbackIcon = GuIcons.users;

  /// Izgara kartında "kategori · N üye" ayracı (`cards.js:32`).
  static const String _separator = ' · ';

  /// Avatar grubu çapı (`cards.js:38` `size=${24}`; K-47).
  static final double _avatarSize = GuSizes.avatarGroupSizes.first;

  /// Kulüp.
  final ClubModel club;

  /// Kullanıcının kulübe erişim kipi (`RolePolicy.accessOf`).
  final ClubAccess access;

  /// Üyelik belgesinin durumu; belge yoksa `null` (`ClubCta` ile aynı).
  final MembershipStatus? membershipStatus;

  /// Liste kartındaki avatar grubu (en çok 3 kişi çizilir); ızgarada yok.
  final List<GuAvatarData> memberPreview;

  /// Izgara kartı (`true`) ya da liste kartı.
  final bool grid;

  /// 1,5 sn vurgu halkası (`GuCard.highlight`).
  final bool highlight;

  /// Yüklenmiş kapak (`club.coverPath`, çağıran `ref.clubCoverImage(club)`
  /// ile çözer); `null` → şablon kapak (`CoverMapper.club`).
  final ImageProvider? coverImage;

  /// Yüklenmiş logo (`club.logoPath`, `ref.clubLogoImage(club)`); `null` →
  /// ikonlu amblem (`CoverMapper.emblem`).
  final ImageProvider? logoImage;

  /// Karta ve "Aç" düğmesine dokunma — kulübü açar (CLB-03).
  final VoidCallback onOpen;

  /// "Katıl" — katılım akışını başlatır.
  final VoidCallback onJoin;

  /// Devre dışı "Başvurular kapalı" düğmesine dokunma (TST-X1).
  final VoidCallback onClosedTap;

  /// Başvuru durumuna git (CLB-05).
  final VoidCallback onStatus;

  /// Kartın anahtarı (`<ID>.card.<clubId>`).
  final Key? actionKey;

  /// "Katıl" / "Başvurular kapalı" düğmesinin anahtarı
  /// (`<ID>.join.<clubId>`).
  final Key? joinKey;

  /// Durum düğmesinin anahtarı (`<ID>.status.<clubId>`).
  final Key? statusKey;

  /// "Aç" düğmesinin anahtarı (`<ID>.open.<clubId>`).
  final Key? openKey;

  /// Izgara kartının kapağındaki üyelik rozeti (`cards.js:31`); rozet yoksa
  /// `null`.
  ///
  /// Bekleyen → `pending`, reddedilen → `rejected`, kulübün etkin üyesi
  /// (üye / yönetici / danışman) → `active` ("Üye"). Ziyaretçi rozet almaz.
  /// Prototip `mode !== 'visitor'` olan herkese `active` çizer; bu, kulüpten
  /// çıkarılmış kullanıcıya ve üyeliği olmayan süper admine de "Üye" yazar.
  /// Burada rozet üyelik belgesini izler: çıkarılmış üye rozet almaz (durumu
  /// düğmede "Çıkarıldın" olarak görünür), süper admin yalnızca etkin üyeliği
  /// varsa "Üye" alır.
  static GuStatusBadgeKind? gridStatusOf({
    required ClubAccess access,
    MembershipStatus? membershipStatus,
  }) => switch (access) {
    ClubAccess.visitor => null,
    ClubAccess.pending => GuStatusBadgeKind.pending,
    ClubAccess.rejected => GuStatusBadgeKind.rejected,
    ClubAccess.member ||
    ClubAccess.manager ||
    ClubAccess.advisor => GuStatusBadgeKind.active,
    ClubAccess.superAdmin =>
      membershipStatus == MembershipStatus.active
          ? GuStatusBadgeKind.active
          : null,
  };

  GuIcons get _icon => CoverMapper.icon(club.iconName) ?? fallbackIcon;

  ClubCta _cta({required bool full}) => ClubCta(
    club: club,
    access: access,
    membershipStatus: membershipStatus,
    size: GuButtonSize.sm,
    full: full,
    joinKey: joinKey,
    statusKey: statusKey,
    openKey: openKey,
    onJoin: onJoin,
    onClosedTap: onClosedTap,
    onStatus: onStatus,
    onOpen: onOpen,
  );

  @override
  Widget build(BuildContext context) => GuCard(
    key: actionKey,
    onTap: onOpen,
    highlight: highlight,
    child: grid ? _buildGrid(context) : _buildList(context),
  );

  Widget _buildGrid(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final status = gridStatusOf(
      access: access,
      membershipStatus: membershipStatus,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoverMapper.club(
          club,
          image: coverImage,
          ratio: GuCoverRatio.r3x2,
          overlays: [
            Positioned(
              left: GuSizes.clubCardEmblemOffset,
              bottom: GuSizes.clubCardEmblemOffset,
              child: CoverMapper.emblem(
                icon: _icon,
                logo: logoImage,
                size: GuEmblemSize.xs,
                background: gu.colors.bgSurface,
              ),
            ),
            if (status != null)
              Positioned(
                left: GuSpacing.s8,
                top: GuSpacing.s8,
                right: GuSpacing.s8,
                child: Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: GuStatusBadge(
                    kind: status,
                    label: switch (status) {
                      GuStatusBadgeKind.pending => l10n.statusPending,
                      GuStatusBadgeKind.rejected => l10n.statusRejected,
                      _ => l10n.clubsCardMemberShort,
                    },
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: GuInsets.only(
            left: GuSizes.clubCardBodyPaddingX,
            top: GuSizes.clubCardBodyPaddingTop,
            right: GuSizes.clubCardBodyPaddingX,
            bottom: GuSizes.clubCardBodyPaddingBottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: GuSpacing.s6,
            children: [
              Text(
                club.name,
                style: gu.text.titleS,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                StaticLabels.category(context, club.categoryId) +
                    _separator +
                    l10n.clubsCardMembers(club.memberCount),
                style: gu.text.caption,
              ),
              // `<div style="display:flex">` (cards.js:32): düğme satırı
              // doldurur; "Askıda" rozeti kendi genişliğinde, solda kalır.
              Row(children: [Expanded(child: _cta(full: true))]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final colors = gu.colors;
    final caption = gu.text.caption;
    final summary = '${club.summary} ${club.about}'.trim();
    final shown = memberPreview.take(previewMax).toList(growable: false);
    final rest = club.memberCount - shown.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoverMapper.club(
          club,
          image: coverImage,
          overlays: [
            if (club.isSuspended)
              Positioned(
                left: GuSpacing.s12,
                top: GuSpacing.s12,
                right: GuSpacing.s12,
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: GuBadge(
                    label: l10n.statusSuspended,
                    kind: GuBadgeKind.danger,
                    icon: GuIcons.ban,
                  ),
                ),
              ),
          ],
        ),
        Padding(
          // `.card-body` 16 + `padding-top:12px` (cards.js:35).
          padding: GuCard.bodyPadding.copyWith(top: GuSpacing.s12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: GuSpacing.s8,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: GuSpacing.s12,
                children: [
                  CoverMapper.emblem(
                    icon: _icon,
                    logo: logoImage,
                    iconSize: GuSizes.icon22,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: GuSpacing.s4,
                      children: [
                        Text(
                          club.name,
                          style: gu.text.titleS,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Wrap(
                          spacing: GuSpacing.s6,
                          runSpacing: GuSpacing.s6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            GuBadge(
                              label: StaticLabels.category(
                                context,
                                club.categoryId,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: GuSpacing.s4,
                              children: [
                                GuIcon(
                                  GuIcons.users,
                                  size: GuSizes.icon14,
                                  color: colors.textMuted,
                                ),
                                Flexible(
                                  child: Text(
                                    l10n.clubsCardMembers(club.memberCount),
                                    style: caption.copyWith(
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (summary.isNotEmpty)
                ExcludeSemantics(
                  child: Text(
                    summary,
                    style: gu.text.bodyS.copyWith(color: colors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // `row between gap8` (cards.js:38): düğme kendi genişliğinde,
              // avatar grubu + tür kalan alanda; sığmazsa düğme alta iner.
              AdaptivePair(
                gap: GuSpacing.s8,
                leading: Row(
                  spacing: GuSpacing.s6,
                  children: [
                    if (shown.isNotEmpty || rest > 0)
                      ExcludeSemantics(
                        child: GuAvatarGroup(
                          avatars: shown,
                          size: _avatarSize,
                          max: previewMax,
                          moreLabel: rest > 0 ? '+$rest' : null,
                        ),
                      ),
                    Flexible(
                      child: Text(
                        club.approvalRequired
                            ? l10n.clubTypeApproval
                            : l10n.clubTypeInstant,
                        style: caption,
                      ),
                    ),
                  ],
                ),
                trailing: _cta(full: false),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
