import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';

/// Zaman çizgisi noktası durumu — CSS `.timeline-dot` + `.is-*` (css:310–311).
enum GuTimelineDotState {
  /// Sınıfsız nokta: `border.default`.
  pending,

  /// `.is-done`: `state.success`.
  done,

  /// `.is-active`: `brand.primary`.
  active,

  /// `.is-danger`: `state.danger`.
  danger;

  /// Nokta ve dış halka rengi.
  Color resolve(GuColors c) => switch (this) {
    pending => c.borderDefault,
    done => c.stateSuccess,
    active => c.brandPrimary,
    danger => c.stateDanger,
  };
}

/// [GuTimeline] adımı — `.timeline-item` içeriği (`screens-clubs.js:131`):
/// nokta durumu + başlık (`t-label-l c-heading`) + açıklama (`t-caption`).
@immutable
class GuTimelineItem {
  const GuTimelineItem({
    required this.state,
    required this.title,
    this.caption,
  });

  /// Nokta durumu.
  final GuTimelineDotState state;

  /// Adım başlığı.
  final String title;

  /// Açıklama satırı; `null` ya da boş → çizilmez.
  final String? caption;
}

/// Zaman çizgisi noktası — CSS `.timeline-dot` (css:310–311): 12 px daire,
/// 2 px `bg.surface` iç kenarlık, 2 px durum renginde dış halka
/// (`box-shadow:0 0 0 2px`; yerleşimi büyütmez).
class GuTimelineDot extends StatelessWidget {
  const GuTimelineDot({this.state = GuTimelineDotState.pending, super.key});

  /// Nokta durumu.
  final GuTimelineDotState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.gu.colors;
    final color = state.resolve(colors);
    return SizedBox.square(
      dimension: GuSizes.timelineDot,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: colors.bgSurface,
            width: GuSizes.timelineDotBorder,
          ),
          boxShadow: [
            BoxShadow(color: color, spreadRadius: GuSizes.timelineDotRing),
          ],
        ),
      ),
    );
  }
}

/// Dikey adım listesi — CSS `.timeline` / `.timeline-item` / `.timeline-rail`
/// / `.timeline-line` (css:307–312), prototip `screens-clubs.js:131`
/// (CLB-05 başvuru adımları; K-36). Öğe en az 56 px, ray 24, aralık 12; son
/// öğe dışında noktanın altında 2 px `border.default` çizgi. Etkileşim ve
/// animasyon yok; her adım tek semantik düğümde okunur.
class GuTimeline extends StatelessWidget {
  const GuTimeline({required this.items, super.key});

  /// Adımlar (yukarıdan aşağıya).
  final List<GuTimelineItem> items;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, item) in items.indexed)
        _TimelineRow(item: item, showLine: index < items.length - 1),
    ],
  );
}

/// `.timeline-item` (css:308): ray (nokta + çizgi) + içerik sütunu
/// (`col gap2 pb16`, `screens-clubs.js:131`).
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.showLine});

  final GuTimelineItem item;
  final bool showLine;

  /// Çizginin öğe üstünden başlangıcı: nokta üst boşluğu + nokta + çizgi
  /// boşluğu (css:310, 312).
  static const double _lineTop =
      GuSizes.timelineDotTop +
      GuSizes.timelineDot +
      GuSizes.timelineLineMarginY;

  /// Çizginin ray içindeki yatay konumu (ortalı, css:309).
  static const double _lineStart =
      (GuSizes.timelineRailWidth - GuSizes.timelineLineWidth) / 2;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final caption = item.caption;
    return MergeSemantics(
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: GuSizes.timelineItemMinHeight,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: GuSizes.timelineRailWidth,
                  child: Padding(
                    padding: GuInsets.only(top: GuSizes.timelineDotTop),
                    child: Center(
                      heightFactor: 1,
                      child: GuTimelineDot(state: item.state),
                    ),
                  ),
                ),
                const SizedBox(width: GuSizes.timelineGap),
                Expanded(
                  child: Padding(
                    padding: GuInsets.only(bottom: GuSpacing.s16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: gu.text.labelL.copyWith(
                            color: gu.colors.textHeading,
                          ),
                        ),
                        if (caption != null && caption.isNotEmpty) ...[
                          const SizedBox(height: GuSpacing.s2),
                          Text(caption, style: gu.text.caption),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showLine)
            PositionedDirectional(
              start: _lineStart,
              top: _lineTop,
              bottom: GuSizes.timelineLineMarginY,
              width: GuSizes.timelineLineWidth,
              child: ColoredBox(color: gu.colors.borderDefault),
            ),
        ],
      ),
    );
  }
}
