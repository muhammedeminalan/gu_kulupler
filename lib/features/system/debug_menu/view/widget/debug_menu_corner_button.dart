import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// DebugMenu'nun giriş noktası (CD-69): `GuApp.builder` zincirinin en içinde,
/// [child]'ın (gezgin) sağ üst köşesinde 32 dp'lik yarı saydam düğme.
///
/// Yalnızca `AppEnvironment.debugMenuEnabled` iken ağaca girer (çağıran
/// derleme sabitiyle koşullar; release'te ağaçtan düşer). Anahtarı
/// [openKey]'dir — `GuKey.action` **değildir**: tasarım aksiyon envanterine
/// girmez.
class DebugMenuCornerButton extends StatelessWidget {
  /// [onPressed] DebugMenu rotasını açar (düğme gezginin üstünde durduğundan
  /// gezinmeyi çağıran yapar).
  const DebugMenuCornerButton({
    required this.onPressed,
    required this.child,
    super.key,
  });

  /// Düğmenin anahtarı.
  static const Key openKey = ValueKey<String>('debug.open');

  /// Düğmeye dokunma.
  final VoidCallback onPressed;

  /// Düğmenin üstüne bindiği içerik.
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      Positioned(
        top: MediaQuery.viewPaddingOf(context).top + GuSpacing.s4,
        right: GuSpacing.s4,
        child: Opacity(
          opacity: GuOpacity.disabled,
          child: GuIconButton(
            key: openKey,
            icon: GuIcons.slidersHorizontal,
            size: GuIconButtonSize.xs,
            semanticLabel: context.l10n.settingsGroupAppearance,
            onPressed: onPressed,
          ),
        ),
      ),
    ],
  );
}
