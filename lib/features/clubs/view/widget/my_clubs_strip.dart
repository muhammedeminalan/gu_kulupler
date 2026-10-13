import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// "Kulüplerim" şeridi — CLB-01'in başında, kullanıcının etkin üyesi olduğu
/// kulüpler (prototip `screens-clubs.js:25`).
///
/// Bölüm başlığı (üst boşluksuz) + yatay kaydırılan şerit (`.hscroll.pb16`
/// yazılmıştır, ancak dikey dolgu 3 px kalır — K-59):
/// [chips] (`MyClubChip` kartları, çağıran kurar) ve sonda "Tümü" kartı
/// (`arrow-right` 22 + etiket, ikisi de `brand.primaryText`). "Tümü" kartının
/// anahtarı çağırandan ([allKey] `CLB-01.myClubsAll`).
class MyClubsStrip extends StatelessWidget {
  /// [chips] kulüp kartları; "Tümü" [onAll] çağırır (PRF-03).
  const MyClubsStrip({
    required this.chips,
    required this.onAll,
    this.allKey,
    super.key,
  });

  /// Kulüp kartları (`MyClubChip`).
  final List<Widget> chips;

  /// "Tümü" — kulüplerim sayfası (PRF-03).
  final VoidCallback onAll;

  /// "Tümü" kartının anahtarı.
  final Key? allKey;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final l10n = context.l10n;
    final brand = gu.colors.brandPrimaryText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GuSectionTitle(
          title: l10n.clubsMyTitle,
          topMargin: GuSectionTitleMargin.none,
        ),
        GuHorizontalList(
          children: [
            ...chips,
            GuCard(
              key: allKey,
              onTap: onAll,
              semanticLabel: l10n.commonAll,
              child: SizedBox(
                width: GuSizes.myClubsAllTileWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: GuSpacing.s6,
                  children: [
                    GuIcon(
                      GuIcons.arrowRight,
                      size: GuSizes.icon22,
                      color: brand,
                    ),
                    Text(
                      l10n.commonAll,
                      style: gu.text.labelM.copyWith(color: brand),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
