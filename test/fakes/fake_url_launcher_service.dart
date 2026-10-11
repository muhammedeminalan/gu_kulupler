// `UrlLauncherService` fake'i (PLAN §16.3, CD-08): adresleri açmaz, kaydeder.
//
//   final launcher = FakeUrlLauncherService();
//   await viewModel.contactSupport();
//   expect(launcher.opened, [Uri(scheme: 'mailto', path: supportEmail)]);
//   launcher.canOpen = false; // cihazda açabilecek uygulama yok
import 'package:gu_kulupler/product/service/url_launcher_service.dart';

import 'fake_base.dart';

final class FakeUrlLauncherService extends FakeBase
    implements UrlLauncherService {
  /// Açılması istenen adresler, sırasıyla (açılamayanlar dahil).
  final List<Uri> opened = <Uri>[];

  /// [open] sonucu: `false` → cihazda adresi açabilecek uygulama yok.
  bool canOpen = true;

  /// Gerçek servis gibi hiçbir zaman fırlatmaz: bekleyen hata (`failNext`)
  /// `false` sonucuna çevrilir.
  @override
  Future<bool> open(Uri uri) async {
    record('open', [uri]);
    opened.add(uri);
    if (takeFailure() != null) return false;
    return canOpen;
  }

  @override
  void resetFake() {
    super.resetFake();
    opened.clear();
    canOpen = true;
  }
}
