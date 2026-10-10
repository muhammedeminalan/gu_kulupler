import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/utils/gu_tap_target.dart';

/// Tekerlek seçici — prototip `Wheel` (`sheets.js:137–138`), CSS `.wheel`
/// (css:321–322); SHT-29 saat / dakika (CD-25).
///
/// Yükseklik 160, öğe 40 (üstte / altta 1,5 öğe boşluk: seçili öğe ortada),
/// öğeye yapışan kaydırma, üst / alt %30 saydamlaşan maske. Öğe metni
/// Montserrat 600 18 `text.muted`, seçili `text.heading`.
///
/// * Kaydırma ortadaki öğeyi seçer ([onChanged], `round(scrollTop / 40)`
///   sheets.js:137); öğeye dokunma seçer ve yumuşak kaydırır (sheets.js:138).
/// * [values] biçimlenmiş metindir (`pad2`, çağırandan); [value] listede
///   yoksa ilk öğe ortalanır, hiçbiri seçili çizilmez.
/// * Metin ölçeği: öğe yüksekliği ve tekerlek yüksekliği yazı ölçeğiyle
///   çarpılır ([itemExtentOf], [heightOf]; K-08) — SHT-29 seçim bandı aynı
///   değerleri kullanır. Bandı (40 px, üst / alt 1 px `border.default`,
///   sheets.js:140) sheet çizer; iki tekerleği birlikte kaplar.
/// * Semantik: tek ayarlanabilir düğüm — [semanticLabel] + seçili değer,
///   artır / azalt eylemleri (`role="listbox"` + `aria-label`); öğeler ayrı
///   düğüm değildir.
/// * Öğe anahtarı çağırandan ([itemKeyBuilder]:
///   `(i) => GuKey.action('SHT-29.hour.<değer>')`, CD-111).
/// * Sınırlı genişlik ister (`flex:1`; `Row` içinde çağıran `Expanded` ile
///   sarar).
class GuWheelPicker extends StatefulWidget {
  const GuWheelPicker({
    required this.values,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    this.itemKeyBuilder,
    super.key,
  });

  /// Değerler (görünen metin).
  final List<String> values;

  /// Seçili değer.
  final String value;

  /// Seçim değişimi (kaydırma, dokunma, erişilebilirlik eylemi).
  final ValueChanged<String> onChanged;

  /// Erişilebilirlik etiketi (`sht.29.hour` / `sht.29.minute`).
  final String semanticLabel;

  /// Öğe anahtarı üreticisi (`GuKey.action('<ID>.<alan>.<değer>')`).
  final Key Function(int index)? itemKeyBuilder;

  /// Öğe yüksekliği: 40 × etkin yazı ölçeği (css:322).
  static double itemExtentOf(BuildContext context) {
    final gu = context.gu;
    final fontSize = gu.text.wheel.fontSize;
    final factor = fontSize == null
        ? 1.0
        : gu.textScaler.scale(fontSize) / fontSize;
    return GuSizes.wheelItemHeight * factor;
  }

  /// Tekerlek yüksekliği: 160 × etkin yazı ölçeği (css:321; 4 öğe).
  static double heightOf(BuildContext context) =>
      itemExtentOf(context) * (GuSizes.wheelHeight / GuSizes.wheelItemHeight);

  @override
  State<GuWheelPicker> createState() => _GuWheelPickerState();
}

class _GuWheelPickerState extends State<GuWheelPicker> {
  /// `ListWheelScrollView` silindirini düzleştirir: CSS tekerleği düz bir
  /// kaydırma listesidir (perspektif / eğrilik yok).
  static const double _flatDiameterRatio = 100;

  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: _indexOf(widget.value));

  /// Programlı atlama sürerken ortalanan öğe bildirilmez (değişimi zaten
  /// çağıran başlatmıştır).
  bool _jumping = false;

  /// [value]'nun sırası; listede yoksa 0 (sheets.js:137 `i >= 0`).
  int _indexOf(String value) => math.max(0, widget.values.indexOf(value));

  @override
  void didUpdateWidget(GuWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    // Dışarıdan gelen değişim: kullanıcı kaydırmıyorken tekerlek yeni değere
    // atlar, [GuWheelPicker.onChanged] çağrılmaz (kaydırma kaynaklı değişimde
    // konum zaten eşittir).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final index = _indexOf(widget.value);
      if (_controller.position.isScrollingNotifier.value ||
          _controller.selectedItem == index) {
        return;
      }
      _jumpTo(index);
    });
  }

  void _jumpTo(int index) {
    _jumping = true;
    _controller.jumpToItem(index);
    _jumping = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCentered(int index) {
    if (_jumping) return;
    final value = widget.values[index];
    if (value != widget.value) widget.onChanged(value);
  }

  /// Dokunma / erişilebilirlik eylemi: seçer ve öğeyi ortaya kaydırır.
  void _select(int index) {
    widget.onChanged(widget.values[index]);
    // `scrollTo({behavior:'smooth'})` için süre token'ı yok; en yakın:
    // `GuMotion.base` + `easeStandard`.
    final duration = context.gu.duration(GuMotion.base);
    if (duration == Duration.zero) {
      _jumpTo(index);
    } else {
      unawaited(
        _controller.animateToItem(
          index,
          duration: duration,
          curve: GuMotion.easeStandard,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final values = widget.values;
    final extent = GuWheelPicker.itemExtentOf(context);
    final index = _indexOf(widget.value);
    final hasPrevious = index > 0;
    final hasNext = index < values.length - 1;
    final style = gu.text.wheel;
    final selectedStyle = style.copyWith(color: gu.colors.textHeading);
    final opaque = gu.colors.textHeading;
    // ignore-hardcode: eksik token — css:321 mask-image `transparent` ucu
    final clear = opaque.withValues(alpha: 0);

    return Semantics(
      container: true,
      label: widget.semanticLabel,
      value: widget.value,
      increasedValue: hasNext ? values[index + 1] : null,
      decreasedValue: hasPrevious ? values[index - 1] : null,
      onIncrease: hasNext ? () => _select(index + 1) : null,
      onDecrease: hasPrevious ? () => _select(index - 1) : null,
      excludeSemantics: true,
      child: SizedBox(
        height: GuWheelPicker.heightOf(context),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [clear, opaque, opaque, clear],
            stops: const [0, GuSizes.wheelMaskStart, GuSizes.wheelMaskEnd, 1],
          ).createShader(bounds),
          // css:321 `scrollbar-width:none`.
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: extent,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: _flatDiameterRatio,
              onSelectedItemChanged: _handleCentered,
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: values.length,
                builder: (context, itemIndex) => GuTapTarget(
                  key: widget.itemKeyBuilder?.call(itemIndex),
                  onTap: () => _select(itemIndex),
                  excludeFromSemantics: true,
                  // Bitişik satırlar: etkin alan satırın kendisidir
                  // (komşuya taşan dolgu yanlış öğeyi seçtirir).
                  minSize: extent,
                  child: Center(
                    child: Text(
                      values[itemIndex],
                      style: values[itemIndex] == widget.value
                          ? selectedStyle
                          : style,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
