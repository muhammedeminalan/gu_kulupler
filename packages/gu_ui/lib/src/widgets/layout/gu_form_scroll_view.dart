import 'package:flutter/widgets.dart';

/// Metin alanı içeren form sayfalarının kaydırması — `SingleChildScrollView`
/// + sürükleyince klavye kapanır (kullanıcı kararı, K-93).
///
/// Flutter'ın `ScrollViewKeyboardDismissBehavior.onDrag` davranışı gibidir,
/// ama yalnızca **bu kaydırmanın kendi** sürüklemesine (`depth == 0`) tepki
/// verir: çok satırlı metin alanının kendi içinde kaydırılması (açıklama,
/// biyografi, not) odağı bırakmaz. `onDrag` iç kaydırıcının bildirimini de
/// dinlediği için Android'de alan içinde kaydırmak klavyeyi kapatıyordu.
///
/// * Sürükleme alanın üstünden başlasa da sayfa kayıyorsa klavye kapanır;
///   alanın dışına dokunma zaten `GuInput`'ta odağı bırakır (K-93).
/// * Odak bu kapsamın kendisindeyse (alan değil) dokunulmaz — Flutter
///   `onDrag` koşulunun aynısı.
/// * [key] kaydırmaya değil sarmalayıcıya gider: `PageStorageKey` (adım
///   başına kaydırma konumu) aynı şekilde işler.
class GuFormScrollView extends StatelessWidget {
  /// [child] formunu kaydırır.
  const GuFormScrollView({
    required this.child,
    this.padding,
    this.controller,
    super.key,
  });

  /// Kaydırılan içerik.
  final Widget child;

  /// İçerik dolgusu (`SingleChildScrollView.padding`).
  final EdgeInsetsGeometry? padding;

  /// Kaydırma denetleyicisi; `null` → kendi kurar.
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) {
          if (notification.depth != 0 || notification.dragDetails == null) {
            return false;
          }
          final scope = FocusScope.of(context);
          if (!scope.hasPrimaryFocus && scope.hasFocus) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
          return false;
        },
        child: SingleChildScrollView(
          controller: controller,
          padding: padding,
          child: child,
        ),
      );
}
