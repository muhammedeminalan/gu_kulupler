import 'package:flutter/widgets.dart';
import 'package:gu_kulupler/core/l10n/build_context_l10n_x.dart';
import 'package:gu_ui/gu_ui.dart';

/// DebugMenu'nun giriş noktası (CD-69): `GuApp.builder` zincirinin en içinde,
/// [child]'ın (gezgin) **sağ kenarına yapışık**, dikeyde ekranın yaklaşık
/// %45'inde duran yarı saydam küçük tutamaç.
///
/// * Konum: üst çubuk eylemlerinin (ONB-01 "Atla", AUT-01 dil menüsü,
///   uygulama çubuğu düğmeleri) ve alt sekme çubuğunun dışında kalır.
/// * Ölçü: genişlik sayfa kenar boşluğu kadardır (16 dp) — standart 16 dp
///   yatay dolguyla yerleşen içeriğin üstüne binmez; yükseklik 48 dp. Etkin
///   dokunma alanı görselin kendisidir (genişletilmez).
/// * Yalnızca `AppEnvironment.debugMenuEnabled` iken ağaca girer (çağıran
///   derleme sabitiyle koşullar; release'te ağaçtan düşer). Anahtarı
///   [openKey]'dir — `GuKey.action` **değildir**: tasarım aksiyon envanterine
///   girmez.
class DebugMenuCornerButton extends StatelessWidget {
  /// [onPressed] DebugMenu rotasını açar (tutamaç gezginin üstünde durduğundan
  /// gezinmeyi çağıran yapar).
  const DebugMenuCornerButton({
    required this.onPressed,
    required this.child,
    super.key,
  });

  /// Tutamacın anahtarı.
  static const Key openKey = ValueKey<String>('debug.open');

  /// Tutamacın genişliği: sayfa kenar boşluğu.
  static const double handleWidth = GuSpacing.s16;

  /// Tutamacın yüksekliği.
  static const double handleHeight = GuSpacing.s48;

  /// Dikey konum: tutamacın üstü, boş yüksekliğin bu oranındadır.
  static const double verticalFraction = 0.45;

  /// Tutamaca dokunma.
  final VoidCallback onPressed;

  /// Tutamacın üstüne bindiği içerik.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.gu.colors;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned.fill(
          right: MediaQuery.viewPaddingOf(context).right,
          child: Align(
            alignment: const Alignment(1, verticalFraction * 2 - 1),
            child: Opacity(
              opacity: GuOpacity.disabled,
              child: GuTapTarget(
                key: openKey,
                minSize: 0,
                semanticLabel: context.l10n.settingsGroupAppearance,
                onTap: onPressed,
                child: SizedBox(
                  width: handleWidth,
                  height: handleHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.textHeading,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(GuRadius.sm),
                      ),
                    ),
                    child: Center(
                      child: GuIcon(
                        GuIcons.slidersHorizontal,
                        size: GuSizes.icon12,
                        color: colors.bgSurface,
                      ),
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
