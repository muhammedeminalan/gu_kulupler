import 'dart:math' as math;
import 'dart:ui' show SemanticsValidationResult;

import 'package:flutter/material.dart'
    show
        Colors,
        InputBorder,
        InputDecoration,
        Material,
        MaterialType,
        TextField;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_opacity.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/utils/gu_tap_target.dart';
import 'package:gu_ui/src/widgets/inputs/gu_field.dart';

/// Metin girişi — prototip `Input` (`ui.js:22`), CSS `.field` / `.input`
/// (css:161–172); `ds_inputs.webp` 8 durum.
///
/// * Kutu: min 48, dolgu 0/14, radius `sm`, zemin `bg.surfaceMuted`, 1 px
///   saydam kenarlık (css:163). Odak → kenarlık `brand.primaryText` + zemin
///   `bg.surface` (css:164); hata → kenarlık `state.danger`; [readOnly] /
///   [locked] → zemin saydam + `border.default`; [disabled] → opaklık .6
///   (css:165). Geçiş `GuMotion.fast`. CSS sırası korunur: salt-okunur hatayı
///   ve odağı, hata odak kenarlığını ezer.
/// * [multiline] → dolgu 12/14, üste hizalı, metin alanı en az 88 px
///   (css:169); görünen satır `max(rows, 4)` — `rows` < 4 iken CSS
///   `min-height:88px` yüksekliği zaten 4 satıra tamamlar.
/// * [icon] 20 `text.muted` (css:170); [locked] → sonda kilit 18 (ui.js:30);
///   [trailing] en sonda (şifre göster / gizle ve temizle düğmesi çağırandan:
///   `GuIconButton(size: sm)`, AUT-01 / CLB-02).
/// * [maxLength] + [showCounter]: sayaç uzunluk ≥ `floor(maxLength × 0.8)`
///   olunca etiket satırında görünür, sınır aşılınca `state.danger`
///   (ui.js:23, css:172). Yazma `maxLength + 20`'de durur (ui.js:24).
/// * İmleç rengi temadan (`textSelectionTheme`, CD-121(7)); metin
///   `GuTypography.input`, yer tutucu `text.muted` (css:166–167).
/// * Etkin alan (K-03): kutunun tamamı odağı verir; alanın semantik kutusu
///   `GuTapTarget` ile ≥ 44 pt / 48 dp.
/// * `Semantics`: `textField` + [semanticLabel] (yoksa [label]); hata →
///   `validationResult: invalid` (`aria-invalid`, ui.js:24).
/// * Anahtar çağırandan: `actionKey: GuKey.action('ID.aksiyon')` metin
///   alanına bağlanır (CD-111).
class GuInput extends StatefulWidget {
  const GuInput({
    this.controller,
    this.label,
    this.placeholder,
    this.help,
    this.errorText,
    this.icon,
    this.trailing,
    this.multiline = false,
    this.rows = GuSizes.textareaRows,
    this.maxLength,
    this.showCounter = false,
    this.obscure = false,
    this.locked = false,
    this.readOnly = false,
    this.disabled = false,
    this.autofocus = false,
    this.compact = false,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.semanticLabel,
    this.actionKey,
    super.key,
  }) : assert(!obscure || !multiline, 'Gizli metin çok satırlı olamaz.'),
       assert(rows > 0, 'rows pozitif olmalı.');

  /// Metin denetleyicisi; `null` → widget kendi denetleyicisini kurar.
  final TextEditingController? controller;

  /// Etiket (`.field-label`).
  final String? label;

  /// Yer tutucu.
  final String? placeholder;

  /// Yardım metni (`.field-help`).
  final String? help;

  /// Hata metni; verilirse kenarlık `state.danger`, [help] gizlenir.
  final String? errorText;

  /// Baştaki ikon (`.in-icon`).
  final GuIcons? icon;

  /// Sondaki widget (göz / temizle düğmesi).
  final Widget? trailing;

  /// Çok satırlı (`textarea`).
  final bool multiline;

  /// Çok satırlıda satır sayısı (ui.js:29 `rows || 4`).
  final int rows;

  /// Sayaç sınırı; yazma `maxLength + 20`'de durur.
  final int? maxLength;

  /// %80 eşiğinden sonra sayaç gösterilir (ui.js:23 `counter=true`).
  final bool showCounter;

  /// Gizli metin (şifre).
  final bool obscure;

  /// Kilitli: salt-okunur + kilit ikonu (PRF-02 e-posta).
  final bool locked;

  /// Salt-okunur (`.is-readonly`).
  final bool readOnly;

  /// Devre dışı (`.is-disabled`).
  final bool disabled;

  /// İlk karede odağı alır (`data-autofocus`).
  final bool autofocus;

  /// Kutu min 44 (CLB-02 arama çubuğu, `screens-clubs.js` / `pages-ds.js:34`).
  final bool compact;

  /// Odak düğümü (CD-118: `KeyboardFocusMixin`).
  final FocusNode? focusNode;

  /// Klavye türü; `null` → tek satır `text`, çok satır `multiline`.
  final TextInputType? keyboardType;

  /// Klavye eylem tuşu.
  final TextInputAction? textInputAction;

  /// Metin değişti.
  final ValueChanged<String>? onChanged;

  /// Enter (ui.js:24 `onEnter`); çok satırlıda çağrılmaz.
  final VoidCallback? onSubmitted;

  /// Erişilebilirlik etiketi (`aria-label`); `null` → [label].
  final String? semanticLabel;

