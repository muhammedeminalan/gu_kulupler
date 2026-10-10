// T-10 · RemoteConfigKeys: anahtar adları architecture §11 ve PLAN §10.2 ile
// birebir.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

void main() {
  group('T-10 · RemoteConfigKeys', () {
    test('dört anahtar, konsoldaki adlarla', () {
      expect(RemoteConfigKeys.minSupportedBuild, 'min_supported_build');
      expect(RemoteConfigKeys.maintenanceMessage, 'maintenance_message');
      expect(
        RemoteConfigKeys.announcementDailyLimit,
        'announcement_daily_limit',
      );
      expect(RemoteConfigKeys.reapplyCooldownDays, 'reapply_cooldown_days');
      expect(RemoteConfigKeys.all, [
        RemoteConfigKeys.minSupportedBuild,
        RemoteConfigKeys.maintenanceMessage,
        RemoteConfigKeys.announcementDailyLimit,
        RemoteConfigKeys.reapplyCooldownDays,
      ]);
      expect(RemoteConfigKeys.all.toSet(), hasLength(4));
    });

    test('architecture §11 anahtar listesiyle aynı küme', () {
      final architecture = readRepoFile('docs/architecture.md').split('\n');
      final heading = architecture.indexWhere(
        (line) => line.startsWith('## 11. Remote Config anahtarları'),
      );
      final section = architecture
          .skip(heading + 1)
          .takeWhile((line) => !line.startsWith('## '))
          .join('\n');
      final documented = codeSpans(section).where(
        (span) => RegExp(r'^[a-z]+(_[a-z]+)+$').hasMatch(span),
      );

      expect(documented.toSet(), RemoteConfigKeys.all.toSet());
    });
  });
}
