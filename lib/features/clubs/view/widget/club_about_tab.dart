import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/share_sheet.dart';
import 'package:gu_kulupler/product/media/user_avatar_image.dart';
import 'package:gu_kulupler/product/widget/member/member_row.dart';
import 'package:gu_kulupler/product/widget/member/user_row.dart';
import 'package:gu_ui/gu_ui.dart';

/// CLB-03 "Hakkında" sekmesi — prototip `screens-clubs.js:94–101`. Yatay 16,
/// üst 16, alt 24 dolgulu sütun; bölümler arası 20:
///
/// 1. Tanıtım metni (`bodyM`; üç satıra kırpılır) · "Devamı" (`labelL`,
///    marka rengi — `CLB-03.about.more`, metni açar) · "{yıl} yılında
///    kuruldu" (`landmark` 14 + `caption`). "Devamı" yalnızca metin üç satırı
///    aşıyorsa çizilir.
/// 2. İletişim kartı: e-posta (`mail`), Instagram (`camera`), web sitesi
///    (`globe`) — kart içi satırlar, aralarında ayraç; boş bağlantının
///    satırı yoktur. Dokunma harici bağlantı onayına gider (DLG-32).
/// 3. "Danışman" — tek kişi satırı (`UserRow`; alt satır rol adı).
/// 4. "Yönetim kurulu" — başkan önde; kart içi `MemberRow` (rol rozeti +
///    bölüm · sınıf + ok). Etkin yönetici üyelikleri doğrulanmış her
///    kullanıcıya okunur (CD-139); liste boşsa bölüm çizilmez.
///
/// Kişi satırları CLB-07'ye gider (`CLB-03.about.person.<userId>`).
/// 5. "Katılım koşulları" — madde imli liste (`bodyM`, `text.secondary`).
/// 6. "Bu kulübü şikayet et" (metin düğmesi + `flag` — `CLB-03.report`).
///
/// Anahtarlar çağırandan gelir (D-18).
class ClubAboutTab extends StatelessWidget {
  /// [club] kulübünün "Hakkında" içeriği.
  const ClubAboutTab({
    required this.club,
    required this.expanded,
    required this.onReadMore,
    required this.onEmail,
    required this.onInstagram,
    required this.onWeb,
    required this.onPerson,
    required this.onReport,
    required this.personKeyOf,
    this.managers = const [],
    this.readMoreKey,
    this.emailKey,
    this.instagramKey,
    this.webKey,
    this.reportKey,
    super.key,
  });

  /// Kulüp.
  final ClubModel club;

  /// Yönetim kurulu (başkan önde); boşsa bölüm çizilmez.
  final List<MembershipModel> managers;

  /// Tanıtım metni açık mı ("Devamı"ya dokunuldu)?
  final bool expanded;

  /// "Devamı" (`CLB-03.about.more`).
  final VoidCallback onReadMore;

  /// E-posta satırı (`CLB-03.about.link.email`).
  final VoidCallback onEmail;

  /// Instagram satırı (`CLB-03.about.link.instagram`).
  final VoidCallback onInstagram;

  /// Web sitesi satırı (`CLB-03.about.link.web`).
  final VoidCallback onWeb;

  /// Kişi satırı (`CLB-03.about.person.<userId>`).
  final ValueChanged<String> onPerson;

  /// "Bu kulübü şikayet et" (`CLB-03.report`).
  final VoidCallback onReport;

  /// Kişi satırının anahtarı (`CLB-03.about.person.<userId>`).
  final Key Function(String userId) personKeyOf;

  /// "Devamı" anahtarı.
  final Key? readMoreKey;

  /// E-posta satırının anahtarı.
  final Key? emailKey;

  /// Instagram satırının anahtarı.
  final Key? instagramKey;

  /// Web sitesi satırının anahtarı.
  final Key? webKey;

  /// Şikayet düğmesinin anahtarı.
  final Key? reportKey;

  /// Marka adı — çevrilmez (prototip `screens-clubs.js:96` düz metin).
  static const String instagramLabel = 'Instagram';

  /// Tanıtım metninin kapalıyken gösterilen satır sayısı (`.clamp3`).
  static const int collapsedLines = 3;

  /// Madde imi (`ul` varsayılan `disc`).
  static const String _bullet = '•';