  /// Metin alanının anahtarı.
  final Key? actionKey;

  // ignore-hardcode: eksik token — ui.js:24 `maxLength + 20`
  static const int _maxLengthSlack = 20;

  // ignore-hardcode: eksik token — pages-ds.js:34 `.input` `min-height:44px`
  static const double _compactHeight = 44;

  @override
  State<GuInput> createState() => _GuInputState();
}

class _GuInputState extends State<GuInput> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void dispose() {
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_controller, _focusNode]),
    builder: _buildField,
  );

  Widget _buildField(BuildContext context, Widget? _) {
    final w = widget;
    final gu = context.gu;
    final colors = gu.colors;
    final style = gu.text.input;
    final isReadOnly = w.readOnly || w.locked;
    final hasError = w.errorText != null;
    final focused = _focusNode.hasFocus;

    // ui.js:23: sayaç eşiği ve sınır aşımı (JS `length` = UTF-16 birimi).
    final length = _controller.text.length;
    final maxLength = w.maxLength;
    final counterVisible =
        w.showCounter &&
        maxLength != null &&
        length >= (maxLength * GuSizes.counterThresholdRatio).floor();
    final counterOver = maxLength != null && length > maxLength;

    // css:164–165 kural sırası: readonly > error > focus.
    final Color? background;
    final Color borderColor;
    if (isReadOnly) {
      background = null;
      borderColor = colors.borderDefault;
    } else {
      background = focused ? colors.bgSurface : colors.bgSurfaceMuted;
      borderColor = hasError
          ? colors.stateDanger
          : focused
          ? colors.brandPrimaryText
          : Colors.transparent;
    }

    // css:163 `min-height:48px;align-items:center` (border-box): tek satırda
    // metin alanı iç kutunun tamamını kaplar, böylece dokunuş doğal konuma
    // düşer; metin ölçeği büyüdükçe dolgu sıfıra iner.
    final minHeight = w.compact ? GuInput._compactHeight : GuSizes.inputHeight;
    final lineHeight = gu.textScaler.scale(style.fontSize!) * style.height!;
    final fieldPaddingY = w.multiline
        ? 0.0
        : math.max<double>(
            0,
            (minHeight - GuSizes.inputBorder * 2 - lineHeight) / 2,
          );
    final lines = math.max(w.rows, GuSizes.textareaRows);
    final onSubmitted = w.onSubmitted;

    Widget field = Material(
      type: MaterialType.transparency,
      child: TextField(
        key: w.actionKey,
        controller: _controller,
        focusNode: _focusNode,
        style: style,
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          contentPadding: GuInsets.sym(v: fieldPaddingY),
          hintText: w.placeholder,
          hintStyle: style.copyWith(color: colors.textMuted),
          hintMaxLines: w.multiline ? lines : 1,
        ),
        obscureText: w.obscure,
        readOnly: isReadOnly,
        enabled: !w.disabled,
        autofocus: w.autofocus,
        keyboardType: w.keyboardType,
        textInputAction: w.textInputAction,
        minLines: w.multiline ? lines : null,
        maxLines: w.multiline ? lines : 1,
        textAlignVertical: TextAlignVertical.top,
        inputFormatters: maxLength == null
            ? null
            : [
                LengthLimitingTextInputFormatter(
                  maxLength + GuInput._maxLengthSlack,
                ),
              ],
        onChanged: w.onChanged,
        onSubmitted: onSubmitted == null || w.multiline
            ? null
            : (_) => onSubmitted(),
      ),
    );
    if (w.multiline) {
      field = ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: GuSizes.textareaMinHeight,
        ),
        child: field,
      );
    }

    final icon = w.icon;
    final trailing = w.trailing;
    Widget box = AnimatedContainer(
      duration: gu.duration(GuMotion.fast),
      curve: GuMotion.easeCss,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: GuInsets.sym(
        h: GuSizes.inputPaddingX,
        v: w.multiline ? GuSizes.inputMultilinePaddingY : 0,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: GuRadius.borderSm,
        border: Border.all(
          color: borderColor,
          // Token değeri varsayılanla (1) aynı; kaynak token kalır.
          // ignore: avoid_redundant_argument_values
          width: GuSizes.inputBorder,
        ),
      ),
      child: Row(
        crossAxisAlignment: w.multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        spacing: GuSizes.inputGap,
        children: [
          if (icon != null)
            GuIcon(icon, size: GuSizes.inputIcon, color: colors.textMuted),
          Expanded(
            child: GuTapTarget(
              child: Semantics(
                label: w.semanticLabel ?? w.label,
                validationResult: hasError
                    ? SemanticsValidationResult.invalid
                    : SemanticsValidationResult.none,
                child: field,
              ),
            ),
          ),
          if (w.locked)
            GuIcon(
              GuIcons.lock,
              size: GuSizes.inputLockIcon,
              color: colors.textMuted,
            ),
          ?trailing,
        ],
      ),
    );
    if (w.disabled) {
      box = Opacity(opacity: GuOpacity.inputDisabled, child: box);
    } else if (!isReadOnly) {
      // K-03: ikon, dolgu ve kenarlık bandı da odağı verir.
      box = GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: _focusNode.requestFocus,
        child: box,
      );
    }

    return GuField(
      label: w.label,
      counter: counterVisible ? '$length/$maxLength' : null,
      counterOver: counterOver,
      help: w.help,
      errorText: w.errorText,
      excludeLabelSemantics: true,
      child: box,
    );
  }
}
