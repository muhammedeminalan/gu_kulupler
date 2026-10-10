import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/display/gu_illustration.dart';
import 'package:gu_ui/src/widgets/display/gu_illustrations.dart';
import 'package:gu_ui/src/widgets/primitives/gu_button.dart';

/// `.empty` gövdesinin dolgu + illüstrasyon ölçüsü (css:300; `ui.js:101`,
/// `:107`).
enum GuEmptyStateLayout {
  /// `.empty{padding:32px 24px}`, illüstrasyon 140.
  regular(GuSizes.emptyPaddingY, GuSizes.emptyPaddingX, GuSizes.illustration),

  /// `compact`: dolgu 20 / 16, illüstrasyon 96 (EVT-01 gün listesi).
  compact(
    GuSizes.emptyCompactPaddingY,
    GuSizes.emptyCompactPaddingX,
    GuSizes.illustrationCompact,
  ),

  /// `inline` hata (`GuListState` içi): dolgu 24 / 16, illüstrasyon 96.
  inline(
    GuSizes.emptyInlinePaddingY,
    GuSpacing.s16,
    GuSizes.illustrationCompact,
  );

  const GuEmptyStateLayout(
    this.paddingY,
    this.paddingX,
    this.illustrationSize,
  );

  /// Dikey dolgu (dp).
  final double paddingY;

  /// Yatay dolgu (dp).
  final double paddingX;

  /// İllüstrasyon kenarı (dp).
  final double illustrationSize;
}

/// Boş durum — prototip `EmptyState` (`ui.js:100–103`), CSS `.empty` /
/// `.empty .ill` (css:300–301). Tek gövde: `GuErrorState` ve `GuOfflineState`
/// bunu sarar (CD-27).
///
/// Ortalı sütun, aralık 12: illüstrasyon · [title] (titleS; `null` → satır
/// yok, CD-105) · [description] (bodyS `text.secondary`, en çok 280 dp) ·
/// [ctaLabel] (`GuButton` primary) · [secondaryLabel] (`GuButton` text).
/// [compact] → dolgu 20 / 16, illüstrasyon 96.
///
/// [GuEmptyState.body] aynı gövdeyi serbest eylem alanıyla ([actions]) çizer:
/// sarmalayıcılar ve ham `.empty` kullanan ekranlar (SYS-04, CLB-03 kilit
/// bloğu) içindir.
class GuEmptyState extends StatelessWidget {
  const GuEmptyState({
    required this.illustration,
    this.title,
    this.description,
    this.ctaLabel,
    this.onCta,
    this.ctaActionKey,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryActionKey,
    bool compact = false,
    super.key,
  }) : layout = compact
           ? GuEmptyStateLayout.compact
           : GuEmptyStateLayout.regular,
       descriptionMaxWidth = GuSizes.emptyDescMaxWidth,
       actions = null,
       liveRegion = false;

  /// Ortak gövde: düğmeler yerine [actions] alanı.
  const GuEmptyState.body({
    required this.illustration,
    this.title,
    this.description,
    this.actions,
    this.layout = GuEmptyStateLayout.regular,
    this.descriptionMaxWidth = GuSizes.emptyDescMaxWidth,
    this.liveRegion = false,
    super.key,
  }) : ctaLabel = null,
       onCta = null,
       ctaActionKey = null,
       secondaryLabel = null,
       onSecondary = null,
       secondaryActionKey = null;

  /// İllüstrasyon (dekoratif).
  final GuIllustrations illustration;

  /// Başlık; `null` → çizilmez (`NoAccessView`, CD-105).
  final String? title;

  /// Açıklama.
  final String? description;

  /// Birincil düğme metni; `null` → düğme yok.
  final String? ctaLabel;

  /// Birincil düğme dokunması.
  final VoidCallback? onCta;

  /// Birincil düğme anahtarı (`GuKey.action`, çağırandan — CD-111).
  final Key? ctaActionKey;

  /// İkincil (metin) düğme metni; `null` → düğme yok.
  final String? secondaryLabel;

  /// İkincil düğme dokunması.
  final VoidCallback? onSecondary;

  /// İkincil düğme anahtarı.
  final Key? secondaryActionKey;

  /// Dolgu + illüstrasyon ölçüsü.
  final GuEmptyStateLayout layout;

  /// Açıklamanın en büyük genişliği; `null` → sınırsız (`OfflineState`,
  /// `ui.js:113`).
  final double? descriptionMaxWidth;

  /// Serbest eylem alanı ([GuEmptyState.body]).
  final Widget? actions;

  /// `role="alert"` (`ErrorState`, `ui.js:107`) → canlı bölge.
  final bool liveRegion;

  /// Kompakt görünüm mü ([GuEmptyStateLayout.compact]).
  bool get compact => layout == GuEmptyStateLayout.compact;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final title = this.title;
    final description = this.description;
    final ctaLabel = this.ctaLabel;
    final secondaryLabel = this.secondaryLabel;
    final maxWidth = descriptionMaxWidth;
    final body = Center(
      heightFactor: 1,
      child: Padding(
        padding: GuInsets.sym(h: layout.paddingX, v: layout.paddingY),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: GuSizes.emptyGap,
          children: [
            GuIllustration(illustration, size: layout.illustrationSize),
            if (title != null)
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: gu.text.titleS,
                  textAlign: TextAlign.center,
                ),
              ),
            if (description != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: maxWidth ?? double.infinity,
                ),
                child: Text(
                  description,
                  style: gu.text.bodyS.copyWith(color: gu.colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            if (ctaLabel != null)
              GuButton(key: ctaActionKey, label: ctaLabel, onPressed: onCta),
            if (secondaryLabel != null)
              GuButton(
                key: secondaryActionKey,
                label: secondaryLabel,
                onPressed: onSecondary,
                variant: GuButtonVariant.text,
              ),
            ?actions,
          ],
        ),
      ),
    );
    if (!liveRegion) return body;
    return Semantics(container: true, liveRegion: true, child: body);
  }
}
