// T-44 · profil ölçümü sürücüsü: `integration_test/perf/*_perf_test.dart`
// senaryolarının `traceAction` zaman çizelgelerini özetler ve `build/`
// altına yazar:
//
// * `<anahtar>.timeline_summary.json` — ortalama / 90p / 99p / en kötü kare
//   yapım ve raster süreleri, takılan (16 ms'yi aşan) kare sayısı
//   (`TimelineSummary`).
// * `<anahtar>.timeline.json` — DevTools / Perfetto'da açılabilen ham
//   zaman çizelgesi.
// * `perf_report_data.json` — sayısal ölçümler (açılış ms vb.).
//
// Komut (profil derlemesi, gerçek cihaz):
//
//   flutter drive --profile --driver=test_driver/perf_driver.dart \
//     --target=integration_test/perf/club_list_scroll_perf_test.dart \
//     --dart-define=ENV=emulator --dart-define=EMULATOR_HOST=<Mac IP>
//
// Ayrıntı ve eşikler: `docs/reports/T-44-perf.md`.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Özetlerin yazıldığı klasör (`flutter drive` çalışma dizinine göre).
const String _outputDirectory = 'build';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final numbers = <String, Object?>{};
    for (final MapEntry(:key, :value) in data.entries) {
      if (value is Map<String, dynamic> && value.containsKey('traceEvents')) {
        final timeline = driver.Timeline.fromJson(value);
        final summary = driver.TimelineSummary.summarize(timeline);
        await summary.writeTimelineToFile(
          key,
          destinationDirectory: _outputDirectory,
          pretty: true,
        );
      } else {
        numbers[key] = value;
      }
    }
    if (numbers.isEmpty) return;
    final file = File('$_outputDirectory/perf_report_data.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(numbers),
    );
  },
);
