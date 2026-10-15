// T-42 bağlama (CD-165 c, d) · sunucu push'u ↔ istemci sözleşmesi:
// `firebase/test/contracts/push_contract.json`. Aynı dosyayı
// `functions/test/push_contract.test.ts` okur (sunucunun tercih süzgeci,
// FCM `data` yükü ve jeton okuması). Burada istemci tarafı sınanır:
//
// * `preferences` — `NotificationPreferenceFilter` (gelen kutusu süzgeci)
//   sunucunun push süzgeciyle aynı kararı verir;
// * `payloads` — sunucunun `data` yükü `NotificationNavigator.openPush`'un
//   kullandığı anahtarlarla (`MessagingService.notificationIdKey` /
//   `typeKey`) ve `NotificationRefsModel.fromJson` ile belgenin `refs`'ine
//   birebir geri döner (ağ hatasında yükten açılış yolu);
// * `tokens` — `FcmTokenModel.toJson` sunucunun okuduğu alanları yazar,
//   `locale` olmayan eski öğe `tr` okunur.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gu_data/gu_data.dart';

import '../helpers/repo_sources.dart';

const String _contractPath = 'firebase/test/contracts/push_contract.json';

/// Sözleşmedeki istemci zamanı nöbetçisi.
const String _now = '@now';

void main() {
  final contract = readRepoJson(_contractPath);
  final uid = contract['uid']! as String;
  final preferences = (contract['preferences']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final payloads = (contract['payloads']! as List<Object?>)
      .cast<Map<String, Object?>>();
  final tokens = contract['tokens']! as Map<String, Object?>;

  group('T-42 · push sözleşmesi (functions ile ortak dosya)', () {
    for (final row in preferences) {
      test('tercih süzgeci — ${row['name']}', () {
        final raw = row['settings'] as Map<String, Object?>?;
        final settings = raw == null
            ? UserSettingsModel.defaults(uid)
            : UserSettingsModel.fromJson(raw, id: uid);
        final allowed = (row['allowed']! as Map<String, Object?>)
            .cast<String, bool>();

        final actual = {
          for (final type in allowed.keys)
            type: NotificationPreferenceFilter.allows(
              NotificationModel(
                id: '${type}_k_$uid',
                userId: uid,
                type: NotificationType.fromJson(type),
                refs: NotificationRefsModel(clubId: row['clubId'] as String?),
              ),
              settings,
            ),
        };

        expect(actual, allowed);
      });
    }

    test('sözleşme bilinen her türü en az bir kez kapsar', () {
      final types = {
        for (final row in preferences)
          ...(row['allowed']! as Map<String, Object?>).keys,
      };
      for (final type in NotificationType.values) {
        if (type == NotificationType.unknown) continue;
        expect(types, contains(type.json));
      }
    });

    for (final row in payloads) {
      test("data yükü — ${row['type']}: openPush anahtarları ve refs geri "
          'dönüşü', () {
        final data = (row['data']! as Map<String, Object?>)
            .cast<String, String>();
        final refs = row['refs']! as Map<String, Object?>;

        expect(
          data[MessagingService.notificationIdKey],
          row['notificationId'],
        );
        final type = NotificationType.fromJson(
          data[MessagingService.typeKey] ?? '',
        );
        expect(type, isNot(NotificationType.unknown));
        expect(type.json, row['type']);
        // openPush'un ağ hatası dalı: yükün kendisinden refs.
        expect(
          NotificationRefsModel.fromJson(Map<String, Object?>.of(data)),
          NotificationRefsModel.fromJson(refs),
        );
        // Yük, belgenin refs'inden fazlasını taşımaz (kişisel veri yok).
        expect(
          data.keys.toSet(),
          {
            MessagingService.notificationIdKey,
            MessagingService.typeKey,
            ...refs.keys,
          },
        );
      });
    }

    test('jeton öğesi: FcmTokenModel.toJson sunucunun okuduğu biçimdir; '
        'locale olmayan eski öğe tr', () {
      final stored = (tokens['stored']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final read = (tokens['read']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final now = Timestamp.now();
      final parsed = [
        for (final item in stored)
          FcmTokenModel.fromJson({
            for (final MapEntry(:key, :value) in item.entries)
              key: value == _now ? now : value,
          }),
      ];

      expect(
        [
          for (final token in parsed)
            {'token': token.token, 'locale': token.locale},
        ],
        read,
      );
      // Tam öğe (locale'li) istemcinin yazdığı anahtar kümesiyle aynıdır.
      expect(parsed.first.toJson().keys.toSet(), stored.first.keys.toSet());
    });
  });
}
