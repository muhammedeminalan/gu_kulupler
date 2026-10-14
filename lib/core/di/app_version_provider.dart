import 'package:get_it/get_it.dart';
import 'package:gu_kulupler/product/service/app_info_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_version_provider.g.dart';

/// View katmanının uygulama sürümü köprüsü: `AppInfoService.version` (ör.
/// `1.0.0`; okunamadıysa boş — satır çizilmez). SET-01 sürüm satırı okur.
///
/// SET-01'in ayrı ViewModel'i yoktur (PLAN §12.12); view katmanı servis
/// bulucu çağıramadığı için (HC13) değer bu köprüden okunur
/// (`appClockProvider` kalıbı, CD-93). ViewModel'ler (SET-04
/// `AboutViewModel`) `ProjectDependencyMixin.appInfoService` kullanır. Testte
/// `registerDefaultFakes` `FakeAppInfoService` kaydeder.
@Riverpod(keepAlive: true)
String appVersion(Ref ref) => GetIt.I<AppInfoService>().version;
