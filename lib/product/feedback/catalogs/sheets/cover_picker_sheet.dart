import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_data/gu_data.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_kulupler/l10n/app_localizations.dart';
import 'package:gu_kulupler/product/feedback/catalogs/sheets/photo_source_sheet.dart';
import 'package:gu_kulupler/product/feedback/feedback_keys.dart';
import 'package:gu_kulupler/product/feedback/feedback_service_provider.dart';
import 'package:gu_kulupler/product/feedback/sheet_id.dart';
import 'package:gu_kulupler/product/service/image_picker_service.dart';
import 'package:gu_kulupler/product/widget/club/cover_mapper.dart';
import 'package:gu_ui/gu_ui.dart';

/// SHT-31 "Kapak seç" sonucu — sayfanın `pop` değeri. X / scrim / sürükleme /
/// geri → `null` (kapak değişmez).
sealed class CoverPickerResult extends Equatable {
  const CoverPickerResult();
}

/// Şablon kapak (`SHT-31.use`): [palette] × [pattern] (3 × 4 = 12 şablon,
/// K-C; `SHT-31.template.<palette>.<pattern>`), desen tohumu [seed]
/// (`SHT-31.shuffle` değiştirir). Şablon seçimi özel kapağı (`coverPath`)
/// bırakır.
final class CoverTemplatePicked extends CoverPickerResult {
  /// [palette] × [pattern] şablonu, [seed] tohumuyla.
  const CoverTemplatePicked({
    required this.palette,
    required this.pattern,
    required this.seed,
  });

  /// Seçilen palet.
  final ClubPalette palette;

  /// Seçilen desen.
  final ClubPattern pattern;

  /// Desen tohumu (`coverSeed`). Etkinlikte tohum kimlikten türetilir
  /// (`FirestoreIds.eventCoverSeed`, Rules `coverSeed == 'event-' + id`):
  /// çağıran yazmaz.
  final String seed;

  @override
  List<Object?> get props => [palette, pattern, seed];
}

/// Özel kapak (`SHT-31.gallery` → SHT-16): görsel [source] kaynağından
/// seçilir; seçme, sıkıştırma ve yükleme çağıranın ViewModel'indedir
/// (MGT-05: `createDraft` → `uploadCover` — CD-47).
final class CoverUploadPicked extends CoverPickerResult {
  /// [source] kaynağından özel kapak.
  const CoverUploadPicked(this.source);

  /// SHT-16'da seçilen kaynak (kamera / galeri).
  final MediaSource source;

  @override
  List<Object?> get props => [source];
}

/// SHT-31 "Kapak seç" gövdesi — 16:9 önizleme + palet başına 4 desen
/// şablonu (palet adı görünür etiket, desen adı Semantics — CD-35) +
/// "Deseni karıştır"; alt çubuk "Galeriden seç" (SHT-16) · "Kullan"
/// (prototip `SHEETS['SHT-31']`, `sheets.js:144–148`). MGT-05 (T-34), MGT-09
/// (T-36) ve ADM-03 (T-39) açar; birden çok feature kullandığı için
/// product'tadır.
///
/// Sayfa hiçbir şey yazmaz: [CoverPickerResult] döner (`pop`). Anahtarlar
/// `SHT-31.template.<palette>.<pattern>`, `SHT-31.shuffle`,
/// `SHT-31.gallery`, `SHT-31.use`, `SHT-31.close`.
///
/// ```dart
/// final result = await feedback.showSheet<CoverPickerResult>(
///   SheetId.sht31,
///   builder: (_) => CoverPickerContent(
///     palette: state.coverPalette,
///     pattern: state.coverPattern,
///     seed: seed,
///     icon: GuIcons.calendar,
///   ),
/// );
/// ```
///
/// Design: SHT-31
class CoverPickerContent extends ConsumerStatefulWidget {
  /// Başlangıç seçimi [palette] × [pattern], tohum [seed]; önizlemedeki
  /// sembol [icon].
  const CoverPickerContent({
    required this.palette,
    required this.pattern,
    required this.seed,
    this.icon,
    super.key,
  });

  /// Açılıştaki palet.
  final ClubPalette palette;

  /// Açılıştaki desen.
  final ClubPattern pattern;

  /// Açılıştaki desen tohumu.
  final String seed;

  /// Önizleme sembolü (prototip `props.icon`); `null` → varsayılan.
  final GuIcons? icon;

  /// Paletlerin sırası (prototip `PALETTES`, `art.js:4–8`).
  static const List<ClubPalette> palettes = [
    ClubPalette.red,
    ClubPalette.slate,
    ClubPalette.bordeaux,
  ];

  /// Desenlerin sırası (prototip `PATTERNS`, `art.js:9`).
  static const List<ClubPattern> patterns = [
    ClubPattern.mountain,
    ClubPattern.lines,
    ClubPattern.dots,
    ClubPattern.waves,
  ];

  /// SHT-31 [action] anahtarı (`SHT-31.<aksiyon>`).
  static Key keyOf(String action) =>
      FeedbackKeys.of(SheetId.sht31.designId, action);

  /// [palette] × [pattern] şablon hücresinin anahtarı
  /// (`SHT-31.template.<palette>.<pattern>`).
  static Key templateKeyOf(ClubPalette palette, ClubPattern pattern) =>
      keyOf('template.${palette.json}.${pattern.json}');

  /// [palette] adı (CD-35; görünür grup etiketi).
  static String paletteLabel(AppLocalizations l10n, ClubPalette palette) =>
      switch (palette) {
        ClubPalette.red => l10n.coverPaletteRed,
        ClubPalette.slate => l10n.coverPaletteSlate,
        ClubPalette.bordeaux => l10n.coverPaletteBordeaux,
      };

