import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:gu_ui/src/extensions/build_context_x.dart';
import 'package:gu_ui/src/icons/gu_icon.dart';
import 'package:gu_ui/src/icons/gu_icons.dart';
import 'package:gu_ui/src/tokens/gu_colors.dart';
import 'package:gu_ui/src/tokens/gu_motion.dart';
import 'package:gu_ui/src/tokens/gu_radius.dart';
import 'package:gu_ui/src/tokens/gu_sizes.dart';
import 'package:gu_ui/src/tokens/gu_spacing.dart';
import 'package:gu_ui/src/widgets/layout/gu_content_column.dart';
import 'package:gu_ui/src/widgets/primitives/gu_action_surface.dart';
import 'package:gu_ui/src/widgets/primitives/gu_icon_button.dart';

/// Toast türü — prototip `Toast` (`shell.js:20`): ikon + sol şerit rengi.
enum GuToastKind {
  /// `circle-check`, `state.success`.
  success(GuIcons.circleCheck),

  /// `triangle-alert`, `state.danger` (`role="alert"`).
  error(GuIcons.triangleAlert),

  /// `info`, `state.info`.
  info(GuIcons.info);

  const GuToastKind(this.icon);

  /// Tür ikonu (18 px).
  final GuIcons icon;

  /// İkon ve 4 px şerit rengi (`--toast-color`, `shell.js:20`).
  Color colorOf(GuColors c) => switch (this) {
    GuToastKind.success => c.stateSuccess,
    GuToastKind.error => c.stateDanger,
    GuToastKind.info => c.stateInfo,
  };
}

/// Toast kutusu — prototip `Toast` (`shell.js:20–21`), CSS `.toast`
/// `.toast-icon` `.toast-text` `.toast-action` (css:290–294).
///
/// Satır: sol 4 px tür şeridi · tür ikonu 18 · [text] (500 13 / 1.4, sarar)
/// · isteğe bağlı eylem (36 yükseklik, dolgu 10, radius 8,
/// `toastActionBackground` / `toastActionForeground` — CD-98, K-41) · kapat
/// (`x` 16, 32 px). Zemin `text.heading`, metin `bg.surface`, radius `sm`,
/// gölge `e2`; dolgu 12 / 8 / 12 / 14, aralık 10.
///
/// * Canlı bölge: `role="alert"` / `status` + `aria-live` (shell.js:21).
/// * Saf görünüm: konum, süre ve kuyruk [GuToastHost]'tadır; metinler ve
///   anahtarlar çağırandan (ARB, `GuKey.action` — CD-111).
/// * Eylem etiketi satırın en çok yarısını kaplar (dar ekran + büyük yazı).
class GuToast extends StatelessWidget {
  const GuToast({
    required this.kind,
    required this.text,
    required this.onClose,
    required this.closeSemanticLabel,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.closeKey,
    super.key,
  }) : assert(
         actionLabel == null || onAction != null,
         'actionLabel verildiyse onAction da verilmeli.',
       );

  /// Tür (ikon + şerit rengi).
  final GuToastKind kind;

  /// Toast metni (çağırandan; ARB).
  final String text;

  /// Kapat düğmesi dokunması.
  final VoidCallback onClose;

  /// Kapat düğmesi erişilebilirlik etiketi (ARB `a11yClose`).
  final String closeSemanticLabel;

  /// Eylem düğmesi metni ("Geri al", "Görüntüle" …); `null` → düğme yok.
  final String? actionLabel;

  /// Eylem dokunması.
  final VoidCallback? onAction;

  /// Eylem düğmesi anahtarı (`<id>.undo` / `<id>.action`).
  final Key? actionKey;

  /// Kapat düğmesi anahtarı (`<id>.close`).
  final Key? closeKey;

