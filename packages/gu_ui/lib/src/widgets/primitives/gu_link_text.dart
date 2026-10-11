import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/utils/gu_tap_target.dart';

/// [GuLinkText] cümlesinin bir parçası: düz metin ya da bağlantı.
@immutable
final class GuLinkSpan {
  /// Düz metin parçası (boşlukları çağıran yazar).
  const GuLinkSpan.text(this.text) : onTap = null, actionKey = null;

  /// Bağlantı parçası; [actionKey] bağlantının aksiyon anahtarıdır.
  const GuLinkSpan.link(
    this.text, {
    required VoidCallback this.onTap,
    required Key this.actionKey,
  });

  /// Parçanın metni (çağırandan; ARB).
  final String text;

  /// Bağlantıya dokunma; düz metinde `null`.
  final VoidCallback? onTap;

  /// Bağlantının aksiyon anahtarı; düz metinde `null`.
  final Key? actionKey;

  /// Parça bağlantı mı?
  bool get isLink => onTap != null;
}

/// Cümle içi bağlantılı metin — prototip `<p>… <button class="c-brand">…
/// </button> …</p>` (`screens-auth.js:78`, `:101`; `sheets.js:32`).
///
/// Bağlantılar cümlenin içinde akar ve satır sonunda cümleyle birlikte kırılır;
/// görsel ölçüleri metin kadardır, renkleri `brand.primaryText`. Dokunma alanı
/// **blok düzeyinde** genişler (K-03): bloğa (cümle + [padding]) gelen dokunuş,
/// en küçük dokunma hedefine büyütülmüş kutusu noktayı içeren **en yakın**
/// bağlantıya gider. Böylece alt alta düşen bağlantılar birbirinin dokunuşunu
/// çalmaz; hiçbir bağlantıya yakın olmayan dokunuş etkisizdir.
///
/// Semantikte her bağlantı `link`'tir (metin içi bağlantı, görsel kutusuyla
/// okunur). Metin ölçeğini çevreleyen paragraf uygular; bağlantı kendi
/// metnini ayrıca ölçeklemez.
///
/// ```dart
/// GuLinkText(
///   style: context.gu.text.caption,
///   textAlign: TextAlign.center,
///   spans: [
///     GuLinkSpan.text('${l10n.authLegalPrefix} '),
///     GuLinkSpan.link(
///       l10n.legalKosullarTitle,
///       actionKey: GuKey.action('AUT-01.terms'),
///       onTap: openTerms,
///     ),
///     GuLinkSpan.text(l10n.authLegalSuffix),
///   ],
/// )
/// ```
class GuLinkText extends StatefulWidget {
  /// Cümle içi bağlantılı metin.
  const GuLinkText({
    required this.spans,
    required this.style,
    this.textAlign = TextAlign.start,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  /// Cümlenin parçaları, sırayla.
  final List<GuLinkSpan> spans;

  /// Cümlenin metin stili; bağlantılar aynı stilin `brand.primaryText` renkli
  /// hâlidir.
  final TextStyle style;

  /// Yatay hizalama.
  final TextAlign textAlign;

  /// Cümlenin çevresindeki boşluk; dokunma alanına dahildir.
  final EdgeInsetsGeometry padding;

  @override
  State<GuLinkText> createState() => _GuLinkTextState();
}

class _GuLinkTextState extends State<GuLinkText> {
  /// Bağlantıların görsel kutuları (parça sırasıyla; düz metinde yoktur).
  final Map<int, GlobalKey> _boxes = {};

  GlobalKey _boxOf(int index) =>
      _boxes[index] ??= GlobalKey(debugLabel: 'GuLinkText.link.$index');

  /// [position] (küresel) noktasına en yakın, büyütülmüş kutusu noktayı içeren
  /// bağlantının eylemi; yoksa `null`.
  VoidCallback? _linkAt(Offset position) {
    final minSize = GuTapTarget.minSizeFor(defaultTargetPlatform);
    VoidCallback? nearest;
    var nearestDistance = double.infinity;
    for (final (index, span) in widget.spans.indexed) {
      final onTap = span.onTap;
      if (onTap == null) continue;
      final box = _boxes[index]?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      // Paragraf, bağlantıyı metin ölçeğiyle büyüterek çizer: ekrandaki kutu
      // dönüşümle birlikte okunur.
      final rect = MatrixUtils.transformRect(
        box.getTransformTo(null),
        Offset.zero & box.size,
      );
      final target = Rect.fromCenter(
        center: rect.center,
        width: math.max(rect.width, minSize),
        height: math.max(rect.height, minSize),
      );
      if (!target.contains(position)) continue;
      // Noktanın bağlantının görsel kutusuna uzaklığı (içindeyse 0).
      final dx = math.max<double>(
        0,
        math.max(rect.left - position.dx, position.dx - rect.right),
      );
      final dy = math.max<double>(
        0,
        math.max(rect.top - position.dy, position.dy - rect.bottom),
      );
      final distance = dx * dx + dy * dy;
      if (distance < nearestDistance) {
        nearest = onTap;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  InlineSpan _spanOf(int index, GuLinkSpan span, TextStyle linkStyle) {
    final onTap = span.onTap;
    if (onTap == null) return TextSpan(text: span.text);
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Semantics(
        key: span.actionKey,
        link: true,
        onTap: onTap,
        child: Text(
          span.text,
          key: _boxOf(index),
          style: linkStyle,
          // `WidgetSpan` çocuğunu çevreleyen paragraf metin ölçeğiyle zaten
          // büyütür; burada yeniden ölçeklenirse yazı iki kez büyür.
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final linkStyle = widget.style.copyWith(
      color: context.gu.colors.brandPrimaryText,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapUp: (details) => _linkAt(details.globalPosition)?.call(),
      child: Padding(
        padding: widget.padding,
        child: Text.rich(
          TextSpan(
            children: [
              for (final (index, span) in widget.spans.indexed)
                _spanOf(index, span, linkStyle),
            ],
          ),
          style: widget.style,
          textAlign: widget.textAlign,
        ),
      ),
    );
  }
}