  /// [pattern] adı (CD-35; şablon hücresinin Semantics etiketinde).
  static String patternLabel(AppLocalizations l10n, ClubPattern pattern) =>
      switch (pattern) {
        ClubPattern.mountain => l10n.coverPatternMountain,
        ClubPattern.lines => l10n.coverPatternLines,
        ClubPattern.dots => l10n.coverPatternDots,
        ClubPattern.waves => l10n.coverPatternWaves,
      };

  @override
  ConsumerState<CoverPickerContent> createState() => _CoverPickerContentState();
}

class _CoverPickerContentState extends ConsumerState<CoverPickerContent> {
  /// "Deseni karıştır" tohum son eki uzunluğu (prototip
  /// `Math.random().toString(36).slice(2, 8)`).
  static const int _seedLength = 6;
  static const int _seedRadix = 36;
  static const String _seedPrefix = 'cover-';

  static final math.Random _random = math.Random();

  late ClubPalette _palette = widget.palette;
  late ClubPattern _pattern = widget.pattern;
  late String _seed = widget.seed;

  /// Seçim halkasının hücreden taşması (`outline 3px` + `outline-offset 2px`,
  /// `sheets.js:147`).
  static const double _ringOutset =
      GuSizes.highlightRingWidth + GuSizes.focusRingOffset;

  void _shuffle() => setState(() {
    final suffix = StringBuffer();
    for (var i = 0; i < _seedLength; i++) {
      suffix.write(_random.nextInt(_seedRadix).toRadixString(_seedRadix));
    }
    _seed = '$_seedPrefix$suffix';
  });

  void _use() => Navigator.of(context).pop(
    CoverTemplatePicked(palette: _palette, pattern: _pattern, seed: _seed),
  );

  /// "Galeriden seç" (`SHT-31.gallery`): SHT-16 kaynağı sorar; kamera /
  /// galeri seçilirse sayfa [CoverUploadPicked] ile kapanır (seçme, yeniden
  /// kodlama ve yükleme çağıranın ViewModel'inde — CD-47, CD-135).
  Future<void> _gallery() async {
    final choice = await ref
        .read(feedbackServiceProvider)
        .showSheet<PhotoSourceChoice>(
          SheetId.sht16,
          builder: (_) => const PhotoSourceSheet(),
        );
    if (!mounted) return;
    final source = switch (choice) {
      PhotoSourceChoice.camera => MediaSource.camera,
      PhotoSourceChoice.gallery => MediaSource.gallery,
      // "Fotoğrafı kaldır" burada sunulmaz (`hasPhoto` verilmez).
      PhotoSourceChoice.remove || null => null,
    };
    if (source == null) return;
    Navigator.of(context).pop(CoverUploadPicked(source));
  }

  Widget _template(
    AppLocalizations l10n,
    ClubPalette palette,
    ClubPattern pattern,
  ) {
    final selected = palette == _palette && pattern == _pattern;
    final ring = context.gu.colors.brandPrimary;
    return GuActionSurface(
      key: CoverPickerContent.templateKeyOf(palette, pattern),
      borderRadius: GuRadius.borderChip,
      selected: selected,
      semanticLabel:
          '${CoverPickerContent.paletteLabel(l10n, palette)} · '
          '${CoverPickerContent.patternLabel(l10n, pattern)}',
      onTap: () => setState(() {
        _palette = palette;
        _pattern = pattern;
      }),
      builder: (context, pressed) => Stack(
        clipBehavior: Clip.none,
        children: [
          GuCover.template(
            palette: CoverMapper.palette(palette),
            pattern: CoverMapper.pattern(pattern),
            icon: widget.icon,
            ratio: GuCoverRatio.r1x1,
            borderRadius: GuRadius.borderChip,
          ),
          if (selected)
            Positioned(
              left: -_ringOutset,
              top: -_ringOutset,
              right: -_ringOutset,
              bottom: -_ringOutset,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: ring,
                      width: GuSizes.highlightRingWidth,
                    ),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(GuRadius.chip + _ringOutset),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _paletteGroup(AppLocalizations l10n, ClubPalette palette) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: GuSpacing.s8,
    children: [
      Text(
        CoverPickerContent.paletteLabel(l10n, palette),
        style: context.gu.text.fieldLabel,
      ),
      Row(
        spacing: GuSpacing.s8,
        children: [
          for (final pattern in CoverPickerContent.patterns)
            Expanded(child: _template(l10n, palette, pattern)),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GuSheetFrame(
      title: l10n.sht31Title,
      closeSemanticLabel: l10n.a11yClose,
      closeKey: CoverPickerContent.keyOf('close'),
      full: true,
      footer: [
        GuButton(
          key: CoverPickerContent.keyOf('gallery'),
          label: l10n.sht31Gallery,
          variant: GuButtonVariant.outline,
          icon: GuIcons.images,
          onPressed: _gallery,
        ),
        GuButton(
          key: CoverPickerContent.keyOf('use'),
          label: l10n.sht31Use,
          onPressed: _use,
        ),
      ],
      body: Padding(
        padding: GuInsets.only(bottom: GuSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: GuSpacing.s16,
          children: [
            GuCover.template(
              palette: CoverMapper.palette(_palette),
              pattern: CoverMapper.pattern(_pattern),
              icon: widget.icon,
              borderRadius: GuRadius.borderMd,
            ),
            for (final palette in CoverPickerContent.palettes)
              _paletteGroup(l10n, palette),
            GuButton(
              key: CoverPickerContent.keyOf('shuffle'),
              label: l10n.sht31Shuffle,
              variant: GuButtonVariant.text,
              icon: GuIcons.refreshCw,
              onPressed: _shuffle,
            ),
          ],
        ),
      ),
    );
  }
}
