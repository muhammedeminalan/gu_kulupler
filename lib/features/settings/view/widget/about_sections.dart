import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/features/settings/constants/about_content.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_ui/gu_ui.dart';

/// SET-04 kartları — prototip `screens-profile.js:100–103`. Durum ve
/// eylemler `AboutView`'dan gelir; kartlar yalnızca çizer.

/// "Ekip" kartı (`card-body col gap8`): başlık + ad / rol satırları (avatar
/// 32, satır aralığı 8 — K-42 `row gap10` → 8).
class AboutTeamCard extends StatelessWidget {
  /// Ekip kartı.
  const AboutTeamCard({super.key});

  static String _role(AppLocalizations l10n, AboutTeamRole role) =>
      switch (role) {
        AboutTeamRole.pm => l10n.aboutTeamPm,
        AboutTeamRole.design => l10n.aboutTeamDesign,
        AboutTeamRole.dev => l10n.aboutTeamDev,
      };

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    return GuCard(
      padding: GuInsets.all16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: GuSpacing.s8,
        children: [
          Text(l10n.aboutTeam.upperFor(locale), style: gu.text.overline),
          for (final member in AboutContent.team)
            Row(
              spacing: GuSpacing.s8,
              children: [
                GuAvatar(
                  initials: member.name.initials,
                  seed: member.name,
                  size: GuSizes.avatarSizes[1],
                ),
                Expanded(
                  child: Text(
                    member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: gu.text.bodyM.copyWith(
                      color: gu.colors.textHeading,
                    ),
                  ),
                ),
                Text(_role(l10n, member.role), style: gu.text.caption),
              ],
            ),
        ],
      ),
    );
  }
}

/// "Açık kaynak lisansları" kartı: başlık (12 / 16 / 4) + her lisans için
/// açılır satır; açıkken açıklama + "Lisansı görüntüle" (yatay 16, alt 16,
/// aralık 8).
class AboutLicensesCard extends StatelessWidget {
  /// [isOpen] satırın açıklığı; [onToggle] satıra, [onOpenLink] "Lisansı
  /// görüntüle"ye dokunma.
  const AboutLicensesCard({
    required this.isOpen,
    required this.onToggle,
    required this.onOpenLink,
    super.key,
  });

  /// Lisans satırı açık mı?
  final bool Function(AboutLicense license) isOpen;

  /// Satıra dokunma (`SET-04.license.<k>`).
  final ValueChanged<AboutLicense> onToggle;

  /// "Lisansı görüntüle" (`SET-04.licenseLink.<k>`).
  final ValueChanged<AboutLicense> onOpenLink;