  /// [value] boş değilse kırpılmış hali, boşsa `null`.
  static String? _filled(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final colors = gu.colors;
    final about = club.about.trim();
    final email = _filled(club.social.email);
    final instagram = _filled(club.social.instagram);
    final web = _filled(club.social.web);
    final advisor = club.advisor;

    Widget heading(String text) =>
        Semantics(header: true, child: Text(text, style: gu.text.titleS));

    Widget link({
      required GuIcons icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      required Key? key,
    }) => GuTile(
      key: key,
      title: title,
      subtitle: subtitle,
      padding: GuTilePadding.inCard,
      leading: GuIcon(
        icon,
        size: GuSizes.icon20,
        color: colors.brandPrimaryText,
      ),
      onTap: onTap,
    );

    final links = [
      if (email != null)
        link(
          icon: GuIcons.mail,
          title: email,
          subtitle: l10n.clubContactEmail,
          onTap: onEmail,
          key: emailKey,
        ),
      if (instagram != null)
        link(
          icon: GuIcons.camera,
          title: instagram,
          subtitle: instagramLabel,
          onTap: onInstagram,
          key: instagramKey,
        ),
      if (web != null)
        link(
          icon: GuIcons.globe,
          title: ShareLinks.display(web),
          subtitle: l10n.clubContactWeb,
          onTap: onWeb,
          key: webKey,
        ),
    ];

    return Padding(
      padding: GuInsets.only(
        left: GuSpacing.s16,
        top: GuSpacing.s16,
        right: GuSpacing.s16,
        bottom: GuSpacing.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s20,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: GuSpacing.s8,
            children: [
              if (about.isNotEmpty)
                _AboutText(
                  text: about,
                  expanded: expanded,
                  onReadMore: onReadMore,
                  readMoreKey: readMoreKey,
                ),
              Row(
                spacing: GuSpacing.s4,
                children: [
                  GuIcon(
                    GuIcons.landmark,
                    size: GuSizes.icon14,
                    color: colors.textMuted,
                  ),
                  Flexible(
                    child: Text(
                      l10n.clubFounded(club.founded.toString()),
                      style: gu.text.caption,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (links.isNotEmpty)
            GuCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (index, row) in links.indexed) ...[
                    if (index > 0) const GuDivider(),
                    row,
                  ],
                ],
              ),
            ),
          if (advisor != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: GuSpacing.s8,
              children: [
                heading(l10n.clubAdvisor),
                GuCard(child: _advisorRow(context, advisor)),
              ],
            ),
          if (managers.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: GuSpacing.s8,
              children: [
                heading(l10n.clubBoard),
                GuCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (index, manager) in managers.indexed) ...[
                        if (index > 0) const GuDivider(),
                        _managerRow(manager),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          if (club.conditions.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: GuSpacing.s8,
              children: [
                heading(l10n.clubConditions),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: GuSpacing.s6,
                  children: [
                    for (final condition in club.conditions)
                      _condition(context, condition),
                  ],
                ),
              ],
            ),
          GuButton(
            key: reportKey,
            label: l10n.clubReport,
            icon: GuIcons.flag,
            variant: GuButtonVariant.text,
            full: true,
            onPressed: onReport,
          ),
        ],
      ),
    );
  }

  /// Danışman satırı. Ad ünvanıyla birlikte yazılır; hesaba bağlanmamış
  /// danışmanın satırı dokunulmaz, oksuz ve anahtarsızdır
  /// (`screens-clubs.js:97`).
  Widget _advisorRow(BuildContext context, ClubAdvisorModel advisor) {
    final userId = advisor.userId;
    final name = [
      advisor.title.trim(),
      advisor.name.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    UserRow row([ImageProvider? avatarImage]) => UserRow.named(
      name: name,
      avatarSeed: userId ?? name,
      sub: context.l10n.roleAdvisor,
      inCard: true,
      chevron: userId != null,
      actionKey: userId == null ? null : personKeyOf(userId),
      onTap: userId == null ? null : () => onPerson(userId),
      avatarImage: avatarImage,
    );
    if (userId == null) return row();
    // Hesaba bağlı danışmanın fotoğrafı kimliğinden çözülür.
    return Consumer(
      builder: (context, ref, _) =>
          row(ref.userAvatarImageOf(userId, displaySize: GuSizes.avatar)),
    );
  }

  /// Yönetim kurulu satırı: rol rozeti + bölüm · sınıf.
  /// Fotoğraf yöneticinin kimliğinden çözülür (kartın bütün satırları tek
  /// toplu okumada — `userAvatarImageOf`).
  Widget _managerRow(MembershipModel manager) => Consumer(
    builder: (context, ref, _) => MemberRow(
      membership: manager,
      inCard: true,
      chevron: true,
      avatarImage: ref.userAvatarImageOf(
        manager.userId,
        displaySize: GuSizes.avatar,
      ),
      actionKey: personKeyOf(manager.userId),
      onTap: () => onPerson(manager.userId),
    ),
  );

  /// Katılım koşulu: madde imi (20 dp girinti, `ul{padding-left:20px}`) +
  /// metin.
  Widget _condition(BuildContext context, String condition) {
    final gu = context.gu;
    final style = gu.text.bodyM.copyWith(color: gu.colors.textSecondary);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: GuSpacing.s20,
          child: ExcludeSemantics(
            child: Text(_bullet, style: style, textAlign: TextAlign.center),
          ),
        ),
        Expanded(child: Text(condition, style: style)),
      ],
    );
  }
}

/// Tanıtım metni + "Devamı". Kapalıyken metin
/// [ClubAboutTab.collapsedLines] satıra kırpılır; "Devamı" yalnızca metin
/// kırpıldıysa çizilir.
class _AboutText extends StatelessWidget {
  const _AboutText({
    required this.text,
    required this.expanded,
    required this.onReadMore,
    required this.readMoreKey,
  });

  final String text;
  final bool expanded;
  final VoidCallback onReadMore;
  final Key? readMoreKey;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final style = gu.text.bodyM;
    if (expanded) return Text(text, style: style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: ClubAboutTab.collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final clipped = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: GuSpacing.s8,
          children: [
            Text(
              text,
              style: style,
              maxLines: ClubAboutTab.collapsedLines,
              overflow: TextOverflow.ellipsis,
            ),
            if (clipped)
              GuTapTarget(
                key: readMoreKey,
                onTap: onReadMore,
                child: Text(
                  context.l10n.commonReadMore,
                  style: gu.text.labelL.copyWith(
                    color: gu.colors.brandPrimaryText,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
