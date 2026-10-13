import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/di/app_clock_provider.dart';
import 'package:gu_kulupler/core/format/app_date_formats.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/product/format/relative_time_formatter.dart';
import 'package:gu_ui/gu_ui.dart';

/// Anket bloğu — prototip `PollBlock` (`cards.js:83–91`), CSS `.poll-opt` /
/// `.poll-fill` / `.is-mine` (css:328–330): seçenek düğmeleri, sonuç dolumu
/// ve "N oy · kalan süre" satırı. `PostCard` içinden çizilir.
///
/// * Oy sayıları gönderi belgesinde tutulmaz: [results] (seçenek → oy)
///   `PostRepository.countVotes` sonucudur; toplam ve yüzdeler bundan
///   hesaplanır (anketin seçeneği olmayan anahtar sayılmaz). Kullanıcının oyu
///   [myOptionId].
/// * [ended] verilmezse anketin süresi saatten okunur (`poll.endsAt`, bitiş
///   anı kapalı sayılır); [showResults] verilmezse sonuçlar kullanıcı oy
///   verdiyse, anket bittiyse ya da anket "oy vermeden sonuç göster" ise
///   görünür (`cards.js:84`).
/// * Durumlar: **oy öncesi** düz seçenek düğmeleri (sonuç gizliyse dolum ve
///   yüzde yok) · **oy verilmiş** kendi seçeneği `brand.primary` kenarlık +
///   `circle-check`, tüm seçeneklerde dolum (`brand.primaryContainer`,
///   genişlik değişimi `GuMotion.fill`) + yüzde · **bitti** sonuçlar + "Anket
///   sona erdi".
/// * Alt satır: "N oy · 3 gün kaldı" / "N oy · Anket sona erdi"; kalan süre
///   uygulama saatinden (`AppClock`), [remainingLabel] verilirse o yazılır.
/// * Seçeneğe dokunma her durumda [onVote]'tur (seçenek kimliğiyle);
///   korumalar ve yazım `PostActionsMixin.votePost`'tadır (oy verilmiş →
///   TST-10, süresi dolmuş → hiçbir şey, danışman → TST-26).
/// * Yüzde yerel ayara göre yazılır (TR `%62`, EN `62%` — CD-101, K-39).
/// * Anahtarı çağıran verir (D-18, CD-86): [optionKey]
///   `<ID>.vote.<postId>.<optionId>`.
/// * Erişilebilirlik: her seçenek metni (+ yüzdesi) ile okunan düğmedir;
///   kendi oyu "seçili", oy verilmiş / bitmiş ankette "devre dışı".
class PollBlock extends ConsumerWidget {
  /// [poll] anketinin bloğu.
  const PollBlock({
    required this.poll,
    this.results = const <String, int>{},
    this.myOptionId,
    this.ended,
    this.showResults,
    this.remainingLabel,
    this.onVote,
    this.optionKey,
    super.key,
  });

  /// Alt satır ayracı (`cards.js:90` `' · '`).
  static const String _separator = ' · ';

  /// Yüzde tabanı.
  static const int _percentBase = 100;

  /// Anket (seçenekler, bitiş, sonuç görünürlüğü).
  final PollModel poll;

  /// Seçenek kimliği → oy sayısı (`countVotes`); bilinmeyen seçenek 0.
  final Map<String, int> results;

  /// Kullanıcının seçtiği seçenek; oy vermediyse `null`.
  final String? myOptionId;

  /// Anket bitti mi; `null` → saatten okunur.
  final bool? ended;

  /// Sonuçlar (dolum + yüzde) çizilsin mi; `null` → kurala göre.
  final bool? showResults;

  /// Kalan süre metni ("3 gün"); `null` → saatten hesaplanır.
  final String? remainingLabel;

  /// Seçeneğe dokunma (seçenek kimliği).
  final ValueChanged<String>? onVote;

  /// Seçenek düğmesinin anahtarı (`<ID>.vote.<postId>.<optionId>`).
  final Key? Function(String optionId)? optionKey;

  /// Anketin seçeneklerine verilen toplam oy.
  int get totalVotes {
    var total = 0;
    for (final option in poll.options) {
      total += results[option.id] ?? 0;
    }
    return total;
  }

