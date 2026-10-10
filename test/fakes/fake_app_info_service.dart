// `AppInfoService` fake'i (PLAN §16.3, CD-08): sürüm ve derleme numarası
// alanlardan okunur.
//
//   final info = FakeAppInfoService()..buildNumber = '7';
import 'package:gu_kulupler/product/service/app_info_service.dart';

import 'fake_base.dart';

final class FakeAppInfoService extends FakeBase implements AppInfoService {
  @override
  String version = '1.0.0';

  @override
  String buildNumber = '1';

  /// Gerçek servisle aynı kural: sayı değilse `0`.
  @override
  int get buildCode => int.tryParse(buildNumber.trim()) ?? 0;
}
