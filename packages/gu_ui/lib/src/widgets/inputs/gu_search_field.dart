import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/widgets/inputs/gu_input.dart';
import 'package:gu_ui/src/widgets/primitives/gu_icon_button.dart';

/// Arama alanı — prototip `Input icon="search"` (11 ekran / sheet) ve CLB-02
/// arama çubuğu (`screens-clubs.js`, `ds_nav.webp`: `.input` `min-height:44px`
/// + `IconButton small x`); ayrı CSS yok, `GuInput` üstüne ince sarmalayıcı
/// (G13).
///
/// * İkon `search`, klavye eylemi `TextInputAction.search`.
/// * [value] denetimlidir: dışarıdan değişirse alan eşitlenir (imleç sona).
/// * Temizle düğmesi (`x`, `GuIconButton(size: sm)`) yalnızca [onClear]
///   verilmiş ve alan doluyken görünür; dokunma alanı boşaltır,
///   `onChanged('')` ve [onClear] çağrılır. Etiketi [clearSemanticLabel]
///   (`common.clear`) çağırandan.
/// * [compact] → kutu min 44 (CLB-02).
/// * Anahtarlar çağırandan: [actionKey] metin alanına, [clearKey] temizle
///   düğmesine (`ID.search`, `ID.clear`; CD-111).
class GuSearchField extends StatefulWidget {
  const GuSearchField({
    required this.value,
    this.onChanged,
    this.onClear,
    this.onSubmitted,
    this.placeholder,
    this.semanticLabel,
    this.clearSemanticLabel,
    this.compact = false,
    this.autofocus = false,
    this.focusNode,
    this.actionKey,
    this.clearKey,
    super.key,
  }) : assert(
         onClear == null || clearSemanticLabel != null,
         'Temizle düğmesi için clearSemanticLabel gerekir.',
       );

  /// Arama metni.
  final String value;

  /// Metin değişti (debounce çağırandan).
  final ValueChanged<String>? onChanged;

  /// Temizle düğmesine dokunuldu; `null` → düğme yok.
  final VoidCallback? onClear;

  /// Klavyede "Ara" / Enter (CLB-02 `commit`).
  final VoidCallback? onSubmitted;

  /// Yer tutucu.
  final String? placeholder;

  /// Erişilebilirlik etiketi (`aria-label`).
  final String? semanticLabel;

  /// Temizle düğmesinin etiketi.
  final String? clearSemanticLabel;

  /// Kutu min 44.
  final bool compact;

  /// İlk karede odağı alır.
  final bool autofocus;

  /// Odak düğümü.
  final FocusNode? focusNode;

  /// Metin alanının anahtarı.
  final Key? actionKey;

  /// Temizle düğmesinin anahtarı.
  final Key? clearKey;

  @override
  State<GuSearchField> createState() => _GuSearchFieldState();
}

class _GuSearchFieldState extends State<GuSearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(GuSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value;
    if (value != oldWidget.value && value != _controller.text) {
      _controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final clearLabel = widget.clearSemanticLabel;
      final showClear =
          widget.onClear != null &&
          clearLabel != null &&
          _controller.text.isNotEmpty;
      return GuInput(
        controller: _controller,
        placeholder: widget.placeholder,
        icon: GuIcons.search,
        compact: widget.compact,
        autofocus: widget.autofocus,
        focusNode: widget.focusNode,
        textInputAction: TextInputAction.search,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        semanticLabel: widget.semanticLabel,
        actionKey: widget.actionKey,
        trailing: showClear
            ? GuIconButton(
                key: widget.clearKey,
                icon: GuIcons.x,
                size: GuIconButtonSize.sm,
                semanticLabel: clearLabel,
                onPressed: _clear,
              )
            : null,
      );
    },
  );
}
