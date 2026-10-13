// T-16 · DebugMenu · demo kulüpler: `DebugDemoClubs` ↔
// `tool/seed/demo-data.json#clubs` (kulüp var, aktif, katılım biçimi satır
// etiketiyle aynı). Beklentiler dosyadan okunur; seed değişirse test kırılır.
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_kulupler/features/system/debug_menu/provider/debug_demo_clubs.dart';

import '../../../../helpers/design_files.dart';

void main() {
  group('T-16 · DebugMenu · demo kulüpler', () {
    final seed = readJsonMap('tool/seed/demo-data.json');
    final clubs = seed['clubs'] as Map<String, dynamic>;

    test('her katılım biçiminden bir kulüp; kimlikler tekil', () {
      expect(
        [for (final club in DebugDemoClubs.all) club.kind],
        DebugDemoClubKind.values,
      );
      expect(
        {for (final club in DebugDemoClubs.all) club.id},
        hasLength(DebugDemoClubs.all.length),
      );
    });

    test('kulüpler seed verisinde vardır ve aktiftir', () {
      for (final club in DebugDemoClubs.all) {
        final data = clubs[club.id] as Map<String, dynamic>?;
        expect(data, isNotNull, reason: club.id);
        expect(data!['status'], 'active', reason: club.id);
      }
    });

    test('katılım biçimi seed alanlarıyla aynıdır (approvalRequired, '
        'applicationsOpen)', () {
      for (final club in DebugDemoClubs.all) {
        final data = clubs[club.id] as Map<String, dynamic>;
        final expected = switch ((
          data['applicationsOpen'] as bool,
          data['approvalRequired'] as bool,
        )) {
          (false, _) => DebugDemoClubKind.closed,
          (true, true) => DebugDemoClubKind.approval,
          (true, false) => DebugDemoClubKind.instant,
        };
        expect(club.kind, expected, reason: club.id);
      }
    });
  });
}