  @override
  Widget build(BuildContext context) {
    final gu = context.gu;
    final accent = kind.colorOf(gu.colors);
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;

    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: gu.colors.textHeading,
          borderRadius: GuRadius.borderSm,
          boxShadow: gu.shadows.e2,
        ),
        child: CustomPaint(
          painter: _ToastAccentPainter(color: accent),
          child: Padding(
            padding: GuInsets.only(
              left: GuSizes.toastAccent + GuSizes.toastPaddingLeft,
              top: GuSizes.toastPaddingTop,
              right: GuSizes.toastPaddingRight,
              bottom: GuSizes.toastPaddingBottom,
            ),
            child: DefaultTextStyle(
              style: gu.text.toast,
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  spacing: GuSizes.toastGap,
                  children: [
                    GuIcon(kind.icon, size: GuSizes.toastIcon, color: accent),
                    Expanded(child: Text(text)),
                    if (actionLabel != null && onAction != null)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth / 2,
                        ),
                        child: _ToastAction(
                          key: actionKey,
                          label: actionLabel,
                          onTap: onAction,
                        ),
                      ),
                    GuIconButton(
                      key: closeKey,
                      icon: GuIcons.x,
                      semanticLabel: closeSemanticLabel,
                      onPressed: onClose,
                      size: GuIconButtonSize.xs,
                      iconSize: GuSizes.toastCloseIcon,
                      foregroundInherit: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.toast .toast-action` (css:293–294): en az 36 yükseklik, yatay dolgu 10,
/// radius 8, 700 ağırlık; CSS'te `:hover` / `:active` kuralı yok → basılı
/// görünümü yok.
class _ToastAction extends StatelessWidget {
  const _ToastAction({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GuActionSurface(
    onTap: onTap,
    semanticLabel: label,
    borderRadius: GuRadius.borderSkeleton,
    builder: (context, _) {
      final gu = context.gu;
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: GuSizes.toastActionHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: gu.component.toastActionBackground,
            borderRadius: GuRadius.borderSkeleton,
          ),
          child: Padding(
            padding: GuInsets.sym(h: GuSizes.toastActionPaddingX),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: gu.text.toastAction.copyWith(
                  color: gu.component.toastActionForeground,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// `.toast{border-left:4px solid var(--toast-color)}` + `border-radius:12px`
/// (css:290): CSS kenarlığı köşeyi izler, iç kenar yarıçapı yatayda
/// `12 − 4`, dikeyde 12 olur → şerit, dış yuvarlak dikdörtgen ile sola 4 px
/// kaydırılmış iç yuvarlak dikdörtgenin farkıdır.
class _ToastAccentPainter extends CustomPainter {
  const _ToastAccentPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const outerRadius = Radius.circular(GuRadius.sm);
    const innerRadius = Radius.elliptical(
      GuRadius.sm - GuSizes.toastAccent,
      GuRadius.sm,
    );
    final outer = RRect.fromRectAndRadius(Offset.zero & size, outerRadius);
    final inner = RRect.fromLTRBAndCorners(
      GuSizes.toastAccent,
      0,
      size.width,
      size.height,
      topLeft: innerRadius,
      bottomLeft: innerRadius,
      topRight: outerRadius,
      bottomRight: outerRadius,
    );
    canvas.drawDRRect(outer, inner, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ToastAccentPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Gösterilecek tek toastın verisi ([GuToastController.show]).
///
/// Süre: [duration] verilmezse eylem varsa `GuMotion.toastUndo` (6 sn),
/// yoksa `GuMotion.toastDefault` (4 sn) — `core.js:567`, CD-24.
/// [persistent] → süreyle kapanmaz (kapat / eylem / yeni toast kapatır).
@immutable
class GuToastEntry {
  const GuToastEntry({
    required this.kind,
    required this.text,
    required this.closeSemanticLabel,
    this.actionLabel,
    this.onAction,
    this.duration,
    this.persistent = false,
    this.toastKey,
    this.actionKey,
    this.closeKey,
  });

  /// Tür.
  final GuToastKind kind;

  /// Toast metni.
  final String text;

  /// Kapat düğmesi erişilebilirlik etiketi.
  final String closeSemanticLabel;

  /// Eylem düğmesi metni; `null` → düğme yok.
  final String? actionLabel;

  /// Eylem dokunması; toast önce kapanır, sonra çağrılır (`shell.js:21`).
  final VoidCallback? onAction;

  /// Görünme süresi; `null` → [effectiveDuration] varsayılanı.
  final Duration? duration;

  /// Süre dolunca kapanmaz.
  final bool persistent;

  /// Toast kutusunun anahtarı (test / `data-toast`).
  final Key? toastKey;

  /// Eylem düğmesi anahtarı.
  final Key? actionKey;

  /// Kapat düğmesi anahtarı.
  final Key? closeKey;

  /// [duration] ya da eylemli 6 sn / eylemsiz 4 sn.
  Duration get effectiveDuration =>
      duration ??
      (actionLabel != null ? GuMotion.toastUndo : GuMotion.toastDefault);
}

/// Toast kuyruğu — aynı anda en çok 1 (`core.js:565–570`): [show] öncekini
/// hemen kapatır, [hide] geçerli toastı kaldırır. Görünüm ve süre sayacı
/// [GuToastHost]'tadır.
class GuToastController extends ChangeNotifier {
  GuToastEntry? _current;
  int _serial = 0;

  /// Gösterilen toast; yoksa `null`.
  GuToastEntry? get current => _current;

  /// Her [show] çağrısında artan sıra numarası (aynı girdi yeniden
  /// gösterildiğinde de yeni toast sayılır).
  int get serial => _serial;

  /// Toast görünür mü.
  bool get isVisible => _current != null;

  /// [entry]'yi gösterir; varsa önceki toast hemen kapanır.
  void show(GuToastEntry entry) {
    _current = entry;
    _serial++;
    notifyListeners();
  }

  /// Geçerli toastı kapatır (yoksa etkisiz).
  void hide() {
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }
}

/// Toast katmanı — prototip `Overlays` (`shell.js:17–19`), CSS `.toast-wrap`
/// / `.above-nav` (css:288–289).
///
/// [child]'ın üstünde, altta tek toast çizer: yatay boşluk 12, alt boşluk
/// `güvenli alan + bottomInset + 12`; klavye açıksa klavyenin 12 üstü. Geniş
/// ekranda 480 sütununa ortalanır (CD-29).
///
/// * [bottomInset]: alt sekme çubuğu görünürken `GuSizes.bottomNavHeight`
///   (`.above-nav`), değilse 0.
/// * Giriş `toastIn` (css:416): 24 px yukarı + solma, `GuMotion.slow` /
///   `easeEmphasized`; çıkış aynı hareketin tersi, `GuMotion.base`.
///   Azaltılmış harekette ikisi de anında.
/// * Süre `GuToastEntry.effectiveDuration`; dolunca `controller.hide()`.
///   Yeni toast sayacı sıfırlar; `persistent` sayaç kurmaz.
/// * Eylem dokunuşu: önce gizle, sonra `onAction` (`shell.js:21`).
class GuToastHost extends StatefulWidget {
  const GuToastHost({
    required this.controller,
    required this.child,
    this.bottomInset = 0,
    super.key,
  });

  /// Toast kuyruğu.
  final GuToastController controller;

  /// Üstüne toast çizilen içerik (uygulama gövdesi).
  final Widget child;

  /// Güvenli alanın üstüne eklenen alt boşluk (alt sekme çubuğu yüksekliği).
  final double bottomInset;

  @override
  State<GuToastHost> createState() => _GuToastHostState();
}

class _GuToastHostState extends State<GuToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(vsync: this)
    ..addStatusListener(_onStatus);
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _animation,
    curve: GuMotion.easeEmphasized,
  );

  /// Çizilen toast (çıkış animasyonu boyunca da tutulur).
  GuToastEntry? _entry;

  /// [_entry]'nin `GuToastController.serial` değeri.
  int _serial = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    // Host, `show`'dan sonra kurulduysa bekleyen toast ilk karede çizilir.
    _adopt();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final gu = context.gu;
    _animation
      ..duration = gu.duration(GuMotion.slow)
      ..reverseDuration = gu.duration(GuMotion.base);
    if (_entry != null && _animation.isDismissed) {
      unawaited(_animation.forward());
    }
  }

  @override
  void didUpdateWidget(GuToastHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_sync);
    widget.controller.addListener(_sync);
    _timer?.cancel();
    _timer = null;
    _entry = null;
    _serial = 0;
    _animation.value = 0;
    if (_adopt()) unawaited(_animation.forward());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _timer?.cancel();
    _curve.dispose();
    _animation.dispose();
    super.dispose();
  }

  /// Denetleyicideki yeni toastı devralır ve süre sayacını kurar; yeni
  /// toast yoksa `false`.
  bool _adopt() {
    final controller = widget.controller;
    final current = controller.current;
    if (current == null || controller.serial == _serial) return false;
    _timer?.cancel();
    _timer = current.persistent
        ? null
        : Timer(current.effectiveDuration, controller.hide);
    _entry = current;
    _serial = controller.serial;
    return true;
  }

  void _sync() {
    if (widget.controller.current == null) {
      _timer?.cancel();
      _timer = null;
      if (_entry != null) unawaited(_animation.reverse());
      return;
    }
    if (!_adopt()) return;
    setState(() {});
    unawaited(_animation.forward(from: 0));
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed &&
        widget.controller.current == null &&
        _entry != null) {
      setState(() => _entry = null);
    }
  }

  void _onAction(GuToastEntry entry) {
    widget.controller.hide();
    entry.onAction?.call();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    final media = MediaQuery.of(context);
    final bottom =
        math.max(
          media.viewInsets.bottom,
          media.viewPadding.bottom + widget.bottomInset,
        ) +
        GuSizes.toastBottomExtra;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (entry != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom,
            child: GuContentColumn(
              child: Padding(
                padding: GuInsets.sym(h: GuSizes.toastMarginX),
                child: AnimatedBuilder(
                  animation: _curve,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(
                      0,
                      (1 - _curve.value) * GuMotion.toastEnterOffsetY,
                    ),
                    child: child,
                  ),
                  child: FadeTransition(
                    opacity: _curve,
                    child: KeyedSubtree(
                      key: ValueKey<int>(_serial),
                      child: GuToast(
                        key: entry.toastKey,
                        kind: entry.kind,
                        text: entry.text,
                        closeSemanticLabel: entry.closeSemanticLabel,
                        onClose: widget.controller.hide,
                        actionLabel: entry.actionLabel,
                        onAction: entry.actionLabel == null
                            ? null
                            : () => _onAction(entry),
                        actionKey: entry.actionKey,
                        closeKey: entry.closeKey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