  /// [optionId] seçeneğinin yüzdesi (0–100, yuvarlanmış); oy yoksa 0
  /// (`cards.js:87`).
  int percentOf(String optionId) {
    final total = totalVotes;
    if (total == 0) return 0;
    return ((results[optionId] ?? 0) / total * _percentBase).round();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gu = context.gu;
    final l10n = context.l10n;
    final clock = ref.watch(appClockProvider);
    final isEnded = ended ?? !clock.nowUtc().isBefore(poll.endsAt);
    final hasVoted = myOptionId != null;
    final resultsVisible =
        showResults ?? (hasVoted || isEnded || !poll.showResultsAfterVote);
    final formats = AppDateFormats(Localizations.localeOf(context), clock);
    final status = isEnded
        ? l10n.feedPollEnded
        : l10n.feedPollRemaining(
            remainingLabel ??
                RelativeTimeFormatter(l10n, clock).countdown(poll.endsAt),
          );
    final onVote = this.onVote;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: GuSpacing.s6,
      children: [
        for (final option in poll.options)
          _PollOption(
            key: optionKey?.call(option.id),
            text: option.text,
            mine: option.id == myOptionId,
            locked: isEnded || hasVoted,
            percent: resultsVisible ? percentOf(option.id) : null,
            percentLabel: resultsVisible
                ? formats.percent(percentOf(option.id))
                : null,
            onTap: onVote == null ? null : () => onVote(option.id),
          ),
        Row(
          spacing: GuSpacing.s6,
          children: [
            GuIcon(
              GuIcons.chartColumn,
              size: GuSizes.icon14,
              color: gu.colors.textMuted,
            ),
            Expanded(
              child: Text(
                [l10n.feedPollVotes(totalVotes), status].join(_separator),
                style: gu.text.caption,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tek seçenek düğmesi (`.poll-opt`, css:328–330): 1 px kenarlık, radius 12,
/// dolgu 10 / 12; sonuç görünürken arkada yüzde genişliğinde dolum.
class _PollOption extends StatelessWidget {
  const _PollOption({
    required this.text,
    required this.mine,
    required this.locked,
    required this.percent,
    required this.percentLabel,
    required this.onTap,
    super.key,
  });

  /// Seçenek metni.
  final String text;

  /// Kullanıcının oyu mu (`.is-mine`)?
  final bool mine;

  /// Oy verilemez mi (`aria-disabled`: oy verilmiş / anket bitmiş)?
  final bool locked;

  /// Yüzde (0–100); `null` → sonuç gizli.
  final int? percent;

  /// Yüzde metni (`%62`); `null` → sonuç gizli.
  final String? percentLabel;

  /// Dokunma; `null` → düz kutu.
  final VoidCallback? onTap;

  /// İçerik kırpması: dış radius − kenarlık (CSS dolgu kutusu köşesi).
  static final BorderRadius _innerRadius =
      GuRadius.borderSm - BorderRadius.circular(GuSizes.pollOptionBorder);

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final colors = gu.colors;
    final percent = this.percent;
    final percentLabel = this.percentLabel;

    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: GuRadius.borderSm,
        border: Border.all(
          color: mine ? colors.brandPrimary : colors.borderDefault,
          // Token açık kalsın (varsayılanla aynı değer).
          // ignore: avoid_redundant_argument_values
          width: GuSizes.pollOptionBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GuSizes.pollOptionBorder),
        child: ClipRRect(
          borderRadius: _innerRadius,
          child: Stack(
            children: [
              if (percent != null)
                Positioned.fill(
                  child: AnimatedFractionallySizedBox(
                    duration: gu.duration(GuMotion.fill),
                    curve: GuMotion.easeStandard,
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: percent / PollBlock._percentBase,
                    heightFactor: 1,
                    child: ColoredBox(color: colors.brandPrimaryContainer),
                  ),
                ),
              Padding(
                padding: GuInsets.sym(
                  h: GuSizes.pollOptionPaddingX,
                  v: GuSizes.pollOptionPaddingY,
                ),
                child: Row(
                  children: [
                    if (mine) ...[
                      GuIcon(
                        GuIcons.circleCheck,
                        size: GuSizes.icon16,
                        color: colors.brandPrimaryText,
                      ),
                      const SizedBox(width: GuSpacing.s6),
                    ],
                    Expanded(
                      child: Text(
                        text,
                        style: gu.text.bodyS.copyWith(
                          color: colors.textHeading,
                        ),
                      ),
                    ),
                    if (percentLabel != null) ...[
                      GuGap.h8,
                      Text(
                        percentLabel,
                        style: gu.text.labelM.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final semantics = Semantics(
      button: true,
      enabled: !locked,
      selected: mine,
      label: [text, ?percentLabel].join(PollBlock._separator),
      excludeSemantics: true,
      onTap: onTap,
      child: box,
    );
    if (onTap == null) return semantics;
    return GuTapTarget(
      onTap: onTap,
      excludeFromSemantics: true,
      child: semantics,
    );
  }
}
