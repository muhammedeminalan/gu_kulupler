// T-44 · R-02 kapak SVG mikro ölçümü (kalite kapısına GİRMEZ — `flutter
// test` yalnızca `test/` klasörünü koşar).
//
// `assets/covers/*.svg` (26 kapak: 14 demo + 12 şablon) ve
// `assets/patterns/*.svg` (4 desen) için flutter_svg'nin uygulamada izlediği
// yol ölçülür (`SvgPicture` → `SvgLoader.loadBytes` → `vg.loadPicture`):
//
// * **ilk** — önbellek boşken: XML ayrıştırma + vector_graphics derleme
//   (`vg.encodeSvg`) + çizim komutlarının `Picture`'a çözülmesi.
// * **önbellekli** — derlenmiş baytlar `svg.cache`'teyken (aynı kapak ikinci
//   kez çizilir): yalnızca `Picture` çözümü.
// * **ikonlu şablon** — `GuCovers.composeTemplate` (şablon + kulüp ikonu):
//   her şablon × ikon çifti ayrı önbellek anahtarıdır.
//
// Debug (JIT) test ortamında ölçülür: mutlak süreler cihazdaki AOT profil /
// sürüm derlemesinden yüksektir; dosyalar arası oran ve ilk / önbellekli
// farkı anlamlıdır. Isınma turu atılır, her dosya [_runs] kez ölçülür
// (ortanca). Sonuç `build/cover_svg_bench.json` dosyasına ve standart
// çıktıya yazılır; rapor: `docs/reports/T-44-perf.md`.
//
//   flutter test benchmark/
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_ui/gu_ui.dart';

/// Dosya başına ölçüm sayısı (ortanca alınır).
const int _runs = 7;

/// Raporlanan en ağır dosya sayısı.
const int _heaviest = 5;

/// Kulüp ikonuyla birleştirilen şablon ölçümünde kullanılan ikon.
const GuIcons _clubIcon = GuIcons.mountain;

/// Ölçülen tek dosya.
final class _Sample {
  _Sample(this.name, this.svg);

  final String name;
  final String svg;
  final List<int> coldMicros = [];
  final List<int> cachedMicros = [];

  int get bytes => utf8.encode(svg).length;

  int get elements => RegExp(
    r'<(circle|path|rect|line|polygon|polyline|ellipse)\b',
  ).allMatches(svg).length;

  int get circles => RegExp(r'<circle\b').allMatches(svg).length;

  static int _median(List<int> values) {
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }

  int get coldMedian => _median(coldMicros);

  int get cachedMedian => _median(cachedMicros);

  Map<String, Object> toJson() => {
    'file': name,
    'bytes': bytes,
    'elements': elements,
    'circles': circles,
    'coldMedianUs': coldMedian,
    'cachedMedianUs': cachedMedian,
  };
}

/// [svg] kapağını uygulamadaki yoldan yükler; geçen süre (µs).
Future<int> _load(String svg) async {
  final watch = Stopwatch()..start();
  final info = await vg.loadPicture(SvgStringLoader(svg), null);
  final elapsed = watch.elapsedMicroseconds;
  info.picture.dispose();
  return elapsed;
}

List<_Sample> _read(String directory) {
  final files =
      Directory(directory)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.svg'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      _Sample(file.uri.pathSegments.last, file.readAsStringSync()),
  ];
}

Future<void> _measure(List<_Sample> samples) async {
  // Isınma: JIT derleyicisi ilk dosyada ısınır; sonuç atılır.
  for (final sample in samples) {
    svg.cache.clear();
    await _load(sample.svg);
  }
  for (var run = 0; run < _runs; run++) {
    for (final sample in samples) {
      svg.cache.clear();
      sample.coldMicros.add(await _load(sample.svg));
      sample.cachedMicros.add(await _load(sample.svg));
    }
  }
}

String _ms(int micros) =>
    (micros / Duration.microsecondsPerMillisecond).toStringAsFixed(2);

void main() {
  test('R-02 · kapak ve desen SVG ayrıştırma süreleri', () async {
    final covers = _read('assets/covers');
    final patterns = _read('assets/patterns');
    expect(covers, hasLength(26));
    expect(patterns, hasLength(4));

    final iconSvg = File(_clubIcon.assetPath).readAsStringSync();
    final composed = [
      for (final template in covers.where(
        (s) => s.name.startsWith('template-'),
      ))
        _Sample(
          '${template.name} + ${_clubIcon.fileName}',
          GuCovers.composeTemplate(template.svg, iconSvg),
        ),
    ];

    final all = [...covers, ...patterns, ...composed];
    await _measure(all);

    int total(List<_Sample> samples, int Function(_Sample) of) =>
        samples.fold(0, (sum, sample) => sum + of(sample));
    final heaviest = [...covers]
      ..sort((a, b) => b.coldMedian.compareTo(a.coldMedian));
    final report = <String, Object>{
      'mode': kDebugMode ? 'debug (JIT, flutter test)' : 'profile/release',
      'runsPerFile': _runs,
      'covers': {
        'count': covers.length,
        'totalColdMs': _ms(total(covers, (s) => s.coldMedian)),
        'totalCachedMs': _ms(total(covers, (s) => s.cachedMedian)),
        'totalBytes': total(covers, (s) => s.bytes),
        'totalCircles': total(covers, (s) => s.circles),
      },
      'heaviest': [for (final s in heaviest.take(_heaviest)) s.toJson()],
      'patterns': [for (final s in patterns) s.toJson()],
      'composedTemplates': {
        'icon': _clubIcon.fileName,
        'medianColdMs': _ms(
          (composed.map((s) => s.coldMedian).toList()
            ..sort())[composed.length ~/ 2],
        ),
      },
      'files': [for (final s in all) s.toJson()],
    };

    final out = File('build/cover_svg_bench.json');
    await out.parent.create(recursive: true);
    await out.writeAsString(const JsonEncoder.withIndent('  ').convert(report));

    final lines = StringBuffer()
      ..writeln('R-02 kapak SVG ölçümü (${report['mode']}, ortanca/$_runs)')
      ..writeln('dosya | bayt | öğe | daire | ilk ms | önbellekli ms');
    for (final s in all) {
      lines.writeln(
        '${s.name} | ${s.bytes} | ${s.elements} | ${s.circles} | '
        '${_ms(s.coldMedian)} | ${_ms(s.cachedMedian)}',
      );
    }
    stdout.write(lines);

    for (final s in all) {
      expect(s.coldMicros, hasLength(_runs));
    }
  });
}
