import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:gu_kulupler/product/navigation/shell/app_sidebar.dart';
import 'package:gu_kulupler/product/navigation/shell/shell_tab_selector.dart';
import 'package:gu_kulupler/product/navigation/shell/web_layout_scope.dart';
import 'package:gu_ui/gu_ui.dart';

/// Web düzeni (H-23; referans projedeki telefon kartı + yan menü) —
/// `GuApp.builder` uygulamanın tamamını sarar.
///
/// * **Mobil (iOS / Android) hiç değişmez:** [isWeb] `false` → [child]
///   olduğu gibi döner.
/// * Web, pencere ≤ `GuBreakpoints.webFrame` (768): çerçeve yok (bugünkü
///   görünüm; telefon tarayıcısı).
/// * Web, > 768: uygulama desenli zeminde ortalanmış telefon kartında
///   (`GuWebFrame`); alt çubuk kartın içinde kalır.
/// * Web, ≥ `GuBreakpoints.webSidebar` (1024) ve kabuk sayfasında (sekme
///   yolu, etkin oturum): kartın solunda yan menü ([AppSidebar]); alt çubuk
///   gizlenir ([WebLayoutScope]).
class WebShell extends ConsumerWidget {
  const WebShell({
    required this.location,
    required this.child,
    this.isWeb = kIsWeb,
    super.key,
  });

  /// Yönlendiricinin geçerli konumu.
  final Uri location;

  /// Uygulama (yönlendirici ve üstündeki katmanlar).
  final Widget child;

  /// Web'de mi? (Testte verilir; varsayılan `kIsWeb`.)
  final bool isWeb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isWeb) return child;
    final width = MediaQuery.sizeOf(context).width;
    final framed = width > GuBreakpoints.webFrame;
    final selector = ref.watch(shellTabSelectorProvider);
    final hasSidebar =
        framed &&
        width >= GuBreakpoints.webSidebar &&
        selector != null &&
        GuTab.ofLocation(location) != null;
    return GuWebFrame(
      framed: framed,
      showSidebar: hasSidebar,
      sidebar: selector == null ? null : AppSidebar(location: location),
      child: WebLayoutScope(isSidebarVisible: hasSidebar, child: child),
    );
  }
}
