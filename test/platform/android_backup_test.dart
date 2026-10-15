// T-45 (A3-01) · Android uygulama verisi bulut yedeğine ve cihazdan cihaza
// aktarıma girmez: Firebase Auth oturumu, Firestore kalıcı önbelleği (D-29
// private/* e-postaları), FlutterSharedPreferences (jetonlu görsel adresleri,
// taslaklar, son aramalar). Android varsayılanı `allowBackup="true"`dur;
// API 31+'da D2D yalnızca `dataExtractionRules` ile kapanır.
import 'package:flutter_test/flutter_test.dart';

import '../helpers/design_files.dart';

/// Yedekten bütünüyle dışlanması gereken alanlar.
const List<String> _domains = [
  'root',
  'file',
  'database',
  'sharedpref',
  'external',
];

/// `<tag …>…</tag>` bölümünün içi; yoksa `null`.
String? _section(String xml, String tag) =>
    RegExp('<$tag>([\\s\\S]*?)</$tag>').firstMatch(xml)?.group(1);

bool _excludes(String section, String domain) => RegExp(
  '<exclude\\s+domain="$domain"\\s+path="\\."\\s*/>',
).hasMatch(section);

void main() {
  group('T-45 · Android yedekleme (A3-01)', () {
    final manifest = readText('android/app/src/main/AndroidManifest.xml');
    final application = RegExp(
      r'<application\b[^>]*>',
    ).firstMatch(manifest)!.group(0)!;

    test('<application> yedeği kapatır ve kural dosyalarını gösterir', () {
      expect(application, contains('android:allowBackup="false"'));
      expect(
        application,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
      expect(
        application,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
    });

    test("debug ve profile manifest'leri yedeği yeniden açmaz", () {
      for (final variant in const ['debug', 'profile']) {
        final text = readText('android/app/src/$variant/AndroidManifest.xml');
        expect(text, isNot(contains('allowBackup')), reason: variant);
        expect(text, isNot(contains('dataExtractionRules')), reason: variant);
      }
    });

    test('data_extraction_rules (API 31+): bulut yedeği ve cihaz aktarımı '
        'tüm alanları dışlar, hiçbir şey dahil edilmez', () {
      final rules = readText(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      );
      expect(rules, isNot(contains('<include')));
      for (final tag in const ['cloud-backup', 'device-transfer']) {
        final section = _section(rules, tag);
        expect(section, isNotNull, reason: tag);
        for (final domain in _domains) {
          expect(_excludes(section!, domain), isTrue, reason: '$tag/$domain');
        }
      }
    });

    test('backup_rules (API ≤ 30): tam yedek tüm alanları dışlar', () {
      final rules = readText('android/app/src/main/res/xml/backup_rules.xml');
      expect(rules, isNot(contains('<include')));
      final section = _section(rules, 'full-backup-content');
      expect(section, isNotNull);
      for (final domain in _domains) {
        expect(_excludes(section!, domain), isTrue, reason: domain);
      }
    });
  });
}
