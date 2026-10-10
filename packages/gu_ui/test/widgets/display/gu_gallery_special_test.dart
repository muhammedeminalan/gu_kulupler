// T-06 · takvim / özel grup galeri golden'ı
// (`gu_gallery_special__default__*.png`): GuCalendar (varsayılan: bugün =
// seçili + noktalar; compact: bugün halkası, seçili, min / max dışı, EN
// etiketleri), GuMapPlaceholder, GuSuccessCheck (72 / 96 / 110, son kare),
// GuParallaxHeader (kapak + on-cover düğmeler).
// Referans: `ds_special.webp` (takvim), `sheets/SHT-28` (compact),
// `screens/CLB-04` (başarı işareti), `screens/EVT-02` (parallax, harita).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

import '../../helpers/golden_helper.dart';

final DateTime _october = DateTime(2026, 10);
final DateTime _today = DateTime(2026, 10, 8);

/// `ds_special.webp` takvimindeki etkinlik noktaları (Ekim 2026).
const Map<int, int> _dots = {
  2: 1,
  4: 1,
  8: 1,
  9: 1,
  10: 1,
  11: 1,
  12: 1,
  13: 2,
  14: 1,
  15: 1,
  16: 1,
  17: 1,
  18: 1,
  19: 1,
  20: 1,
  22: 1,
  24: 1,
  26: 1,
  28: 1,
};

String _dayLabel(DateTime day) => GuCalendar.dayKey(day);

void _noop() {}

void _noSelect(DateTime day) {}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // `ds_special.webp`: bugün = seçili 8 Ekim, noktalar, Bugün.
              GuCard(
                padding: GuCard.bodyPadding,
                child: GuCalendar(
                  month: _october,
                  today: _today,
                  selected: _today,
                  onSelect: _noSelect,
                  monthTitle: 'Ekim 2026',
                  weekdayLabels: const [
                    'Pz',
                    'Sa',
                    'Ça',
                    'Pe',
                    'Cu',
                    'Cm',
                    'Pa',
                  ],
                  dotsFor: (day) =>
                      day.month == DateTime.october ? _dots[day.day] ?? 0 : 0,
                  onPrev: _noop,
                  onNext: _noop,
                  onToday: _noop,
                  todayLabel: 'Bugün',
                  prevSemanticLabel: 'Önceki ay',
                  nextSemanticLabel: 'Sonraki ay',
                  daySemanticLabel: _dayLabel,
                ),
              ),
              GuGap.v16,
              const GuMapPlaceholder(
                label: 'map placeholder · Bilgisayar Laboratuvarı-2',
              ),
              GuGap.v16,
              // Son kare (azaltılmış hareket): 72 / 96 / 110.
              MediaQuery(
                data: media.copyWith(disableAnimations: true),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GuSuccessCheck(semanticLabel: 'Başarılı', size: 72),
                    GuSuccessCheck(semanticLabel: 'Başarılı'),
                    GuSuccessCheck(semanticLabel: 'Başarılı', size: 110),
                  ],
                ),
              ),
            ],
          ),
        ),
        GuGap.h16,
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // SHT-28 düzeni (compact): bugün halkası 8, seçili 14 (beyaz
              // noktalar), 5 Ekim öncesi / 28 Ekim sonrası devre dışı.
              GuCard(
                padding: GuCard.bodyPadding,
                child: GuCalendar(
                  month: _october,
                  today: _today,
                  selected: DateTime(2026, 10, 14),
                  onSelect: _noSelect,
                  monthTitle: 'October 2026',
                  weekdayLabels: const [
                    'Mo',
                    'Tu',
                    'We',
                    'Th',
                    'Fr',
                    'Sa',
                    'Su',
                  ],
                  dotsFor: (day) => day.day == 14 ? 5 : _dots[day.day] ?? 0,
                  min: DateTime(2026, 10, 5),
                  max: DateTime(2026, 10, 28),
                  onPrev: _noop,
                  onNext: _noop,
                  prevSemanticLabel: 'Previous month',
                  nextSemanticLabel: 'Next month',
                  daySemanticLabel: _dayLabel,
                  compact: true,
                ),
              ),
              GuGap.v16,
              // EVT-02 başlığı: tasarım mock'undaki üst inset (54) ile.
              MediaQuery(
                data: media.copyWith(
                  viewPadding: const EdgeInsets.only(top: 54),
                ),
                child: const GuParallaxHeader(
                  cover: GuCover.template(
                    palette: GuCoverPalette.red,
                    pattern: GuCoverPattern.lines,
                    icon: GuIcons.codeXml,
                    ratio: GuCoverRatio.fill,
                  ),
                  scrollOffset: AlwaysStoppedAnimation<double>(0),
                  leading: GuIconButton(
                    icon: GuIcons.arrowLeft,
                    semanticLabel: 'Geri',
                    onPressed: _noop,
                    onCover: true,
                  ),
                  actions: [
                    GuIconButton(
                      icon: GuIcons.share2,
                      semanticLabel: 'Paylaş',
                      onPressed: _noop,
                      onCover: true,
                    ),
                    GuIconButton(
                      icon: GuIcons.moreVertical,
                      semanticLabel: 'Daha fazla',
                      onPressed: _noop,
                      onCover: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('T-06 · takvim / özel grup · galeri golden (açık + koyu)', (
    tester,
  ) async {
    await goldenForWidget(tester, 'gu_gallery_special', {
      'default': const _Gallery(),
    }, size: const Size(780, 844));
    expect(tester.takeException(), isNull);
  });
}
