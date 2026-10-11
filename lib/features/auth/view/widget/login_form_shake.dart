import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_ui/gu_ui.dart';

/// Hatalı girişte formu yatayda sallar — prototip `form.shake`
/// (`screens-auth.js:69`), CSS `.shake` (css:334; `@keyframes shake` css:421:
/// 0 / −8 / 8 / −5 / 5 / 0, 400 ms).
///
/// [trigger] her **arttığında** bir kez oynar (`LoginState.failedAttempts`);
/// azalması ya da aynı kalması etkisizdir. Azaltılmış hareket ayarında
/// oynamaz. Yerleşimi değiştirmez (yalnızca boyama kayar).
class LoginFormShake extends ConsumerStatefulWidget {
  /// [trigger] arttıkça [child] sallanır.
  const LoginFormShake({required this.trigger, required this.child, super.key});

  /// Sallanmayı tetikleyen sayaç.
  final int trigger;

  /// Sallanan içerik.
  final Widget child;

  @override
  ConsumerState<LoginFormShake> createState() => _LoginFormShakeState();
}

class _LoginFormShakeState extends ConsumerState<LoginFormShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: GuMotion.shake,
  );

  /// `@keyframes shake`: eşit aralıklı kareler, her aralık `easeStandard` ile.
  late final Animation<double> _offsetX = _controller.drive(
    TweenSequence<double>([
      for (var i = 0; i < GuMotion.shakeOffsets.length - 1; i++)
        TweenSequenceItem(
          tween: Tween<double>(
            begin: GuMotion.shakeOffsets[i],
            end: GuMotion.shakeOffsets[i + 1],
          ).chain(CurveTween(curve: GuMotion.easeStandard)),
          weight: 1,
        ),
    ]),
  );

  @override
  void didUpdateWidget(LoginFormShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger > oldWidget.trigger && !context.gu.reduceMotion) {
      unawaited(_controller.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _offsetX,
    builder: (context, child) =>
        Transform.translate(offset: Offset(_offsetX.value, 0), child: child),
    child: widget.child,
  );
}
