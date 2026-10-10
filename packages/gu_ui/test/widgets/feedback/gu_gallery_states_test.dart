// T-06 · durum grubu galeri golden'ı (`gu_gallery_states__default__*.png`):
// GuBanner, GuSkeleton, GuSkeletonList, GuListEnd, GuEmptyState,
// GuErrorState, GuOfflineState (GuListState gövdeleri bunlardır).
// Referans: `ds_banners.webp` (6 tür, eylem + kapat, card), `ds_cards.webp`
// (iskelet + boş durum), `ds_feedback.webp` (hata), `states/CLB-01__loading`
// (card), `states/NTF-01__loading` (tile), `states/EVT-01__empty`,
// `states/CLB-01__error` (inline), `screens/SYS-03` (çevrimdışı).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/golden_helper.dart';

void _noop() {}

Widget _column(List<Widget> children) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  spacing: GuSpacing.s8,
  children: children,
);

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 728,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: GuSpacing.s12,
      children: [
        Expanded(
          child: _column([
            // ds_banners sırası.
            const GuBanner(
              text: 'Çevrimdışısın. Önbellekteki veriler gösteriliyor.',
              kind: GuBannerKind.offline,
            ),
            const GuBanner(text: 'Etkinlik henüz başlamadı.'),
            const GuBanner(
              text: 'Bildirimler kapalı',
              kind: GuBannerKind.warning,
              actionLabel: 'Aç',
              onAction: _noop,
              onDismiss: _noop,
              dismissSemanticLabel: 'Kapat',
            ),
            const GuBanner(
              text: 'Danışman görünümü — salt okunur',
              kind: GuBannerKind.readonly,
            ),
            const GuBanner(
              text: 'Bu kulüp geçici olarak askıda.',
              kind: GuBannerKind.danger,
              icon: GuIcons.ban,
            ),
            const GuBanner(
              text: 'Üyeliğin onaylandı.',
              kind: GuBannerKind.success,
              card: true,
            ),
            // MGT-02: satır içi anahtar.
            GuBanner(
              text: 'Başvurular kapalı',
              icon: GuIcons.lock,
              trailing: GuSwitch(
                value: false,
                onChanged: (_) {},
                semanticLabel: 'Başvuruları aç',
              ),
            ),
            // Tek blok: çizgi + daire.
            const Row(
              spacing: GuSpacing.s12,
              children: [
                GuSkeleton(
                  width: GuSizes.icon24,
                  height: GuSizes.icon24,
                  circle: true,
                ),
                Expanded(child: GuSkeleton()),
              ],
            ),
            const GuSkeletonList(count: 2, semanticLabel: 'Yükleniyor'),
            GuListState(
              status: GuListStatus.loading,
              dataBuilder: (_) => const SizedBox.shrink(),
              emptyBuilder: (_) => const SizedBox.shrink(),
              errorBuilder: (_) => const SizedBox.shrink(),
              skeletonCount: 1,
              skeletonVariant: GuSkeletonVariant.card,
              skeletonSemanticLabel: 'Yükleniyor',
            ),
            const GuListEnd(label: 'Hepsi bu kadar'),
            const GuEmptyState(
              illustration: GuIllustrations.emptyEvents,
              title: 'Bu aralıkta etkinlik yok',
              description: 'Filtreleri değiştir ya da başka bir tarih seç.',
              compact: true,
            ),
          ]),
        ),
        Expanded(
          child: _column([
            const GuEmptyState(
              illustration: GuIllustrations.emptyClubs,
              title: 'Aramana uygun kulüp bulamadık',
              description:
                  'Filtreleri gevşetmeyi ya da başka bir kategori seçmeyi '
                  'dene.',
              ctaLabel: 'Filtreleri temizle',
              onCta: _noop,
              secondaryLabel: 'Kulüp ara',
              onSecondary: _noop,
            ),
            GuErrorState(
              title: 'Bir şeyler ters gitti',
              description:
                  'İçerik yüklenemedi. Bağlantını kontrol edip yeniden '
                  'deneyebilirsin.',
              retryLabel: 'Yeniden dene',
              onRetry: () async {},
              homeLabel: 'Ana sayfaya dön',
              onHome: _noop,
              inline: true,
            ),
            GuOfflineState(
              title: 'Çevrimdışısın',
              description:
                  'Önbellekte gösterilecek veri yok. Bağlantı gelince '
                  'yeniden dene.',
              retryLabel: 'Yeniden dene',
              onRetry: () async => false,
            ),
          ]),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('T-06 · durum grubu · galeri golden (açık + koyu)', (
    tester,
  ) async {
    await goldenForWidget(
      tester,
      'gu_gallery_states',
      {'default': const _Gallery()},
      size: const Size(780, 1160),
    );
  });
}
