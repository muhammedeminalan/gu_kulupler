// SVG varlıklarının gerçekten yüklendiğini doğrulayan test yardımcısı (T-03).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pump_app.dart';

/// [assets] anahtarlarını tek ağaçta `SvgPicture.asset` ile çizer ve
/// yüklenemeyenleri `"<anahtar>: <neden>"` olarak döndürür.
///
/// Yakalanan yollar: `errorBuilder` çağrısı (ayrıştırma/okuma hatası) ve yer
/// tutucunun yerinde kalması (yükleme tamamlanmadı). Ayrıca flutter_svg
/// önbelleği yükleme hatasını ele alınmamış `Future` hatası olarak da
/// yayar (`cache.dart putIfAbsent`); bu, testi kendiliğinden düşürür.
Future<List<String>> pumpSvgAssets(
  WidgetTester tester,
  Iterable<String> assets, {
  double dimension = 24,
}) async {
  final failures = <String>[];
  await tester.pumpApp(
    SingleChildScrollView(
      child: Wrap(
        children: [
          for (final asset in assets)
            SvgPicture.asset(
              asset,
              key: ValueKey<String>(asset),
              width: dimension,
              height: dimension,
              placeholderBuilder: (_) =>
                  SizedBox(key: ValueKey<String>('placeholder:$asset')),
              errorBuilder: (_, error, _) {
                failures.add('$asset: $error');
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
    ),
  );
  await tester.pump();
  for (final asset in assets) {
    final placeholder = find.byKey(ValueKey<String>('placeholder:$asset'));
    if (placeholder.evaluate().isNotEmpty) {
      failures.add('$asset: yüklenmedi (yer tutucu duruyor)');
    }
  }
  return failures;
}