  static String _description(AppLocalizations l10n, AboutLicense license) =>
      switch (license) {
        AboutLicense.lucide => l10n.aboutLicenseLucide,
        AboutLicense.montserrat => l10n.aboutLicenseMontserrat,
        AboutLicense.inter => l10n.aboutLicenseInter,
      };

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    return GuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: GuInsets.only(
              left: GuSpacing.s16,
              top: GuSpacing.s12,
              right: GuSpacing.s16,
              bottom: GuSpacing.s4,
            ),
            child: Text(
              l10n.aboutLicenses.upperFor(locale),
              style: gu.text.overline,
            ),
          ),
          for (final license in AboutLicense.values) ...[
            AboutExpandTile(
              actionKey: GuKey.action('SET-04.license.${license.name}'),
              title: license.title,
              subtitle: license.licenseName,
              isOpen: isOpen(license),
              onTap: () => onToggle(license),
            ),
            if (isOpen(license))
              Padding(
                padding: GuInsets.only(
                  left: GuSpacing.s16,
                  right: GuSpacing.s16,
                  bottom: GuSpacing.s16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: GuSpacing.s8,
                  children: [
                    Text(
                      _description(l10n, license),
                      style: gu.text.bodyS.copyWith(
                        color: gu.colors.textSecondary,
                      ),
                    ),
                    GuButton(
                      key: GuKey.action('SET-04.licenseLink.${license.name}'),
                      label: l10n.aboutViewLicense,
                      icon: GuIcons.externalLink,
                      variant: GuButtonVariant.text,
                      size: GuButtonSize.sm,
                      onPressed: () => onOpenLink(license),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// "Sürüm notları" kartı: açılır satır ("v{sürüm}"); açıkken 4 madde
/// (`ul` sol 32, sağ 16, alt 16, aralık 4).
class AboutReleaseNotesCard extends StatelessWidget {
  /// [version] alt satır metnidir (`v1.0.0`).
  const AboutReleaseNotesCard({
    required this.version,
    required this.isOpen,
    required this.onToggle,
    super.key,
  });

  /// Alt satır (`v{sürüm}`).
  final String version;

  /// Notlar açık mı?
  final bool isOpen;

  /// Satıra dokunma (`SET-04.releaseNotes`).
  final VoidCallback onToggle;

  /// Madde imi (`ul` varsayılan `disc`).
  static const String _bullet = '•';

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final style = gu.text.bodyS.copyWith(color: gu.colors.textSecondary);
    final notes = [
      l10n.aboutNote1,
      l10n.aboutNote2,
      l10n.aboutNote3,
      l10n.aboutNote4,
    ];
    return GuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AboutExpandTile(
            actionKey: GuKey.action('SET-04.releaseNotes'),
            title: l10n.aboutReleaseNotes,
            subtitle: version,
            isOpen: isOpen,
            onTap: onToggle,
          ),
          if (isOpen)
            Padding(
              padding: GuInsets.only(
                left: GuSpacing.s16,
                right: GuSpacing.s16,
                bottom: GuSpacing.s16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: GuSpacing.s4,
                children: [
                  for (final note in notes)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Madde imi sütunu: metin soldan 32'de başlar.
                        SizedBox(
                          width: GuSpacing.s16,
                          child: ExcludeSemantics(
                            child: Text(
                              _bullet,
                              style: style,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Expanded(child: Text(note, style: style)),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Koşullar · gizlilik · destek kartı: marka renkli ikonlu, sonda
/// `chevron-right`, aralarında ayraç.
class AboutLinksCard extends StatelessWidget {
  /// Üç satırın dokunma geri çağrıları.
  const AboutLinksCard({
    required this.onTerms,
    required this.onPrivacy,
    required this.onSupport,
    super.key,
  });

  /// "Kullanım Koşulları" (`SET-04.terms`).
  final VoidCallback onTerms;

  /// "Gizlilik Politikası" (`SET-04.privacy`).
  final VoidCallback onPrivacy;

  /// "Yardım ve destek" (`SET-04.support`).
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.gu.colors.brandPrimaryText;
    Widget tile(GuIcons icon, String title, Key key, VoidCallback tap) =>
        GuTile(
          key: key,
          title: title,
          padding: GuTilePadding.inCard,
          leading: GuIcon(icon, size: GuSizes.icon20, color: brand),
          chevron: true,
          onTap: tap,
        );
    return GuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tile(
            GuIcons.scrollText,
            l10n.legalKosullarTitle,
            GuKey.action('SET-04.terms'),
            onTerms,
          ),
          const GuDivider(),
          tile(
            GuIcons.shield,
            l10n.legalGizlilikTitle,
            GuKey.action('SET-04.privacy'),
            onPrivacy,
          ),
          const GuDivider(),
          tile(
            GuIcons.lifeBuoy,
            l10n.supportTitle,
            GuKey.action('SET-04.support'),
            onSupport,
          ),
        ],
      ),
    );
  }
}

/// Kart içi açılır satır: başlık + alt satır + `chevron-down` / `-up` (20,
/// soluk); açıklık erişilebilirlik ağacına `expanded` olarak yansır.
class AboutExpandTile extends StatelessWidget {
  /// [actionKey] satırın aksiyon anahtarıdır.
  const AboutExpandTile({
    required this.actionKey,
    required this.title,
    required this.subtitle,
    required this.isOpen,
    required this.onTap,
    super.key,
  });

  /// Aksiyon anahtarı (`GuKey.action`).
  final Key actionKey;

  /// Başlık.
  final String title;

  /// Alt satır.
  final String subtitle;

  /// Açık mı?
  final bool isOpen;

  /// Dokunma.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    expanded: isOpen,
    child: GuTile(
      key: actionKey,
      title: title,
      subtitle: subtitle,
      padding: GuTilePadding.inCard,
      trailing: GuIcon(
        isOpen ? GuIcons.chevronUp : GuIcons.chevronDown,
        size: GuSizes.icon20,
        color: context.gu.colors.textMuted,
      ),
      onTap: onTap,
    ),
  );
}
