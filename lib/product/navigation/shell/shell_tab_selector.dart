import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:gu_kulupler/product/navigation/app_navigator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shell_tab_selector.g.dart';

/// Uygulama kabuğunun sekme seçicisi (H-23): web yan menüsü
/// (`AppSidebar`) yönlendiricinin üstünde çizilir, dal kabına
/// (`StatefulNavigationShell`) erişemez. Kabuk (`AppShellView`) kurulunca
/// seçim kuralını buraya bağlar ([attach]), kaldırılınca çözer ([detach]);
/// yan menü yalnızca bağlı bir seçici varken çizilir (etkin oturum).
@Riverpod(keepAlive: true)
final class ShellTabSelector extends _$ShellTabSelector {
  @override
  ValueChanged<GuTab>? build() => null;

  /// [select] kabuğun sekme seçim kuralıdır (`AppShellView.selectTab`).
  void attach(ValueChanged<GuTab> select) => state = select;

  /// [select] hâlâ bağlıysa çözer (yeni kabuk önce bağlandıysa dokunmaz).
  /// Kapsayıcı söküldüyse (uygulama / test kapanışı) etkisizdir.
  void detach(ValueChanged<GuTab> select) {
    if (!ref.mounted) return;
    if (identical(state, select)) state = null;
  }
}
