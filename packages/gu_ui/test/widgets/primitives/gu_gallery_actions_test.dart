// T-04 · eylem grubu galeri golden'ı (`gu_gallery_actions__default__*.png`):
// GuButton, GuIconButton, GuChip, GuFab.
// Referans: `ds_buttons.webp` (varyant × boyut, ikonlu, iconOnly, full, ikon
// düğmeleri), `ds_selection.webp` (çipler), `screens/ADM-02` (FAB),
// `ds_cards.webp` (sayaçlı / tonlu ikon düğmeleri).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/golden_helper.dart';

void _noop() {}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final colors = context.gu.colors;
    Widget wrap(List<Widget> children) => Wrap(
      spacing: GuSpacing.s8,
      runSpacing: GuSpacing.s8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: GuSpacing.s12,
      children: [
        // ds_buttons: varyant başına sm / md / lg + ikonlu + iconOnly.
        for (final variant in GuButtonVariant.values)
          wrap([
            for (final size in GuButtonSize.values)
              GuButton(
                label: 'Katıl',
                variant: variant,
                size: size,
                onPressed: _noop,
              ),
            GuButton(
              label: 'Seçenek ekle',
              variant: variant,
              icon: GuIcons.plus,
              onPressed: _noop,
            ),
            GuButton(
              label: 'Beğen',
              semanticLabel: 'Beğen',
              variant: variant,
              icon: GuIcons.heart,
              iconOnly: true,
              onPressed: _noop,
            ),
          ]),
        const GuButton(
          label: 'Başvuruyu gönder',
          full: true,
          onPressed: _noop,
        ),
        // Durumlar: loading, disabled, sondaki ikon.
        wrap(const [
          GuButton(label: 'Gönder', loading: true, onPressed: _noop),
          GuButton(
            label: 'Gönder',
            variant: GuButtonVariant.outline,
            loading: true,
            onPressed: _noop,
          ),
          GuButton(label: 'Kaydet', disabled: true, onPressed: _noop),
          GuButton(
            label: 'Kaydet',
            variant: GuButtonVariant.tonal,
            disabled: true,
            onPressed: _noop,
          ),
          GuButton(
            label: 'Devam',
            variant: GuButtonVariant.dangerOutline,
            disabled: true,
            onPressed: _noop,
          ),
          GuButton(
            label: 'Tümü',
            variant: GuButtonVariant.text,
            size: GuButtonSize.sm,
            iconTrailing: GuIcons.arrowRight,
            onPressed: _noop,
          ),
        ]),
        // ds_buttons alt sıra + K-32 görünümleri.
        wrap([
          const GuIconButton(
            icon: GuIcons.search,
            semanticLabel: 'Ara',
            onPressed: _noop,
          ),
          const GuIconButton(
            icon: GuIcons.bell,
            semanticLabel: 'Bildirimler',
            badge: '3',
            onPressed: _noop,
          ),
          const GuIconButton(
            icon: GuIcons.moreVertical,
            semanticLabel: 'Daha fazla',
            disabled: true,
            onPressed: _noop,
          ),
          const GuIconButton(
            icon: GuIcons.scanLine,
            semanticLabel: 'Tara',
            tone: GuIconButtonTone.brand,
            onPressed: _noop,
          ),
          const GuIconButton(
            icon: GuIcons.x,
            semanticLabel: 'Kapat',
            size: GuIconButtonSize.sm,
            iconSize: GuSizes.icon18,
            onPressed: _noop,
          ),
          const GuIconButton(
            icon: GuIcons.x,
            semanticLabel: 'Kapat',
            size: GuIconButtonSize.xs,
            iconSize: GuSizes.icon16,
            onPressed: _noop,
          ),
          const GuIconButton(
            icon: GuIcons.check,
            semanticLabel: 'Onayla',
            tone: GuIconButtonTone.success,
            onPressed: _noop,
          ),
          const GuIconButton(
            icon: GuIcons.x,
            semanticLabel: 'Reddet',
            tone: GuIconButtonTone.danger,
            onPressed: _noop,
          ),
          const GuIconButton(
            icon: GuIcons.heart,
            semanticLabel: 'Beğen',
            iconSize: GuSizes.icon22,
            countLabel: '128',
            onPressed: _noop,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.brandPrimary, colors.stateInfo],
              ),
            ),
            child: const Padding(
              padding: GuInsets.all8,
              child: GuIconButton(
                icon: GuIcons.share2,
                semanticLabel: 'Paylaş',
                onCover: true,
                onPressed: _noop,
              ),
            ),
          ),
        ]),
        // ds_selection: seçili, ikonlu, sayaçlı, input + kaldır, disabled.
        wrap(const [
          GuChip(label: 'Tümü', selected: true, onTap: _noop),
          GuChip(label: 'Teknoloji', icon: GuIcons.cpu, onTap: _noop),
          GuChip(label: 'Filtre', count: 2, onTap: _noop),
          GuChip(
            label: 'hackathon',
            input: true,
            removable: true,
            removeSemanticLabel: 'Kaldır',
            onRemove: _noop,
          ),
          GuChip(
            label: 'Spor',
            icon: GuIcons.dumbbell,
            count: 3,
            selected: true,
            onTap: _noop,
          ),
          GuChip(label: 'Başvurular kapalı', disabled: true, onTap: _noop),
        ]),
        // screens/ADM-02: FAB sağ altta (alt 16, sağ 16).
        const SizedBox(
          height: 88,
          child: Stack(
            children: [
              GuFab(
                label: 'Kulüp oluştur',
                icon: GuIcons.plus,
                semanticLabel: 'Kulüp oluştur',
                onPressed: _noop,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('T-04 · eylem grubu · galeri golden (açık + koyu)', (
    tester,
  ) async {
    await goldenForWidget(tester, 'gu_gallery_actions', {
      'default': const _Gallery(),
    }, size: const Size(540, 1200));
  });
}
