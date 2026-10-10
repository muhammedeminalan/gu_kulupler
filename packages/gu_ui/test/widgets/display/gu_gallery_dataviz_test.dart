// T-04 · veri görseli grubu galeri golden'ı
// (`gu_gallery_dataviz__default__*.png`): GuProgress, GuDonut, GuDateBadge,
// GuMiniLineChart (seçili nokta + ipucu), GuTimeline, GuTicketFrame.
// Referans: `ds_feedback.webp` (48/60, 60/60, %62), `ds_special.webp`
// ("9 EKİ", grafik), `screens/CLB-05` (adımlar), `screens/EVT-03` (bilet).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/golden_helper.dart';
import '../../helpers/pump_app.dart';

const _chartAction = 'MGT-01.chart.point';
const _chartLabels = ['-7', '-6', '-5', '-4', '-3', '-2', '-1', '0'];

class _ProgressRow extends StatelessWidget {
  const _ProgressRow(this.progress, this.label);

  final GuProgress progress;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: progress),
      GuGap.h8,
      Text(label, style: context.gu.text.caption),
    ],
  );
}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // İlerleme: brand 48/60, muted 60/60, ince warning, ince success.
        const _ProgressRow(
          GuProgress(value: 48, max: 60, semanticLabel: '48/60'),
          '48/60',
        ),
        GuGap.v8,
        const _ProgressRow(
          GuProgress(
            value: 60,
            max: 60,
            kind: GuProgressKind.muted,
            semanticLabel: '60/60',
          ),
          '60/60',
        ),
        GuGap.v8,
        const Row(
          children: [
            Expanded(
              child: GuProgress(
                value: 36,
                max: 40,
                kind: GuProgressKind.warning,
                thin: true,
                semanticLabel: '36/40',
              ),
            ),
            GuGap.h16,
            Expanded(
              child: GuProgress(
                value: 10,
                kind: GuProgressKind.success,
                thin: true,
                semanticLabel: '%10',
              ),
            ),
          ],
        ),
        GuGap.v16,
        // Halka (%62, %0, %100 küçük) + tarih rozetleri.
        const Row(
          children: [
            GuDonut(value: 62, valueLabel: '%62', semanticLabel: '%62'),
            GuGap.h16,
            GuDonut(
              value: 100,
              valueLabel: '%100',
              semanticLabel: '%100',
              size: 56,
              strokeWidth: 6,
            ),
            GuGap.h16,
            GuDonut(
              value: 0,
              valueLabel: '0%',
              semanticLabel: '0%',
              size: 56,
              strokeWidth: 6,
            ),
            GuGap.h8,
            GuDateBadge(day: 9, monthShort: 'EKİ'),
            GuGap.h8,
            GuDateBadge(day: 28, monthShort: 'OCT'),
          ],
        ),
        GuGap.v16,
        // Mini grafik (kart zemini üstünde); testte 5. nokta seçilir.
        DecoratedBox(
          decoration: BoxDecoration(
            color: gu.colors.bgSurface,
            borderRadius: GuRadius.borderLg,
          ),
          child: Padding(
            padding: GuInsets.all16,
            child: GuMiniLineChart(
              data: const [120, 128, 131, 140, 146, 152, 160, 171],
              labels: _chartLabels,
              pointKeyBuilder: (i) => GuKey.action('$_chartAction.$i'),
              semanticLabel: 'Üye büyümesi',
              pointLabelBuilder: (index, value) =>
                  '${_chartLabels[index]}: ${value.round()}',
              tooltipBuilder: (index, value) =>
                  '${_chartLabels[index]} · ${value.round()}',
            ),
          ),
        ),
        GuGap.v16,
        // Zaman çizgisi: CLB-05 beklemede (done / active / pending) ve ret.
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GuTimeline(
                items: [
                  GuTimelineItem(
                    state: GuTimelineDotState.done,
                    title: 'Gönderildi',
                    caption: '6 Eki Sal, 20:04',
                  ),
                  GuTimelineItem(
                    state: GuTimelineDotState.active,
                    title: 'İnceleniyor',
                    caption: 'Kulüp yönetimi inceliyor',
                  ),
                  GuTimelineItem(
                    state: GuTimelineDotState.pending,
                    title: 'Sonuç',
                    caption: 'Bekleniyor',
                  ),
                ],
              ),
            ),
            GuGap.h8,
            Expanded(
              child: GuTimeline(
                items: [
                  GuTimelineItem(
                    state: GuTimelineDotState.done,
                    title: 'İnceleniyor',
                    caption: '7 Eki Çar, 09:12',
                  ),
                  GuTimelineItem(
                    state: GuTimelineDotState.danger,
                    title: 'Sonuç',
                    caption: 'Reddedildi',
                  ),
                ],
              ),
            ),
          ],
        ),
        GuGap.v8,
        // Bilet çerçevesi (EVT-03 gövde düzeni).
        GuTicketFrame(
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YAZILIM VE YAPAY ZEKÂ TOPLULUĞU', style: gu.text.overline),
              GuGap.v4,
              Text('Yapay Zekâya Giriş Atölyesi', style: gu.text.titleM),
            ],
          ),
          body: Column(
            children: [
              Text('GU-CWV4-JMW9', style: gu.text.ticketCode),
              GuGap.v12,
              Text(
                'Mehmet Kaya',
                style: gu.text.bodyM.copyWith(color: gu.colors.textHeading),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void main() {
  // `goldenForWidget` ile aynı çerçeve, boyut ve dosya adı; fark: karşılaştırma
  // öncesi grafikte bir nokta seçilir (seçili nokta + ipucu durumu).
  testWidgets('T-04 · veri görseli grubu · galeri golden (açık + koyu)', (
    tester,
  ) async {
    for (final theme in kGoldenThemes) {
      await tester.pumpApp(
        const GoldenFrame(child: _Gallery()),
        theme: theme,
      );
      await tester.tap(find.byKey(GuKey.action('$_chartAction.5')));
      await tester.pump(GuMotion.base);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(kGoldenFrameKey),
        matchesGoldenFile(
          goldenUri(widgetGoldenPath('gu_gallery_dataviz', 'default', theme)),
        ),
      );
    }
  });
}
