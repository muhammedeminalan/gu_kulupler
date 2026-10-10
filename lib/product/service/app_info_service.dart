import 'package:gu_kulupler/core/error/app_logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Kurulu uygulamanın sürüm bilgisi (CD-08): zorunlu güncelleme kapısı
/// (DLG-26) ve Hakkında ekranı (SET-04). Sürüm kodda sabit **yazılmaz**.
abstract interface class AppInfoService {
  /// Sürüm adı (`pubspec.yaml` `version:` — `+` öncesi), ör. `1.0.0`.
  String get version;

  /// Derleme numarası (`+` sonrası), ör. `1`. Okunamadıysa boş.
  String get buildNumber;

  /// [buildNumber] tam sayı olarak; sayı değilse `0` (kapı kapalı sayılır).
  int get buildCode;
}

/// [AppInfoService] uygulaması: `package_info_plus`.
final class PackageAppInfoService implements AppInfoService {
  /// Değerleri doğrudan verir (bkz. [load]).
  const PackageAppInfoService({
    required this.version,
    required this.buildNumber,
  });

  /// Platformdan okur. Hiçbir zaman fırlatmaz: okunamazsa boş değerler döner
  /// (sürüm metni gösterilmez, güncelleme kapısı açılmaz).
  static Future<PackageAppInfoService> load({
    Future<PackageInfo> Function() read = PackageInfo.fromPlatform,
  }) async {
    try {
      final info = await read();
      return PackageAppInfoService(
        version: info.version,
        buildNumber: info.buildNumber,
      );
    } on Object catch (error, stack) {
      AppLogger.warn(
        'Uygulama sürümü okunamadı',
        error: error,
        stackTrace: stack,
      );
      return const PackageAppInfoService(version: '', buildNumber: '');
    }
  }

  @override
  final String version;

  @override
  final String buildNumber;

  @override
  int get buildCode => int.tryParse(buildNumber.trim()) ?? 0;
}
