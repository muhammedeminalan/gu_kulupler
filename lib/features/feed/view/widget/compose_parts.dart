import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/features/feed/provider/compose_state.dart';
import 'package:gu_kulupler/product/widget/post/image_grid.dart';
import 'package:gu_ui/gu_ui.dart';

/// FED-03 formunun küçük ortak parçaları (`ComposeForm`, `PollEditor`).

/// Alan altı hata satırı — CSS `.field-help.is-error` (css:171): 14 px
/// `triangle-alert` + `state.danger` metin; `role="alert"`
/// (`screens-clubs.js:211`).
class ComposeErrorLine extends StatelessWidget {
  /// [text] hata metniyle.
  const ComposeErrorLine(this.text, {super.key});

  /// Hata metni (ARB; çağırandan).
  final String text;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final danger = gu.colors.stateDanger;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: GuSizes.fieldHelpGap,
        children: [
          GuIcon(
            GuIcons.triangleAlert,
            size: GuSizes.fieldHelpIcon,
            color: danger,
          ),
          Expanded(
            child: Text(text, style: gu.text.fieldHelp.copyWith(color: danger)),
          ),
        ],
      ),
    );
  }
}

/// Etiket + anahtar satırı — prototip `row between` (`screens-clubs.js:206`,
/// `:207`, `:213`): solda `bodyM` etiket (altında isteğe bağlı `caption`
/// yardım metni), sağda `GuSwitch`.
class ComposeSwitchRow extends StatelessWidget {
  /// [label] etiketli anahtar satırı.
  const ComposeSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.switchKey,
    this.help,
    this.disabled = false,
    this.onDisabledPressed,
    super.key,
  });

  /// Etiket (anahtarın semantik etiketi de budur).
  final String label;

  /// Etiketin altındaki yardım metni; `null` → yok.
  final String? help;

  /// Anahtar açık mı?
  final bool value;

  /// Anahtar değişti.
  final ValueChanged<bool> onChanged;

  /// Anahtarın aksiyon anahtarı (`GuKey.action('FED-03.pin')`).
  final Key switchKey;

  /// Devre dışı: soluk; dokunuş [onDisabledPressed]'e gider.
  final bool disabled;

  /// Devre dışıyken dokunuldu.
  final VoidCallback? onDisabledPressed;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final help = this.help;
    return Row(
      spacing: GuSpacing.s8,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: gu.text.bodyM),
              if (help != null) Text(help, style: gu.text.caption),
            ],
          ),
        ),
        GuSwitch(
          key: switchKey,
          value: value,
          onChanged: onChanged,
          semanticLabel: label,
          disabled: disabled,
          onDisabledPressed: onDisabledPressed,
        ),
      ],
    );
  }
}

/// Formdaki görsellerin çözücüsü: yeni seçilmiş görsel bellekteki
/// baytlarından çizilir (yüklendikten sonra da), gönderide zaten bulunan
/// görsel [remote] çözücüsüne (Storage) sorulur. Küçük önizlemeler ve
/// önizleme kartı aynı çözücüyü kullanır.
PostImageResolver composeImageResolver(
  List<ComposeImage> images,
  PostImageResolver remote,
) => (model) {
  for (final (index, image) in images.indexed) {
    final picked = image.picked;
    if (picked == null) continue;
    if (image.uploaded == model ||
        ComposeImage.previewPath(index) == model.path) {
      return MemoryImage(picked.bytes);
    }
  }
  return remote(model);
};
