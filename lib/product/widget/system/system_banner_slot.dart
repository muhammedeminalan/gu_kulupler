import 'package:flutter/widgets.dart';

/// Kök bant yuvası (`GuApp.builder` zinciri): [banner] varsa [child]'ın
/// üstüne, tam genişlikte çizer — prototip `ScreenHost`'un ekranın en üstüne
/// koyduğu bant (`shell.js:14`).
///
/// * Bant gerçek üst güvenli alanın **altında** başlar (K-07); altındaki
///   [child] üst güvenli alanı yeniden eklemez (`MediaQuery` üst dolgusu
///   sıfırlanır), böylece `GuAppBar` bandın hemen altından başlar.
/// * Bant yokken [child] olduğu gibi çizilir. Ağaç biçimi iki durumda da
///   aynıdır: bant açılıp kapanırken [child] (gezgin) yeniden kurulmaz.
/// * İç içe kullanılabilir: dıştaki bant üst güvenli alanı tüketir, içteki
///   ek boşluk bırakmaz.
class SystemBannerSlot extends StatelessWidget {
  /// [banner] `null` → bant yok.
  const SystemBannerSlot({
    required this.banner,
    required this.child,
    super.key,
  });

  /// Çizilecek bant (`GuBanner`); `null` → çizilmez.
  final Widget? banner;

  /// Bandın altındaki içerik (uygulama gövdesi).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final banner = this.banner;
    final media = MediaQuery.of(context);
    return Column(
      children: [
        if (banner == null)
          const SizedBox.shrink()
        else
          SafeArea(bottom: false, child: banner),
        Expanded(
          child: MediaQuery(
            data: banner == null ? media : media.removePadding(removeTop: true),
            child: child,
          ),
        ),
      ],
    );
  }
}
